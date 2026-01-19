// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {MinimalProxy} from "../src/Factory.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {FractalERC1155Impl} from "../src/FractalERC1155.sol";

contract FractalLaunchpadScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint256 platformFee = vm.envUint("PLATFORM_FEE"); // e.g., 0.01 ether = 10000000000000000

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementations
        console.log("Deploying ERC721 Implementation...");
        FractalERC721Impl erc721Implementation = new FractalERC721Impl();
        console.log("ERC721 Implementation deployed at:", address(erc721Implementation));

        console.log("Deploying ERC1155 Implementation...");
        FractalERC1155Impl erc1155Implementation = new FractalERC1155Impl();
        console.log("ERC1155 Implementation deployed at:", address(erc1155Implementation));

        // 2. Deploy factory
        console.log("Deploying MinimalProxy Factory...");
        MinimalProxy factory = new MinimalProxy();
        console.log("Factory deployed at:", address(factory));

        // 3. Deploy launchpad
        console.log("Deploying FractalLaunchpad...");
        FractalLaunchpad launchpad = new FractalLaunchpad(
            feeRecipient, platformFee, address(erc1155Implementation), address(erc721Implementation), address(factory)
        );
        console.log("FractalLaunchpad deployed at:", address(launchpad));

        vm.stopBroadcast();

        // Log summary
        console.log("\n=== Deployment Summary ===");
        console.log("ERC721 Implementation:", address(erc721Implementation));
        console.log("ERC1155 Implementation:", address(erc1155Implementation));
        console.log("Factory:", address(factory));
        console.log("Launchpad:", address(launchpad));
        console.log("Fee Recipient:", feeRecipient);
        console.log("Platform Fee:", platformFee);
    }
}
