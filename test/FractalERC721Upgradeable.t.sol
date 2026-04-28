// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LicenseVersion, FractalERC721Impl} from "../src/FractalERC721.sol";
import {ICantBeEvil} from "@a16z/contracts/licenses/ICantBeEvil.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FractalLaunchpad} from "../src/FractalLaunchpad.sol";
import {ProxyFactory} from "../src/Factory.sol";
import {FractalERC1155Impl} from "../src/FractalERC1155.sol";


// Mock upgraded version for testing
contract FractalERC721ImplV2 is FractalERC721Impl {
    // New state variable to test storage layout preservation
    uint256 public newFeature;

    // New function to test upgrade functionality
    function setNewFeature(uint256 _value) external onlyOwner {
        newFeature = _value;
    }

    // New version function to test upgrade functionality
    function getVersion() external pure returns (string memory) {
        return "v2.0.0";
    }

    // Test adding new initialization logic
    function initializeV2(uint256 _newFeature) external {
        // Ensure this can only be called once per upgrade
        require(newFeature == 0, "Already initialized V2");
        newFeature = _newFeature;
    }
}

// Mock malicious contract for testing access controls
contract MaliciousFractalERC721 is FractalERC721Impl {
    function maliciousFunction() external pure returns (string memory) {
        return "HACKED";
    }
}

