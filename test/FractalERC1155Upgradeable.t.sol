// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LicenseVersion, FractalERC1155Impl} from "../src/FractalERC1155.sol";
import {ICantBeEvil} from "@a16z/contracts/licenses/ICantBeEvil.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Mock upgraded version for testing
contract FractalERC1155ImplV2 is FractalERC1155Impl {
    // New state variables to test storage layout preservation
    uint256 public newFeature;
    mapping(uint256 => bool) public tokenFlags;
    
    // New functions to test upgrade functionality
    function setNewFeature(uint256 _value) external onlyOwner {
        newFeature = _value;
    }
    
    function setTokenFlag(uint256 _tokenId, bool _flag) external onlyOwner {
        tokenFlags[_tokenId] = _flag;
    }
    
    // Override to test function changes
    function version() external pure returns (string memory) {
        return "v2.0.0";
    }
    
    // Test batch operations with new features
    function batchSetTokenFlags(uint256[] calldata _tokenIds, bool _flag) external onlyOwner {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenFlags[_tokenIds[i]] = _flag;
        }
    }
    
    // Test adding new initialization logic
    function initializeV2(uint256 _newFeature) external {
        require(newFeature == 0, "Already initialized V2");
        newFeature = _newFeature;
    }
}

// Mock malicious contract for testing access controls
contract MaliciousFractalERC1155 is FractalERC1155Impl {
    function maliciousFunction() external pure returns (string memory) {
        return "HACKED";
    }
    
    function stealTokens(address _from, address _to, uint256 _id, uint256 _amount) external {
        _safeTransferFrom(_from, _to, _id, _amount, "");
    }
}

