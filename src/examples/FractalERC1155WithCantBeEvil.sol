// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@a16z/contracts/licenses/CantBeEvil.sol";

/**
 * @title FractalERC1155WithCantBeEvil
 * @dev Example contract showing how to integrate CantBeEvil license with FractalERC1155
 * 
 * This contract demonstrates:
 * 1. How to inherit from both ERC1155Upgradeable and CantBeEvil
 * 2. How to properly handle supportsInterface with multiple inheritance
 * 3. How to set different license types for different token collections
 * 4. How to manage per-token licensing in ERC1155
 */
contract FractalERC1155WithCantBeEvil is 
    Initializable, 
    ERC1155Upgradeable, 
    OwnableUpgradeable, 
    CantBeEvil 
{
    // Custom errors
    error MaxSupplyReached();
    error InvalidTokenId();
    error NotAuthorized();
    error MismatchedArrays();

    // State variables
    string public name;
    string public symbol;
    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => uint256) public totalSupply;
    
    // Optional: Different licenses per token ID
    mapping(uint256 => LicenseVersion) public tokenLicenses;
    bool public useTokenSpecificLicenses;

    // Events
    event TokenLicenseSet(uint256 indexed tokenId, LicenseVersion licenseVersion);
    event TokenSpecificLicensingToggled(bool enabled);

    constructor(LicenseVersion _licenseVersion) CantBeEvil(_licenseVersion) {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract with basic parameters and license
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _baseURI Base URI for token metadata
     * @param _owner Contract owner
     * @param _licenseVersion Default CantBeEvil license version
     * @param _useTokenSpecificLicenses Whether to allow different licenses per token
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _owner,
        LicenseVersion _licenseVersion,
        bool _useTokenSpecificLicenses
    ) public initializer {
        __ERC1155_init(_baseURI);
        __Ownable_init(_owner);
        
        name = _name;
        symbol = _symbol;
        licenseVersion = _licenseVersion;
        useTokenSpecificLicenses = _useTokenSpecificLicenses;
    }

    /**
     * @dev Set max supply for a token ID (0 for infinite)
     * @param _tokenId Token ID
     * @param _maxSupply Maximum supply for this token
     */
    function setMaxSupply(uint256 _tokenId, uint256 _maxSupply) external onlyOwner {
        maxSupply[_tokenId] = _maxSupply;
    }

    /**
     * @dev Mint tokens to the specified address
     * @param _to Address to mint tokens to
     * @param _tokenId Token ID to mint
     * @param _amount Amount to mint
     * @param _data Additional data
     */
    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _data
    ) external onlyOwner {
        uint256 currentSupply = totalSupply[_tokenId];
        uint256 tokenMaxSupply = maxSupply[_tokenId];
        
        if (tokenMaxSupply != 0 && currentSupply + _amount > tokenMaxSupply) {
            revert MaxSupplyReached();
        }
        
        totalSupply[_tokenId] += _amount;
        _mint(_to, _tokenId, _amount, _data);
    }

    /**
     * @dev Batch mint tokens
     * @param _to Address to mint tokens to
     * @param _tokenIds Array of token IDs
     * @param _amounts Array of amounts to mint
     * @param _data Additional data
     */
    function batchMint(
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        bytes memory _data
    ) external onlyOwner {
        if (_tokenIds.length != _amounts.length) {
            revert MismatchedArrays();
        }
        
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 amount = _amounts[i];
            uint256 currentSupply = totalSupply[tokenId];
            uint256 tokenMaxSupply = maxSupply[tokenId];
            
            if (tokenMaxSupply != 0 && currentSupply + amount > tokenMaxSupply) {
                revert MaxSupplyReached();
            }
            
            totalSupply[tokenId] += amount;
        }
        
        _mintBatch(_to, _tokenIds, _amounts, _data);
    }

    /**
     * @dev Burn tokens
     * @param _from Address to burn from
     * @param _tokenId Token ID to burn
     * @param _amount Amount to burn
     */
    function burn(address _from, uint256 _tokenId, uint256 _amount) external {
        if (_from != msg.sender && !isApprovedForAll(_from, msg.sender)) {
            revert NotAuthorized();
        }
        
        totalSupply[_tokenId] -= _amount;
        _burn(_from, _tokenId, _amount);
    }

    /**
     * @dev Batch burn tokens
     * @param _from Address to burn from
     * @param _tokenIds Array of token IDs
     * @param _amounts Array of amounts to burn
     */
    function burnBatch(
        address _from,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external {
        if (_from != msg.sender && !isApprovedForAll(_from, msg.sender)) {
            revert NotAuthorized();
        }
        
        if (_tokenIds.length != _amounts.length) {
            revert MismatchedArrays();
        }
        
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            totalSupply[_tokenIds[i]] -= _amounts[i];
        }
        
        _burnBatch(_from, _tokenIds, _amounts);
    }

    /**
     * @dev Set license for a specific token ID (if token-specific licensing is enabled)
     * @param _tokenId Token ID
     * @param _licenseVersion License version for this token
     */
    function setTokenLicense(uint256 _tokenId, LicenseVersion _licenseVersion) external onlyOwner {
        if (!useTokenSpecificLicenses) {
            revert("Token-specific licensing is disabled");
        }
        
        tokenLicenses[_tokenId] = _licenseVersion;
        emit TokenLicenseSet(_tokenId, _licenseVersion);
    }

    /**
     * @dev Toggle token-specific licensing on/off
     * @param _enabled Whether to enable token-specific licensing
     */
    function setTokenSpecificLicensing(bool _enabled) external onlyOwner {
        useTokenSpecificLicenses = _enabled;
        emit TokenSpecificLicensingToggled(_enabled);
    }

    /**
     * @dev Update the default license version
     * @param _licenseVersion New default license version
     */
    function updateDefaultLicense(LicenseVersion _licenseVersion) external onlyOwner {
        licenseVersion = _licenseVersion;
    }

    /**
     * @dev Get license URI for a specific token
     * @param _tokenId Token ID
     * @return License URI (token-specific if enabled, otherwise default)
     */
    function getLicenseURIForToken(uint256 _tokenId) external view returns (string memory) {
        if (useTokenSpecificLicenses) {
            LicenseVersion tokenLicense = tokenLicenses[_tokenId];
            // If no specific license set for this token, use default
            if (uint8(tokenLicense) == 0 && tokenLicense != LicenseVersion.PUBLIC) {
                return getLicenseURI();
            }
            return string.concat(
                "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/",
                Strings.toString(uint8(tokenLicense))
            );
        }
        return getLicenseURI();
    }

    /**
     * @dev Get license name for a specific token
     * @param _tokenId Token ID
     * @return License name (token-specific if enabled, otherwise default)
     */
    function getLicenseNameForToken(uint256 _tokenId) external view returns (string memory) {
        if (useTokenSpecificLicenses) {
            LicenseVersion tokenLicense = tokenLicenses[_tokenId];
            // If no specific license set for this token, use default
            if (uint8(tokenLicense) == 0 && tokenLicense != LicenseVersion.PUBLIC) {
                return getLicenseName();
            }
            return _getLicenseNameFromVersion(tokenLicense);
        }
        return getLicenseName();
    }

    /**
     * @dev Override supportsInterface to handle multiple inheritance
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC1155Upgradeable, CantBeEvil) 
        returns (bool) 
    {
        return 
            ERC1155Upgradeable.supportsInterface(interfaceId) ||
            CantBeEvil.supportsInterface(interfaceId);
    }

    /**
     * @dev Get comprehensive license information for the contract and a specific token
     * @param _tokenId Token ID to check
     * @return defaultLicenseURI Default license URI for the contract
     * @return defaultLicenseName Default license name for the contract
     * @return tokenLicenseURI License URI for the specific token
     * @return tokenLicenseName License name for the specific token
     * @return hasTokenSpecificLicense Whether the token has a specific license
     */
    function getComprehensiveLicenseInfo(uint256 _tokenId) 
        external 
        view 
        returns (
            string memory defaultLicenseURI,
            string memory defaultLicenseName,
            string memory tokenLicenseURI,
            string memory tokenLicenseName,
            bool hasTokenSpecificLicense
        ) 
    {
        defaultLicenseURI = getLicenseURI();
        defaultLicenseName = getLicenseName();
        
        if (useTokenSpecificLicenses) {
            LicenseVersion tokenLicense = tokenLicenses[_tokenId];
            hasTokenSpecificLicense = uint8(tokenLicense) != 0 || tokenLicense == LicenseVersion.PUBLIC;
            
            if (hasTokenSpecificLicense) {
                tokenLicenseURI = string.concat(
                    "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/",
                    Strings.toString(uint8(tokenLicense))
                );
                tokenLicenseName = _getLicenseNameFromVersion(tokenLicense);
            } else {
                tokenLicenseURI = defaultLicenseURI;
                tokenLicenseName = defaultLicenseName;
            }
        } else {
            tokenLicenseURI = defaultLicenseURI;
            tokenLicenseName = defaultLicenseName;
            hasTokenSpecificLicense = false;
        }
    }

    /**
     * @dev Check if infinite minting is enabled for a token
     * @param _tokenId Token ID to check
     */
    function isInfiniteMinting(uint256 _tokenId) external view returns (bool) {
        return maxSupply[_tokenId] == 0;
    }

    /**
     * @dev Helper function to get license name by version (internal helper to avoid conflicts)
     */
    function _getLicenseNameFromVersion(LicenseVersion _licenseVersion) internal pure returns (string memory) {
        if (LicenseVersion.PUBLIC == _licenseVersion) return "PUBLIC";
        if (LicenseVersion.EXCLUSIVE == _licenseVersion) return "EXCLUSIVE";
        if (LicenseVersion.COMMERCIAL == _licenseVersion) return "COMMERCIAL";
        if (LicenseVersion.COMMERCIAL_NO_HATE == _licenseVersion) return "COMMERCIAL_NO_HATE";
        if (LicenseVersion.PERSONAL == _licenseVersion) return "PERSONAL";
        else return "PERSONAL_NO_HATE";
    }
}