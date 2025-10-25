// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";


// Upgradeable ERC1155 implementation for cloning
contract FractalERC1155Impl is ERC1155Upgradeable, OwnableUpgradeable {
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => string) public tokenURIs;

    error AlreadyInitialized();
    
    function initialize(
        string memory name,
        string memory symbol,
        uint256 /*_maxSupply*/,
        string memory baseURI,
        address owner
    ) public initializer {
        __ERC1155_init(baseURI);
        __Ownable_init(owner);

    }
    
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        require(totalSupply[id] + amount <= maxSupply[id], "Max supply exceeded");
        totalSupply[id] += amount;
        _mint(to, id, amount, data);
    }
    
    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            require(totalSupply[ids[i]] + amounts[i] <= maxSupply[ids[i]], "Max supply exceeded");
            totalSupply[ids[i]] += amounts[i];
        }
        _mintBatch(to, ids, amounts, data);
    }
    
    function setMaxSupply(uint256 id, uint256 _maxSupply) external onlyOwner {
        maxSupply[id] = _maxSupply;
    }
    
    function setTokenURI(uint256 id, string memory tokenURI) external onlyOwner {
        tokenURIs[id] = tokenURI;
    }
    
    function tokenURI(uint256 id) public view returns (string memory) {
        return bytes(tokenURIs[id]).length > 0 ? tokenURIs[id] : super.uri(id);
    }
}