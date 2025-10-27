// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";


contract FractalERC1155Impl is ERC1155Upgradeable, OwnableUpgradeable {
    string public name;
    string public symbol;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => string) public tokenURIs;

    // note: maxSupply is only set for token ID 0 during initialization, for other IDs it can be set later using the setMaxSupply function
    function initialize(
        string memory _name,    
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner
    ) public initializer {
        __ERC1155_init(_baseURI);
        __Ownable_init(_owner);
        name = _name;
        symbol = _symbol;
        maxSupply[0] = _maxSupply;

    }
    
    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external onlyOwner {
        if (maxSupply[_id] > 0) {
            require(totalSupply[_id] + _amount <= maxSupply[_id], "Max supply exceeded");
        }
        totalSupply[_id] += _amount;
        _mint(_to, _id, _amount, _data);
    }
    
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) external onlyOwner {
        require(_ids.length == _amounts.length, "Length mismatch");

        for (uint256 i = 0; i < _ids.length; i++) {
            if (maxSupply[_ids[i]] > 0) {
                require(totalSupply[_ids[i]] + _amounts[i] <= maxSupply[_ids[i]], "Max supply exceeded");
            }
            totalSupply[_ids[i]] += _amounts[i];
        }

        _mintBatch(_to, _ids, _amounts, _data);
    }
    
    function setMaxSupply(uint256 _id, uint256 _maxSupply) external onlyOwner {
        require(_maxSupply >= totalSupply[_id], "Max supply below current supply");
        maxSupply[_id] = _maxSupply;
    }
    
    function setTokenURI(uint256 _id, string memory _tokenURI) external onlyOwner {
        tokenURIs[_id] = _tokenURI;
    }
    
    function uri(uint256 _id) public view override returns (string memory) {
        return bytes(tokenURIs[_id]).length > 0 ? tokenURIs[_id] : super.uri(_id);
    }

    function burn(address _from, uint256 _id, uint256 _amount) external {
        address caller = msg.sender;

        require(_from == caller || isApprovedForAll(_from, caller), "Not authorized");
        totalSupply[_id] -= _amount;
        _burn(_from, _id, _amount);
    }

    function burnBatch(address _from, uint256[] calldata _ids, uint256[] calldata _amounts) external {
        address caller = msg.sender;

        require(_from == caller || isApprovedForAll(_from, caller), "Not authorized");
        require(_ids.length == _amounts.length, "Length mismatch");


        for (uint256 i = 0; i < _ids.length; i++) {
            totalSupply[_ids[i]] -= _amounts[i];
        }

        super._burnBatch(_from, _ids, _amounts);
    }
}