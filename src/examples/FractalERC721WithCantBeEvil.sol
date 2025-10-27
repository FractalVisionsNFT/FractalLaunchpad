// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@a16z/contracts/licenses/CantBeEvil.sol";

/**
 * @title FractalERC721WithCantBeEvil
 * @dev Example contract showing how to integrate CantBeEvil license with FractalERC721
 * 
 * This contract demonstrates:
 * 1. How to inherit from both ERC721Upgradeable and CantBeEvil
 * 2. How to properly handle supportsInterface with multiple inheritance
 * 3. How to set different license types for different use cases
 * 
 * License Options:
 * - PUBLIC: CC0 - All copyrights waived
 * - EXCLUSIVE: Full exclusive commercial rights, no creator retention
 * - COMMERCIAL: Non-exclusive commercial rights, creator retains rights
 * - COMMERCIAL_NO_HATE: Commercial rights with hate speech termination
 * - PERSONAL: Personal use only
 * - PERSONAL_NO_HATE: Personal use with hate speech termination
 */
contract FractalERC721WithCantBeEvil is 
    Initializable, 
    ERC721Upgradeable, 
    OwnableUpgradeable, 
    CantBeEvil 
{
    // Custom errors
    error MaxSupplyReached();
    error InvalidTokenId();
    error NotAuthorized();

    // State variables
    uint256 public maxSupply;
    uint256 public totalSupply;
    string private baseURI;

    // Events
    event BaseURIUpdated(string newBaseURI);
    event LicenseSet(LicenseVersion licenseVersion);

    constructor(LicenseVersion _licenseVersion) CantBeEvil(_licenseVersion) {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract with basic parameters and license
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _maxSupply Maximum supply (0 for infinite)
     * @param _baseTokenURI Base URI for token metadata
     * @param _owner Contract owner
     * @param _licenseVersion CantBeEvil license version
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseTokenURI,
        address _owner,
        LicenseVersion _licenseVersion
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_owner);
        
        maxSupply = _maxSupply;
        baseURI = _baseTokenURI;
        licenseVersion = _licenseVersion;
        
        emit LicenseSet(_licenseVersion);
    }

    /**
     * @dev Mint a token to the specified address
     * @param _to Address to mint the token to
     * @param _tokenId Token ID to mint
     */
    function mint(address _to, uint256 _tokenId) external onlyOwner {
        if (maxSupply != 0 && totalSupply >= maxSupply) {
            revert MaxSupplyReached();
        }
        
        totalSupply++;
        _safeMint(_to, _tokenId);
    }

    /**
     * @dev Batch mint tokens
     * @param _to Address to mint tokens to
     * @param _tokenIds Array of token IDs to mint
     */
    function batchMint(address _to, uint256[] calldata _tokenIds) external onlyOwner {
        uint256 mintAmount = _tokenIds.length;
        
        if (maxSupply != 0 && totalSupply + mintAmount > maxSupply) {
            revert MaxSupplyReached();
        }
        
        for (uint256 i = 0; i < mintAmount; i++) {
            _safeMint(_to, _tokenIds[i]);
        }
        
        totalSupply += mintAmount;
    }

    /**
     * @dev Burn a token
     * @param _tokenId Token ID to burn
     */
    function burn(uint256 _tokenId) external {
        if (ownerOf(_tokenId) != msg.sender && getApproved(_tokenId) != msg.sender) {
            revert NotAuthorized();
        }
        
        totalSupply--;
        _burn(_tokenId);
    }

    /**
     * @dev Set the base URI for token metadata
     * @param _newBaseURI New base URI
     */
    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
        emit BaseURIUpdated(_newBaseURI);
    }

    /**
     * @dev Update the license version (only owner can change)
     * @param _licenseVersion New license version
     */
    function updateLicense(LicenseVersion _licenseVersion) external onlyOwner {
        licenseVersion = _licenseVersion;
        emit LicenseSet(_licenseVersion);
    }

    /**
     * @dev Override to return the base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Override supportsInterface to handle multiple inheritance
     * This is crucial when inheriting from multiple contracts that implement ERC165
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721Upgradeable, CantBeEvil) 
        returns (bool) 
    {
        return 
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            CantBeEvil.supportsInterface(interfaceId);
    }

    /**
     * @dev Get current license information
     * @return licenseURI The Arweave URI for the license
     * @return licenseName The human-readable license name
     */
    function getLicenseInfo() external view returns (string memory licenseURI, string memory licenseName) {
        return (getLicenseURI(), getLicenseName());
    }

    /**
     * @dev Check if infinite minting is enabled
     */
    function isInfiniteMinting() external view returns (bool) {
        return maxSupply == 0;
    }
}