contract FractalERC1155UpgradeableTest is Test {
    FractalERC1155Impl public implementation;
    FractalERC1155Impl public proxy;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public unauthorized;
    address public proxyAdmin;
    
    string public constant NAME = "Upgradeable 1155";
    string public constant SYMBOL = "U1155";
    uint256 public constant MAX_SUPPLY = 1000;
    string public constant BASE_URI = "https://upgradeable1155.com/{id}";
    uint96 public constant ROYALTY_FEE = 500; // 5%
    
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event URI(string value, uint256 indexed id);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    event Upgraded(address indexed implementation);
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        unauthorized = makeAddr("unauthorized");
        proxyAdmin = makeAddr("proxyAdmin");
        
        // Deploy implementation
        implementation = new FractalERC1155Impl();
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            FractalERC1155Impl.initialize.selector,
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            BASE_URI,
            owner,
            ROYALTY_FEE,
            LicenseVersion.COMMERCIAL
        );
        
        // Deploy proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        // Cast proxy to implementation interface
        proxy = FractalERC1155Impl(address(proxyContract));
    }
    
    // ============ Proxy Deployment Tests ============
    
    function test_ProxyDeployment_Success() public {
        // Verify proxy is properly initialized
        assertEq(proxy.name(), NAME);
        assertEq(proxy.symbol(), SYMBOL);
        assertEq(proxy.maxSupply(0), MAX_SUPPLY); // Token ID 0 has max supply
        assertEq(proxy.uri(0), BASE_URI);
        assertEq(proxy.owner(), owner);
        assertEq(proxy.totalSupply(0), 0);
        
        // Verify license is properly set
        assertEq(proxy.getLicenseName(), "COMMERCIAL");
        assertEq(proxy.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");
        
        // Verify interface support
        assertTrue(proxy.supportsInterface(type(ICantBeEvil).interfaceId));
    }
    
    function test_ProxyDeployment_ImplementationNotInitialized() public {
        // Implementation contract should not be initialized
        // Check that critical state variables are empty/default
        assertEq(implementation.totalSupply(0), 0);
        assertEq(implementation.maxSupply(0), 0);
        
        // Should not have an owner set
        try implementation.owner() returns (address owner) {
            assertEq(owner, address(0));
        } catch {
            // If it reverts, that's also acceptable behavior
        }
    }
    
    function test_ProxyDeployment_CannotReinitialize() public {
        // Proxy should not be re-initializable
        vm.expectRevert();
        proxy.initialize(NAME, SYMBOL, MAX_SUPPLY, BASE_URI, owner, ROYALTY_FEE, LicenseVersion.PUBLIC);
    }
    
    function test_ProxyDeployment_WithDifferentLicenses() public {
        LicenseVersion[3] memory licenses = [
            LicenseVersion.PUBLIC,
            LicenseVersion.EXCLUSIVE,
            LicenseVersion.PERSONAL
        ];
        
        string[3] memory expectedNames = ["PUBLIC", "EXCLUSIVE", "PERSONAL"];
        
        for (uint256 i = 0; i < licenses.length; i++) {
            FractalERC1155Impl newImplementation = new FractalERC1155Impl();
            
            bytes memory initData = abi.encodeWithSelector(
                FractalERC1155Impl.initialize.selector,
                NAME,
                SYMBOL,
                MAX_SUPPLY,
                BASE_URI,
                owner,
                ROYALTY_FEE,
                licenses[i]
            );
            
            ERC1967Proxy newProxy = new ERC1967Proxy(
                address(newImplementation),
                initData
            );
            
            FractalERC1155Impl newProxyContract = FractalERC1155Impl(address(newProxy));
            
            // Verify license is correctly set
            assertEq(newProxyContract.getLicenseName(), expectedNames[i]);
        }
    }
    
    // ============ Basic Functionality Through Proxy Tests ============
    
    function test_ProxyFunctionality_Minting() public {
        vm.startPrank(owner);
        
        // Test single mint
        proxy.mint(user1, 0, 100, "");
        assertEq(proxy.balanceOf(user1, 0), 100);
        assertEq(proxy.totalSupply(0), 100);
        
        // Test different token ID
        proxy.mint(user1, 1, 200, "");
        assertEq(proxy.balanceOf(user1, 1), 200);
        assertEq(proxy.totalSupply(1), 200);
        
        // Test batch mint
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2;
        ids[1] = 3;
        ids[2] = 4;
        amounts[0] = 50;
        amounts[1] = 75;
        amounts[2] = 100;
        
        proxy.batchMint(user1, ids, amounts, "");
        
        for (uint256 i = 0; i < ids.length; i++) {
            assertEq(proxy.balanceOf(user1, ids[i]), amounts[i]);
            assertEq(proxy.totalSupply(ids[i]), amounts[i]);
        }
        
        vm.stopPrank();
    }
    
    function test_ProxyFunctionality_Burning() public {
        vm.startPrank(owner);
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Single burn
        proxy.burn(user1, 0, 50);
        assertEq(proxy.balanceOf(user1, 0), 50);
        assertEq(proxy.totalSupply(0), 50);
        
        // Batch burn
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        amounts[0] = 25;
        amounts[1] = 100;
        
        proxy.burnBatch(user1, ids, amounts);
        assertEq(proxy.balanceOf(user1, 0), 25);
        assertEq(proxy.balanceOf(user1, 1), 100);
        
        vm.stopPrank();
    }
    
    function test_ProxyFunctionality_OwnerFunctions() public {
        vm.startPrank(owner);
        
        // Test setMaxSupply
        proxy.setMaxSupply(1, 2000);
        assertEq(proxy.maxSupply(1), 2000);
        
        // Test setTokenURI
        string memory customURI = "https://custom.com/token/1";
        proxy.setTokenURI(1, customURI);
        assertEq(proxy.uri(1), customURI);
        assertEq(proxy.tokenURIs(1), customURI);
        
        vm.stopPrank();
    }
    
    function test_ProxyFunctionality_Transfers() public {
        vm.startPrank(owner);
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        // Single transfer
        proxy.safeTransferFrom(user1, user2, 0, 50, "");
        assertEq(proxy.balanceOf(user1, 0), 50);
        assertEq(proxy.balanceOf(user2, 0), 50);
        
        // Batch transfer
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        amounts[0] = 25;
        amounts[1] = 100;
        
        proxy.safeBatchTransferFrom(user1, user2, ids, amounts, "");
        assertEq(proxy.balanceOf(user1, 0), 25);
        assertEq(proxy.balanceOf(user1, 1), 100);
        assertEq(proxy.balanceOf(user2, 0), 75);
        assertEq(proxy.balanceOf(user2, 1), 100);
        
        vm.stopPrank();
    }
    
    // ============ Upgrade Tests ============
    
    function test_Upgrade_Success() public {
        // Set up comprehensive state before upgrade
        vm.startPrank(owner);
        
        // Mint various tokens
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        proxy.mint(user2, 2, 150, "");
        
        // Set max supplies
        proxy.setMaxSupply(1, 500);
        proxy.setMaxSupply(2, 300);
        
        // Set custom URIs
        proxy.setTokenURI(1, "https://custom1.com/");
        proxy.setTokenURI(2, "https://custom2.com/");
        
        vm.stopPrank();
        
        // Store state before upgrade
        uint256 totalSupply0 = proxy.totalSupply(0);
        uint256 totalSupply1 = proxy.totalSupply(1);
        uint256 totalSupply2 = proxy.totalSupply(2);
        uint256 maxSupply1 = proxy.maxSupply(1);
        uint256 maxSupply2 = proxy.maxSupply(2);
        string memory customURI1 = proxy.uri(1);
        string memory customURI2 = proxy.uri(2);
        address contractOwner = proxy.owner();
        string memory licenseName = proxy.getLicenseName();
        
        // Deploy new implementation
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        // Upgrade
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        // Cast to new interface
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify state preservation
        assertEq(upgradedProxy.totalSupply(0), totalSupply0);
        assertEq(upgradedProxy.totalSupply(1), totalSupply1);
        assertEq(upgradedProxy.totalSupply(2), totalSupply2);
        assertEq(upgradedProxy.maxSupply(1), maxSupply1);
        assertEq(upgradedProxy.maxSupply(2), maxSupply2);
        assertEq(upgradedProxy.uri(1), customURI1);
        assertEq(upgradedProxy.uri(2), customURI2);
        assertEq(upgradedProxy.owner(), contractOwner);
        assertEq(upgradedProxy.getLicenseName(), licenseName);
        
        // Verify balances are preserved
        assertEq(upgradedProxy.balanceOf(user1, 0), 100);
        assertEq(upgradedProxy.balanceOf(user1, 1), 200);
        assertEq(upgradedProxy.balanceOf(user2, 2), 150);
        
        // Verify new functionality works
        vm.startPrank(owner);
        upgradedProxy.setNewFeature(12345);
        upgradedProxy.setTokenFlag(1, true);
        assertEq(upgradedProxy.newFeature(), 12345);
        assertTrue(upgradedProxy.tokenFlags(1));
        assertEq(upgradedProxy.version(), "v2.0.0");
        vm.stopPrank();
    }
    
    function test_Upgrade_WithInitialization() public {
        // Deploy new implementation
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        // Prepare upgrade data with initialization
        bytes memory upgradeData = abi.encodeWithSelector(
            FractalERC1155ImplV2.initializeV2.selector,
            99999
        );
        
        // Upgrade with initialization
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            upgradeData
        );
        vm.stopPrank();
        
        // Cast to new interface
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify initialization was called
        assertEq(upgradedProxy.newFeature(), 99999);
    }
    
    function test_Upgrade_RevertIf_NotOwner() public {
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(unauthorized);
        
        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        
        vm.stopPrank();
    }
    
    function test_Upgrade_PreservesLicenseIntegrity() public {
        // Verify license before upgrade
        assertEq(proxy.getLicenseName(), "COMMERCIAL");
        assertEq(proxy.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");
        assertTrue(proxy.supportsInterface(type(ICantBeEvil).interfaceId));
        
        // Deploy and upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify license is preserved
        assertEq(upgradedProxy.getLicenseName(), "COMMERCIAL");
        assertEq(upgradedProxy.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");
        assertTrue(upgradedProxy.supportsInterface(type(ICantBeEvil).interfaceId));
    }
    
    // ============ Storage Layout Tests ============
    
    function test_StorageLayout_PreservationAcrossUpgrades() public {
        // Set comprehensive state
        vm.startPrank(owner);
        
        // Mint tokens with different patterns
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        proxy.mint(user2, 0, 50, "");
        proxy.mint(user2, 2, 300, "");
        proxy.mint(user3, 1, 150, "");
        
        // Set max supplies
        proxy.setMaxSupply(1, 1000);
        proxy.setMaxSupply(2, 500);
        proxy.setMaxSupply(3, 2000);
        
        // Set custom URIs
        proxy.setTokenURI(1, "https://token1.com/");
        proxy.setTokenURI(2, "https://token2.com/");
        proxy.setTokenURI(3, "https://token3.com/");
        
        vm.stopPrank();
        
        // Transfer tokens to create complex state
        vm.startPrank(user1);
        proxy.safeTransferFrom(user1, user3, 0, 25, "");
        proxy.setApprovalForAll(user2, true);
        vm.stopPrank();
        
        vm.startPrank(user2);
        proxy.safeTransferFrom(user1, user2, 1, 50, "");
        vm.stopPrank();
        
        // Store comprehensive state
        uint256[4] memory totalSupplies = [
            proxy.totalSupply(0),
            proxy.totalSupply(1),
            proxy.totalSupply(2),
            proxy.totalSupply(3)
        ];
        
        uint256[4] memory maxSupplies = [
            proxy.maxSupply(0),
            proxy.maxSupply(1),
            proxy.maxSupply(2),
            proxy.maxSupply(3)
        ];
        
        string[4] memory tokenURIs = [
            proxy.uri(0),
            proxy.uri(1),
            proxy.uri(2),
            proxy.uri(3)
        ];
        
        // Store balances
        uint256[3][4] memory balances; // balances[tokenId][user]
        address[3] memory users = [user1, user2, user3];
        for (uint256 i = 0; i < 4; i++) {
            for (uint256 j = 0; j < 3; j++) {
                balances[i][j] = proxy.balanceOf(users[j], i);
            }
        }
        
        // Store approvals
        bool isApprovedForAll = proxy.isApprovedForAll(user1, user2);
        
        // Upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify all state is preserved
        for (uint256 i = 0; i < 4; i++) {
            assertEq(upgradedProxy.totalSupply(i), totalSupplies[i]);
            assertEq(upgradedProxy.maxSupply(i), maxSupplies[i]);
            assertEq(upgradedProxy.uri(i), tokenURIs[i]);
            
            for (uint256 j = 0; j < 3; j++) {
                assertEq(upgradedProxy.balanceOf(users[j], i), balances[i][j]);
            }
        }
        
        // Verify approvals are preserved
        assertEq(upgradedProxy.isApprovedForAll(user1, user2), isApprovedForAll);
        
        // Verify new storage slots are empty initially
        assertEq(upgradedProxy.newFeature(), 0);
        assertFalse(upgradedProxy.tokenFlags(0));
        assertFalse(upgradedProxy.tokenFlags(1));
    }
    
    function test_StorageLayout_NewVariablesAfterUpgrade() public {
        // Upgrade first
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Test new storage variables work properly
        vm.startPrank(owner);
        upgradedProxy.setNewFeature(42);
        upgradedProxy.setTokenFlag(1, true);
        upgradedProxy.setTokenFlag(2, false);
        
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 3;
        tokenIds[1] = 4;
        tokenIds[2] = 5;
        upgradedProxy.batchSetTokenFlags(tokenIds, true);
        vm.stopPrank();
        
        assertEq(upgradedProxy.newFeature(), 42);
        assertTrue(upgradedProxy.tokenFlags(1));
        assertFalse(upgradedProxy.tokenFlags(2));
        assertTrue(upgradedProxy.tokenFlags(3));
        assertTrue(upgradedProxy.tokenFlags(4));
        assertTrue(upgradedProxy.tokenFlags(5));
        
        // Mint tokens to verify old functionality still works with new storage
        vm.startPrank(owner);
        upgradedProxy.mint(user1, 0, 100, "");
        upgradedProxy.mint(user1, 1, 200, "");
        vm.stopPrank();
        
        assertEq(upgradedProxy.totalSupply(0), 100);
        assertEq(upgradedProxy.totalSupply(1), 200);
        assertEq(upgradedProxy.balanceOf(user1, 0), 100);
        assertEq(upgradedProxy.balanceOf(user1, 1), 200);
        assertEq(upgradedProxy.newFeature(), 42); // New variable should be unchanged
    }
    
    // ============ Batch Operation Tests After Upgrade ============
    
    function test_Upgrade_BatchOperationsWork() public {
        // Set up initial state
        vm.startPrank(owner);
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        proxy.mint(user1, 2, 300, "");
        vm.stopPrank();
        
        // Upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Test batch operations work after upgrade
        vm.startPrank(owner);
        
        // Batch mint
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 3;
        ids[1] = 4;
        ids[2] = 5;
        amounts[0] = 50;
        amounts[1] = 75;
        amounts[2] = 100;
        
        upgradedProxy.batchMint(user2, ids, amounts, "");
        
        for (uint256 i = 0; i < ids.length; i++) {
            assertEq(upgradedProxy.balanceOf(user2, ids[i]), amounts[i]);
        }
        
        // Test new batch function
        upgradedProxy.batchSetTokenFlags(ids, true);
        for (uint256 i = 0; i < ids.length; i++) {
            assertTrue(upgradedProxy.tokenFlags(ids[i]));
        }
        
        vm.stopPrank();
        
        // Test batch transfers work
        vm.startPrank(user2);
        
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 25;
        transferAmounts[1] = 35;
        transferAmounts[2] = 45;
        
        upgradedProxy.safeBatchTransferFrom(user2, user3, ids, transferAmounts, "");
        
        for (uint256 i = 0; i < ids.length; i++) {
            assertEq(upgradedProxy.balanceOf(user3, ids[i]), transferAmounts[i]);
            assertEq(upgradedProxy.balanceOf(user2, ids[i]), amounts[i] - transferAmounts[i]);
        }
        
        vm.stopPrank();
    }
    
    // ============ Multiple Upgrade Tests ============
    
    function test_MultipleUpgrades_Success() public {
        // Initial state
        vm.startPrank(owner);
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        vm.stopPrank();
        
        // First upgrade
        FractalERC1155ImplV2 newImplementationV2 = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementationV2),
            abi.encodeWithSelector(FractalERC1155ImplV2.initializeV2.selector, 100)
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 proxyV2 = FractalERC1155ImplV2(address(proxy));
        assertEq(proxyV2.newFeature(), 100);
        assertEq(proxyV2.balanceOf(user1, 0), 100);
        assertEq(proxyV2.balanceOf(user1, 1), 200);
        
        // Add some new state
        vm.startPrank(owner);
        proxyV2.setTokenFlag(0, true);
        proxyV2.setTokenFlag(1, false);
        vm.stopPrank();
        
        // Second upgrade (upgrade to same version again)
        FractalERC1155ImplV2 newImplementationV2Again = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementationV2Again),
            ""
        );
        vm.stopPrank();
        
        // State should be preserved
        assertEq(proxyV2.newFeature(), 100);
        assertEq(proxyV2.balanceOf(user1, 0), 100);
        assertEq(proxyV2.balanceOf(user1, 1), 200);
        assertTrue(proxyV2.tokenFlags(0));
        assertFalse(proxyV2.tokenFlags(1));
    }
    
    // ============ Upgrade Security Tests ============
    
    function test_UpgradeSecurity_OnlyOwnerCanUpgrade() public {
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        // User1 cannot upgrade
        vm.startPrank(user1);
        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        // Unauthorized cannot upgrade
        vm.startPrank(unauthorized);
        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        // Only owner can upgrade
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        // Verify upgrade succeeded
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        assertEq(upgradedProxy.version(), "v2.0.0");
    }
    
    function test_UpgradeSecurity_MaliciousContractUpgrade() public {
        // Mint some tokens first
        vm.startPrank(owner);
        proxy.mint(user1, 0, 100, "");
        vm.stopPrank();
        
        MaliciousFractalERC1155 maliciousImplementation = new MaliciousFractalERC1155();
        
        // Upgrade to malicious contract
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(maliciousImplementation),
            ""
        );
        vm.stopPrank();
        
        // The malicious function should be available
        MaliciousFractalERC1155 maliciousProxy = MaliciousFractalERC1155(address(proxy));
        assertEq(maliciousProxy.maliciousFunction(), "HACKED");
        
        // But original functionality and state should still work
        assertEq(maliciousProxy.owner(), owner);
        assertEq(maliciousProxy.balanceOf(user1, 0), 100);
        
        // The malicious steal function should also work (demonstrating the risk)
        vm.startPrank(owner); // Even owner can call malicious functions
        maliciousProxy.stealTokens(user1, user2, 0, 50);
        assertEq(maliciousProxy.balanceOf(user1, 0), 50);
        assertEq(maliciousProxy.balanceOf(user2, 0), 50);
        vm.stopPrank();
    }
    
    // ============ Edge Cases and Error Conditions ============
    
    function test_EdgeCase_UpgradePreservesApprovals() public {
        // Set up tokens and approvals
        vm.startPrank(owner);
        proxy.mint(user1, 0, 100, "");
        proxy.mint(user1, 1, 200, "");
        vm.stopPrank();
        
        vm.startPrank(user1);
        proxy.setApprovalForAll(user2, true);
        vm.stopPrank();
        
        // Store approval state
        bool isApprovedForAll = proxy.isApprovedForAll(user1, user2);
        assertTrue(isApprovedForAll);
        
        // Upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify approvals are preserved
        assertTrue(upgradedProxy.isApprovedForAll(user1, user2));
        
        // Verify approved user can still transfer
        vm.startPrank(user2);
        upgradedProxy.safeTransferFrom(user1, user3, 0, 50, "");
        assertEq(upgradedProxy.balanceOf(user3, 0), 50);
        assertEq(upgradedProxy.balanceOf(user1, 0), 50);
        vm.stopPrank();
    }
    
    function test_EdgeCase_UpgradeWithActiveMaxSupply() public {
        vm.startPrank(owner);
        
        // Set max supply and mint close to limit
        proxy.setMaxSupply(1, 100);
        proxy.mint(user1, 1, 95, "");
        
        vm.stopPrank();
        
        // Upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Max supply constraints should still be enforced
        assertEq(upgradedProxy.maxSupply(1), 100);
        assertEq(upgradedProxy.totalSupply(1), 95);
        
        // Should be able to mint 5 more but not 6
        vm.startPrank(owner);
        upgradedProxy.mint(user1, 1, 5, "");
        assertEq(upgradedProxy.totalSupply(1), 100);
        
        vm.expectRevert(FractalERC1155Impl.MaxSupplyExceeded.selector);
        upgradedProxy.mint(user1, 1, 1, "");
        vm.stopPrank();
    }
    
    // ============ Gas Usage Tests ============
    
    function test_GasUsage_UpgradeOperation() public {
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        
        uint256 gasBefore = gasleft();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        // Gas usage should be reasonable (less than 100k gas)
        assertTrue(gasUsed < 100000);
        console.log("ERC1155 Upgrade gas used:", gasUsed);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_Upgrade_PreservesTokenBalances(uint8 numTokens, uint8 numUsers) public {
        vm.assume(numTokens > 0 && numTokens <= 20);
        vm.assume(numUsers > 0 && numUsers <= 5);
        
        address[] memory users = new address[](numUsers);
        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string.concat("user", vm.toString(i)));
        }
        
        // Mint random tokens to random users
        vm.startPrank(owner);
        uint256[][] memory balances = new uint256[][](numUsers);
        for (uint256 i = 0; i < numUsers; i++) {
            balances[i] = new uint256[](numTokens);
        }
        
        for (uint256 tokenId = 0; tokenId < numTokens; tokenId++) {
            for (uint256 userIdx = 0; userIdx < numUsers; userIdx++) {
                uint256 amount = (tokenId + userIdx + 1) * 10; // Deterministic amount
                proxy.mint(users[userIdx], tokenId, amount, "");
                balances[userIdx][tokenId] = amount;
            }
        }
        vm.stopPrank();
        
        // Upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify all balances are preserved
        for (uint256 tokenId = 0; tokenId < numTokens; tokenId++) {
            for (uint256 userIdx = 0; userIdx < numUsers; userIdx++) {
                assertEq(
                    upgradedProxy.balanceOf(users[userIdx], tokenId),
                    balances[userIdx][tokenId]
                );
            }
        }
    }
    
    function testFuzz_Upgrade_PreservesCustomURIs(uint8 numTokens) public {
        vm.assume(numTokens > 0 && numTokens <= 50);
        
        // Set custom URIs for random tokens
        vm.startPrank(owner);
        string[] memory customURIs = new string[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            string memory customURI = string.concat("https://token", vm.toString(i), ".com/");
            proxy.setTokenURI(i, customURI);
            customURIs[i] = customURI;
        }
        vm.stopPrank();
        
        // Upgrade
        FractalERC1155ImplV2 newImplementation = new FractalERC1155ImplV2();
        
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
        vm.stopPrank();
        
        FractalERC1155ImplV2 upgradedProxy = FractalERC1155ImplV2(address(proxy));
        
        // Verify all custom URIs are preserved
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(upgradedProxy.uri(i), customURIs[i]);
            assertEq(upgradedProxy.tokenURIs(i), customURIs[i]);
        }
    }
}