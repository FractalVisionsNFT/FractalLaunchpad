// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FractalERC721WithCantBeEvil} from "../src/examples/FractalERC721WithCantBeEvil.sol";
import {FractalERC1155WithCantBeEvil} from "../src/examples/FractalERC1155WithCantBeEvil.sol";
import {LicenseVersion} from "@a16z/contracts/licenses/CantBeEvil.sol";
import {MinimalProxy} from "../src/Factory.sol";

contract CantBeEvilIntegrationTest is Test {
    FractalERC721WithCantBeEvil public erc721Implementation;
    FractalERC1155WithCantBeEvil public erc1155Implementation;
    MinimalProxy public factory;
    
    address public owner;
    address public user;
    
    // Expected Arweave URIs for each license type
    string constant PUBLIC_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/0";
    string constant EXCLUSIVE_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/1";
    string constant COMMERCIAL_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2";
    string constant COMMERCIAL_NO_HATE_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/3";
    string constant PERSONAL_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/4";
    string constant PERSONAL_NO_HATE_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/5";
    
    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        
        // Deploy implementations with different licenses
        erc721Implementation = new FractalERC721WithCantBeEvil(LicenseVersion.COMMERCIAL);
        erc1155Implementation = new FractalERC1155WithCantBeEvil(LicenseVersion.PUBLIC);
        
        // Deploy factory
        factory = new MinimalProxy();
    }
    
    // ============ ERC721 CantBeEvil Integration Tests ============
    
    function test_ERC721_LicenseIntegration_AllVersions() public {
        // Test each license version
        LicenseVersion[6] memory versions = [
            LicenseVersion.PUBLIC,
            LicenseVersion.EXCLUSIVE,
            LicenseVersion.COMMERCIAL,
            LicenseVersion.COMMERCIAL_NO_HATE,
            LicenseVersion.PERSONAL,
            LicenseVersion.PERSONAL_NO_HATE
        ];
        
        string[6] memory expectedURIs = [
            PUBLIC_URI,
            EXCLUSIVE_URI,
            COMMERCIAL_URI,
            COMMERCIAL_NO_HATE_URI,
            PERSONAL_URI,
            PERSONAL_NO_HATE_URI
        ];
        
        string[6] memory expectedNames = [
            "PUBLIC",
            "EXCLUSIVE",
            "COMMERCIAL",
            "COMMERCIAL_NO_HATE",
            "PERSONAL",
            "PERSONAL_NO_HATE"
        ];
        
        for (uint i = 0; i < versions.length; i++) {
            // Deploy new contract with specific license
            FractalERC721WithCantBeEvil nft = new FractalERC721WithCantBeEvil(versions[i]);
            
            // Initialize the contract
            nft.initialize(
                "Test NFT",
                "TNFT",
                1000,
                "https://test.com/",
                owner,
                versions[i]
            );
            
            // Test license URI and name
            assertEq(nft.getLicenseURI(), expectedURIs[i], "Incorrect license URI");
            assertEq(nft.getLicenseName(), expectedNames[i], "Incorrect license name");
            
            // Test getLicenseInfo function
            (string memory licenseURI, string memory licenseName) = nft.getLicenseInfo();
            assertEq(licenseURI, expectedURIs[i], "Incorrect license URI from getLicenseInfo");
            assertEq(licenseName, expectedNames[i], "Incorrect license name from getLicenseInfo");
        }
    }
    
    function test_ERC721_SupportsInterface() public {
        erc721Implementation.initialize(
            "Test NFT",
            "TNFT",
            1000,
            "https://test.com/",
            owner,
            LicenseVersion.COMMERCIAL
        );
        
        // Should support ERC721 interface
        assertTrue(erc721Implementation.supportsInterface(0x80ac58cd), "Should support ERC721");
        
        // Should support CantBeEvil interface
        assertTrue(erc721Implementation.supportsInterface(0x953d9b5d), "Should support ICantBeEvil");
        
        // Should support ERC165
        assertTrue(erc721Implementation.supportsInterface(0x01ffc9a7), "Should support ERC165");
    }
    
    function test_ERC721_UpdateLicense() public {
        erc721Implementation.initialize(
            "Test NFT",
            "TNFT",
            1000,
            "https://test.com/",
            owner,
            LicenseVersion.PERSONAL
        );
        
        // Initial license should be PERSONAL
        assertEq(erc721Implementation.getLicenseName(), "PERSONAL");
        assertEq(erc721Implementation.getLicenseURI(), PERSONAL_URI);
        
        // Update license (only owner can do this)
        vm.prank(owner);
        erc721Implementation.updateLicense(LicenseVersion.COMMERCIAL);
        
        // License should be updated
        assertEq(erc721Implementation.getLicenseName(), "COMMERCIAL");
        assertEq(erc721Implementation.getLicenseURI(), COMMERCIAL_URI);
    }
    
    function test_ERC721_UpdateLicense_RevertIf_NotOwner() public {
        erc721Implementation.initialize(
            "Test NFT",
            "TNFT",
            1000,
            "https://test.com/",
            owner,
            LicenseVersion.PERSONAL
        );
        
        // Should revert if non-owner tries to update license
        vm.prank(user);
        vm.expectRevert();
        erc721Implementation.updateLicense(LicenseVersion.COMMERCIAL);
    }
    
    // ============ ERC1155 CantBeEvil Integration Tests ============
    
    function test_ERC1155_LicenseIntegration_DefaultLicense() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL_NO_HATE,
            false // No token-specific licensing
        );
        
        assertEq(erc1155Implementation.getLicenseName(), "COMMERCIAL_NO_HATE");
        assertEq(erc1155Implementation.getLicenseURI(), COMMERCIAL_NO_HATE_URI);
        
        // All tokens should use the default license
        assertEq(erc1155Implementation.getLicenseURIForToken(1), COMMERCIAL_NO_HATE_URI);
        assertEq(erc1155Implementation.getLicenseNameForToken(1), "COMMERCIAL_NO_HATE");
    }
    
    function test_ERC1155_TokenSpecificLicensing() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL, // Default license
            true // Enable token-specific licensing
        );
        
        // Set specific licenses for different tokens
        vm.startPrank(owner);
        erc1155Implementation.setTokenLicense(1, LicenseVersion.PUBLIC);
        erc1155Implementation.setTokenLicense(2, LicenseVersion.EXCLUSIVE);
        erc1155Implementation.setTokenLicense(3, LicenseVersion.PERSONAL);
        vm.stopPrank();
        
        // Check default license
        assertEq(erc1155Implementation.getLicenseName(), "COMMERCIAL");
        assertEq(erc1155Implementation.getLicenseURI(), COMMERCIAL_URI);
        
        // Check token-specific licenses
        assertEq(erc1155Implementation.getLicenseNameForToken(1), "PUBLIC");
        assertEq(erc1155Implementation.getLicenseURIForToken(1), PUBLIC_URI);
        
        assertEq(erc1155Implementation.getLicenseNameForToken(2), "EXCLUSIVE");
        assertEq(erc1155Implementation.getLicenseURIForToken(2), EXCLUSIVE_URI);
        
        assertEq(erc1155Implementation.getLicenseNameForToken(3), "PERSONAL");
        assertEq(erc1155Implementation.getLicenseURIForToken(3), PERSONAL_URI);
        
        // Token without specific license should use default
        assertEq(erc1155Implementation.getLicenseNameForToken(99), "COMMERCIAL");
        assertEq(erc1155Implementation.getLicenseURIForToken(99), COMMERCIAL_URI);
    }
    
    function test_ERC1155_ComprehensiveLicenseInfo() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL,
            true // Enable token-specific licensing
        );
        
        // Set a specific license for token 1
        vm.prank(owner);
        erc1155Implementation.setTokenLicense(1, LicenseVersion.PUBLIC);
        
        // Test comprehensive license info for token with specific license
        (
            string memory defaultLicenseURI,
            string memory defaultLicenseName,
            string memory tokenLicenseURI,
            string memory tokenLicenseName,
            bool hasTokenSpecificLicense
        ) = erc1155Implementation.getComprehensiveLicenseInfo(1);
        
        assertEq(defaultLicenseURI, COMMERCIAL_URI);
        assertEq(defaultLicenseName, "COMMERCIAL");
        assertEq(tokenLicenseURI, PUBLIC_URI);
        assertEq(tokenLicenseName, "PUBLIC");
        assertTrue(hasTokenSpecificLicense);
        
        // Test for token without specific license
        (
            defaultLicenseURI,
            defaultLicenseName,
            tokenLicenseURI,
            tokenLicenseName,
            hasTokenSpecificLicense
        ) = erc1155Implementation.getComprehensiveLicenseInfo(99);
        
        assertEq(defaultLicenseURI, COMMERCIAL_URI);
        assertEq(defaultLicenseName, "COMMERCIAL");
        assertEq(tokenLicenseURI, COMMERCIAL_URI);
        assertEq(tokenLicenseName, "COMMERCIAL");
        assertFalse(hasTokenSpecificLicense);
    }
    
    function test_ERC1155_ToggleTokenSpecificLicensing() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL,
            true // Enable token-specific licensing
        );
        
        // Set a specific license for token 1
        vm.startPrank(owner);
        erc1155Implementation.setTokenLicense(1, LicenseVersion.PUBLIC);
        
        // Disable token-specific licensing
        erc1155Implementation.setTokenSpecificLicensing(false);
        vm.stopPrank();
        
        // Now all tokens should use the default license
        assertEq(erc1155Implementation.getLicenseNameForToken(1), "COMMERCIAL");
        assertEq(erc1155Implementation.getLicenseURIForToken(1), COMMERCIAL_URI);
    }
    
    function test_ERC1155_SupportsInterface() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.PUBLIC,
            false
        );
        
        // Should support ERC1155 interface
        assertTrue(erc1155Implementation.supportsInterface(0xd9b67a26), "Should support ERC1155");
        
        // Should support CantBeEvil interface
        assertTrue(erc1155Implementation.supportsInterface(0x953d9b5d), "Should support ICantBeEvil");
        
        // Should support ERC165
        assertTrue(erc1155Implementation.supportsInterface(0x01ffc9a7), "Should support ERC165");
    }
    
    // ============ Integration with Factory Tests ============
    
    function test_CreateCloneWithCantBeEvil() public {
        // Create a clone of the ERC721 implementation
        address clone = factory.createClone(address(erc721Implementation));
        FractalERC721WithCantBeEvil clonedNFT = FractalERC721WithCantBeEvil(clone);
        
        // Initialize the clone
        clonedNFT.initialize(
            "Cloned NFT",
            "CNFT",
            500,
            "https://cloned.com/",
            owner,
            LicenseVersion.EXCLUSIVE
        );
        
        // Clone should have the correct license
        assertEq(clonedNFT.getLicenseName(), "EXCLUSIVE");
        assertEq(clonedNFT.getLicenseURI(), EXCLUSIVE_URI);
        
        // Should be able to mint tokens
        vm.prank(owner);
        clonedNFT.mint(user, 1);
        
        assertEq(clonedNFT.ownerOf(1), user);
        assertEq(clonedNFT.totalSupply(), 1);
    }
    
    // ============ Event Tests ============
    
    function test_ERC721_LicenseSetEvent() public {
        erc721Implementation.initialize(
            "Test NFT",
            "TNFT",
            1000,
            "https://test.com/",
            owner,
            LicenseVersion.PERSONAL
        );
        
        // Expect the LicenseSet event when updating license
        vm.expectEmit(true, true, true, true);
        emit LicenseSet(LicenseVersion.COMMERCIAL);
        
        vm.prank(owner);
        erc721Implementation.updateLicense(LicenseVersion.COMMERCIAL);
    }
    
    function test_ERC1155_TokenLicenseSetEvent() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL,
            true
        );
        
        // Expect the TokenLicenseSet event when setting token license
        vm.expectEmit(true, true, true, true);
        emit TokenLicenseSet(1, LicenseVersion.PUBLIC);
        
        vm.prank(owner);
        erc1155Implementation.setTokenLicense(1, LicenseVersion.PUBLIC);
    }
    
    // ============ Edge Cases and Error Tests ============
    
    function test_ERC1155_SetTokenLicense_RevertIf_TokenSpecificDisabled() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL,
            false // Disable token-specific licensing
        );
        
        vm.prank(owner);
        vm.expectRevert("Token-specific licensing is disabled");
        erc1155Implementation.setTokenLicense(1, LicenseVersion.PUBLIC);
    }
    
    function test_ERC1155_SetTokenLicense_RevertIf_NotOwner() public {
        erc1155Implementation.initialize(
            "Test 1155",
            "T1155",
            "https://test.com/{id}",
            owner,
            LicenseVersion.COMMERCIAL,
            true
        );
        
        vm.prank(user);
        vm.expectRevert();
        erc1155Implementation.setTokenLicense(1, LicenseVersion.PUBLIC);
    }
    
    // ============ Helper Events ============
    
    event LicenseSet(LicenseVersion licenseVersion);
    event TokenLicenseSet(uint256 indexed tokenId, LicenseVersion licenseVersion);
}