// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {FractalERC1155Impl} from "../src/FractalERC1155.sol";

/// @notice Deploys new ERC721 and ERC1155 implementations via CREATE2 so every chain
///         gets the same deterministic address, then registers them with the live Launchpad.
///
/// Required env vars
/// -----------------
///   PRIVATE_KEY            – deployer private key
///   LAUNCHPAD_ADDRESS      – address of the already-deployed FractalLaunchpad
///   DEPLOY_SALT            – arbitrary bytes32 salt (hex string, e.g. 0xfractal01...)
///                            Keep the SAME value across all chains for the same addresses.
///
/// Optional env vars
/// -----------------
///   SKIP_UPDATE=true       – deploy implementations only, do NOT call the launchpad update
///                            (useful when deploying to a new chain where the launchpad
///                            is not yet live)
///
/// Usage examples
/// --------------
/// Dry-run (simulation):
///   forge script script/DeployImplementations.s.sol \
///       --rpc-url base_sepolia -vvvv
///
/// Live broadcast + verify:
///   forge script script/DeployImplementations.s.sol \
///       --rpc-url base_sepolia \
///       --broadcast --verify
///
/// Cross-chain (run once per chain, same salt → same addresses):
///   forge script script/DeployImplementations.s.sol --rpc-url op_mainnet  --broadcast --verify
///   forge script script/DeployImplementations.s.sol --rpc-url base_sepolia --broadcast --verify
contract DeployImplementations is Script {

    // ------------------------------------------------------------------ //
    //  Helpers                                                             //
    // ------------------------------------------------------------------ //

    /// @dev Predict the CREATE2 address that `vm.deployCode` will produce.
    ///      Forge's `vm.deployCode` uses the deployer's CREATE2 factory at
    ///      0x4e59b44847b379578588920cA78FbF26c0B4956C (Nick's factory),
    ///      so the address is: keccak256(0xff ++ factory ++ salt ++ keccak256(initcode))[12:]
    function _create2Addr(bytes memory initcode, bytes32 salt) internal pure returns (address) {
        // Nick's deterministic deployment factory (available on all major EVM chains)
        address FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        bytes32 h = keccak256(abi.encodePacked(bytes1(0xff), FACTORY, salt, keccak256(initcode)));
        return address(uint160(uint256(h)));
    }

    // ------------------------------------------------------------------ //
    //  Main                                                                //
    // ------------------------------------------------------------------ //

    function run() public {
        // ── Read env ────────────────────────────────────────────────────
        bytes32 salt         = vm.envBytes32("DEPLOY_SALT");
        address launchpadAddr = vm.envAddress("LAUNCHPAD_ADDRESS");
        bool skipUpdate      = vm.envOr("SKIP_UPDATE", false);

        // ── Predict addresses before broadcasting ───────────────────────
        bytes memory erc721Initcode  = type(FractalERC721Impl).creationCode;
        bytes memory erc1155Initcode = type(FractalERC1155Impl).creationCode;

        address predicted721  = _create2Addr(erc721Initcode,  salt);
        address predicted1155 = _create2Addr(erc1155Initcode, salt);

        console.log("=== CREATE2 Predicted Addresses ===");
        console.log("ERC721  implementation:", predicted721);
        console.log("ERC1155 implementation:", predicted1155);
        console.log("Salt (bytes32):        ", vm.toString(salt));
        console.log("");

        // ── Deploy ──────────────────────────────────────────────────────
        vm.startBroadcast();

        // CREATE2 via Nick's factory: prefix the initcode with the 32-byte salt.
        // Forge's `new{salt: ...}(...)` uses the same factory under the hood.
        FractalERC721Impl erc721Impl   = new FractalERC721Impl{salt: salt}();
        FractalERC1155Impl erc1155Impl = new FractalERC1155Impl{salt: salt}();

        console.log("=== Deployed Addresses ===");
        console.log("ERC721  implementation:", address(erc721Impl));
        console.log("ERC1155 implementation:", address(erc1155Impl));

        // Sanity-check: predicted == actual (will revert on mismatch)
        require(address(erc721Impl)  == predicted721,  "ERC721 address mismatch");
        require(address(erc1155Impl) == predicted1155, "ERC1155 address mismatch");

        // ── Update live Launchpad ────────────────────────────────────────
        if (!skipUpdate) {
            FractalLaunchpad launchpad = FractalLaunchpad(payable(launchpadAddr));

            address old721  = launchpad.erc721Implementation();
            address old1155 = launchpad.erc1155Implementation();

            console.log("");
            console.log("=== Updating Launchpad:", launchpadAddr, "===");
            console.log("Old ERC721  impl:", old721);
            console.log("New ERC721  impl:", address(erc721Impl));
            console.log("Old ERC1155 impl:", old1155);
            console.log("New ERC1155 impl:", address(erc1155Impl));

            launchpad.updateERC721Implementation(address(erc721Impl));
            launchpad.updateERC1155Implementation(address(erc1155Impl));

            console.log("Launchpad updated successfully");
        } else {
            console.log("");
            console.log("SKIP_UPDATE=true — Launchpad NOT updated");
            console.log("Run again without SKIP_UPDATE, or call updateERC721Implementation /");
            console.log("updateERC1155Implementation manually on:", launchpadAddr);
        }

        vm.stopBroadcast();

        // ── Final summary ────────────────────────────────────────────────
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Chain ID:              ", block.chainid);
        console.log("Salt:                  ", vm.toString(salt));
        console.log("ERC721  implementation:", address(erc721Impl));
        console.log("ERC1155 implementation:", address(erc1155Impl));
        if (!skipUpdate) {
            console.log("Launchpad updated at:  ", launchpadAddr);
        }
    }
}
