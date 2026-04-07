// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {CantBeEvilUpgradeable, LicenseVersion} from "./a16z/CantBeEvilUpgradeable.sol";

contract FractalERC721Impl is
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    CantBeEvilUpgradeable,
    ERC2981Upgradeable
{
    // Custom errors
    error MaxSupplyBelowCurrentSupply();
    error MaxSupplyExceeded();
    error LengthMismatch();
    error NotAuthorized();
    error RoyaltyExceedsCap();

    
    // State Variables
    /// @dev 10% hard cap on all royalties — default and per-token
    uint96 public constant MAX_ROYALTY_BPS = 1000;
    uint256 public totalSupply;
    uint256 public maxSupply;
    string public baseTokenURI;
    mapping(uint256 => string) private tokenURIs;


    event MaxSupplySet(uint256 maxSupply);
    event BaseURISet(string baseURI);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    event TokenRoyaltySet(uint256 indexed tokenId, address receiver, uint96 feeNumerator);
    // EIP-4906
    event MetadataUpdate(uint256 _tokenId);


    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseUri,
        address _owner,
        uint96 _royaltyFee, //500 = 5%
        LicenseVersion _licenseVersion
    ) public initializer {
        if (_royaltyFee > MAX_ROYALTY_BPS) revert RoyaltyExceedsCap();

        __ERC721_init(_name, _symbol);
        __Ownable_init(_owner);
        __CantBeEvil_init(_licenseVersion);
        __UUPSUpgradeable_init();
        __ERC2981_init();
        _setDefaultRoyalty(_owner, _royaltyFee);
        maxSupply = _maxSupply;
        baseTokenURI = _baseUri;

        emit LicenseVersionSet(_licenseVersion);
    }

    function mint(address _to, uint256 _tokenId) external onlyOwner {
        if (maxSupply != 0 && totalSupply >= maxSupply) revert MaxSupplyExceeded();
        totalSupply++;
        _safeMint(_to, _tokenId);
    }

    function mintWithURI(address _to, uint256 _tokenId, string calldata _tokenUri) external onlyOwner {
        if (maxSupply != 0 && totalSupply >= maxSupply) revert MaxSupplyExceeded();
        totalSupply++;
        _safeMint(_to, _tokenId);
        tokenURIs[_tokenId] = _tokenUri;

        emit MetadataUpdate(_tokenId);
    }

    function batchMint(address _to, uint256[] calldata _tokenIds) external onlyOwner {
        if (maxSupply != 0 && totalSupply + _tokenIds.length > maxSupply) revert MaxSupplyExceeded();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            totalSupply++;
            _safeMint(_to, _tokenIds[i]);
        }
    }

    function batchMintWithURI(address _to, uint256[] calldata _tokenIds, string[] calldata _tokenUris)
        external
        onlyOwner
    {
        if (_tokenIds.length != _tokenUris.length) revert LengthMismatch();
        if (maxSupply != 0 && totalSupply + _tokenIds.length > maxSupply) revert MaxSupplyExceeded();

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            totalSupply++;
            _safeMint(_to, _tokenIds[i]);
            tokenURIs[_tokenIds[i]] = _tokenUris[i];

            emit MetadataUpdate(_tokenIds[i]);
        }
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        if (_maxSupply < totalSupply) revert MaxSupplyBelowCurrentSupply();
        maxSupply = _maxSupply;

        emit MaxSupplySet(_maxSupply);
    }

     /**
     * @dev Override royalty for a specific token. Must be between 0 and 10% (0–1000 bps).
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external onlyOwner {
        if (_feeNumerator > MAX_ROYALTY_BPS) revert RoyaltyExceedsCap();
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
        emit TokenRoyaltySet(_tokenId, _receiver, _feeNumerator);
    }

    function resetTokenRoyalty(uint256 _tokenId) external onlyOwner {
        _resetTokenRoyalty(_tokenId);  
    }

    function setBaseURI(string calldata _baseUri) external onlyOwner {
        baseTokenURI = _baseUri;
        emit BaseURISet(_baseUri);
    }
    
    function setTokenUri(uint256 _tokenId, string calldata _tokenUri) external onlyOwner {
        tokenURIs[_tokenId] = _tokenUri;

        emit MetadataUpdate(_tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }


    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        _requireOwned(_tokenId);

        if (bytes(tokenURIs[_tokenId]).length > 0) {
            return tokenURIs[_tokenId];
        }
        
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, Strings.toString(_tokenId)) : "";
      
}

    function burn(uint256 _tokenId) external {
        if (!_isAuthorized(_ownerOf(_tokenId), msg.sender, _tokenId)) revert NotAuthorized();
        totalSupply--;
        _burn(_tokenId);

        if (bytes(tokenURIs[_tokenId]).length != 0) {
            delete tokenURIs[_tokenId];
        } 
    }

    // Override supportsInterface to combine all parent implementations
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, CantBeEvilUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return ERC721Upgradeable.supportsInterface(interfaceId) || CantBeEvilUpgradeable.supportsInterface(interfaceId)
            || ERC2981Upgradeable.supportsInterface(interfaceId);
    }

    // UUPS Upgrade authorization - only owner can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
