// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./a16z/CantBeEvilUpgradeable.sol";

contract FractalERC1155Impl is ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable, CantBeEvilUpgradeable, ERC2981 {

    // Custom errors
    error MaxSupplyExceeded();
    error MaxSupplyBelowCurrentSupply();
    error LengthMismatch();
    error NotAuthorized();

    // State Variables
    string public name;
    string public symbol;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => string) public tokenURIs;

    event MaxSupplySet(uint256 indexed tokenId, uint256 maxSupply);
    event TokenURISet(uint256 indexed tokenId, string tokenURI);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);

    // note: maxSupply is only set for token ID 0 during initialization, for other IDs it can be set later using the setMaxSupply function
   /**
     * @dev Initializes the contract
     * @param _name Token collection name
     * @param _symbol Token collection symbol
     * @param _maxSupply Max supply for token ID 0 (0 for unlimited)
     * @param _baseURI Base URI for token metadata
     * @param _owner Contract owner address
     * @param _royaltyFee Royalty fee in basis points (500 = 5%)
     * @param _licenseVersion License type for NFT usage rights
     */
    function initialize(
        string memory _name,    
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner,
        uint96 _royaltyFee,
        LicenseVersion _licenseVersion
    ) public initializer {
        __ERC1155_init(_baseURI);
        __Ownable_init(_owner);
        __CantBeEvil_init(_licenseVersion);
        __UUPSUpgradeable_init();
        _setDefaultRoyalty(_owner, _royaltyFee);
        name = _name;
        symbol = _symbol;
        maxSupply[0] = _maxSupply;
        
        emit LicenseVersionSet(_licenseVersion);
    }
    
    function mint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external onlyOwner {
        if (maxSupply[_id] > 0) {
            if (totalSupply[_id] + _amount > maxSupply[_id]) revert MaxSupplyExceeded();
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
        if (_ids.length != _amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < _ids.length; i++) {
            if (maxSupply[_ids[i]] > 0) {
                if (totalSupply[_ids[i]] + _amounts[i] > maxSupply[_ids[i]]) revert MaxSupplyExceeded();
            }
            totalSupply[_ids[i]] += _amounts[i];
        }

        _mintBatch(_to, _ids, _amounts, _data);
    }
    
    function setMaxSupply(uint256 _id, uint256 _maxSupply) external onlyOwner {
        if (_maxSupply < totalSupply[_id]) revert MaxSupplyBelowCurrentSupply();
        maxSupply[_id] = _maxSupply;

         emit MaxSupplySet(_id, _maxSupply);
    }
    
    function setTokenURI(uint256 _id, string memory _tokenURI) external onlyOwner {
        tokenURIs[_id] = _tokenURI;

        emit TokenURISet(_id, _tokenURI);
    }
    
    function uri(uint256 _id) public view override returns (string memory) {
        return bytes(tokenURIs[_id]).length > 0 ? tokenURIs[_id] : super.uri(_id);
    }

    function burn(address _from, uint256 _id, uint256 _amount) external {
        address caller = msg.sender;

        if (_from != caller && !isApprovedForAll(_from, caller)) revert NotAuthorized();
        totalSupply[_id] -= _amount;
        _burn(_from, _id, _amount);
    }

    function burnBatch(address _from, uint256[] calldata _ids, uint256[] calldata _amounts) external {
        address caller = msg.sender;

        if (_from != caller && !isApprovedForAll(_from, caller)) revert NotAuthorized();
        if (_ids.length != _amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < _ids.length; i++) {
            totalSupply[_ids[i]] -= _amounts[i];
        }

        super._burnBatch(_from, _ids, _amounts);
    }

    /**
     * @dev Override supportsInterface to include all parent contracts
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC1155Upgradeable, CantBeEvilUpgradeable, ERC2981) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev UUPS Upgrade authorization - only owner can upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}