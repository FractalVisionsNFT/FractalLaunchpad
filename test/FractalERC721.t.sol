// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LicenseVersion, FractalERC721Impl} from "../src/FractalERC721.sol";
import {ICantBeEvil} from "@a16z/contracts/licenses/ICantBeEvil.sol";

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
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        unauthorized = makeAddr("unauthorized");
        
        // Deploy the implementation
        nft = new FractalERC721Impl();
        
        // Initialize with owner
        nft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL);
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
        FractalERC721Impl infiniteNft = new FractalERC721Impl();
        infiniteNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner, LicenseVersion.PUBLIC);
        
        assertEq(infiniteNft.maxSupply(), 0);
        assertEq(infiniteNft.name(), NAME);
        assertEq(infiniteNft.symbol(), SYMBOL);
        assertEq(infiniteNft.owner(), owner);
    }
    
    function test_Initialize_CannotReinitialize() public {
        FractalERC721Impl newNft = new FractalERC721Impl();
        newNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner, LicenseVersion.PUBLIC);
        
        // Should revert if we try to initialize again
        vm.expectRevert();
        newNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL);
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
        infiniteNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner, LicenseVersion.PUBLIC);
        
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
        infiniteNft.initialize(NAME, SYMBOL, 0, BASE_URI, owner, LicenseVersion.PUBLIC);
        
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
            FractalERC721Impl testNft = new FractalERC721Impl();
            testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, licenses[i]);
            
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
        FractalERC721Impl publicNft = new FractalERC721Impl();
        publicNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.PUBLIC);
        assertEq(publicNft.getLicenseURI(), string.concat(baseURI, "0"));
        
        // Test EXCLUSIVE (1)
        FractalERC721Impl exclusiveNft = new FractalERC721Impl();
        exclusiveNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.EXCLUSIVE);
        assertEq(exclusiveNft.getLicenseURI(), string.concat(baseURI, "1"));
        
        // Test COMMERCIAL (2)
        FractalERC721Impl commercialNft = new FractalERC721Impl();
        commercialNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL);
        assertEq(commercialNft.getLicenseURI(), string.concat(baseURI, "2"));
        
        // Test COMMERCIAL_NO_HATE (3)
        FractalERC721Impl commercialNoHateNft = new FractalERC721Impl();
        commercialNoHateNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL_NO_HATE);
        assertEq(commercialNoHateNft.getLicenseURI(), string.concat(baseURI, "3"));
        
        // Test PERSONAL (4)
        FractalERC721Impl personalNft = new FractalERC721Impl();
        personalNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.PERSONAL);
        assertEq(personalNft.getLicenseURI(), string.concat(baseURI, "4"));
        
        // Test PERSONAL_NO_HATE (5)
        FractalERC721Impl personalNoHateNft = new FractalERC721Impl();
        personalNoHateNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.PERSONAL_NO_HATE);
        assertEq(personalNoHateNft.getLicenseURI(), string.concat(baseURI, "5"));
    }
    
    function test_CantBeEvil_GetLicenseName_AllVersions() public {
        // Test each license version returns correct name
        FractalERC721Impl testNft;
        
        testNft = new FractalERC721Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.PUBLIC);
        assertEq(testNft.getLicenseName(), "PUBLIC");
        
        testNft = new FractalERC721Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.EXCLUSIVE);
        assertEq(testNft.getLicenseName(), "EXCLUSIVE");
        
        testNft = new FractalERC721Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL);
        assertEq(testNft.getLicenseName(), "COMMERCIAL");
        
        testNft = new FractalERC721Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL_NO_HATE);
        assertEq(testNft.getLicenseName(), "COMMERCIAL_NO_HATE");
        
        testNft = new FractalERC721Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.PERSONAL);
        assertEq(testNft.getLicenseName(), "PERSONAL");
        
        testNft = new FractalERC721Impl();
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.PERSONAL_NO_HATE);
        assertEq(testNft.getLicenseName(), "PERSONAL_NO_HATE");
    }
    
    function test_CantBeEvil_SupportsInterface() public {
        // Test that contract supports ICantBeEvil interface
        bytes4 cantBeEvilInterfaceId = type(ICantBeEvil).interfaceId;
        assertTrue(nft.supportsInterface(cantBeEvilInterfaceId));
        
        // Test that it still supports ERC721 interface
        bytes4 erc721InterfaceId = 0x80ac58cd;
        assertTrue(nft.supportsInterface(erc721InterfaceId));
        
        // Test that it still supports ERC165 interface
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        assertTrue(nft.supportsInterface(erc165InterfaceId));
        
        // Test that it doesn't support a random interface
        bytes4 randomInterfaceId = 0xffffffff;
        assertFalse(nft.supportsInterface(randomInterfaceId));
    }
    
    function test_CantBeEvil_LicenseVersionSetEvent() public {
        // Test that LicenseVersionSet event is emitted during initialization
        FractalERC721Impl testNft = new FractalERC721Impl();
        
        vm.expectEmit(true, true, true, true);
        emit LicenseVersionSet(LicenseVersion.COMMERCIAL);
        
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, LicenseVersion.COMMERCIAL);
    }
    
    function test_CantBeEvil_LicenseIntegrationWithNFTOperations() public {
        // Test that license functionality works alongside normal NFT operations
        vm.startPrank(owner);
        
        // Mint NFT
        nft.mint(user1, 1);
        assertEq(nft.ownerOf(1), user1);
        
        // License functions should still work
        assertEq(nft.getLicenseName(), "COMMERCIAL");
        assertEq(nft.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");
        
        // Transfer NFT
        vm.stopPrank();
        vm.startPrank(user1);
        nft.transferFrom(user1, user2, 1);
        assertEq(nft.ownerOf(1), user2);
        
        // License should remain the same
        assertEq(nft.getLicenseName(), "COMMERCIAL");
        
        // Burn NFT
        vm.stopPrank();
        vm.startPrank(user2);
        nft.burn(1);
        
        // License should still be accessible
        assertEq(nft.getLicenseName(), "COMMERCIAL");
        
        vm.stopPrank();
    }
    
    function test_CantBeEvil_LicenseImmutable() public {
        // License should be set during initialization and cannot be changed
        assertEq(nft.getLicenseName(), "COMMERCIAL");
        
        // There should be no function to change the license after initialization
        // This is enforced by the CantBeEvil contract design
        
        // Mint and transfer operations shouldn't affect license
        vm.startPrank(owner);
        nft.mint(user1, 1);
        vm.stopPrank();
        
        vm.startPrank(user1);
        nft.transferFrom(user1, user2, 1);
        vm.stopPrank();
        
        assertEq(nft.getLicenseName(), "COMMERCIAL");
    }
    
    function test_CantBeEvil_MultipleLicenseTypesWorkflow() public {
        // Create NFTs with different license types and test they work independently
        FractalERC721Impl publicNft = new FractalERC721Impl();
        FractalERC721Impl personalNft = new FractalERC721Impl();
        FractalERC721Impl exclusiveNft = new FractalERC721Impl();
        
        publicNft.initialize("Public NFT", "PUB", 1000, BASE_URI, owner, LicenseVersion.PUBLIC);
        personalNft.initialize("Personal NFT", "PERS", 500, BASE_URI, owner, LicenseVersion.PERSONAL);
        exclusiveNft.initialize("Exclusive NFT", "EXC", 100, BASE_URI, owner, LicenseVersion.EXCLUSIVE);
        
        // Verify each has correct license
        assertEq(publicNft.getLicenseName(), "PUBLIC");
        assertEq(personalNft.getLicenseName(), "PERSONAL");
        assertEq(exclusiveNft.getLicenseName(), "EXCLUSIVE");
        
        // Test minting on each
        vm.startPrank(owner);
        publicNft.mint(user1, 1);
        personalNft.mint(user1, 1);
        exclusiveNft.mint(user1, 1);
        vm.stopPrank();
        
        // Verify owners
        assertEq(publicNft.ownerOf(1), user1);
        assertEq(personalNft.ownerOf(1), user1);
        assertEq(exclusiveNft.ownerOf(1), user1);
        
        // Verify licenses remain unchanged
        assertEq(publicNft.getLicenseName(), "PUBLIC");
        assertEq(personalNft.getLicenseName(), "PERSONAL");
        assertEq(exclusiveNft.getLicenseName(), "EXCLUSIVE");
    }
    
    // ============ Fuzz Tests for CantBeEvil ============
    
    function testFuzz_CantBeEvil_LicenseVersionBounds(uint8 licenseVersionRaw) public {
        vm.assume(licenseVersionRaw <= 5); // Valid license versions are 0-5
        
        LicenseVersion licenseVersion = LicenseVersion(licenseVersionRaw);
        FractalERC721Impl testNft = new FractalERC721Impl();
        
        testNft.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, licenseVersion);
        
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
}