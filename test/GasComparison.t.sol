// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FractalERC1155Impl} from "../src/FractalERC1155.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {LicenseVersion} from "../src/FractalERC1155.sol";
import {ProxyFactory} from "../src/Factory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GasComparisonTest is Test {
    FractalERC1155Impl public erc1155Impl;
    FractalERC721Impl public erc721Impl;
    ProxyFactory public factory;

    address public owner;

    function setUp() public {
        owner = makeAddr("owner");
        vm.startPrank(owner);
        erc1155Impl = new FractalERC1155Impl();
        erc721Impl = new FractalERC721Impl();
        factory = new ProxyFactory();
        factory.grantRole(factory.CREATOR_ROLE(), owner);
        vm.stopPrank();
    }

    function test_GasCost_ProxyFactory_ERC1155() public {
        vm.startPrank(owner);

        uint256 gasBefore = gasleft();
        factory.createClone(
            address(erc1155Impl),
            "Test Collection",
            "TEST",
            1000,
            "ipfs://QmTestHash/",
            owner,
            500,
            LicenseVersion.COMMERCIAL
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("=== ProxyFactory (ERC1967) - ERC1155 ===");
        console.log("Gas used:", gasUsed);
    }

    function test_GasCost_ProxyFactory_ERC721() public {
        vm.startPrank(owner);

        uint256 gasBefore = gasleft();
        factory.createClone(
            address(erc721Impl),
            "Test Collection",
            "TEST",
            1000,
            "https://test.com/",
            owner,
            500,
            LicenseVersion.COMMERCIAL
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("=== ProxyFactory (ERC1967) - ERC721 ===");
        console.log("Gas used:", gasUsed);
    }

    function test_GasCost_RawERC1967_ERC1155() public {
        bytes memory initData = abi.encodeWithSelector(
            FractalERC1155Impl.initialize.selector,
            "Test Collection",
            "TEST",
            1000,
            "ipfs://QmTestHash/",
            owner,
            500,
            LicenseVersion.COMMERCIAL
        );

        uint256 gasBefore = gasleft();
        new ERC1967Proxy(address(erc1155Impl), initData);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("=== Raw ERC1967 (no factory) - ERC1155 ===");
        console.log("Gas used:", gasUsed);
    }

    function test_GasCost_RawERC1967_ERC721() public {
        bytes memory initData = abi.encodeWithSelector(
            FractalERC721Impl.initialize.selector,
            "Test Collection",
            "TEST",
            1000,
            "https://test.com/",
            owner,
            500,
            LicenseVersion.COMMERCIAL
        );

        uint256 gasBefore = gasleft();
        new ERC1967Proxy(address(erc721Impl), initData);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("=== Raw ERC1967 (no factory) - ERC721 ===");
        console.log("Gas used:", gasUsed);
    }
}
