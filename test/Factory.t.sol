// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ProxyFactory} from "../src/Factory.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {LicenseVersion, FractalERC1155Impl} from "../src/FractalERC1155.sol";

contract ProxyFactoryTest is Test {
    ProxyFactory public factory;
    FractalERC721Impl public erc721Impl;
    FractalERC1155Impl public erc1155Impl;

    address public admin;
    address public creator;
    address public unauthorized;
    address public user;

    string public constant NAME = "Test Token";
    string public constant SYMBOL = "TT";
    uint256 public constant MAX_SUPPLY = 1000;
    string public constant BASE_URI = "https://test.com/";
    uint96 public constant ROYALTY_FEE = 500;

    function setUp() public {
        admin = makeAddr("admin");
        creator = makeAddr("creator");
        unauthorized = makeAddr("unauthorized");
        user = makeAddr("user");

        vm.startPrank(admin);
        factory = new ProxyFactory();
        erc721Impl = new FractalERC721Impl();
        erc1155Impl = new FractalERC1155Impl();
        factory.grantRole(factory.CREATOR_ROLE(), creator);
        vm.stopPrank();
    }

    // ============ Constructor / Roles ============

    function test_Constructor_AdminHasDefaultAdminRole() public {
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Constructor_AdminHasCreatorRole() public {
        assertTrue(factory.hasRole(factory.CREATOR_ROLE(), admin));
    }

    function test_Constructor_GrantedCreatorHasRole() public {
        assertTrue(factory.hasRole(factory.CREATOR_ROLE(), creator));
    }

    function test_Constructor_UnauthorizedHasNoRole() public {
        assertFalse(factory.hasRole(factory.CREATOR_ROLE(), unauthorized));
        assertFalse(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), unauthorized));
    }

    // ============ createClone Tests ============

    function test_CreateClone_ERC721_Success() public {
        vm.startPrank(creator);
        address proxyAddr = factory.createClone(
            address(erc721Impl), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.COMMERCIAL
        );
        vm.stopPrank();

        assertTrue(proxyAddr != address(0));
        assertTrue(proxyAddr.code.length > 0);

        FractalERC721Impl proxy = FractalERC721Impl(proxyAddr);
        assertEq(proxy.name(), NAME);
        assertEq(proxy.symbol(), SYMBOL);
        assertEq(proxy.maxSupply(), MAX_SUPPLY);
        assertEq(proxy.owner(), user);
    }

    function test_CreateClone_ERC1155_Success() public {
        vm.startPrank(creator);
        address proxyAddr = factory.createClone(
            address(erc1155Impl), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();

        assertTrue(proxyAddr != address(0));
        assertTrue(proxyAddr.code.length > 0);

        FractalERC1155Impl proxy = FractalERC1155Impl(proxyAddr);
        assertEq(proxy.name(), NAME);
        assertEq(proxy.symbol(), SYMBOL);
        assertEq(proxy.maxSupply(0), MAX_SUPPLY);
        assertEq(proxy.owner(), user);
    }

    function test_CreateClone_RevertIf_ZeroAddress() public {
        vm.startPrank(creator);
        vm.expectRevert(ProxyFactory.InvalidImplementation.selector);
        factory.createClone(
            address(0), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();
    }

    function test_CreateClone_RevertIf_NoCode() public {
        vm.startPrank(creator);
        vm.expectRevert(ProxyFactory.ImplementationHasNoCode.selector);
        factory.createClone(
            makeAddr("eoa"), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();
    }

    function test_CreateClone_RevertIf_NotCreatorRole() public {
        vm.startPrank(unauthorized);
        vm.expectRevert();
        factory.createClone(
            address(erc721Impl), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();
    }

    function test_CreateClone_TracksInMappings() public {
        vm.startPrank(creator);
        address proxy1 = factory.createClone(
            address(erc721Impl), "Token 1", "T1", 100, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        address proxy2 = factory.createClone(
            address(erc1155Impl), "Token 2", "T2", 200, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();

        // proxyToImplementation
        assertTrue(factory.isClone(address(erc721Impl), proxy1));
        assertTrue(factory.isClone(address(erc1155Impl), proxy2));
        assertFalse(factory.isClone(address(erc1155Impl), proxy1));
        assertFalse(factory.isClone(address(erc721Impl), proxy2));

        // deployerToContracts
        address[] memory creatorProxies = factory.getAllProxiesByDeployer(creator);
        assertEq(creatorProxies.length, 2);
        assertEq(creatorProxies[0], proxy1);
        assertEq(creatorProxies[1], proxy2);
    }

    // ============ View Functions ============

    function test_GetCloneAddress() public {
        vm.startPrank(creator);
        address proxy1 = factory.createClone(
            address(erc721Impl), "T1", "T1", 100, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        address proxy2 = factory.createClone(
            address(erc1155Impl), "T2", "T2", 200, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();

        assertEq(factory.getCloneAddress(0), proxy1);
        assertEq(factory.getCloneAddress(1), proxy2);
    }

    function test_GetAllCreatedAddresses() public {
        vm.startPrank(creator);
        address proxy1 = factory.createClone(
            address(erc721Impl), "T1", "T1", 100, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        address proxy2 = factory.createClone(
            address(erc1155Impl), "T2", "T2", 200, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();

        address[] memory all = factory.getAllCreatedAddresses();
        assertEq(all.length, 2);
        assertEq(all[0], proxy1);
        assertEq(all[1], proxy2);
    }

    function test_GetAllCreatedAddresses_EmptyInitially() public {
        address[] memory all = factory.getAllCreatedAddresses();
        assertEq(all.length, 0);
    }

    function test_GetAllProxiesByDeployer_EmptyForUnknown() public {
        address[] memory proxies = factory.getAllProxiesByDeployer(unauthorized);
        assertEq(proxies.length, 0);
    }

    function test_IsClone_FalseForRandomAddress() public {
        assertFalse(factory.isClone(address(erc721Impl), makeAddr("random")));
    }

    function test_IsClone_FalseForZeroAddress() public {
        assertFalse(factory.isClone(address(erc721Impl), address(0)));
    }

    // ============ Role Management ============

    function test_GrantCreatorRole() public {
        address newCreator = makeAddr("newCreator");
        bytes32 role = factory.CREATOR_ROLE();

        vm.prank(admin);
        factory.grantRole(role, newCreator);
        assertTrue(factory.hasRole(role, newCreator));

        // New creator can create clones
        vm.prank(newCreator);
        address proxyAddr = factory.createClone(
            address(erc721Impl), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        assertTrue(proxyAddr != address(0));
    }

    function test_RevokeCreatorRole() public {
        bytes32 role = factory.CREATOR_ROLE();

        vm.prank(admin);
        factory.revokeRole(role, creator);
        assertFalse(factory.hasRole(role, creator));
    }

    function test_RevokeCreatorRole_CannotCreateAfter() public {
        bytes32 role = factory.CREATOR_ROLE();

        vm.prank(admin);
        factory.revokeRole(role, creator);

        vm.startPrank(creator);
        vm.expectRevert();
        factory.createClone(
            address(erc721Impl), NAME, SYMBOL, MAX_SUPPLY, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );
        vm.stopPrank();
    }

    function test_GrantRole_RevertIf_NotAdmin() public {
        bytes32 role = factory.CREATOR_ROLE();

        vm.prank(unauthorized);
        vm.expectRevert();
        factory.grantRole(role, unauthorized);
    }

    // ============ Multiple Deployers ============

    function test_MultipleDeployers_TrackedSeparately() public {
        address creator2 = makeAddr("creator2");
        bytes32 role = factory.CREATOR_ROLE();

        vm.prank(admin);
        factory.grantRole(role, creator2);

        vm.prank(creator);
        address proxy1 = factory.createClone(
            address(erc721Impl), "T1", "T1", 100, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );

        vm.prank(creator2);
        address proxy2 = factory.createClone(
            address(erc1155Impl), "T2", "T2", 200, BASE_URI, user, ROYALTY_FEE, LicenseVersion.PUBLIC
        );

        address[] memory creator1Proxies = factory.getAllProxiesByDeployer(creator);
        address[] memory creator2Proxies = factory.getAllProxiesByDeployer(creator2);

        assertEq(creator1Proxies.length, 1);
        assertEq(creator2Proxies.length, 1);
        assertEq(creator1Proxies[0], proxy1);
        assertEq(creator2Proxies[0], proxy2);

        address[] memory all = factory.getAllCreatedAddresses();
        assertEq(all.length, 2);
    }
}
