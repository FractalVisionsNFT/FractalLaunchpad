// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

import "./a16z/CantBeEvilUpgradeable.sol";
contract FractalERC721Impl is ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable, CantBeEvilUpgradeable, ERC2981 {

    error MaxSupplyBelowCurrentSupply();
    error MaxSupplyExceeded();
    error NotAuthorized();

    uint256 public totalSupply;
    uint256 public maxSupply;
    string public baseTokenURI;


    event MaxSupplySet(uint256 maxSupply);
    event BaseURISet(string baseURI);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    
    
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner,
        uint96 _royaltyFee,  //500 = 5%
        LicenseVersion _licenseVersion  
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_owner);
        __CantBeEvil_init(_licenseVersion); 
        __UUPSUpgradeable_init();
        _setDefaultRoyalty(_owner, _royaltyFee);
        maxSupply = _maxSupply;
        baseTokenURI = _baseURI;

        emit LicenseVersionSet(_licenseVersion);
    }
    
    function mint(address _to, uint256 _tokenId) external onlyOwner {
        if(maxSupply !=0 && totalSupply >= maxSupply) revert MaxSupplyExceeded();   
        totalSupply++;
        _safeMint(_to, _tokenId);
    }
    
    function batchMint(address _to, uint256[] calldata _tokenIds) external onlyOwner {
        if (maxSupply !=0 && totalSupply + _tokenIds.length > maxSupply) revert MaxSupplyExceeded();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            totalSupply++;
            _safeMint(_to, _tokenIds[i]);
        }
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        if (_maxSupply < totalSupply) revert MaxSupplyBelowCurrentSupply();
        maxSupply = _maxSupply;

        emit MaxSupplySet(_maxSupply);
    }
    
    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseTokenURI = _baseURI;
        emit BaseURISet(_baseURI);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function burn(uint256 _tokenId) external {
        if (!_isAuthorized(_ownerOf(_tokenId), msg.sender, _tokenId)) revert NotAuthorized();
        totalSupply--;  
        _burn(_tokenId);
    }


    // Override supportsInterface to combine all parent implementations
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721Upgradeable, CantBeEvilUpgradeable, ERC2981) 
        returns (bool) 
    {
        return 
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            CantBeEvilUpgradeable.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    // UUPS Upgrade authorization - only owner can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


}