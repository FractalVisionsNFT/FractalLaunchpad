// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {ProxyFactory} from "../src/Factory.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {FractalERC1155Impl} from "../src/FractalERC1155.sol";

contract FractalLaunchpadScript is Script {
    function run() public {
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint256 platformFee = vm.envUint("PLATFORM_FEE"); // e.g., 10000000000000000 = 0.01 ether

        vm.startBroadcast();

        // 1. Deploy implementations
        console.log("Deploying ERC721 Implementation...");
        FractalERC721Impl erc721Implementation = new FractalERC721Impl();
        console.log("ERC721 Implementation deployed at:", address(erc721Implementation));

        console.log("Deploying ERC1155 Implementation...");
        FractalERC1155Impl erc1155Implementation = new FractalERC1155Impl();
        console.log("ERC1155 Implementation deployed at:", address(erc1155Implementation));

        // 2. Deploy factory
        console.log("Deploying ProxyFactory...");
        ProxyFactory factory = new ProxyFactory();
        console.log("Factory deployed at:", address(factory));

        // 3. Deploy launchpad
        console.log("Deploying FractalLaunchpad...");
        FractalLaunchpad launchpad = new FractalLaunchpad(
            feeRecipient,
            platformFee,
            address(erc1155Implementation),
            address(erc721Implementation),
            address(factory)
        );
        console.log("FractalLaunchpad deployed at:", address(launchpad));

        // 4. Grant CREATOR_ROLE to launchpad
        factory.grantRole(factory.CREATOR_ROLE(), address(launchpad));
        console.log("Granted CREATOR_ROLE to Launchpad");

        vm.stopBroadcast();

        // Log summary
        console.log("\n=== Deployment Summary ===");
        console.log("ERC721 Implementation:", address(erc721Implementation));
        console.log("ERC1155 Implementation:", address(erc1155Implementation));
        console.log("Factory:              ", address(factory));
        console.log("Launchpad:            ", address(launchpad));
        console.log("Fee Recipient:        ", feeRecipient);
        console.log("Platform Fee:         ", platformFee);
    }
}