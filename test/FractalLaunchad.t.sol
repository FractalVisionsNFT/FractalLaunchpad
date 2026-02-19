// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {ProxyFactory} from "../src/Factory.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {LicenseVersion, FractalERC1155Impl} from "../src/FractalERC1155.sol";

contract FractalLaunchpadTest is Test {
    FractalLaunchpad public launchpad;
    ProxyFactory public factory;
    FractalERC721Impl public erc721Implementation;
    FractalERC1155Impl public erc1155Implementation;

    address public owner;
    address public feeRecipient;
    address public creator;
    address public user;
    address public unauthorized;

    uint256 public constant PLATFORM_FEE = 0.01 ether;
    uint256 public constant MAX_SUPPLY = 1000;
    uint96 public constant ROYALTY_FEE = 500; // 5%
    string public constant NAME = "Test NFT";
    string public constant SYMBOL = "TNFT";
    string public constant BASE_URI = "https://test.com/";

    event LaunchCreated(
        uint256 launchId,
        FractalLaunchpad.TokenType indexed tokenType,
        address indexed tokenContract,
        address indexed creator
    );

    function setUp() public {
        owner = makeAddr("owner");
        feeRecipient = makeAddr("feeRecipient");
        creator = makeAddr("creator");
        user = makeAddr("user");
        unauthorized = makeAddr("unauthorized");

        vm.startPrank(owner);

        // Deploy implementations
        erc721Implementation = new FractalERC721Impl();
        erc1155Implementation = new FractalERC1155Impl();

        // Deploy factory
        factory = new ProxyFactory();

        // Deploy launchpad
        launchpad = new FractalLaunchpad(
            feeRecipient, PLATFORM_FEE, address(erc1155Implementation), address(erc721Implementation), address(factory)
        );

        // Grant CREATOR_ROLE to the launchpad so it can call createClone
        factory.grantRole(factory.CREATOR_ROLE(), address(launchpad));

        vm.stopPrank();

        // Give some ETH to users
        vm.deal(creator, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(unauthorized, 10 ether);
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        assertEq(launchpad.owner(), owner);
        assertEq(launchpad.feeRecipient(), feeRecipient);
        assertEq(launchpad.platformFee(), PLATFORM_FEE);
        assertEq(address(launchpad.NFT_FACTORY()), address(factory));
        assertEq(launchpad.erc721Implementation(), address(erc721Implementation));
        assertEq(launchpad.erc1155Implementation(), address(erc1155Implementation));
        assertEq(launchpad.nextLaunchId(), 0);
    }

    function test_Constructor_RevertIf_InvalidFeeRecipient() public {
        vm.expectRevert(FractalLaunchpad.InvalidFeeRecipient.selector);
        new FractalLaunchpad(
            address(0), PLATFORM_FEE, address(erc1155Implementation), address(erc721Implementation), address(factory)
        );
    }

    function test_Constructor_RevertIf_InvalidERC1155Implementation() public {
        vm.expectRevert(FractalLaunchpad.InvalidERC1155Implementation.selector);
        new FractalLaunchpad(feeRecipient, PLATFORM_FEE, address(0), address(erc721Implementation), address(factory));
    }

    function test_Constructor_RevertIf_InvalidERC721Implementation() public {
        vm.expectRevert(FractalLaunchpad.InvalidERC721Implementation.selector);
        new FractalLaunchpad(feeRecipient, PLATFORM_FEE, address(erc1155Implementation), address(0), address(factory));
    }

    function test_Constructor_RevertIf_InvalidFactory() public {
        vm.expectRevert(FractalLaunchpad.InvalidFactory.selector);
        new FractalLaunchpad(
            feeRecipient, PLATFORM_FEE, address(erc1155Implementation), address(erc721Implementation), address(0)
        );
    }

    // ============ Create Launch Tests ============

    function test_CreateLaunch_ERC721_Success() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        assertEq(launchId, 0);
        assertEq(launchpad.nextLaunchId(), 1);

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        assertEq(uint8(config.tokenType), uint8(FractalLaunchpad.TokenType.ERC721));
        assertEq(config.creator, creator);
        assertEq(config.maxSupply, MAX_SUPPLY);
        assertEq(config.baseURI, BASE_URI);
        assertTrue(config.tokenContract != address(0));

        // Check creator mapping
        address[] memory creatorERC721s = launchpad.getERC721sByCreator(creator);
        assertEq(creatorERC721s.length, 1);
        assertEq(creatorERC721s[0], config.tokenContract);

        vm.stopPrank();
    }

    function test_CreateLaunch_ERC1155_Success() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE, LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        assertEq(launchId, 0);
        assertEq(launchpad.nextLaunchId(), 1);

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        assertEq(uint8(config.tokenType), uint8(FractalLaunchpad.TokenType.ERC1155));
        assertEq(config.creator, creator);
        assertEq(config.maxSupply, MAX_SUPPLY);
        assertEq(config.baseURI, BASE_URI);
        assertTrue(config.tokenContract != address(0));

        // Check creator mapping
        address[] memory creatorERC1155s = launchpad.getERC1155sByCreator(creator);
        assertEq(creatorERC1155s.length, 1);
        assertEq(creatorERC1155s[0], config.tokenContract);

        vm.stopPrank();
    }

    function test_CreateLaunch_AuthorizedCreator_NoFee() public {
        // Authorize creator
        vm.prank(owner);
        launchpad.setAuthorizedCreator(creator, true);

        vm.startPrank(creator);

        uint256 initialBalance = creator.balance;

        uint256 launchId = launchpad.createLaunch(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        // Balance should remain the same (no fee charged)
        assertEq(creator.balance, initialBalance);
        assertEq(launchId, 0);

        vm.stopPrank();
    }

    function test_CreateLaunch_Owner_NoFee() public {
        vm.startPrank(owner);

        uint256 initialBalance = owner.balance;

        uint256 launchId = launchpad.createLaunch(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        // Balance should remain the same (no fee charged)
        assertEq(owner.balance, initialBalance);
        assertEq(launchId, 0);

        vm.stopPrank();
    }

    function test_CreateLaunch_RevertIf_InsufficientFee() public {
        vm.startPrank(creator);

        vm.expectRevert(FractalLaunchpad.InsufficientFee.selector);
        launchpad.createLaunch{value: PLATFORM_FEE - 1}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        vm.stopPrank();
    }

    function test_CreateLaunch_ZeroMaxSupply_InfiniteMint() public {
        vm.startPrank(creator);

        // Create launch with 0 max supply (infinite minting)
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            0, // Zero max supply for infinite minting
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        assertEq(config.maxSupply, 0);
        assertEq(uint8(config.tokenType), uint8(FractalLaunchpad.TokenType.ERC721));

        vm.stopPrank();
    }

    function test_InfiniteMinting_ERC721() public {
        vm.startPrank(creator);

        // Create launch with 0 max supply
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            "Infinite NFT",
            "INFT",
            0, // Infinite minting
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC721Impl nftContract = FractalERC721Impl(config.tokenContract);

        // Verify max supply is 0 (infinite)
        assertEq(nftContract.maxSupply(), 0);

        // Should be able to mint many tokens without hitting max supply
        for (uint256 i = 1; i <= 100; i++) {
            nftContract.mint(user, i);
        }

        assertEq(nftContract.totalSupply(), 100);

        vm.stopPrank();
    }

    function test_InfiniteMinting_ERC1155() public {
        vm.startPrank(creator);

        // Create launch with 0 max supply
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            "Infinite 1155",
            "I1155",
            0, // Infinite minting
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.PUBLIC,
            FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl nftContract = FractalERC1155Impl(config.tokenContract);

        // Verify max supply for token ID 0 is 0 (infinite)
        assertEq(nftContract.maxSupply(0), 0);

        // Should be able to mint large amounts without hitting max supply
        nftContract.mint(user, 0, 1000000, "");
        assertEq(nftContract.totalSupply(0), 1000000);
        assertEq(nftContract.balanceOf(user, 0), 1000000);

        vm.stopPrank();
    }

    function test_CreateLaunch_MultipleSequential() public {
        vm.startPrank(creator);

        // Create multiple launches
        uint256 launchId1 = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        uint256 launchId2 = launchpad.createLaunch{value: PLATFORM_FEE}(
            "Second NFT",
            "SNFT",
            500,
            "https://second.com/",
            ROYALTY_FEE,
            LicenseVersion.PUBLIC,
            FractalLaunchpad.TokenType.ERC1155
        );

        assertEq(launchId1, 0);
        assertEq(launchId2, 1);
        assertEq(launchpad.nextLaunchId(), 2);

        // Check both launches exist
        FractalLaunchpad.LaunchConfig memory config1 = launchpad.getLaunchInfo(launchId1);
        FractalLaunchpad.LaunchConfig memory config2 = launchpad.getLaunchInfo(launchId2);

        assertEq(uint8(config1.tokenType), uint8(FractalLaunchpad.TokenType.ERC721));
        assertEq(uint8(config2.tokenType), uint8(FractalLaunchpad.TokenType.ERC1155));

        vm.stopPrank();
    }

    // ============ Admin Function Tests ============

    function test_SetAuthorizedCreator_Success() public {
        vm.startPrank(owner);

        launchpad.setAuthorizedCreator(creator, true);
        assertTrue(launchpad.authorizedCreators(creator));

        launchpad.setAuthorizedCreator(creator, false);
        assertFalse(launchpad.authorizedCreators(creator));

        vm.stopPrank();
    }

    function test_SetAuthorizedCreator_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        launchpad.setAuthorizedCreator(creator, true);

        vm.stopPrank();
    }

    function test_SetPlatformFee_Success() public {
        vm.startPrank(owner);

        uint256 newFee = 0.02 ether;
        launchpad.setPlatformFee(newFee);
        assertEq(launchpad.platformFee(), newFee);

        vm.stopPrank();
    }

    function test_SetPlatformFee_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        launchpad.setPlatformFee(0.02 ether);

        vm.stopPrank();
    }

    function test_SetFeeRecipient_Success() public {
        vm.startPrank(owner);

        address newRecipient = makeAddr("newRecipient");
        launchpad.setFeeRecipient(newRecipient);
        assertEq(launchpad.feeRecipient(), newRecipient);

        vm.stopPrank();
    }

    function test_SetFeeRecipient_RevertIf_InvalidAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(FractalLaunchpad.InvalidFeeRecipient.selector);
        launchpad.setFeeRecipient(address(0));

        vm.stopPrank();
    }

    function test_SetFeeRecipient_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        launchpad.setFeeRecipient(makeAddr("newRecipient"));

        vm.stopPrank();
    }

    function test_WithdrawLockedFunds_Success() public {
        // Send some ETH to the contract
        vm.deal(address(launchpad), 5 ether);

        vm.startPrank(owner);

        uint256 initialBalance = owner.balance;
        launchpad.withdrawLockedFunds();

        assertEq(owner.balance, initialBalance + 5 ether);
        assertEq(address(launchpad).balance, 0);

        vm.stopPrank();
    }

    function test_WithdrawLockedFunds_RevertIf_NoFunds() public {
        vm.startPrank(owner);

        vm.expectRevert(FractalLaunchpad.NoFundsToWithdraw.selector);
        launchpad.withdrawLockedFunds();

        vm.stopPrank();
    }

    function test_WithdrawLockedFunds_RevertIf_NotOwner() public {
        vm.deal(address(launchpad), 1 ether);

        vm.startPrank(unauthorized);

        vm.expectRevert();
        launchpad.withdrawLockedFunds();

        vm.stopPrank();
    }

    // ============ View Function Tests ============

    function test_GetLaunchInfo() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);

        assertEq(uint8(config.tokenType), uint8(FractalLaunchpad.TokenType.ERC721));
        assertEq(config.creator, creator);
        assertEq(config.maxSupply, MAX_SUPPLY);
        assertEq(config.baseURI, BASE_URI);
        assertTrue(config.tokenContract != address(0));

        vm.stopPrank();
    }

    function test_GetERC721sByCreator() public {
        vm.startPrank(creator);

        // Create multiple ERC721 launches
        launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        launchpad.createLaunch{value: PLATFORM_FEE}(
            "Second NFT",
            "SNFT",
            500,
            "https://second.com/",
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        address[] memory creatorERC721s = launchpad.getERC721sByCreator(creator);
        assertEq(creatorERC721s.length, 2);

        vm.stopPrank();
    }

    function test_GetERC1155sByCreator() public {
        vm.startPrank(creator);

        // Create multiple ERC1155 launches
        launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE, LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        launchpad.createLaunch{value: PLATFORM_FEE}(
            "Second NFT",
            "SNFT",
            500,
            "https://second.com/",
            ROYALTY_FEE,
            LicenseVersion.PUBLIC,
            FractalLaunchpad.TokenType.ERC1155
        );

        address[] memory creatorERC1155s = launchpad.getERC1155sByCreator(creator);
        assertEq(creatorERC1155s.length, 2);

        vm.stopPrank();
    }

    function test_IsERC721Clone() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);

        assertTrue(launchpad.isERC721Clone(config.tokenContract));
        assertFalse(launchpad.isERC721Clone(makeAddr("randomAddress")));

        vm.stopPrank();
    }

    function test_IsERC1155Clone() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE, LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);

        assertTrue(launchpad.isERC1155Clone(config.tokenContract));
        assertFalse(launchpad.isERC1155Clone(makeAddr("randomAddress")));

        vm.stopPrank();
    }

    // ============ Integration Tests ============

    function test_FullWorkflow_ERC721() public {
        // 1. Create launch
        vm.startPrank(creator);
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );
        vm.stopPrank();

        // 2. Get the deployed contract
        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC721Impl nftContract = FractalERC721Impl(config.tokenContract);

        // 3. Verify contract properties
        assertEq(nftContract.name(), NAME);
        assertEq(nftContract.symbol(), SYMBOL);
        assertEq(nftContract.maxSupply(), MAX_SUPPLY);
        assertEq(nftContract.owner(), creator);

        // 4. Creator can mint tokens
        vm.startPrank(creator);
        nftContract.mint(user, 1);
        assertEq(nftContract.totalSupply(), 1);
        assertEq(nftContract.ownerOf(1), user);
        vm.stopPrank();
    }

    function test_FullWorkflow_ERC1155() public {
        // 1. Create launch
        vm.startPrank(creator);
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE, LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );
        vm.stopPrank();

        // 2. Get the deployed contract
        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl nftContract = FractalERC1155Impl(config.tokenContract);

        // 3. Verify contract properties
        assertEq(nftContract.name(), NAME);
        assertEq(nftContract.symbol(), SYMBOL);
        assertEq(nftContract.maxSupply(0), MAX_SUPPLY);
        assertEq(nftContract.owner(), creator);

        // 4. Creator can mint tokens
        vm.startPrank(creator);
        nftContract.mint(user, 0, 10, "");
        assertEq(nftContract.totalSupply(0), 10);
        assertEq(nftContract.balanceOf(user, 0), 10);
        vm.stopPrank();
    }

    function test_FeeCollection() public {
        uint256 initialFeeRecipientBalance = feeRecipient.balance;

        vm.startPrank(creator);

        // Create a launch with fee
        launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        // Fee recipient should receive the fee
        assertEq(feeRecipient.balance, initialFeeRecipientBalance + PLATFORM_FEE);

        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateLaunch_DifferentSupplies(uint256 _maxSupply) public {
        // Allow any max supply including 0 (infinite minting)
        vm.assume(_maxSupply <= type(uint256).max);

        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME,
            SYMBOL,
            _maxSupply,
            BASE_URI,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL,
            FractalLaunchpad.TokenType.ERC721
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        assertEq(config.maxSupply, _maxSupply);

        vm.stopPrank();
    }

    function testFuzz_SetPlatformFee(uint256 _fee) public {
        vm.startPrank(owner);

        launchpad.setPlatformFee(_fee);
        assertEq(launchpad.platformFee(), _fee);

        vm.stopPrank();
    }

    // ============ Implementation Update Tests ============

    function test_UpdateERC721Implementation_Success() public {
        vm.startPrank(owner);

        FractalERC721Impl newImpl = new FractalERC721Impl();
        address oldImpl = launchpad.erc721Implementation();

        launchpad.updateERC721Implementation(address(newImpl));

        assertEq(launchpad.erc721Implementation(), address(newImpl));
        assertTrue(launchpad.erc721Implementation() != oldImpl);

        vm.stopPrank();
    }

    function test_UpdateERC1155Implementation_Success() public {
        vm.startPrank(owner);

        FractalERC1155Impl newImpl = new FractalERC1155Impl();
        address oldImpl = launchpad.erc1155Implementation();

        launchpad.updateERC1155Implementation(address(newImpl));

        assertEq(launchpad.erc1155Implementation(), address(newImpl));
        assertTrue(launchpad.erc1155Implementation() != oldImpl);

        vm.stopPrank();
    }

    function test_UpdateERC721Implementation_RevertIf_ZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(FractalLaunchpad.InvalidERC721Implementation.selector);
        launchpad.updateERC721Implementation(address(0));

        vm.stopPrank();
    }

    function test_UpdateERC1155Implementation_RevertIf_ZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(FractalLaunchpad.InvalidERC1155Implementation.selector);
        launchpad.updateERC1155Implementation(address(0));

        vm.stopPrank();
    }

    function test_UpdateERC721Implementation_RevertIf_NotOwner() public {
        FractalERC721Impl newImpl = new FractalERC721Impl();

        vm.startPrank(unauthorized);

        vm.expectRevert();
        launchpad.updateERC721Implementation(address(newImpl));

        vm.stopPrank();
    }

    function test_UpdateERC1155Implementation_RevertIf_NotOwner() public {
        FractalERC1155Impl newImpl = new FractalERC1155Impl();

        vm.startPrank(unauthorized);

        vm.expectRevert();
        launchpad.updateERC1155Implementation(address(newImpl));

        vm.stopPrank();
    }

    function test_UpdateERC721Implementation_EmitsEvent() public {
        vm.startPrank(owner);

        FractalERC721Impl newImpl = new FractalERC721Impl();
        address oldImpl = launchpad.erc721Implementation();

        vm.expectEmit(true, true, false, false);
        emit FractalLaunchpad.ERC721ImplementationUpdated(oldImpl, address(newImpl));

        launchpad.updateERC721Implementation(address(newImpl));

        vm.stopPrank();
    }

    function test_UpdateERC1155Implementation_EmitsEvent() public {
        vm.startPrank(owner);

        FractalERC1155Impl newImpl = new FractalERC1155Impl();
        address oldImpl = launchpad.erc1155Implementation();

        vm.expectEmit(true, true, false, false);
        emit FractalLaunchpad.ERC1155ImplementationUpdated(oldImpl, address(newImpl));

        launchpad.updateERC1155Implementation(address(newImpl));

        vm.stopPrank();
    }

    function test_UpdateERC721Implementation_DoesNotAffectExistingClones() public {
        // 1. Create a clone with the original implementation
        vm.prank(creator);
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE,
            LicenseVersion.COMMERCIAL, FractalLaunchpad.TokenType.ERC721
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC721Impl existingClone = FractalERC721Impl(config.tokenContract);

        // 2. Mint a token on the existing clone
        vm.prank(creator);
        existingClone.mint(user, 1);
        assertEq(existingClone.ownerOf(1), user);

        // 3. Update the implementation
        vm.startPrank(owner);
        FractalERC721Impl newImpl = new FractalERC721Impl();
        launchpad.updateERC721Implementation(address(newImpl));
        vm.stopPrank();

        // 4. Existing clone should still work perfectly
        vm.startPrank(creator);
        existingClone.mint(user, 2);
        assertEq(existingClone.ownerOf(2), user);
        assertEq(existingClone.totalSupply(), 2);
        assertEq(existingClone.name(), NAME);
        assertEq(existingClone.symbol(), SYMBOL);
        vm.stopPrank();
    }

    function test_UpdateERC1155Implementation_DoesNotAffectExistingClones() public {
        // 1. Create a clone with the original implementation
        vm.prank(creator);
        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl existingClone = FractalERC1155Impl(config.tokenContract);

        // 2. Mint tokens on the existing clone
        vm.prank(creator);
        existingClone.mint(user, 0, 50, "");
        assertEq(existingClone.balanceOf(user, 0), 50);

        // 3. Update the implementation
        vm.startPrank(owner);
        FractalERC1155Impl newImpl = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(newImpl));
        vm.stopPrank();

        // 4. Existing clone should still work perfectly
        vm.startPrank(creator);
        existingClone.mint(user, 0, 25, "");
        assertEq(existingClone.balanceOf(user, 0), 75);
        assertEq(existingClone.totalSupply(0), 75);
        assertEq(existingClone.name(), NAME);
        vm.stopPrank();
    }

    function test_NewClonesUseUpdatedImplementation() public {
        // 1. Create clone with original implementation
        vm.prank(creator);
        uint256 launchId1 = launchpad.createLaunch{value: PLATFORM_FEE}(
            "Old ERC1155", "OLD", MAX_SUPPLY, "https://old.com/", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config1 = launchpad.getLaunchInfo(launchId1);
        address oldClone = config1.tokenContract;

        // 2. Deploy a new implementation and update
        vm.startPrank(owner);
        FractalERC1155Impl newImpl = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(newImpl));
        vm.stopPrank();

        // 3. Create a new clone — should use the new implementation
        vm.prank(creator);
        uint256 launchId2 = launchpad.createLaunch{value: PLATFORM_FEE}(
            "New ERC1155", "NEW", MAX_SUPPLY, "https://new.com/", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config2 = launchpad.getLaunchInfo(launchId2);
        address newClone = config2.tokenContract;

        // 4. Both clones should be functional
        assertTrue(oldClone != newClone);

        FractalERC1155Impl oldContract = FractalERC1155Impl(oldClone);
        FractalERC1155Impl newContract = FractalERC1155Impl(newClone);

        assertEq(oldContract.name(), "Old ERC1155");
        assertEq(newContract.name(), "New ERC1155");

        // 5. Both should be mintable
        vm.startPrank(creator);
        oldContract.mint(user, 0, 10, "");
        newContract.mint(user, 0, 10, "");
        vm.stopPrank();

        assertEq(oldContract.balanceOf(user, 0), 10);
        assertEq(newContract.balanceOf(user, 0), 10);
    }

    function test_UpdateImplementation_MultipleTimesInSequence() public {
        vm.startPrank(owner);

        address original = launchpad.erc1155Implementation();

        // Update 3 times
        FractalERC1155Impl impl1 = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(impl1));
        assertEq(launchpad.erc1155Implementation(), address(impl1));

        FractalERC1155Impl impl2 = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(impl2));
        assertEq(launchpad.erc1155Implementation(), address(impl2));

        FractalERC1155Impl impl3 = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(impl3));
        assertEq(launchpad.erc1155Implementation(), address(impl3));

        // Should be on the 3rd implementation, none of the previous ones
        assertTrue(launchpad.erc1155Implementation() != original);
        assertTrue(launchpad.erc1155Implementation() != address(impl1));
        assertTrue(launchpad.erc1155Implementation() != address(impl2));

        vm.stopPrank();
    }

    function test_UpdateERC721Implementation_CanSetBackToOriginal() public {
        address original = launchpad.erc721Implementation();

        vm.startPrank(owner);

        FractalERC721Impl newImpl = new FractalERC721Impl();
        launchpad.updateERC721Implementation(address(newImpl));
        assertEq(launchpad.erc721Implementation(), address(newImpl));

        // Set it back to the original
        launchpad.updateERC721Implementation(original);
        assertEq(launchpad.erc721Implementation(), original);

        vm.stopPrank();
    }

    function test_IsClone_AfterImplementationUpdate() public {
        // 1. Create a clone with old implementation
        vm.prank(creator);
        uint256 launchId1 = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );
        FractalLaunchpad.LaunchConfig memory config1 = launchpad.getLaunchInfo(launchId1);
        address oldClone = config1.tokenContract;

        // Old clone IS a clone of the current implementation
        assertTrue(launchpad.isERC1155Clone(oldClone));

        // 2. Update the implementation
        vm.startPrank(owner);
        FractalERC1155Impl newImpl = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(newImpl));
        vm.stopPrank();

        // 3. Old clone is NO LONGER detected as a clone of the NEW implementation
        //    This is expected behavior — isClone checks against the current implementation
        assertFalse(launchpad.isERC1155Clone(oldClone));

        // 4. Create a new clone with the new implementation
        vm.prank(creator);
        uint256 launchId2 = launchpad.createLaunch{value: PLATFORM_FEE}(
            "New", "NEW", MAX_SUPPLY, BASE_URI, ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );
        FractalLaunchpad.LaunchConfig memory config2 = launchpad.getLaunchInfo(launchId2);
        address newClone = config2.tokenContract;

        // New clone IS detected as a clone of the new implementation
        assertTrue(launchpad.isERC1155Clone(newClone));
    }

    // ============ ERC1155 URI Fix Tests ============

    function test_ERC1155_URI_AppendsTokenId() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, "ipfs://QmTestHash/", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl nftContract = FractalERC1155Impl(config.tokenContract);

        // uri should append the token ID to the base URI
        assertEq(nftContract.uri(0), "ipfs://QmTestHash/0");
        assertEq(nftContract.uri(1), "ipfs://QmTestHash/1");
        assertEq(nftContract.uri(42), "ipfs://QmTestHash/42");
        assertEq(nftContract.uri(999), "ipfs://QmTestHash/999");

        vm.stopPrank();
    }

    function test_ERC1155_URI_CustomOverridesBaseWithTokenId() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, "ipfs://QmTestHash/", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl nftContract = FractalERC1155Impl(config.tokenContract);

        // Set a custom URI for token 1
        string memory customURI = "ipfs://QmCustomHash/special";
        nftContract.setTokenURI(1, customURI);

        // Token 1 should return custom URI (not base + id)
        assertEq(nftContract.uri(1), customURI);

        // Other tokens should still return base + id
        assertEq(nftContract.uri(0), "ipfs://QmTestHash/0");
        assertEq(nftContract.uri(2), "ipfs://QmTestHash/2");

        vm.stopPrank();
    }

    function test_ERC1155_URI_EmptyBaseReturnsEmpty() public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, "", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl nftContract = FractalERC1155Impl(config.tokenContract);

        // Empty base URI should return empty string
        assertEq(nftContract.uri(0), "");
        assertEq(nftContract.uri(1), "");

        // But custom URI should still work
        nftContract.setTokenURI(1, "ipfs://QmCustom/1");
        assertEq(nftContract.uri(1), "ipfs://QmCustom/1");
        assertEq(nftContract.uri(0), ""); // Still empty for non-custom

        vm.stopPrank();
    }

    function testFuzz_ERC1155_URI_AppendsAnyTokenId(uint256 tokenId) public {
        vm.startPrank(creator);

        uint256 launchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            NAME, SYMBOL, MAX_SUPPLY, "https://api.example.com/token/", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        FractalERC1155Impl nftContract = FractalERC1155Impl(config.tokenContract);

        string memory expected = string.concat("https://api.example.com/token/", vm.toString(tokenId));
        assertEq(nftContract.uri(tokenId), expected);

        vm.stopPrank();
    }

    // ============ End-to-End Implementation Upgrade Scenario ============

    function test_E2E_UpgradeImplementationAndCreateNewClones() public {
        // Simulates the real-world scenario: fix a bug in implementation, update launchpad, deploy new clones

        // 1. Create a clone with the original implementation
        vm.prank(creator);
        uint256 launchId1 = launchpad.createLaunch{value: PLATFORM_FEE}(
            "Original Collection", "ORIG", 100, "ipfs://QmOriginal/", ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config1 = launchpad.getLaunchInfo(launchId1);
        FractalERC1155Impl originalClone = FractalERC1155Impl(config1.tokenContract);

        // 2. Mint on the original clone
        vm.prank(creator);
        originalClone.mint(user, 0, 5, "");
        assertEq(originalClone.balanceOf(user, 0), 5);

        // 3. Owner deploys a new (fixed) implementation and updates
        vm.startPrank(owner);
        FractalERC1155Impl fixedImpl = new FractalERC1155Impl();
        launchpad.updateERC1155Implementation(address(fixedImpl));
        vm.stopPrank();

        // 4. Create a new clone — uses the fixed implementation
        vm.prank(creator);
        uint256 launchId2 = launchpad.createLaunch{value: PLATFORM_FEE}(
            "Fixed Collection", "FIX", 200, "ipfs://QmFixed/", ROYALTY_FEE,
            LicenseVersion.COMMERCIAL, FractalLaunchpad.TokenType.ERC1155
        );

        FractalLaunchpad.LaunchConfig memory config2 = launchpad.getLaunchInfo(launchId2);
        FractalERC1155Impl fixedClone = FractalERC1155Impl(config2.tokenContract);

        // 5. Both clones work independently
        vm.startPrank(creator);
        originalClone.mint(user, 0, 3, "");
        fixedClone.mint(user, 0, 10, "");
        vm.stopPrank();

        assertEq(originalClone.balanceOf(user, 0), 8);
        assertEq(fixedClone.balanceOf(user, 0), 10);

        // 6. URI fix works on the new clone
        assertEq(fixedClone.uri(0), "ipfs://QmFixed/0");
        assertEq(fixedClone.uri(1), "ipfs://QmFixed/1");

        // 7. Verify correct tracking
        address[] memory creatorERC1155s = launchpad.getERC1155sByCreator(creator);
        assertEq(creatorERC1155s.length, 2);
        assertEq(creatorERC1155s[0], address(originalClone));
        assertEq(creatorERC1155s[1], address(fixedClone));

        // 8. Launch IDs are sequential
        assertEq(launchpad.nextLaunchId(), 2);
    }

    function test_E2E_UpdateBothImplementationsSimultaneously() public {
        vm.startPrank(owner);

        FractalERC721Impl newERC721 = new FractalERC721Impl();
        FractalERC1155Impl newERC1155 = new FractalERC1155Impl();

        launchpad.updateERC721Implementation(address(newERC721));
        launchpad.updateERC1155Implementation(address(newERC1155));

        vm.stopPrank();

        assertEq(launchpad.erc721Implementation(), address(newERC721));
        assertEq(launchpad.erc1155Implementation(), address(newERC1155));

        // Create launches with both new implementations
        vm.startPrank(creator);

        uint256 erc721LaunchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            "New 721", "N721", 100, BASE_URI, ROYALTY_FEE,
            LicenseVersion.COMMERCIAL, FractalLaunchpad.TokenType.ERC721
        );

        uint256 erc1155LaunchId = launchpad.createLaunch{value: PLATFORM_FEE}(
            "New 1155", "N1155", 100, BASE_URI, ROYALTY_FEE,
            LicenseVersion.PUBLIC, FractalLaunchpad.TokenType.ERC1155
        );

        vm.stopPrank();

        FractalLaunchpad.LaunchConfig memory config721 = launchpad.getLaunchInfo(erc721LaunchId);
        FractalLaunchpad.LaunchConfig memory config1155 = launchpad.getLaunchInfo(erc1155LaunchId);

        // Both new clones should be functional
        FractalERC721Impl nft721 = FractalERC721Impl(config721.tokenContract);
        FractalERC1155Impl nft1155 = FractalERC1155Impl(config1155.tokenContract);

        vm.startPrank(creator);
        nft721.mint(user, 1);
        nft1155.mint(user, 0, 5, "");
        vm.stopPrank();

        assertEq(nft721.ownerOf(1), user);
        assertEq(nft1155.balanceOf(user, 0), 5);

        // isClone should work with new implementations
        assertTrue(launchpad.isERC721Clone(config721.tokenContract));
        assertTrue(launchpad.isERC1155Clone(config1155.tokenContract));
    }

    // ============ Fuzz Tests for Implementation Updates ============

    function testFuzz_UpdateERC721Implementation(address _newImpl) public {
        vm.assume(_newImpl != address(0));

        vm.prank(owner);
        launchpad.updateERC721Implementation(_newImpl);
        assertEq(launchpad.erc721Implementation(), _newImpl);
    }

    function testFuzz_UpdateERC1155Implementation(address _newImpl) public {
        vm.assume(_newImpl != address(0));

        vm.prank(owner);
        launchpad.updateERC1155Implementation(_newImpl);
        assertEq(launchpad.erc1155Implementation(), _newImpl);
    }
}
