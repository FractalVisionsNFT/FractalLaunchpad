# CantBeEvil Integration Guide

This guide explains how to integrate the CantBeEvil license from a16z into your Fractal Launchpad contracts.

## What is CantBeEvil?

CantBeEvil is an on-chain licensing system created by a16z that provides standardized NFT licensing terms. It offers six different license types to cover various commercial and personal use cases.

## License Types

1. **PUBLIC** (`LicenseVersion.PUBLIC`) - CC0: All copyrights waived
2. **EXCLUSIVE** (`LicenseVersion.EXCLUSIVE`) - Full exclusive commercial rights, no creator retention
3. **COMMERCIAL** (`LicenseVersion.COMMERCIAL`) - Non-exclusive commercial rights, creator retains rights
4. **COMMERCIAL_NO_HATE** (`LicenseVersion.COMMERCIAL_NO_HATE`) - Commercial rights with hate speech termination
5. **PERSONAL** (`LicenseVersion.PERSONAL`) - Personal use only
6. **PERSONAL_NO_HATE** (`LicenseVersion.PERSONAL_NO_HATE`) - Personal use with hate speech termination

## Installation

The CantBeEvil contracts have been installed as a Foundry dependency:

```bash
# Already completed - contracts are available at:
# lib/a16z-contracts/contracts/licenses/CantBeEvil.sol
```

Remapping has been added to `remappings.txt`:
```
@a16z/contracts/=lib/a16z-contracts/contracts/
```

## Integration Examples

### 1. Basic ERC721 Integration

```solidity
import "@a16z/contracts/licenses/CantBeEvil.sol";

contract MyNFT is ERC721Upgradeable, OwnableUpgradeable, CantBeEvil {
    constructor(LicenseVersion _licenseVersion) CantBeEvil(_licenseVersion) {
        _disableInitializers();
    }
    
    function initialize(
        string memory _name,
        string memory _symbol,
        LicenseVersion _licenseVersion
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(msg.sender);
        licenseVersion = _licenseVersion;
    }
    
    // Important: Override supportsInterface for multiple inheritance
    function supportsInterface(bytes4 interfaceId) 
        public view virtual override(ERC721Upgradeable, CantBeEvil) 
        returns (bool) 
    {
        return 
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            CantBeEvil.supportsInterface(interfaceId);
    }
}
```

### 2. ERC1155 with Token-Specific Licensing

```solidity
contract MyMultiNFT is ERC1155Upgradeable, OwnableUpgradeable, CantBeEvil {
    mapping(uint256 => LicenseVersion) public tokenLicenses;
    bool public useTokenSpecificLicenses;
    
    // Set different licenses for different token IDs
    function setTokenLicense(uint256 _tokenId, LicenseVersion _license) external onlyOwner {
        require(useTokenSpecificLicenses, "Token-specific licensing disabled");
        tokenLicenses[_tokenId] = _license;
    }
    
    // Get license for specific token
    function getLicenseForToken(uint256 _tokenId) external view returns (string memory) {
        if (useTokenSpecificLicenses) {
            LicenseVersion tokenLicense = tokenLicenses[_tokenId];
            // Use token-specific license if set, otherwise default
            return tokenLicense != LicenseVersion(0) ? 
                getTokenLicenseURI(tokenLicense) : getLicenseURI();
        }
        return getLicenseURI();
    }
}
```

## Key Functions Available

### From CantBeEvil Contract

- `getLicenseURI()` - Returns Arweave URL to license text
- `getLicenseName()` - Returns human-readable license name
- `supportsInterface(bytes4)` - ERC165 interface support

### From Example Implementations

- `updateLicense(LicenseVersion)` - Change license (owner only)
- `getLicenseInfo()` - Get both URI and name
- `setTokenLicense(uint256, LicenseVersion)` - Set per-token license (ERC1155)
- `getLicenseForToken(uint256)` - Get license for specific token

## Integration with FractalLaunchpad

To integrate CantBeEvil with your existing launchpad:

### Option 1: Modify Existing Contracts

Add CantBeEvil inheritance to your existing `FractalERC721.sol` and `FractalERC1155.sol`:

```solidity
// In FractalERC721.sol
import "@a16z/contracts/licenses/CantBeEvil.sol";

contract FractalERC721Impl is 
    Initializable, 
    ERC721Upgradeable, 
    OwnableUpgradeable, 
    CantBeEvil 
{
    constructor() CantBeEvil(LicenseVersion.COMMERCIAL) {
        _disableInitializers();
    }
    
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner,
        LicenseVersion _licenseVersion  // Add this parameter
    ) public initializer {
        // ... existing initialization ...
        licenseVersion = _licenseVersion;
    }
    
    // Override supportsInterface
    function supportsInterface(bytes4 interfaceId) 
        public view virtual override(ERC721Upgradeable, CantBeEvil) 
        returns (bool) 
    {
        return 
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            CantBeEvil.supportsInterface(interfaceId);
    }
}
```

### Option 2: Use Example Contracts

Use the provided example contracts in `src/examples/`:
- `FractalERC721WithCantBeEvil.sol`
- `FractalERC1155WithCantBeEvil.sol`

These are drop-in replacements with full CantBeEvil integration.

### Option 3: Create Licensed Variants

Create separate contract variants for specific license types:

```solidity
// For CC0/Public Domain NFTs
contract FractalERC721Public is FractalERC721Impl {
    constructor() CantBeEvil(LicenseVersion.PUBLIC) {}
}

// For Commercial NFTs
contract FractalERC721Commercial is FractalERC721Impl {
    constructor() CantBeEvil(LicenseVersion.COMMERCIAL) {}
}
```

## Updating FractalLaunchpad

To support license selection in the launchpad:

```solidity
// Add license parameter to createLaunch
function createLaunch(
    string memory _name,
    string memory _symbol,
    uint256 _maxSupply,
    string memory _baseURI,
    TokenType _tokenType,
    LicenseVersion _licenseVersion  // Add this
) external payable returns (uint256) {
    // ... existing code ...
    
    // Pass license version to clone initialization
    if (_tokenType == TokenType.ERC721) {
        FractalERC721WithCantBeEvil(clone).initialize(
            _name, _symbol, _maxSupply, _baseURI, msg.sender, _licenseVersion
        );
    } else {
        FractalERC1155WithCantBeEvil(clone).initialize(
            _name, _symbol, _baseURI, msg.sender, _licenseVersion, false
        );
    }
}
```

## Testing

Run the comprehensive test suite:

```bash
forge test --match-contract CantBeEvilIntegrationTest -vv
```

This tests:
- All six license types
- ERC165 interface support
- License updates
- Token-specific licensing (ERC1155)
- Factory integration
- Error conditions

## Best Practices

1. **Choose Appropriate License**: Consider your NFT's intended use case
2. **Document License Choice**: Make license terms clear to users
3. **Interface Support**: Always override `supportsInterface` correctly
4. **Upgrade Safely**: If changing licenses, consider impact on existing holders
5. **Test Thoroughly**: Use provided tests as a reference

## License URIs

Each license points to immutable Arweave storage:
- PUBLIC: `ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/0`
- EXCLUSIVE: `ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/1`
- COMMERCIAL: `ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/2`
- COMMERCIAL_NO_HATE: `ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/3`
- PERSONAL: `ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/4`
- PERSONAL_NO_HATE: `ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/5`

## Support

For questions about CantBeEvil licensing, refer to:
- [a16z Contracts Repository](https://github.com/a16z/a16z-contracts)
- [License Documentation](https://github.com/a16z/a16z-contracts/blob/master/licenses/)
- Example implementations in `src/examples/`