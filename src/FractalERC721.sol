// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


// Upgradeable ERC721 implementation for cloning
contract FractalERC721Impl is ERC721Upgradeable, OwnableUpgradeable {
    uint256 public totalSupply;
    uint256 public maxSupply;
    string public _baseTokenURI;

    error AlreadyInitialized();

    
    function initialize(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        string memory baseURI,
        address owner
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(owner);
        maxSupply = _maxSupply;
        _baseTokenURI = baseURI;
    }
    
    function mint(address to, uint256 tokenId) external onlyOwner {
        require(totalSupply < maxSupply, "Max supply reached");
        totalSupply++;
        _mint(to, tokenId);
    }
    
    function batchMint(address to, uint256[] calldata tokenIds) external onlyOwner {
        require(totalSupply + tokenIds.length <= maxSupply, "Max supply exceeded");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            totalSupply++;
            _mint(to, tokenIds[i]);
        }
    }
    
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}