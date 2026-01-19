// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {MinimalProxy} from "../src/Factory.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";
import {LicenseVersion, FractalERC1155Impl} from "../src/FractalERC1155.sol";

contract FractalLaunchpadTest is Test {
    FractalLaunchpad public launchpad;
    MinimalProxy public factory;
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
        factory = new MinimalProxy();

        // Deploy launchpad
        launchpad = new FractalLaunchpad(
            feeRecipient, PLATFORM_FEE, address(erc1155Implementation), address(erc721Implementation), address(factory)
        );

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
        assertEq(address(launchpad.nftFactory()), address(factory));
        assertEq(launchpad.ERC721_IMPLEMENTATION(), address(erc721Implementation));
        assertEq(launchpad.ERC1155_IMPLEMENTATION(), address(erc1155Implementation));
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
}
