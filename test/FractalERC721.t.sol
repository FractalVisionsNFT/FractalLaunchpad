// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FractalERC721Impl} from "../src/FractalERC721.sol";

contract FractalERC721Test is Test {
    FractalERC721Impl public nft;
    
    address public owner;
    address public user1;
    address public user2;
    address public unauthorized;
    
    string public constant NAME = "Test NFT";
    string public constant SYMBOL = "TNFT";
    uint256 public constant MAX_SUPPLY = 1000;
    string public constant BASE_URI = "https://test.com/";
    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        unauthorized = makeAddr("unauthorized");
        
        // Deploy the implementation
        nft = new FractalERC721Impl();
        
        // Initialize with owner
        nft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner);
    }
    
    // ============ Initialization Tests ============
    
    function test_Initialize_Success() public {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertEq(nft.baseTokenURI(), BASE_URI);
        assertEq(nft.owner(), owner);
        assertEq(nft.totalSupply(), 0);
    }
    
    function test_Initialize_ZeroMaxSupply() public {
        FractalERC721Impl newNft = new FractalERC721Impl();
        newNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner);
        
        assertEq(newNft.maxSupply(), 0);
        // Should allow infinite minting when max supply is 0
    }
    
    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        nft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner);
    }
    
    // ============ Mint Tests ============
    
    function test_Mint_Success() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user1, 1);
        
        nft.mint(user1, 1);
        
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.balanceOf(user1), 1);
        
        vm.stopPrank();
    }
    
    function test_Mint_MultipleTokens() public {
        vm.startPrank(owner);
        
        nft.mint(user1, 1);
        nft.mint(user1, 2);
        nft.mint(user2, 3);
        
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user1);
        assertEq(nft.ownerOf(3), user2);
        
        vm.stopPrank();
    }
    
    function test_Mint_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);
        
        vm.expectRevert();
        nft.mint(user1, 1);
        
        vm.stopPrank();
    }
    
    function test_Mint_RevertIf_MaxSupplyExceeded() public {
        vm.startPrank(owner);
        
        // Mint up to max supply
        for (uint256 i = 1; i <= MAX_SUPPLY; i++) {
            nft.mint(user1, i);
        }
        
        // This should revert
        vm.expectRevert(FractalERC721Impl.MaxSupplyExceeded.selector);
        nft.mint(user1, MAX_SUPPLY + 1);
        
        vm.stopPrank();
    }
    
    function test_Mint_InfiniteWhenMaxSupplyZero() public {
        // Create NFT with zero max supply
        FractalERC721Impl infiniteNft = new FractalERC721Impl();
        infiniteNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner);
        
        vm.startPrank(owner);
        
        // Should be able to mint way beyond normal limits
        for (uint256 i = 1; i <= 1500; i++) {
            infiniteNft.mint(user1, i);
        }
        
        assertEq(infiniteNft.totalSupply(), 1500);
        
        vm.stopPrank();
    }
    
    function test_Mint_RevertIf_TokenAlreadyExists() public {
        vm.startPrank(owner);
        
        nft.mint(user1, 1);
        
        vm.expectRevert();
        nft.mint(user2, 1); // Same token ID
        
        vm.stopPrank();
    }
    
    // ============ Batch Mint Tests ============
    
    function test_BatchMint_Success() public {
        vm.startPrank(owner);
        
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        
        nft.batchMint(user1, tokenIds);
        
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.balanceOf(user1), 3);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user1);
        assertEq(nft.ownerOf(3), user1);
        
        vm.stopPrank();
    }
    
    function test_BatchMint_EmptyArray() public {
        vm.startPrank(owner);
        
        uint256[] memory tokenIds = new uint256[](0);
        nft.batchMint(user1, tokenIds);
        
        assertEq(nft.totalSupply(), 0);
        
        vm.stopPrank();
    }
    
    function test_BatchMint_RevertIf_MaxSupplyExceeded() public {
        vm.startPrank(owner);
        
        uint256[] memory tokenIds = new uint256[](MAX_SUPPLY + 1);
        for (uint256 i = 0; i <= MAX_SUPPLY; i++) {
            tokenIds[i] = i + 1;
        }
        
        vm.expectRevert(FractalERC721Impl.MaxSupplyExceeded.selector);
        nft.batchMint(user1, tokenIds);
        
        vm.stopPrank();
    }
    
    function test_BatchMint_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        
        vm.expectRevert();
        nft.batchMint(user1, tokenIds);
        
        vm.stopPrank();
    }
    
    function test_BatchMint_InfiniteWhenMaxSupplyZero() public {
        FractalERC721Impl infiniteNft = new FractalERC721Impl();
        infiniteNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner);
        
        vm.startPrank(owner);
        
        uint256[] memory tokenIds = new uint256[](2000);
        for (uint256 i = 0; i < 2000; i++) {
            tokenIds[i] = i + 1;
        }
        
        infiniteNft.batchMint(user1, tokenIds);
        assertEq(infiniteNft.totalSupply(), 2000);
        
        vm.stopPrank();
    }
    
    // ============ Set Max Supply Tests ============
    
    function test_SetMaxSupply_Success() public {
        vm.startPrank(owner);
        
        uint256 newMaxSupply = 2000;
        nft.setMaxSupply(newMaxSupply);
        
        assertEq(nft.maxSupply(), newMaxSupply);
        
        vm.stopPrank();
    }
    
    function test_SetMaxSupply_ToZero() public {
        vm.startPrank(owner);
        
        nft.setMaxSupply(0);
        assertEq(nft.maxSupply(), 0);
        
        // Should now allow infinite minting
        for (uint256 i = 1; i <= 1500; i++) {
            nft.mint(user1, i);
        }
        
        assertEq(nft.totalSupply(), 1500);
        
        vm.stopPrank();
    }
    
    function test_SetMaxSupply_RevertIf_BelowCurrentSupply() public {
        vm.startPrank(owner);
        
        // Mint some tokens first
        nft.mint(user1, 1);
        nft.mint(user1, 2);
        nft.mint(user1, 3);
        
        // Try to set max supply below current supply
        vm.expectRevert(FractalERC721Impl.MaxSupplyBelowCurrentSupply.selector);
        nft.setMaxSupply(2);
        
        vm.stopPrank();
    }
    
    function test_SetMaxSupply_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);
        
        vm.expectRevert();
        nft.setMaxSupply(500);
        
        vm.stopPrank();
    }
    
    // ============ Set Base URI Tests ============
    
    function test_SetBaseURI_Success() public {
        vm.startPrank(owner);
        
        string memory newBaseURI = "https://newuri.com/";
        nft.setBaseURI(newBaseURI);
        
        assertEq(nft.baseTokenURI(), newBaseURI);
        
        vm.stopPrank();
    }
    
    function test_SetBaseURI_RevertIf_NotOwner() public {
        vm.startPrank(unauthorized);
        
        vm.expectRevert();
        nft.setBaseURI("https://hack.com/");
        
        vm.stopPrank();
    }
    
    function test_TokenURI_UsesBaseURI() public {
        vm.startPrank(owner);
        
        nft.mint(user1, 1);
        
        string memory expectedURI = string.concat(BASE_URI, "1");
        assertEq(nft.tokenURI(1), expectedURI);
        
        // Change base URI and verify
        string memory newBaseURI = "https://newdomain.com/metadata/";
        nft.setBaseURI(newBaseURI);
        
        string memory newExpectedURI = string.concat(newBaseURI, "1");
        assertEq(nft.tokenURI(1), newExpectedURI);
        
        vm.stopPrank();
    }
    
    // ============ Burn Tests ============
    
    function test_Burn_Success() public {
        vm.startPrank(owner);
        nft.mint(user1, 1);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, address(0), 1);
        
        nft.burn(1);
        
        assertEq(nft.totalSupply(), 0);
        
        vm.expectRevert();
        nft.ownerOf(1); // Should revert as token doesn't exist
        
        vm.stopPrank();
    }
    
    function test_Burn_RevertIf_NotAuthorized() public {
        vm.startPrank(owner);
        nft.mint(user1, 1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        
        vm.expectRevert(FractalERC721Impl.NotAuthorized.selector);
        nft.burn(1);
        
        vm.stopPrank();
    }
    
    function test_Burn_RevertIf_TokenNotExists() public {
        vm.startPrank(user1);
        
        // Trying to burn non-existent token should revert with underflow
        vm.expectRevert();
        nft.burn(999);
        
        vm.stopPrank();
    }
    
    function test_Burn_ByApprovedAddress() public {
        vm.startPrank(owner);
        nft.mint(user1, 1);
        vm.stopPrank();
        
        vm.startPrank(user1);
        nft.approve(user2, 1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        nft.burn(1);
        
        assertEq(nft.totalSupply(), 0);
        vm.stopPrank();
    }
    
    function test_Burn_ByOperator() public {
        vm.startPrank(owner);
        nft.mint(user1, 1);
        vm.stopPrank();
        
        vm.startPrank(user1);
        nft.setApprovalForAll(user2, true);
        vm.stopPrank();
        
        vm.startPrank(user2);
        nft.burn(1);
        
        assertEq(nft.totalSupply(), 0);
        vm.stopPrank();
    }
    
    // ============ Integration Tests ============
    
    function test_FullWorkflow() public {
        vm.startPrank(owner);
        
        // 1. Mint tokens
        nft.mint(user1, 1);
        nft.mint(user1, 2);
        
        uint256[] memory batchTokens = new uint256[](3);
        batchTokens[0] = 3;
        batchTokens[1] = 4;
        batchTokens[2] = 5;
        nft.batchMint(user2, batchTokens);
        
        assertEq(nft.totalSupply(), 5);
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.balanceOf(user2), 3);
        
        // 2. Update max supply
        nft.setMaxSupply(10);
        assertEq(nft.maxSupply(), 10);
        
        // 3. Update base URI
        nft.setBaseURI("https://updated.com/");
        assertEq(nft.tokenURI(1), "https://updated.com/1");
        
        vm.stopPrank();
        
        // 4. User burns their token
        vm.startPrank(user1);
        nft.burn(1);
        
        assertEq(nft.totalSupply(), 4);
        assertEq(nft.balanceOf(user1), 1);
        
        vm.stopPrank();
    }
    
    function test_MaxSupplyEnforcement() public {
        vm.startPrank(owner);
        
        // Set a low max supply
        nft.setMaxSupply(3);
        
        // Mint up to max
        nft.mint(user1, 1);
        nft.mint(user1, 2);
        nft.mint(user1, 3);
        
        // Next mint should fail
        vm.expectRevert(FractalERC721Impl.MaxSupplyExceeded.selector);
        nft.mint(user1, 4);
        
        // Burn one token
        vm.stopPrank();
        vm.startPrank(user1);
        nft.burn(1);
        vm.stopPrank();
        
        // Now should be able to mint again
        vm.startPrank(owner);
        nft.mint(user1, 4); // This should succeed
        assertEq(nft.totalSupply(), 3);
        
        vm.stopPrank();
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_Mint_DifferentTokenIds(uint256 _tokenId) public {
        vm.assume(_tokenId > 0 && _tokenId <= type(uint256).max);
        
        vm.startPrank(owner);
        
        nft.mint(user1, _tokenId);
        assertEq(nft.ownerOf(_tokenId), user1);
        assertEq(nft.totalSupply(), 1);
        
        vm.stopPrank();
    }
    
    function testFuzz_SetMaxSupply_ValidValues(uint256 _maxSupply) public {
        vm.assume(_maxSupply >= 0);
        
        vm.startPrank(owner);
        
        nft.setMaxSupply(_maxSupply);
        assertEq(nft.maxSupply(), _maxSupply);
        
        vm.stopPrank();
    }
    
    function testFuzz_BatchMint_DifferentSizes(uint8 _size) public {
        vm.assume(_size > 0 && _size <= 100); // Reasonable size for testing
        
        vm.startPrank(owner);
        
        uint256[] memory tokenIds = new uint256[](_size);
        for (uint256 i = 0; i < _size; i++) {
            tokenIds[i] = i + 1;
        }
        
        nft.batchMint(user1, tokenIds);
        
        assertEq(nft.totalSupply(), _size);
        assertEq(nft.balanceOf(user1), _size);
        
        vm.stopPrank();
    }
    
    // ============ Edge Cases ============
    
    function test_EdgeCase_MintTokenIdZero() public {
        vm.startPrank(owner);
        
        // Token ID 0 should work fine
        nft.mint(user1, 0);
        assertEq(nft.ownerOf(0), user1);
        
        vm.stopPrank();
    }
    
    function test_EdgeCase_MintMaxTokenId() public {
        vm.startPrank(owner);
        
        uint256 maxTokenId = type(uint256).max;
        nft.mint(user1, maxTokenId);
        assertEq(nft.ownerOf(maxTokenId), user1);
        
        vm.stopPrank();
    }
    
    function test_EdgeCase_SetMaxSupplyToCurrentSupply() public {
        vm.startPrank(owner);
        
        nft.mint(user1, 1);
        nft.mint(user1, 2);
        
        // Set max supply equal to current supply
        nft.setMaxSupply(2);
        assertEq(nft.maxSupply(), 2);
        
        // Should not be able to mint more
        vm.expectRevert(FractalERC721Impl.MaxSupplyExceeded.selector);
        nft.mint(user1, 3);
        
        vm.stopPrank();
    }
    
    function test_EdgeCase_BurnAndMintAgain() public {
        vm.startPrank(owner);
        nft.mint(user1, 1);
        vm.stopPrank();
        
        vm.startPrank(user1);
        nft.burn(1);
        vm.stopPrank();
        
        vm.startPrank(owner);
        // Should be able to mint the same token ID again
        nft.mint(user2, 1);
        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.totalSupply(), 1);
        vm.stopPrank();
    }
}