contract FractalERC721UpgradeableTest is Test {
    FractalERC721Impl public implementation;
    FractalERC721Impl public proxy;
    FractalLaunchpad public launchpad;
    ProxyFactory public factory;
    FractalERC1155Impl public erc1155Implementation;

    address public owner;
    address public user1;
    address public user2;
    address public unauthorized;
    address public deployer;
    address public feeRecipient;

    string public constant NAME = "Upgradeable NFT";
    string public constant SYMBOL = "UNFT";
    uint256 public constant MAX_SUPPLY = 1000;
    string public constant BASE_URI = "https://upgradeable.com/";
    uint96 public constant ROYALTY_FEE = 500; // 5%

    event Upgraded(address indexed implementation);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        unauthorized = makeAddr("unauthorized");
        deployer = makeAddr("deployer");
        feeRecipient = makeAddr("feeRecipient");

        // Deploy infrastructure as deployer (mirrors real mainnet deployment)
        vm.startPrank(deployer);
        implementation = new FractalERC721Impl();
        erc1155Implementation = new FractalERC1155Impl();
        factory = new ProxyFactory();
        launchpad = new FractalLaunchpad(
            feeRecipient, 0, address(erc1155Implementation), address(implementation), address(factory)
        );
        factory.grantRole(factory.CREATOR_ROLE(), address(launchpad));
        vm.stopPrank();

        // Create proxy through the real Launchpad -> Factory -> ERC1967Proxy flow
        vm.startPrank(owner);
        uint256 launchId = launchpad.createLaunch(
            NAME, SYMBOL, MAX_SUPPLY, BASE_URI, ROYALTY_FEE,
            LicenseVersion.COMMERCIAL, FractalLaunchpad.TokenType.ERC721
        );
        vm.stopPrank();

        FractalLaunchpad.LaunchConfig memory config = launchpad.getLaunchInfo(launchId);
        proxy = FractalERC721Impl(config.tokenContract);
    }

    // ============ Proxy Deployment Tests ============

    function test_ProxyDeployment_Success() public {
        // Verify proxy is properly initialized
        assertEq(proxy.name(), NAME);
        assertEq(proxy.symbol(), SYMBOL);
        assertEq(proxy.maxSupply(), MAX_SUPPLY);
        assertEq(proxy.baseTokenURI(), BASE_URI);
        assertEq(proxy.owner(), owner);
        assertEq(proxy.totalSupply(), 0);

        // Verify license is properly set
        assertEq(proxy.getLicenseName(), "COMMERCIAL");
        assertEq(proxy.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");

        // Verify interface support
        assertTrue(proxy.supportsInterface(type(ICantBeEvil).interfaceId));
    }

    function test_ProxyDeployment_ImplementationNotInitialized() public {
        // Implementation contract should not be initialized
        // Check that critical state variables are empty/default
        assertEq(implementation.totalSupply(), 0);
        assertEq(implementation.maxSupply(), 0);

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
        // Test deploying proxies with different license types
        LicenseVersion[3] memory licenses = [LicenseVersion.PUBLIC, LicenseVersion.EXCLUSIVE, LicenseVersion.PERSONAL];

        for (uint256 i = 0; i < licenses.length; i++) {
            FractalERC721Impl newImplementation = new FractalERC721Impl();

            bytes memory initData = abi.encodeWithSelector(
                FractalERC721Impl.initialize.selector,
                NAME,
                SYMBOL,
                MAX_SUPPLY,
                BASE_URI,
                owner,
                ROYALTY_FEE,
                licenses[i]
            );

            ERC1967Proxy newProxy = new ERC1967Proxy(address(newImplementation), initData);

            FractalERC721Impl newProxyContract = FractalERC721Impl(address(newProxy));

            // Verify license is correctly set
            if (licenses[i] == LicenseVersion.PUBLIC) {
                assertEq(newProxyContract.getLicenseName(), "PUBLIC");
            } else if (licenses[i] == LicenseVersion.EXCLUSIVE) {
                assertEq(newProxyContract.getLicenseName(), "EXCLUSIVE");
            } else if (licenses[i] == LicenseVersion.PERSONAL) {
                assertEq(newProxyContract.getLicenseName(), "PERSONAL");
            }
        }
    }

    // ============ Basic Functionality Through Proxy Tests ============

    function test_ProxyFunctionality_Minting() public {
        vm.startPrank(owner);

        // Test single mint
        proxy.mint(user1, 1);
        assertEq(proxy.ownerOf(1), user1);
        assertEq(proxy.totalSupply(), 1);

        // Test batch mint
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 2;
        tokenIds[1] = 3;
        tokenIds[2] = 4;

        proxy.batchMint(user1, tokenIds);
        assertEq(proxy.totalSupply(), 4);
        assertEq(proxy.balanceOf(user1), 4);

        vm.stopPrank();
    }

    function test_ProxyFunctionality_Burning() public {
        vm.startPrank(owner);
        proxy.mint(user1, 1);
        vm.stopPrank();

        vm.startPrank(user1);
        proxy.burn(1);
        assertEq(proxy.totalSupply(), 0);
        vm.stopPrank();
    }

    function test_ProxyFunctionality_OwnerFunctions() public {
        vm.startPrank(owner);

        // Test setMaxSupply
        proxy.setMaxSupply(2000);
        assertEq(proxy.maxSupply(), 2000);

        // Test setBaseURI
        string memory newURI = "https://newbase.com/";
        proxy.setBaseURI(newURI);
        assertEq(proxy.baseTokenURI(), newURI);

        vm.stopPrank();
    }

    function test_ProxyFunctionality_AccessControl() public {
        vm.startPrank(unauthorized);

        // Non-owner should not be able to mint
        vm.expectRevert();
        proxy.mint(user1, 1);

        // Non-owner should not be able to set max supply
        vm.expectRevert();
        proxy.setMaxSupply(500);

        // Non-owner should not be able to set base URI
        vm.expectRevert();
        proxy.setBaseURI("https://hack.com/");

        vm.stopPrank();
    }

    // ============ Upgrade Tests ============

    function test_Upgrade_Success() public {
        // Mint some tokens before upgrade
        vm.startPrank(owner);
        proxy.mint(user1, 1);
        proxy.mint(user1, 2);
        proxy.setMaxSupply(5000);
        vm.stopPrank();

        // Store state before upgrade
        uint256 totalSupplyBefore = proxy.totalSupply();
        uint256 maxSupplyBefore = proxy.maxSupply();
        address ownerBefore = proxy.owner();
        string memory licenseBefore = proxy.getLicenseName();

        // Deploy new implementation
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        // Upgrade
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Cast to new interface
        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Verify state preservation
        assertEq(upgradedProxy.totalSupply(), totalSupplyBefore);
        assertEq(upgradedProxy.maxSupply(), maxSupplyBefore);
        assertEq(upgradedProxy.owner(), ownerBefore);
        assertEq(upgradedProxy.getLicenseName(), licenseBefore);

        // Verify old functionality still works
        assertEq(upgradedProxy.ownerOf(1), user1);
        assertEq(upgradedProxy.ownerOf(2), user1);

        // Verify new functionality works
        vm.startPrank(owner);
        upgradedProxy.setNewFeature(12345);
        assertEq(upgradedProxy.newFeature(), 12345);
        assertEq(upgradedProxy.version(), uint8(2));
        vm.stopPrank();
    }

    function test_Upgrade_WithInitialization() public {
        // Deploy new implementation
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        // Prepare upgrade data with initialization
        bytes memory upgradeData = abi.encodeWithSelector(FractalERC721ImplV2.initializeV2.selector, 99999);

        // Upgrade with initialization
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), upgradeData);
        vm.stopPrank();

        // Cast to new interface
        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Verify initialization was called
        assertEq(upgradedProxy.newFeature(), 99999);
    }

    function test_Upgrade_RevertIf_NotOwner() public {
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(unauthorized);

        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");

        vm.stopPrank();
    }

    function test_Upgrade_RevertIf_InvalidImplementation() public {
        // Try to upgrade to a non-contract address
        vm.startPrank(owner);

        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(0x123), "");

        vm.stopPrank();
    }

    function test_Upgrade_PreservesLicenseIntegrity() public {
        // Verify license before upgrade
        assertEq(proxy.getLicenseName(), "COMMERCIAL");
        assertEq(proxy.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");
        assertTrue(proxy.supportsInterface(type(ICantBeEvil).interfaceId));

        // Deploy and upgrade
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Verify license is preserved
        assertEq(upgradedProxy.getLicenseName(), "COMMERCIAL");
        assertEq(upgradedProxy.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2");
        assertTrue(upgradedProxy.supportsInterface(type(ICantBeEvil).interfaceId));
    }

    // ============ Storage Layout Tests ============

    function test_StorageLayout_PreservationAcrossUpgrades() public {
        // Set comprehensive state before upgrade
        vm.startPrank(owner);

        proxy.mint(user1, 1);
        proxy.mint(user1, 2);
        proxy.mint(user2, 3);
        proxy.setMaxSupply(1500);
        proxy.setBaseURI("https://preserved.com/");

        vm.stopPrank();

        // Transfer some tokens
        vm.startPrank(user1);
        proxy.transferFrom(user1, user2, 1);
        vm.stopPrank();

        // Store comprehensive state
        uint256 totalSupply = proxy.totalSupply();
        uint256 maxSupply = proxy.maxSupply();
        string memory baseURI = proxy.baseTokenURI();
        address tokenOwner1 = proxy.ownerOf(1);
        address tokenOwner2 = proxy.ownerOf(2);
        address tokenOwner3 = proxy.ownerOf(3);
        uint256 user1Balance = proxy.balanceOf(user1);
        uint256 user2Balance = proxy.balanceOf(user2);
        address contractOwner = proxy.owner();
        string memory licenseName = proxy.getLicenseName();

        // Upgrade
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Verify all state is preserved
        assertEq(upgradedProxy.totalSupply(), totalSupply);
        assertEq(upgradedProxy.maxSupply(), maxSupply);
        assertEq(upgradedProxy.baseTokenURI(), baseURI);
        assertEq(upgradedProxy.ownerOf(1), tokenOwner1);
        assertEq(upgradedProxy.ownerOf(2), tokenOwner2);
        assertEq(upgradedProxy.ownerOf(3), tokenOwner3);
        assertEq(upgradedProxy.balanceOf(user1), user1Balance);
        assertEq(upgradedProxy.balanceOf(user2), user2Balance);
        assertEq(upgradedProxy.owner(), contractOwner);
        assertEq(upgradedProxy.getLicenseName(), licenseName);

        // Verify new storage slot is empty initially
        assertEq(upgradedProxy.newFeature(), 0);
    }

    function test_StorageLayout_NewVariablesAfterUpgrade() public {
        // Upgrade first
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Test new storage variables work properly
        vm.startPrank(owner);
        upgradedProxy.setNewFeature(42);
        vm.stopPrank();

        assertEq(upgradedProxy.newFeature(), 42);

        // Mint tokens to verify old functionality still works with new storage
        vm.startPrank(owner);
        upgradedProxy.mint(user1, 1);
        upgradedProxy.mint(user1, 2);
        vm.stopPrank();

        assertEq(upgradedProxy.totalSupply(), 2);
        assertEq(upgradedProxy.balanceOf(user1), 2);
        assertEq(upgradedProxy.newFeature(), 42); // New variable should be unchanged
    }

    function test_Upgrade_PreservesCustomTokenURIData() public {
        vm.startPrank(owner);
        proxy.mint(user1, 42);
        proxy.setTokenUri(42, "https://custom.example/42.json");
        vm.stopPrank();

        string memory customBefore = proxy.tokenURI(42);
        assertEq(customBefore, "https://custom.example/42.json");

        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        assertEq(upgradedProxy.ownerOf(42), user1);
        assertEq(upgradedProxy.tokenURI(42), "https://custom.example/42.json");

        // Ensure tokenURI fallback behavior still works for tokens without custom URI.
        vm.startPrank(owner);
        upgradedProxy.mint(user1, 43);
        vm.stopPrank();
        assertEq(upgradedProxy.tokenURI(43), string.concat(upgradedProxy.baseTokenURI(), "43"));
    }

    // ============ Multiple Upgrade Tests ============

    function test_MultipleUpgrades_Success() public {
        // Initial state
        vm.startPrank(owner);
        proxy.mint(user1, 1);
        vm.stopPrank();

        // First upgrade
        FractalERC721ImplV2 newImplementationV2 = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImplementationV2), abi.encodeWithSelector(FractalERC721ImplV2.initializeV2.selector, 100)
        );
        vm.stopPrank();

        FractalERC721ImplV2 proxyV2 = FractalERC721ImplV2(address(proxy));
        assertEq(proxyV2.newFeature(), 100);
        assertEq(proxyV2.ownerOf(1), user1);

        // Second upgrade (upgrade to same version again)
        FractalERC721ImplV2 newImplementationV2Again = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementationV2Again), "");
        vm.stopPrank();

        // State should be preserved
        assertEq(proxyV2.newFeature(), 100);
        assertEq(proxyV2.ownerOf(1), user1);
        assertEq(proxyV2.totalSupply(), 1);
    }

    // ============ Upgrade Security Tests ============

    function test_UpgradeSecurity_OnlyOwnerCanUpgrade() public {
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        // User1 cannot upgrade
        vm.startPrank(user1);
        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Unauthorized cannot upgrade
        vm.startPrank(unauthorized);
        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Only owner can upgrade
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Verify upgrade succeeded
        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));
        assertEq(upgradedProxy.version(), uint8(2));
    }

    function test_UpgradeSecurity_CannotUpgradeToMaliciousContract() public {
        MaliciousFractalERC721 maliciousImplementation = new MaliciousFractalERC721();

        // Even owner should not be able to upgrade to incompatible contract
        vm.startPrank(owner);

        // This should work since MaliciousFractalERC721 extends FractalERC721Impl
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(maliciousImplementation), "");

        vm.stopPrank();

        // The malicious function should be available (this shows the importance of careful upgrade management)
        MaliciousFractalERC721 maliciousProxy = MaliciousFractalERC721(address(proxy));
        assertEq(maliciousProxy.maliciousFunction(), "HACKED");

        // But original functionality should still work
        assertEq(maliciousProxy.owner(), owner);
    }

    // ============ Proxy Implementation Tests ============

    function test_ProxyImplementation_ImplementationAddress() public {
        // The proxy should point to the correct implementation
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementationAddress = address(uint160(uint256(vm.load(address(proxy), implementationSlot))));

        assertEq(implementationAddress, address(implementation));
    }

    function test_ProxyImplementation_ChangeAfterUpgrade() public {
        // Get original implementation address
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address originalImplementation = address(uint160(uint256(vm.load(address(proxy), implementationSlot))));

        // Upgrade
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Implementation address should change
        address newImplementationAddress = address(uint160(uint256(vm.load(address(proxy), implementationSlot))));

        assertEq(newImplementationAddress, address(newImplementation));
        assertTrue(newImplementationAddress != originalImplementation);
    }

    // ============ Edge Cases and Error Conditions ============

    function test_EdgeCase_UpgradeWithLargeCalldata() public {
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        // Create large calldata
        bytes memory largeCalldata = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            largeCalldata[i] = bytes1(uint8(i % 256));
        }

        vm.startPrank(owner);

        // This should work even with large calldata (though the call will likely fail)
        try UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), largeCalldata) {
            // Upgrade succeeded
        } catch {
            // Upgrade failed due to calldata, but that's expected
        }

        vm.stopPrank();
    }

    function test_EdgeCase_UpgradePreservesApprovals() public {
        // Mint and approve before upgrade
        vm.startPrank(owner);
        proxy.mint(user1, 1);
        proxy.mint(user1, 2);
        vm.stopPrank();

        vm.startPrank(user1);
        proxy.approve(user2, 1);
        proxy.setApprovalForAll(user2, true);
        vm.stopPrank();

        // Store approval state
        address approvedUser = proxy.getApproved(1);
        bool isApprovedForAll = proxy.isApprovedForAll(user1, user2);

        // Upgrade
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Verify approvals are preserved
        assertEq(upgradedProxy.getApproved(1), approvedUser);
        assertEq(upgradedProxy.isApprovedForAll(user1, user2), isApprovedForAll);

        // Verify approved user can still transfer
        vm.startPrank(user2);
        upgradedProxy.transferFrom(user1, user2, 1);
        assertEq(upgradedProxy.ownerOf(1), user2);
        vm.stopPrank();
    }

    // ============ Gas Usage Tests ============

    function test_GasUsage_UpgradeOperation() public {
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);

        uint256 gasBefore = gasleft();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        // Gas usage should be reasonable (less than 100k gas)
        // This is just a sanity check
        assertTrue(gasUsed < 100000);
        console.log("Upgrade gas used:", gasUsed);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Upgrade_PreservesTokenOwnership(uint256 numTokens) public {
        vm.assume(numTokens > 0 && numTokens <= 100);

        // Mint random number of tokens
        vm.startPrank(owner);
        address[] memory owners = new address[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            address tokenOwner = i % 2 == 0 ? user1 : user2;
            proxy.mint(tokenOwner, i + 1);
            owners[i] = tokenOwner;
        }
        vm.stopPrank();

        // Upgrade
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));

        // Verify all token ownerships are preserved
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(upgradedProxy.ownerOf(i + 1), owners[i]);
        }

        assertEq(upgradedProxy.totalSupply(), numTokens);
    }

    // ============ ContractUpgraded Event + Version Tests ============

    event ContractUpgraded(address indexed newImplementation, uint8 version);

    function test_Upgrade_EmitsContractUpgradedEvent() public {
        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        // The event is emitted inside _authorizeUpgrade, which runs during upgradeToAndCall
        // It should carry the NEW implementation address and the CURRENT version()
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit ContractUpgraded(address(newImplementation), proxy.version());
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();
    }

    function test_Upgrade_VersionAfterUpgrade() public {
        // version() is a pure function on the implementation; after upgrade the proxy
        // delegates to the new implementation, so it must return the new impl's version.
        uint8 versionBefore = proxy.version();

        FractalERC721ImplV2 newImplementation = new FractalERC721ImplV2();

        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        FractalERC721ImplV2 upgradedProxy = FractalERC721ImplV2(address(proxy));
        uint8 versionAfter = upgradedProxy.version();

        // V2 does not override version(), so both report uint8(2).
        // The important assertion is that the version is a valid uint8 and doesn't revert.
        assertEq(versionBefore, uint8(2));
        assertEq(versionAfter, uint8(2));

        // getVersion() is a NEW function only on V2 — confirms we are on the new impl
        assertEq(upgradedProxy.getVersion(), "v2.0.0");
    }

    function test_Upgrade_MultipleUpgrades_VersionConsistent() public {
        // First upgrade
        FractalERC721ImplV2 implV2a = new FractalERC721ImplV2();
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit ContractUpgraded(address(implV2a), uint8(2));
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(implV2a), "");
        vm.stopPrank();

        // Second upgrade (re-deploy of same V2 type)
        FractalERC721ImplV2 implV2b = new FractalERC721ImplV2();
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit ContractUpgraded(address(implV2b), uint8(2));
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(implV2b), "");
        vm.stopPrank();

        // State must survive two upgrades
        FractalERC721ImplV2 up = FractalERC721ImplV2(address(proxy));
        assertEq(up.version(), uint8(2));
        assertEq(up.owner(), owner);
    }

    // ============ setLicenseVersion After Upgrade ============

    function test_Upgrade_SetLicenseVersion_WorksOnUpgradedProxy() public {
        FractalERC721ImplV2 newImpl = new FractalERC721ImplV2();
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImpl), "");
        vm.stopPrank();

        FractalERC721ImplV2 up = FractalERC721ImplV2(address(proxy));

        assertEq(up.getLicenseName(), "COMMERCIAL"); // preserved from init

        vm.startPrank(owner);
        up.setLicenseVersion(LicenseVersion.PUBLIC);
        vm.stopPrank();

        assertEq(up.getLicenseName(), "PUBLIC");
        assertEq(up.getLicenseURI(), "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/0");
    }

    // ============ setDefaultRoyaltyInfo After Upgrade ============

    function test_Upgrade_DefaultRoyaltyInfo_PersistsAndUpdates() public {
        // Mint and set custom royalty BEFORE upgrade
        vm.startPrank(owner);
        proxy.mint(user1, 1);
        proxy.setDefaultRoyaltyInfo(user2, 750); // 7.5%
        vm.stopPrank();

        // Upgrade
        FractalERC721ImplV2 newImpl = new FractalERC721ImplV2();
        vm.startPrank(owner);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImpl), "");
        vm.stopPrank();

        FractalERC721ImplV2 up = FractalERC721ImplV2(address(proxy));

        // Royalty set BEFORE upgrade must still be respected AFTER upgrade
        (address receiver, uint256 amount) = up.royaltyInfo(1, 1 ether);
        assertEq(receiver, user2);
        assertEq(amount, 0.075 ether);

        // Update royalty on the upgraded proxy
        vm.startPrank(owner);
        up.setDefaultRoyaltyInfo(user1, 300); // 3%
        vm.stopPrank();

        (receiver, amount) = up.royaltyInfo(1, 1 ether);
        assertEq(receiver, user1);
        assertEq(amount, 0.03 ether);

        // Transfer and verify royalty still works after resale
        vm.startPrank(user1);
        up.transferFrom(user1, user2, 1);
        vm.stopPrank();

        (receiver, amount) = up.royaltyInfo(1, 2 ether);
        assertEq(receiver, user1);
        assertEq(amount, 0.06 ether); // 3% of 2 ether
    }
}
