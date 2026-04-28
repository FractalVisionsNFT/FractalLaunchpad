// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {LicenseVersion, FractalERC1155Impl} from "../src/FractalERC1155.sol";
import {ICantBeEvil} from "@a16z/contracts/licenses/ICantBeEvil.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FractalERC1155Test is Test {
    FractalERC1155Impl public nft;

    address public owner;
    address public user1;
    address public user2;
    address public operator;
    address public unauthorized;

    string public constant NAME = "Test 1155";
    string public constant SYMBOL = "T1155";
    uint256 public constant MAX_SUPPLY = 1000;
    string public constant BASE_URI = "https://test.com/{id}";
    uint96 public constant ROYALTY_FEE = 500; // 5%

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event URI(string value, uint256 indexed id);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    event MaxSupplySet(uint256 indexed tokenId, uint256 maxSupply);
    event BaseURISet(string baseURI);
    event TokenRoyaltySet(uint256 indexed tokenId, address receiver, uint96 feeNumerator);
    event DefaultRoyaltySet(address receiver, uint96 feeNumerator);
    event ContractUpgraded(address indexed newImplementation, uint8 version);

        // function test_ForkAndSetBaseURI() public {
        //     // Fork Base Sepolia
        //     string memory rpcUrl = "https://opt-mainnet.g.alchemy.com/v2/NsLwY_gPTAf36JQbeG5LLK5m6muNGnLq";
        //     uint256 forkId = vm.createFork(rpcUrl);
        //     vm.selectFork(forkId);

        //     address erc1155 = 0x963dc72e793dBA5028A8003e24d9E3836FeDed07;
        //     address owner = 0x751558F4D5E6aC4D44894e701Ca468A2f98512De;
        //     string memory newBaseURI = "ipfs://QmForkedBaseURI/";

        //     // Impersonate owner
        //     vm.startPrank(owner);

        //     // Call setBaseURI on the contract
        //     (bool success, ) = erc1155.call(abi.encodeWithSignature("setBaseURI(string)", newBaseURI));
        //     require(success, "setBaseURI failed");

        //     vm.stopPrank();
        // }

    /// @dev Helper: deploy a fresh proxy with the given parameters.
    function _deployProxy(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner,
        uint96 _royaltyFee,
        LicenseVersion _licenseVersion
    ) internal returns (FractalERC1155Impl) {
        FractalERC1155Impl impl = new FractalERC1155Impl();
        bytes memory initData = abi.encodeWithSelector(
            FractalERC1155Impl.initialize.selector,
            _name, _symbol, _maxSupply, _baseURI, _owner, _royaltyFee, _licenseVersion
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        return FractalERC1155Impl(address(proxy));
    }

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        operator = makeAddr("operator");
        unauthorized = makeAddr("unauthorized");

        // Deploy through a UUPS proxy (implementation has _disableInitializers in constructor)
        nft = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);
    }

    // ============ Initialization Tests ============

    function test_Initialize_Success() public {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.maxSupply(0), MAX_SUPPLY);
        assertEq(nft.uri(0), string.concat(BASE_URI, "0"));
        assertEq(nft.owner(), owner);
        assertEq(nft.totalSupply(0), 0);
    }

    function test_Initialize_ZeroMaxSupply() public {
        FractalERC1155Impl newNft = _deployProxy(NAME, SYMBOL, 0, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);

        assertEq(newNft.maxSupply(0), 0);
        // Should allow infinite minting when max supply is 0
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        nft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);
    }

    function test_Initialize_RevertIf_RoyaltyAboveCap() public {
        FractalERC1155Impl impl = new FractalERC1155Impl();
        bytes memory initData = abi.encodeWithSelector(
            FractalERC1155Impl.initialize.selector,
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, uint96(1001), LicenseVersion.PUBLIC
        );
        vm.expectRevert(FractalERC1155Impl.RoyaltyExceedsCap.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Initialize_OnlyTokenZeroHasMaxSupply() public {
        // Other token IDs should have 0 max supply initially
        assertEq(nft.maxSupply(1), 0);
        assertEq(nft.maxSupply(999), 0);
        assertEq(nft.maxSupply(type(uint256).max), 0);
    }

    // ============ Mint Tests ============

    function test_Mint_Success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, address(0), user1, 0, 100);

        nft.mint(user1, 0, 100, "");

        assertEq(nft.totalSupply(0), 100);
        assertEq(nft.balanceOf(user1, 0), 100);

        vm.stopPrank();
    }

    function test_Mint_MultipleTokenTypes() public {
        vm.startPrank(owner);

        // Mint different token IDs
        nft.mint(user1, 0, 50, "");
        nft.mint(user1, 1, 25, "");
        nft.mint(user2, 2, 75, "");

        assertEq(nft.totalSupply(0), 50);
        assertEq(nft.totalSupply(1), 25);
        assertEq(nft.totalSupply(2), 75);
        assertEq(nft.balanceOf(user1, 0), 50);
        assertEq(nft.balanceOf(user1, 1), 25);
        assertEq(nft.balanceOf(user2, 2), 75);

        vm.stopPrank();
    }

    function test_Mint_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        nft.mint(user1, 0, 100, "");

        vm.stopPrank();
    }

    function test_Mint_RevertIf_MaxSupplyExceeded() public {
        vm.startPrank(owner);

        // Mint up to max supply for token ID 0
        nft.mint(user1, 0, MAX_SUPPLY, "");

        // This should revert
        vm.expectRevert(FractalERC1155Impl.MaxSupplyExceeded.selector);
        nft.mint(user1, 0, 1, "");

        vm.stopPrank();
    }

    function test_Mint_InfiniteWhenMaxSupplyZero() public {
        vm.startPrank(owner);

        // Token ID 1 has no max supply set (defaults to 0 = infinite)
        for (uint256 i = 0; i < 10; i++) {
            nft.mint(user1, 1, 1000, "");
        }

        assertEq(nft.totalSupply(1), 10000);

        vm.stopPrank();
    }

    function test_Mint_WithData() public {
        vm.startPrank(owner);

        bytes memory data = "test data";
        nft.mint(user1, 0, 100, data);

        assertEq(nft.balanceOf(user1, 0), 100);

        vm.stopPrank();
    }

    function test_Mint_ZeroAmount() public {
        vm.startPrank(owner);

        nft.mint(user1, 0, 0, "");

        assertEq(nft.totalSupply(0), 0);
        assertEq(nft.balanceOf(user1, 0), 0);

        vm.stopPrank();
    }

    // ============ Batch Mint Tests ============

    function test_BatchMint_Success() public {
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(owner, address(0), user1, ids, amounts);

        nft.batchMint(user1, ids, amounts, "");

        assertEq(nft.totalSupply(0), 100);
        assertEq(nft.totalSupply(1), 200);
        assertEq(nft.totalSupply(2), 300);
        assertEq(nft.balanceOf(user1, 0), 100);
        assertEq(nft.balanceOf(user1, 1), 200);
        assertEq(nft.balanceOf(user1, 2), 300);

        vm.stopPrank();
    }

    function test_BatchMint_EmptyArrays() public {
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        nft.batchMint(user1, ids, amounts, "");

        // Should succeed with no changes
        vm.stopPrank();
    }

    function test_BatchMint_RevertIf_LengthMismatch() public {
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](3);

        vm.expectRevert(FractalERC1155Impl.LengthMismatch.selector);
        nft.batchMint(user1, ids, amounts, "");

        vm.stopPrank();
    }

    function test_BatchMint_RevertIf_MaxSupplyExceeded() public {
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        amounts[0] = MAX_SUPPLY + 1;

        vm.expectRevert(FractalERC1155Impl.MaxSupplyExceeded.selector);
        nft.batchMint(user1, ids, amounts, "");

        vm.stopPrank();
    }

    function test_BatchMint_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        amounts[0] = 100;

        vm.expectRevert();
        nft.batchMint(user1, ids, amounts, "");

        vm.stopPrank();
    }

    function test_BatchMint_MixedMaxSupplyConstraints() public {
        vm.startPrank(owner);

        // Set max supply for token ID 1
        nft.setMaxSupply(1, 500);

        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 0; // Has max supply 1000
        ids[1] = 1; // Has max supply 500
        ids[2] = 2; // No max supply (infinite)
        amounts[0] = 500;
        amounts[1] = 250;
        amounts[2] = 1500;

        nft.batchMint(user1, ids, amounts, "");

        assertEq(nft.totalSupply(0), 500);
        assertEq(nft.totalSupply(1), 250);
        assertEq(nft.totalSupply(2), 1500);

        vm.stopPrank();
    }

    // ============ Set Max Supply Tests ============

    function test_SetMaxSupply_Success() public {
        vm.startPrank(owner);

        nft.setMaxSupply(1, 2000);
        assertEq(nft.maxSupply(1), 2000);

        vm.stopPrank();
    }

    function test_SetMaxSupply_ToZero() public {
        vm.startPrank(owner);

        // First set a max supply
        nft.setMaxSupply(1, 1000);
        assertEq(nft.maxSupply(1), 1000);

        // Then set it to zero (infinite)
        nft.setMaxSupply(1, 0);
        assertEq(nft.maxSupply(1), 0);

        // Should now allow infinite minting
        nft.mint(user1, 1, 5000, "");
        assertEq(nft.totalSupply(1), 5000);

        vm.stopPrank();
    }

    function test_SetMaxSupply_RevertIf_BelowCurrentSupply() public {
        vm.startPrank(owner);

        // Mint some tokens first
        nft.mint(user1, 1, 500, "");

        // Try to set max supply below current supply
        vm.expectRevert(FractalERC1155Impl.MaxSupplyBelowCurrentSupply.selector);
        nft.setMaxSupply(1, 400);

        vm.stopPrank();
    }

    function test_SetMaxSupply_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        nft.setMaxSupply(1, 500);

        vm.stopPrank();
    }

    function test_SetMaxSupply_EqualToCurrentSupply() public {
        vm.startPrank(owner);

        nft.mint(user1, 1, 500, "");

        // Set max supply equal to current supply
        nft.setMaxSupply(1, 500);
        assertEq(nft.maxSupply(1), 500);

        // Should not be able to mint more
        vm.expectRevert(FractalERC1155Impl.MaxSupplyExceeded.selector);
        nft.mint(user1, 1, 1, "");

        vm.stopPrank();
    }

    // ============ Set Token URI Tests ============

    function test_SetTokenURI_Success() public {
        vm.startPrank(owner);

        string memory tokenURI = "https://custom.com/token/1";

        nft.setTokenURI(1, tokenURI);
        assertEq(nft.uri(1), tokenURI);
        
        vm.stopPrank();
    }

    function test_SetTokenURI_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        nft.setTokenURI(1, "https://hack.com/");

        vm.stopPrank();
    }

    function test_URI_FallbackToBaseURI() public {
        // Token without custom URI should return base URI + token ID
        assertEq(nft.uri(5), string.concat(BASE_URI, "5"));
    }

    function test_URI_CustomOverridesBase() public {
        vm.startPrank(owner);

        string memory customURI = "https://special.com/token/1";
        nft.setTokenURI(1, customURI);

        // Should return custom URI instead of base URI
        assertEq(nft.uri(1), customURI);

        vm.stopPrank();
    }

    // ============ Burn Tests ============

    function test_Burn_Success() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user1, user1, address(0), 0, 50);

        nft.burn(user1, 0, 50);

        assertEq(nft.totalSupply(0), 50);
        assertEq(nft.balanceOf(user1, 0), 50);

        vm.stopPrank();
    }

    function test_Burn_FullAmount() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user1);

        nft.burn(user1, 0, 100);

        assertEq(nft.totalSupply(0), 0);
        assertEq(nft.balanceOf(user1, 0), 0);

        vm.stopPrank();
    }

    function test_Burn_RevertIf_NotAuthorized() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user2);

        vm.expectRevert(FractalERC1155Impl.NotAuthorized.selector);
        nft.burn(user1, 0, 50);

        vm.stopPrank();
    }

    function test_Burn_ByApprovedOperator() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user1);
        nft.setApprovalForAll(operator, true);
        vm.stopPrank();

        vm.startPrank(operator);
        nft.burn(user1, 0, 50);

        assertEq(nft.totalSupply(0), 50);
        assertEq(nft.balanceOf(user1, 0), 50);

        vm.stopPrank();
    }

    function test_Burn_RevertIf_InsufficientBalance() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 50, "");
        vm.stopPrank();

        vm.startPrank(user1);

        vm.expectRevert();
        nft.burn(user1, 0, 100); // Try to burn more than balance

        vm.stopPrank();
    }

    function test_BurnBatch_RevertIf_LengthMismatch() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 50, "");
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        ids[1] = 1;
        amounts[0] = 10;

        vm.expectRevert(FractalERC1155Impl.LengthMismatch.selector);
        nft.burnBatch(user1, ids, amounts);

        vm.stopPrank();
    }

    function test_BurnBatch_RevertIf_NotAuthorized() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 50, "");
        vm.stopPrank();

        vm.startPrank(unauthorized);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        amounts[0] = 10;

        vm.expectRevert(FractalERC1155Impl.NotAuthorized.selector);
        nft.burnBatch(user1, ids, amounts);

        vm.stopPrank();
    }

    // ============ Batch Burn Tests ============

    function test_BurnBatch_Success() public {
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        nft.batchMint(user1, ids, amounts, "");
        vm.stopPrank();

        vm.startPrank(user1);

        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 50;
        burnAmounts[1] = 100;
        burnAmounts[2] = 150;

        vm.expectEmit(true, true, true, true);
        emit TransferBatch(user1, user1, address(0), ids, burnAmounts);

        nft.burnBatch(user1, ids, burnAmounts);

        assertEq(nft.totalSupply(0), 50);
        assertEq(nft.totalSupply(1), 100);
        assertEq(nft.totalSupply(2), 150);
        assertEq(nft.balanceOf(user1, 0), 50);
        assertEq(nft.balanceOf(user1, 1), 100);
        assertEq(nft.balanceOf(user1, 2), 150);

        vm.stopPrank();
    }

    function test_BurnBatch_ByApprovedOperator() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user1);
        nft.setApprovalForAll(operator, true);
        vm.stopPrank();

        vm.startPrank(operator);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        amounts[0] = 50;

        nft.burnBatch(user1, ids, amounts);

        assertEq(nft.totalSupply(0), 50);
        assertEq(nft.balanceOf(user1, 0), 50);

        vm.stopPrank();
    }

    // ============ Integration Tests ============

    function test_FullWorkflow() public {
        vm.startPrank(owner);

        // 1. Mint tokens
        nft.mint(user1, 0, 100, "");
        nft.mint(user1, 1, 200, "");

        // 2. Set max supply for token 1
        nft.setMaxSupply(1, 500);

        // 3. Set custom URI for token 1
        nft.setTokenURI(1, "https://custom.com/1");

        assertEq(nft.totalSupply(0), 100);
        assertEq(nft.totalSupply(1), 200);
        assertEq(nft.maxSupply(1), 500);
        assertEq(nft.uri(1), "https://custom.com/1");

        vm.stopPrank();

        // 4. User burns some tokens
        vm.startPrank(user1);
        nft.burn(user1, 0, 25);

        assertEq(nft.totalSupply(0), 75);
        assertEq(nft.balanceOf(user1, 0), 75);

        vm.stopPrank();
    }

    function test_MaxSupplyEnforcement() public {
        vm.startPrank(owner);

        // Set max supply for token 1
        nft.setMaxSupply(1, 300);

        // Mint up to max
        nft.mint(user1, 1, 300, "");

        // Next mint should fail
        vm.expectRevert(FractalERC1155Impl.MaxSupplyExceeded.selector);
        nft.mint(user1, 1, 1, "");

        vm.stopPrank();

        // Burn some tokens
        vm.startPrank(user1);
        nft.burn(user1, 1, 100);
        vm.stopPrank();

        // Now should be able to mint again
        vm.startPrank(owner);
        nft.mint(user1, 1, 50, ""); // This should succeed
        assertEq(nft.totalSupply(1), 250);

        vm.stopPrank();
    }

    function test_MultiTokenWorkflow() public {
        vm.startPrank(owner);

        // Set different max supplies
        nft.setMaxSupply(1, 500);
        nft.setMaxSupply(2, 1000);
        // Token 3 remains infinite (max supply 0)

        // Batch mint multiple tokens
        uint256[] memory ids = new uint256[](4);
        uint256[] memory amounts = new uint256[](4);
        ids[0] = 0; // Max 1000 (from initialization)
        ids[1] = 1; // Max 500
        ids[2] = 2; // Max 1000
        ids[3] = 3; // Infinite
        amounts[0] = 800;
        amounts[1] = 400;
        amounts[2] = 900;
        amounts[3] = 5000;

        nft.batchMint(user1, ids, amounts, "");

        // Verify all mints succeeded
        assertEq(nft.balanceOf(user1, 0), 800);
        assertEq(nft.balanceOf(user1, 1), 400);
        assertEq(nft.balanceOf(user1, 2), 900);
        assertEq(nft.balanceOf(user1, 3), 5000);

        vm.stopPrank();
    }

    // ============ Fuzz Tests ============

    function testFuzz_Mint_DifferentAmounts(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= MAX_SUPPLY);

        vm.startPrank(owner);

        nft.mint(user1, 0, _amount, "");
        assertEq(nft.balanceOf(user1, 0), _amount);
        assertEq(nft.totalSupply(0), _amount);

        vm.stopPrank();
    }

    function testFuzz_SetMaxSupply_ValidValues(uint256 _maxSupply) public {
        vm.assume(_maxSupply >= 0);

        vm.startPrank(owner);

        nft.setMaxSupply(1, _maxSupply);
        assertEq(nft.maxSupply(1), _maxSupply);

        vm.stopPrank();
    }

    function testFuzz_Mint_DifferentTokenIds(uint256 _tokenId) public {
        vm.assume(_tokenId > 0 && _tokenId <= type(uint128).max); // Reasonable range

        vm.startPrank(owner);

        uint256 amount = 100;
        nft.mint(user1, _tokenId, amount, "");

        assertEq(nft.balanceOf(user1, _tokenId), amount);
        assertEq(nft.totalSupply(_tokenId), amount);

        vm.stopPrank();
    }

    function testFuzz_BatchMint_DifferentSizes(uint8 _size) public {
        vm.assume(_size > 0 && _size <= 20); // Reasonable size for testing

        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](_size);
        uint256[] memory amounts = new uint256[](_size);

        for (uint256 i = 0; i < _size; i++) {
            ids[i] = i + 1; // Start from token ID 1
            amounts[i] = 10;
        }

        nft.batchMint(user1, ids, amounts, "");

        for (uint256 i = 0; i < _size; i++) {
            assertEq(nft.balanceOf(user1, ids[i]), 10);
            assertEq(nft.totalSupply(ids[i]), 10);
        }

        vm.stopPrank();
    }

    // ============ Edge Cases ============

    function test_EdgeCase_MintTokenIdZero() public {
        vm.startPrank(owner);

        // Token ID 0 should work fine and respect max supply
        nft.mint(user1, 0, 500, "");
        assertEq(nft.balanceOf(user1, 0), 500);

        vm.stopPrank();
    }

    function test_EdgeCase_MintMaxTokenId() public {
        vm.startPrank(owner);

        uint256 maxTokenId = type(uint256).max;
        nft.mint(user1, maxTokenId, 100, "");
        assertEq(nft.balanceOf(user1, maxTokenId), 100);

        vm.stopPrank();
    }

    function test_EdgeCase_BurnAndMintAgain() public {
        vm.startPrank(owner);
        nft.mint(user1, 1, 100, "");
        vm.stopPrank();

        vm.startPrank(user1);
        nft.burn(user1, 1, 100);
        vm.stopPrank();

        vm.startPrank(owner);
        // Should be able to mint again after burning
        nft.mint(user2, 1, 200, "");
        assertEq(nft.balanceOf(user2, 1), 200);
        assertEq(nft.totalSupply(1), 200);
        vm.stopPrank();
    }

    function test_EdgeCase_ZeroSupplyOperations() public {
        vm.startPrank(owner);

        // Mint zero amount
        nft.mint(user1, 1, 0, "");
        assertEq(nft.balanceOf(user1, 1), 0);

        vm.stopPrank();

        vm.startPrank(user1);

        // Burn zero amount
        nft.burn(user1, 1, 0);
        assertEq(nft.balanceOf(user1, 1), 0);

        vm.stopPrank();
    }

    function test_EdgeCase_BatchOperationsWithZeroLength() public {
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        nft.batchMint(user1, ids, amounts, "");

        vm.stopPrank();

        vm.startPrank(user1);

        nft.burnBatch(user1, ids, amounts);

        vm.stopPrank();
    }

    function test_EdgeCase_SetMaxSupplyAfterMinting() public {
        vm.startPrank(owner);

        // Mint first
        nft.mint(user1, 2, 500, "");

        // Then set max supply higher than current supply
        nft.setMaxSupply(2, 1000);

        // Should be able to mint more
        nft.mint(user1, 2, 300, "");
        assertEq(nft.totalSupply(2), 800);

        vm.stopPrank();
    }

    function test_EdgeCase_MultipleURIUpdates() public {
        vm.startPrank(owner);

        string memory uri1 = "https://first.com/";
        string memory uri2 = "https://second.com/";
        string memory uri3 = "https://third.com/";

        nft.setTokenURI(1, uri1);
        assertEq(nft.uri(1), uri1);

        nft.setTokenURI(1, uri2);
        assertEq(nft.uri(1), uri2);

        nft.setTokenURI(1, uri3);
        assertEq(nft.uri(1), uri3);

        vm.stopPrank();
    }

    // ============ CantBeEvil (a16z) License Integration Tests ============

    function test_CantBeEvil_InitializeWithDifferentLicenses() public {
        // Test all license types
        LicenseVersion[6] memory licenses = [
            LicenseVersion.PUBLIC,
            LicenseVersion.EXCLUSIVE,
            LicenseVersion.COMMERCIAL,
            LicenseVersion.COMMERCIAL_NO_HATE,
            LicenseVersion.PERSONAL,
            LicenseVersion.PERSONAL_NO_HATE
        ];

        string[6] memory expectedNames =
            ["PUBLIC", "EXCLUSIVE", "COMMERCIAL", "COMMERCIAL_NO_HATE", "PERSONAL", "PERSONAL_NO_HATE"];

        for (uint256 i = 0; i < licenses.length; i++) {
            FractalERC1155Impl testNft = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, licenses[i]);

            assertEq(testNft.getLicenseName(), expectedNames[i]);

            // Check license URI format
            string memory expectedBaseURI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/";
            string memory expectedLicenseURI = string.concat(expectedBaseURI, vm.toString(uint256(licenses[i])));
            assertEq(testNft.getLicenseURI(), expectedLicenseURI);
        }
    }

    function test_CantBeEvil_GetLicenseURI_AllVersions() public {
        string memory baseURI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/";

        // Test PUBLIC (0)
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC).getLicenseURI(), string.concat(baseURI, "0"));
        // Test EXCLUSIVE (1)
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE).getLicenseURI(), string.concat(baseURI, "1"));
        // Test COMMERCIAL (2)
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL).getLicenseURI(), string.concat(baseURI, "2"));
        // Test COMMERCIAL_NO_HATE (3)
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL_NO_HATE).getLicenseURI(), string.concat(baseURI, "3"));
        // Test PERSONAL (4)
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL).getLicenseURI(), string.concat(baseURI, "4"));
        // Test PERSONAL_NO_HATE (5)
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL_NO_HATE).getLicenseURI(), string.concat(baseURI, "5"));
    }

    function test_CantBeEvil_GetLicenseName_AllVersions() public {
        // Test each license version returns correct name
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC).getLicenseName(), "PUBLIC");
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE).getLicenseName(), "EXCLUSIVE");
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL).getLicenseName(), "COMMERCIAL");
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL_NO_HATE).getLicenseName(), "COMMERCIAL_NO_HATE");
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL).getLicenseName(), "PERSONAL");
        assertEq(_deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL_NO_HATE).getLicenseName(), "PERSONAL_NO_HATE");
    }

    function test_CantBeEvil_SupportsInterface() public {
        // Test that contract supports ICantBeEvil interface
        bytes4 cantBeEvilInterfaceId = type(ICantBeEvil).interfaceId;
        assertTrue(nft.supportsInterface(cantBeEvilInterfaceId));

        // Test that it still supports ERC1155 interface
        bytes4 erc1155InterfaceId = 0xd9b67a26;
        assertTrue(nft.supportsInterface(erc1155InterfaceId));

        // Test that it supports ERC2981 (royalty) interface
        bytes4 erc2981InterfaceId = 0x2a55205a;
        assertTrue(nft.supportsInterface(erc2981InterfaceId));

        // Test that it still supports ERC165 interface
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        assertTrue(nft.supportsInterface(erc165InterfaceId));

        // Test that it doesn't support a random interface
        bytes4 randomInterfaceId = 0xffffffff;
        assertFalse(nft.supportsInterface(randomInterfaceId));
    }

    function test_CantBeEvil_LicenseVersionSetEvent() public {
        // Test that LicenseVersionSet event is emitted during proxy initialization
        FractalERC1155Impl impl = new FractalERC1155Impl();
        bytes memory initData = abi.encodeWithSelector(
            FractalERC1155Impl.initialize.selector,
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL
        );

        vm.expectEmit(true, false, false, false);
        emit LicenseVersionSet(LicenseVersion.COMMERCIAL);

        new ERC1967Proxy(address(impl), initData);
    }

    function test_CantBeEvil_LicenseIntegrationWithERC1155Operations() public {
        // Test that license functionality works alongside normal ERC1155 operations
        vm.startPrank(owner);

        // Mint tokens
        nft.mint(user1, 0, 100, "");
        nft.mint(user1, 1, 200, "");
        assertEq(nft.balanceOf(user1, 0), 100);
        assertEq(nft.balanceOf(user1, 1), 200);

        // License functions should still work
        assertEq(nft.getLicenseName(), "COMMERCIAL");
        assertEq(nft.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");

        // Batch mint
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 2;
        ids[1] = 3;
        amounts[0] = 50;
        amounts[1] = 75;

        nft.batchMint(user1, ids, amounts, "");
        assertEq(nft.balanceOf(user1, 2), 50);
        assertEq(nft.balanceOf(user1, 3), 75);

        // License should remain the same
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        vm.stopPrank();

        // Transfer tokens
        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 0, 25, "");
        assertEq(nft.balanceOf(user1, 0), 75);
        assertEq(nft.balanceOf(user2, 0), 25);

        // License should still be accessible
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        // Burn tokens
        nft.burn(user1, 1, 50);
        assertEq(nft.balanceOf(user1, 1), 150);
        assertEq(nft.totalSupply(1), 150);

        // License should still be accessible
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        vm.stopPrank();
    }

    function test_CantBeEvil_LicenseImmutable() public {
        // License should be set during initialization and cannot be changed
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        // There should be no function to change the license after initialization
        // This is enforced by the CantBeEvil contract design

        // Mint, transfer, and burn operations shouldn't affect license
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 0, 50, "");
        nft.burn(user1, 0, 25);
        vm.stopPrank();

        assertEq(nft.getLicenseName(), "COMMERCIAL");
    }

    function test_CantBeEvil_MultipleLicenseTypesWorkflow() public {
        // Create ERC1155 contracts with different license types and test they work independently
        FractalERC1155Impl publicNft = _deployProxy("Public 1155", "PUB1155", 1000, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        FractalERC1155Impl personalNft = _deployProxy("Personal 1155", "PERS1155", 500, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL);
        FractalERC1155Impl exclusiveNft = _deployProxy("Exclusive 1155", "EXC1155", 100, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE);

        // Verify each has correct license
        assertEq(publicNft.getLicenseName(), "PUBLIC");
        assertEq(personalNft.getLicenseName(), "PERSONAL");
        assertEq(exclusiveNft.getLicenseName(), "EXCLUSIVE");

        // Test minting on each
        vm.startPrank(owner);
        publicNft.mint(user1, 0, 100, "");
        personalNft.mint(user1, 0, 200, "");
        exclusiveNft.mint(user1, 0, 50, "");
        vm.stopPrank();

        // Verify balances
        assertEq(publicNft.balanceOf(user1, 0), 100);
        assertEq(personalNft.balanceOf(user1, 0), 200);
        assertEq(exclusiveNft.balanceOf(user1, 0), 50);

        // Verify licenses remain unchanged
        assertEq(publicNft.getLicenseName(), "PUBLIC");
        assertEq(personalNft.getLicenseName(), "PERSONAL");
        assertEq(exclusiveNft.getLicenseName(), "EXCLUSIVE");
    }

    function test_CantBeEvil_LicenseWithMultipleTokenTypes() public {
        // Test that license applies to all token types in the contract
        vm.startPrank(owner);

        // Mint different token types
        nft.mint(user1, 0, 100, "");
        nft.mint(user1, 1, 200, "");
        nft.mint(user1, 999, 50, "");

        // Set different max supplies and URIs for different token types
        nft.setMaxSupply(1, 500);
        nft.setMaxSupply(999, 100);
        nft.setTokenURI(1, "https://custom1.com/");
        nft.setTokenURI(999, "https://custom999.com/");

        vm.stopPrank();

        // License should be the same for all token types
        assertEq(nft.getLicenseName(), "COMMERCIAL");
        assertEq(nft.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");

        // Different token URIs don't affect license
        assertEq(nft.uri(1), "https://custom1.com/");
        assertEq(nft.uri(999), "https://custom999.com/");
        assertEq(nft.getLicenseName(), "COMMERCIAL");
    }

    function test_CantBeEvil_LicenseWithBatchOperations() public {
        // Test license functionality with batch operations
        vm.startPrank(owner);

        uint256[] memory ids = new uint256[](5);
        uint256[] memory amounts = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            ids[i] = i;
            amounts[i] = 100 * (i + 1);
        }

        // Batch mint
        nft.batchMint(user1, ids, amounts, "");

        // Verify mints
        for (uint256 i = 0; i < 5; i++) {
            assertEq(nft.balanceOf(user1, i), 100 * (i + 1));
        }

        // License should remain unchanged
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        vm.stopPrank();

        // Batch transfer
        vm.startPrank(user1);
        uint256[] memory transferAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            transferAmounts[i] = 50;
        }

        nft.safeBatchTransferFrom(user1, user2, ids, transferAmounts, "");

        // Verify transfers
        for (uint256 i = 0; i < 5; i++) {
            assertEq(nft.balanceOf(user2, i), 50);
        }

        // License should remain unchanged
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        // Batch burn
        uint256[] memory burnAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            burnAmounts[i] = 25;
        }

        nft.burnBatch(user1, ids, burnAmounts);

        // License should still be accessible
        assertEq(nft.getLicenseName(), "COMMERCIAL");

        vm.stopPrank();
    }

    // ============ Fuzz Tests for CantBeEvil ============

    function testFuzz_CantBeEvil_LicenseVersionBounds(uint8 licenseVersionRaw) public {
        vm.assume(licenseVersionRaw <= 5); // Valid license versions are 0-5

        LicenseVersion licenseVersion = LicenseVersion(licenseVersionRaw);
        FractalERC1155Impl testNft = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, licenseVersion);

        // Should not revert and should return valid license data
        string memory licenseName = testNft.getLicenseName();
        string memory licenseURI = testNft.getLicenseURI();

        // License name should not be empty
        assertTrue(bytes(licenseName).length > 0);

        // License URI should contain the base URI
        string memory baseURI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/";
        assertTrue(bytes(licenseURI).length > bytes(baseURI).length);

        // Should support ICantBeEvil interface
        assertTrue(testNft.supportsInterface(type(ICantBeEvil).interfaceId));
    }

    function testFuzz_CantBeEvil_LicenseWithRandomTokenOperations(
        uint256 tokenId,
        uint256 amount,
        uint8 licenseVersionRaw
    ) public {
        vm.assume(licenseVersionRaw <= 5);
        vm.assume(amount > 0 && amount <= 1000000);
        vm.assume(tokenId <= type(uint128).max); // Reasonable token ID range

        LicenseVersion licenseVersion = LicenseVersion(licenseVersionRaw);
        FractalERC1155Impl testNft = _deployProxy(NAME, SYMBOL, 0, BASE_URI, owner, ROYALTY_FEE, licenseVersion); // 0 max supply for unlimited

        // Store original license info
        string memory originalLicenseName = testNft.getLicenseName();
        string memory originalLicenseURI = testNft.getLicenseURI();

        // Perform random operations
        vm.startPrank(owner);
        testNft.mint(user1, tokenId, amount, "");
        vm.stopPrank();

        // License should remain unchanged
        assertEq(testNft.getLicenseName(), originalLicenseName);
        assertEq(testNft.getLicenseURI(), originalLicenseURI);

        // Transfer some tokens
        vm.startPrank(user1);
        uint256 transferAmount = amount / 2;
        if (transferAmount > 0) {
            testNft.safeTransferFrom(user1, user2, tokenId, transferAmount, "");
        }
        vm.stopPrank();

        // License should still be unchanged
        assertEq(testNft.getLicenseName(), originalLicenseName);
        assertEq(testNft.getLicenseURI(), originalLicenseURI);

        // Should still support ICantBeEvil interface
        assertTrue(testNft.supportsInterface(type(ICantBeEvil).interfaceId));
    }

    // ============ Edge Cases for CantBeEvil ============

    function test_CantBeEvil_EdgeCase_EmptyStringHandling() public {
        // Test that license functions handle edge cases properly
        string memory licenseName = nft.getLicenseName();
        string memory licenseURI = nft.getLicenseURI();

        // Neither should be empty
        assertTrue(bytes(licenseName).length > 0);
        assertTrue(bytes(licenseURI).length > 0);

        // Should be valid strings
        assertEq(licenseName, "COMMERCIAL");
        assertTrue(bytes(licenseURI).length > 10); // Reasonable minimum length
    }

    function test_CantBeEvil_EdgeCase_InterfaceIdStability() public {
        // Test that interface IDs are stable across different instances
        FractalERC1155Impl nft1 = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        FractalERC1155Impl nft2 = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE);

        bytes4 interfaceId = type(ICantBeEvil).interfaceId;

        // Both should support the same interface ID
        assertTrue(nft1.supportsInterface(interfaceId));
        assertTrue(nft2.supportsInterface(interfaceId));
        assertTrue(nft.supportsInterface(interfaceId));
    }

    // ============ ERC2981 Royalty Tests ============

    function test_Royalty_CorrectCalculation() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, salePrice);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether); // 5% of 1 ether
    }

    function test_Royalty_DifferentSalePrices() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        // Test with 10 ether
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 10 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.5 ether); // 5% of 10 ether

        // Test with 0.1 ether
        (receiver, royaltyAmount) = nft.royaltyInfo(0, 0.1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.005 ether); // 5% of 0.1 ether

        // Test with 100 wei
        (receiver, royaltyAmount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 5); // 5% of 100
    }

    function test_Royalty_ZeroSalePrice() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 0);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0);
    }

    function test_Royalty_MaxSalePrice() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        // Use a very large but safe value to avoid overflow
        uint256 maxPrice = type(uint128).max;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, maxPrice);

        assertEq(receiver, owner);
        // 5% of max uint128
        assertEq(royaltyAmount, (maxPrice * ROYALTY_FEE) / 10000);

        // Royalty should be reasonable percentage of sale price
        assertTrue(royaltyAmount <= maxPrice);
        assertTrue(royaltyAmount > 0);
    }

    function test_Royalty_NonExistentToken() public {
        // ERC2981 doesn't require token to exist, should still return royalty info
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(999, 1 ether);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether);
    }

    function test_Royalty_DifferentRoyaltyFees() public {
        // Test with 10% royalty (1000 basis points)
        FractalERC1155Impl nft10 = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, 1000, LicenseVersion.PUBLIC);

        (address receiver, uint256 royaltyAmount) = nft10.royaltyInfo(0, 1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.1 ether); // 10%

        // Test with 2.5% royalty (250 basis points)
        FractalERC1155Impl nft25 = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, 250, LicenseVersion.PUBLIC);

        (receiver, royaltyAmount) = nft25.royaltyInfo(0, 1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.025 ether); // 2.5%

        // Test with 0% royalty
        FractalERC1155Impl nft0 = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, 0, LicenseVersion.PUBLIC);

        (receiver, royaltyAmount) = nft0.royaltyInfo(0, 1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0); // 0%
    }

    function test_Royalty_ReceiverIsOwner() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        (address receiver,) = nft.royaltyInfo(0, 1 ether);

        // Royalty receiver should be the owner
        assertEq(receiver, owner);
    }

    function test_Royalty_SetTokenRoyalty_SuccessWithinCap() public {
        vm.startPrank(owner);
        nft.mint(user1, 7, 10, "");
        nft.setTokenRoyalty(7, user2, 1000);
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(7, 1 ether);
        assertEq(receiver, user2);
        assertEq(royaltyAmount, 0.1 ether);
    }

    function test_Royalty_SetTokenRoyalty_RevertIf_AboveCap() public {
        vm.startPrank(owner);
        nft.mint(user1, 7, 10, "");
        vm.expectRevert(FractalERC1155Impl.RoyaltyExceedsCap.selector);
        nft.setTokenRoyalty(7, user2, 1001);
        vm.stopPrank();
    }

    function test_Royalty_SetDefaultRoyaltyInfo_Success() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        nft.setDefaultRoyaltyInfo(user2, 750);
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 2 ether);

        assertEq(receiver, user2);
        assertEq(royaltyAmount, 0.15 ether);
    }

    function test_Royalty_SetDefaultRoyaltyInfo_RevertIf_AboveCap() public {
        vm.startPrank(owner);

        vm.expectRevert(FractalERC1155Impl.RoyaltyExceedsCap.selector);
        nft.setDefaultRoyaltyInfo(user2, 1001);

        vm.stopPrank();
    }

    function test_Royalty_ResetTokenRoyalty_FallsBackToDefault() public {
        vm.startPrank(owner);
        nft.mint(user1, 7, 10, "");
        nft.setTokenRoyalty(7, user2, 1000);
        nft.resetTokenRoyalty(7);
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(7, 1 ether);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether);
    }

    function test_SetLicenseVersion_UpdatesLicenseMetadata() public {
        vm.startPrank(owner);

        nft.setLicenseVersion(LicenseVersion.PUBLIC);

        vm.stopPrank();

        assertEq(nft.getLicenseName(), "PUBLIC");
        assertTrue(bytes(nft.getLicenseURI()).length > 0);
        assertTrue(nft.supportsInterface(type(ICantBeEvil).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC2981).interfaceId));
    }

    function test_Royalty_AfterTokenTransfer() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        // Transfer tokens to user2
        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 0, 5, "");
        vm.stopPrank();

        // Royalty should still go to original owner, not new token holder
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether);
    }

    function test_Royalty_AfterBurn() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        vm.startPrank(user1);
        nft.burn(user1, 0, 10);
        vm.stopPrank();

        // Royalty info should still be available even after burn
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether);
    }

    function test_Royalty_MultipleTokenIdsSameRoyalty() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        nft.mint(user1, 1, 20, "");
        nft.mint(user2, 2, 30, "");
        vm.stopPrank();

        // All token IDs should have same royalty info
        (address receiver0, uint256 amount0) = nft.royaltyInfo(0, 1 ether);
        (address receiver1, uint256 amount1) = nft.royaltyInfo(1, 1 ether);
        (address receiver2, uint256 amount2) = nft.royaltyInfo(2, 1 ether);

        assertEq(receiver0, owner);
        assertEq(receiver1, owner);
        assertEq(receiver2, owner);
        assertEq(amount0, 0.05 ether);
        assertEq(amount1, 0.05 ether);
        assertEq(amount2, 0.05 ether);
    }

    function test_Royalty_DifferentAmountsOfSameToken() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();

        // Royalty should be based on sale price, not token amount
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 1 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether);

        // Even if selling multiple tokens, royalty is per-sale-price
        (receiver, royaltyAmount) = nft.royaltyInfo(0, 10 ether);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.5 ether);
    }

    // ============ Fuzz Tests for Royalty ============

    function testFuzz_Royalty_VariousSalePrices(uint256 salePrice) public {
        vm.assume(salePrice <= type(uint128).max); // Prevent overflow in calculation

        vm.startPrank(owner);
        nft.mint(user1, 0, 10, "");
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, salePrice);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, (salePrice * ROYALTY_FEE) / 10000);

        // Royalty should never exceed sale price
        assertTrue(royaltyAmount <= salePrice);
    }

    function testFuzz_Royalty_VariousTokenIds(uint256 tokenId) public {
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, 1 ether);

        // Should return consistent royalty info regardless of token ID
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.05 ether);
    }

    function testFuzz_Royalty_VariousFees(uint96 royaltyFee) public {
        vm.assume(royaltyFee <= 1000); // Max 10% royalty

        FractalERC1155Impl customNft = _deployProxy(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, royaltyFee, LicenseVersion.PUBLIC);

        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = customNft.royaltyInfo(0, salePrice);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, (salePrice * royaltyFee) / 10000);

        // Royalty should never exceed 10% of sale price
        assertTrue(royaltyAmount <= salePrice);
    }

    // ============ Set Base URI Tests ============

    function test_SetBaseURI_Success() public {
        vm.startPrank(owner);

        string memory newBaseURI = "ipfs://QmNewHash/";
        nft.setBaseURI(newBaseURI);

        assertEq(nft.uri(0), string.concat(newBaseURI, "0"));
        assertEq(nft.uri(5), string.concat(newBaseURI, "5"));

        vm.stopPrank();
    }

    function test_SetBaseURI_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);

        vm.expectRevert();
        nft.setBaseURI("ipfs://hacked/");

        vm.stopPrank();
    }

    function test_SetBaseURI_EmitsBaseURISetEvent() public {
        vm.startPrank(owner);

        string memory newBaseURI = "ipfs://QmNewHash/";

        vm.expectEmit(false, false, false, true);
        emit BaseURISet(newBaseURI);

        nft.setBaseURI(newBaseURI);

        vm.stopPrank();
    }

    function test_SetBaseURI_DoesNotAffectCustomTokenURIs() public {
        vm.startPrank(owner);

        nft.setTokenURI(1, "https://custom.com/1");
        nft.setBaseURI("ipfs://QmNewBase/");

        // Custom URI should remain
        assertEq(nft.uri(1), "https://custom.com/1");

        // Others use new base
        assertEq(nft.uri(0), "ipfs://QmNewBase/0");
        assertEq(nft.uri(2), "ipfs://QmNewBase/2");

        vm.stopPrank();
    }

    function test_SetBaseURI_ToEmpty() public {
        vm.startPrank(owner);

        nft.setBaseURI("");

        assertEq(nft.uri(0), "");
        assertEq(nft.uri(5), "");

        // Custom URIs should still work
        nft.setTokenURI(1, "https://custom.com/1");
        assertEq(nft.uri(1), "https://custom.com/1");

        vm.stopPrank();
    }

    // ============ Standard URI Event Tests ============

    function test_SetTokenURI_EmitsStandardURIEvent() public {
        vm.startPrank(owner);

        string memory tokenURI = "https://custom.com/token/1";

        vm.expectEmit(true, true, true, true);
        emit URI(tokenURI, 1);

        nft.setTokenURI(1, tokenURI);

        vm.stopPrank();
    }

    // ============ MaxSupplySet Event Test ============

    function test_SetMaxSupply_EmitsMaxSupplySetEvent() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit MaxSupplySet(1, 500);

        nft.setMaxSupply(1, 500);

        vm.stopPrank();
    }

    // ============ setLicenseVersion Tests ============

    function test_SetLicenseVersion_EmitsEvent() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit LicenseVersionSet(LicenseVersion.PUBLIC);
        nft.setLicenseVersion(LicenseVersion.PUBLIC);

        vm.stopPrank();
        assertEq(nft.getLicenseName(), "PUBLIC");
    }

    function test_SetLicenseVersion_CyclesThroughAllVersions() public {
        vm.startPrank(owner);

        LicenseVersion[6] memory versions = [
            LicenseVersion.PUBLIC,
            LicenseVersion.EXCLUSIVE,
            LicenseVersion.COMMERCIAL,
            LicenseVersion.COMMERCIAL_NO_HATE,
            LicenseVersion.PERSONAL,
            LicenseVersion.PERSONAL_NO_HATE
        ];
        string[6] memory names = [
            "PUBLIC", "EXCLUSIVE", "COMMERCIAL", "COMMERCIAL_NO_HATE", "PERSONAL", "PERSONAL_NO_HATE"
        ];

        for (uint256 i = 0; i < versions.length; i++) {
            vm.expectEmit(true, false, false, false);
            emit LicenseVersionSet(versions[i]);
            nft.setLicenseVersion(versions[i]);
            assertEq(nft.getLicenseName(), names[i]);
        }

        vm.stopPrank();
    }

    function test_SetLicenseVersion_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);
        vm.expectRevert();
        nft.setLicenseVersion(LicenseVersion.PUBLIC);
        vm.stopPrank();
    }

    // ============ setDefaultRoyaltyInfo Event + Resale Tests ============

    function test_SetDefaultRoyaltyInfo_EmitsDefaultRoyaltySetEvent() public {
        vm.startPrank(owner);

        vm.expectEmit(false, false, false, true);
        emit DefaultRoyaltySet(user2, 750);
        nft.setDefaultRoyaltyInfo(user2, 750);

        vm.stopPrank();
    }

    function test_SetTokenRoyalty_EmitsTokenRoyaltySetEvent() public {
        vm.startPrank(owner);
        nft.mint(user1, 7, 10, "");

        vm.expectEmit(true, false, false, true);
        emit TokenRoyaltySet(7, user2, 800);
        nft.setTokenRoyalty(7, user2, 800);

        vm.stopPrank();
    }

    function test_SetDefaultRoyaltyInfo_RoyaltyPersistsAfterResale() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");

        // Change the royalty recipient and rate
        nft.setDefaultRoyaltyInfo(user2, 750); // 7.5%
        vm.stopPrank();

        // --- First resale: user1 -> user2 ---
        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 0, 50, "");
        vm.stopPrank();

        // Royalty should reflect the new default, not init values
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 1 ether);
        assertEq(receiver, user2);
        assertEq(royaltyAmount, 0.075 ether); // 7.5%

        // --- Second resale: user2 -> user1 ---
        vm.startPrank(user2);
        nft.safeTransferFrom(user2, user1, 0, 25, "");
        vm.stopPrank();

        (receiver, royaltyAmount) = nft.royaltyInfo(0, 2 ether);
        assertEq(receiver, user2);
        assertEq(royaltyAmount, 0.15 ether); // 7.5% of 2 ether
    }

    function test_SetTokenRoyalty_OverridesDefaultForResale() public {
        vm.startPrank(owner);
        nft.mint(user1, 1, 100, "");
        nft.mint(user1, 2, 100, "");

        // Per-token royalty on token 1 only
        nft.setTokenRoyalty(1, user2, 1000); // 10%
        vm.stopPrank();

        // Token 1 resale: uses per-token royalty
        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 1, 50, "");
        vm.stopPrank();

        (address receiver1, uint256 amount1) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver1, user2);
        assertEq(amount1, 0.1 ether); // 10% per-token

        // Token 2 resale: still uses default (5%)
        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 2, 50, "");
        vm.stopPrank();

        (address receiver2, uint256 amount2) = nft.royaltyInfo(2, 1 ether);
        assertEq(receiver2, owner);
        assertEq(amount2, 0.05 ether); // 5% default
    }

    function test_ResetTokenRoyalty_FallsBackToDefaultForResale() public {
        vm.startPrank(owner);
        nft.mint(user1, 5, 100, "");
        nft.setTokenRoyalty(5, user2, 1000); // 10% per-token override

        // Reset removes the override -> falls back to default (owner, 5%)
        nft.resetTokenRoyalty(5);
        vm.stopPrank();

        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, 5, 50, "");
        vm.stopPrank();

        (address receiver, uint256 amount) = nft.royaltyInfo(5, 1 ether);
        assertEq(receiver, owner);
        assertEq(amount, 0.05 ether);
    }

    function test_DefaultRoyaltySet_UpdateAffectsAllUnoverriddentTokensOnResale() public {
        vm.startPrank(owner);
        nft.mint(user1, 1, 100, "");
        nft.mint(user1, 2, 100, "");
        nft.mint(user1, 3, 100, "");

        // Token 2 gets a per-token override; tokens 1 and 3 use default
        nft.setTokenRoyalty(2, user2, 800); // 8%

        // Change the default
        nft.setDefaultRoyaltyInfo(user1, 300); // 3%
        vm.stopPrank();

        // Token 1 (no override) should use the new default
        (address r1, uint256 a1) = nft.royaltyInfo(1, 1 ether);
        assertEq(r1, user1);
        assertEq(a1, 0.03 ether);

        // Token 2 (has override) must NOT be affected by default change
        (address r2, uint256 a2) = nft.royaltyInfo(2, 1 ether);
        assertEq(r2, user2);
        assertEq(a2, 0.08 ether);

        // Token 3 (no override) should also use the new default
        (address r3, uint256 a3) = nft.royaltyInfo(3, 1 ether);
        assertEq(r3, user1);
        assertEq(a3, 0.03 ether);
    }
}
