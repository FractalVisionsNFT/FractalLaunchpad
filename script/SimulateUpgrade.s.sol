// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {FractalERC1155Impl} from "../src/FractalERC1155.sol";

/// @notice LOCAL SIMULATION ONLY — Forks the live chain
/// Usage
/// -----
/// forge script script/SimulateUpgrade.s.sol --rpc-url op_mainnet --sender 0xC281F07d40119BFC670b90550c00E77E2AAfFaf0 -vvvv

contract SimulateUpgrade is Script {
    address constant LAUNCHPAD = 0x7A10b7d6Dc513Ae5F98f2C1546269Be9DE94ebD3;

    bytes32 constant SALT = bytes32(uint256(1));

    // ── Helpers ─────────────────────────────────────────────────────────── //

    function _create2Addr(
        bytes memory initcode,
        bytes32 salt_
    ) internal pure returns (address) {
        address FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        bytes32 h = keccak256(
            abi.encodePacked(bytes1(0xff), FACTORY, salt_, keccak256(initcode))
        );
        return address(uint160(uint256(h)));
    }

    // ── Main ─────────────────────────────────────────────────────────────── //

    function run() public {
        FractalLaunchpad launchpad = FractalLaunchpad(payable(LAUNCHPAD));

        // ── Read live state before anything changes ──────────────────────
        address launchpadOwner = launchpad.owner();
        address old721 = launchpad.erc721Implementation();
        address old1155 = launchpad.erc1155Implementation();

        console.log("=== Live State (before upgrade) ===");
        console.log("Launchpad:       ", LAUNCHPAD);
        console.log("Owner:           ", launchpadOwner);
        console.log("Old ERC721  impl:", old721);
        console.log("Old ERC1155 impl:", old1155);
        console.log("");

        // ── Predict CREATE2 addresses ────────────────────────────────────
        address predicted721 = _create2Addr(
            type(FractalERC721Impl).creationCode,
            SALT
        );
        address predicted1155 = _create2Addr(
            type(FractalERC1155Impl).creationCode,
            SALT
        );

        console.log("=== CREATE2 Predicted Addresses ===");
        console.log("ERC721  impl:", predicted721);
        console.log("ERC1155 impl:", predicted1155);
        console.log("");

        // ── Deploy new implementations () ─────────
        vm.startBroadcast();
        FractalERC721Impl newErc721 = new FractalERC721Impl{salt: SALT}();
        FractalERC1155Impl newErc1155 = new FractalERC1155Impl{salt: SALT}();
        vm.stopBroadcast();

        require(
            address(newErc721) == predicted721,
            "ERC721 CREATE2 address mismatch"
        );
        require(
            address(newErc1155) == predicted1155,
            "ERC1155 CREATE2 address mismatch"
        );

        console.log("=== Deployed (CREATE2 addresses confirmed) ===");
        console.log("ERC721  impl:", address(newErc721));
        console.log("ERC1155 impl:", address(newErc1155));
        console.log("");

        // ── Impersonate owner to call update functions ───────────────────
        // vm.prank / vm.startPrank are cheat codes — simulation only, never on-chain.
        console.log("=== Impersonating owner:", launchpadOwner, "===");

        vm.startPrank(launchpadOwner);
        launchpad.updateERC721Implementation(address(newErc721));
        launchpad.updateERC1155Implementation(address(newErc1155));
        vm.stopPrank();

        // ── Verify the update took effect ────────────────────────────────
        address new721 = launchpad.erc721Implementation();
        address new1155 = launchpad.erc1155Implementation();

        console.log("");
        console.log("=== Post-Upgrade Verification ===");

        // Implementation addresses updated
        require(
            new721 == address(newErc721),
            "ERC721 impl not updated on launchpad"
        );
        require(
            new1155 == address(newErc1155),
            "ERC1155 impl not updated on launchpad"
        );
        console.log("[PASS] ERC721  impl updated:", new721);
        console.log("[PASS] ERC1155 impl updated:", new1155);

        // Owner unchanged
        require(
            launchpad.owner() == launchpadOwner,
            "Owner changed - unexpected"
        );
        console.log("[PASS] Launchpad owner unchanged:", launchpadOwner);

        // Implementation contracts have no initializer set (correct for UUPS impls)
        require(
            newErc721.totalSupply() == 0,
            "ERC721 impl should have zero supply"
        );
        require(
            newErc1155.totalSupply(0) == 0,
            "ERC1155 impl should have zero supply"
        );
        console.log(
            "[PASS] New implementations are uninitialized (as expected)"
        );

        console.log("");
        console.log("=== Simulation complete - all checks passed ===");
        console.log(
            "Safe to broadcast DeployImplementations.s.sol with the owner keystore."
        );
    }
}
