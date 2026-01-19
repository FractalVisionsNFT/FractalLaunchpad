// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LicenseVersion, FractalERC1155Impl} from "../src/FractalERC1155.sol";
import {ICantBeEvil} from "@a16z/contracts/licenses/ICantBeEvil.sol";

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
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event URI(string value, uint256 indexed id);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        operator = makeAddr("operator");
        unauthorized = makeAddr("unauthorized");
        
        // Deploy the implementation
        nft = new FractalERC1155Impl();
        
        nft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);

    }
    
    // ============ Initialization Tests ============
    
    function test_Initialize_Success() public {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.maxSupply(0), MAX_SUPPLY);
        assertEq(nft.uri(0), BASE_URI);
        assertEq(nft.owner(), owner);
        assertEq(nft.totalSupply(0), 0);
    }
    
    function test_Initialize_ZeroMaxSupply() public {
        FractalERC1155Impl newNft = new FractalERC1155Impl();
        newNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        
        assertEq(newNft.maxSupply(0), 0);
        // Should allow infinite minting when max supply is 0
    }
    
    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        nft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);
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
        assertEq(nft.tokenURIs(1), tokenURI);
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
        // Token without custom URI should return base URI
        assertEq(nft.uri(5), BASE_URI);
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
    
    function test_BurnBatch_RevertIf_LengthMismatch() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](3);
        
        vm.expectRevert(FractalERC1155Impl.LengthMismatch.selector);
        nft.burnBatch(user1, ids, amounts);
        
        vm.stopPrank();
    }
    
    function test_BurnBatch_RevertIf_NotAuthorized() public {
        vm.startPrank(owner);
        nft.mint(user1, 0, 100, "");
        vm.stopPrank();
        
        vm.startPrank(user2);
        
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = 0;
        amounts[0] = 50;
        
        vm.expectRevert(FractalERC1155Impl.NotAuthorized.selector);
        nft.burnBatch(user1, ids, amounts);
        
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
        
        string[6] memory expectedNames = [
            "PUBLIC",
            "EXCLUSIVE", 
            "COMMERCIAL",
            "COMMERCIAL_NO_HATE",
            "PERSONAL",
            "PERSONAL_NO_HATE"
        ];
        
        for (uint256 i = 0; i < licenses.length; i++) {
            FractalERC1155Impl testNft = new FractalERC1155Impl();
            testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, licenses[i]);
            
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
        FractalERC1155Impl publicNft = new FractalERC1155Impl();
        publicNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        assertEq(publicNft.getLicenseURI(), string.concat(baseURI, "0"));
        
        // Test EXCLUSIVE (1)
        FractalERC1155Impl exclusiveNft = new FractalERC1155Impl();
        exclusiveNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE);
        assertEq(exclusiveNft.getLicenseURI(), string.concat(baseURI, "1"));
        
        // Test COMMERCIAL (2)
        FractalERC1155Impl commercialNft = new FractalERC1155Impl();
        commercialNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);
        assertEq(commercialNft.getLicenseURI(), string.concat(baseURI, "2"));
        
        // Test COMMERCIAL_NO_HATE (3)
        FractalERC1155Impl commercialNoHateNft = new FractalERC1155Impl();
        commercialNoHateNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL_NO_HATE);
        assertEq(commercialNoHateNft.getLicenseURI(), string.concat(baseURI, "3"));
        
        // Test PERSONAL (4)
        FractalERC1155Impl personalNft = new FractalERC1155Impl();
        personalNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL);
        assertEq(personalNft.getLicenseURI(), string.concat(baseURI, "4"));
        
        // Test PERSONAL_NO_HATE (5)
        FractalERC1155Impl personalNoHateNft = new FractalERC1155Impl();
        personalNoHateNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL_NO_HATE);
        assertEq(personalNoHateNft.getLicenseURI(), string.concat(baseURI, "5"));
    }
    
    function test_CantBeEvil_GetLicenseName_AllVersions() public {
        // Test each license version returns correct name
        FractalERC1155Impl testNft;
        
        testNft = new FractalERC1155Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        assertEq(testNft.getLicenseName(), "PUBLIC");
        
        testNft = new FractalERC1155Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE);
        assertEq(testNft.getLicenseName(), "EXCLUSIVE");
        
        testNft = new FractalERC1155Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);
        assertEq(testNft.getLicenseName(), "COMMERCIAL");
        
        testNft = new FractalERC1155Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL_NO_HATE);
        assertEq(testNft.getLicenseName(), "COMMERCIAL_NO_HATE");
        
        testNft = new FractalERC1155Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL);
        assertEq(testNft.getLicenseName(), "PERSONAL");
        
        testNft = new FractalERC1155Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL_NO_HATE);
        assertEq(testNft.getLicenseName(), "PERSONAL_NO_HATE");
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
        // Test that LicenseVersionSet event is emitted during initialization
        FractalERC1155Impl testNft = new FractalERC1155Impl();
        
        vm.expectEmit(true, true, true, true);
        emit LicenseVersionSet(LicenseVersion.COMMERCIAL);
        
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.COMMERCIAL);
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
        FractalERC1155Impl publicNft = new FractalERC1155Impl();
        FractalERC1155Impl personalNft = new FractalERC1155Impl();
        FractalERC1155Impl exclusiveNft = new FractalERC1155Impl();
        
        publicNft.initialize("Public 1155", "PUB1155", 1000, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        personalNft.initialize("Personal 1155", "PERS1155", 500, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PERSONAL);
        exclusiveNft.initialize("Exclusive 1155", "EXC1155", 100, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE);
        
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
        FractalERC1155Impl testNft = new FractalERC1155Impl();
        
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, licenseVersion);
        
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
        FractalERC1155Impl testNft = new FractalERC1155Impl();
        
        testNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner, ROYALTY_FEE, licenseVersion); // 0 max supply for unlimited
        
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
        FractalERC1155Impl nft1 = new FractalERC1155Impl();
        FractalERC1155Impl nft2 = new FractalERC1155Impl();
        
        nft1.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
        nft2.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.EXCLUSIVE);
        
        bytes4 interfaceId = type(ICantBeEvil).interfaceId;
        
        // Both should support the same interface ID
        assertTrue(nft1.supportsInterface(interfaceId));
        assertTrue(nft2.supportsInterface(interfaceId));
        assertTrue(nft.supportsInterface(interfaceId));
    }
}