// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Custom errors
error MaxSupplyReached();
error MaxSupplyExceeded();
error NotAuthorized();

// Upgradeable ERC721 implementation for cloning
contract FractalERC721Impl is ERC721Upgradeable, OwnableUpgradeable {

    // Custom errors
    error MaxSupplyReached();
    error MaxSupplyExceeded();
    error NotAuthorized();


    // State Variables
    uint256 public totalSupply;
    uint256 public maxSupply;
    string public baseTokenURI;
    
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_owner);
        maxSupply = _maxSupply;
        baseTokenURI = _baseURI;
    }
    
    function mint(address _to, uint256 _tokenId) external onlyOwner {
        if (totalSupply >= maxSupply) revert MaxSupplyReached();
        totalSupply++;
        _mint(_to, _tokenId);
    }
    
    function batchMint(address _to, uint256[] calldata _tokenIds) external onlyOwner {
        if (totalSupply + _tokenIds.length > maxSupply) revert MaxSupplyExceeded();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            totalSupply++;
            _mint(_to, _tokenIds[i]);
        }
    }
    
    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseTokenURI = _baseURI;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function burn(uint256 _tokenId) external {
        if (!_isAuthorized(msg.sender, msg.sender, _tokenId)) revert NotAuthorized();
        totalSupply--;  
        _burn(_tokenId);
    }


}