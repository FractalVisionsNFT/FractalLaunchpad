// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {CantBeEvilUpgradeable, LicenseVersion} from "./a16z/CantBeEvilUpgradeable.sol";

contract FractalERC1155Impl is
    ERC1155Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    CantBeEvilUpgradeable,
    ERC2981Upgradeable
{
    // Custom errors
    error MaxSupplyExceeded();
    error MaxSupplyBelowCurrentSupply();
    error LengthMismatch();
    error NotAuthorized();
    error RoyaltyExceedsCap();


    // State Variables
    /// @dev 10% hard cap on all royalties — default and per-token
    uint96 public constant MAX_ROYALTY_BPS = 1000;

    string public name;
    string public symbol;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => string) private tokenURIs;

    event MaxSupplySet(uint256 indexed tokenId, uint256 maxSupply);
    event BaseURISet(string baseURI);
    event LicenseVersionSet(LicenseVersion indexed licenseVersion);
    event TokenRoyaltySet(uint256 indexed tokenId, address receiver, uint96 feeNumerator);
    event DefaultRoyaltySet(address receiver, uint96 feeNumerator);
    event ContractUpgraded(address indexed newImplementation, uint8 version);

    constructor() {
        _disableInitializers();
    }

    // note: maxSupply is only set for token ID 0 during initialization, for other IDs it can be set later using the setMaxSupply function
    /**
     * @dev Initializes the contract
     * @param _name Token collection name
     * @param _symbol Token collection symbol
     * @param _maxSupply Max supply for token ID 0 (0 for unlimited)
     * @param _baseURI Base URI for token metadata
     * @param _owner Contract owner address
     * @param _royaltyFee Royalty fee in basis points (500 = 5%). Cannot exceed 1000 (10%).
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
        if (_royaltyFee > MAX_ROYALTY_BPS) revert RoyaltyExceedsCap();

        __ERC1155_init(_baseURI);
        __Ownable_init(_owner);
        __CantBeEvil_init(_licenseVersion);
        __UUPSUpgradeable_init();
        __ERC2981_init();
        _setDefaultRoyalty(_owner, _royaltyFee);
        name = _name;
        symbol = _symbol;
        maxSupply[0] = _maxSupply;

        emit LicenseVersionSet(_licenseVersion);
    }

    function version() public pure returns (uint8) {
        return uint8(2);
    }

    function mint(address _to, uint256 _id, uint256 _amount, bytes memory _data) external onlyOwner {
        if (maxSupply[_id] > 0) {
            if (totalSupply[_id] + _amount > maxSupply[_id]) revert MaxSupplyExceeded();
        }
        totalSupply[_id] += _amount;
        _mint(_to, _id, _amount, _data);
    }

    function batchMint(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)
        external
        onlyOwner
    {
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

      /**
     * @dev Override royalty for a specific token ID. Must be between 0 and 10% (0–1000 bps).
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external onlyOwner {
        if (_feeNumerator > MAX_ROYALTY_BPS) revert RoyaltyExceedsCap();
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
        emit TokenRoyaltySet(_tokenId, _receiver, _feeNumerator);
    }

    function setDefaultRoyaltyInfo(address _receiver, uint96 _feeNumerator) external onlyOwner {
        if (_feeNumerator > MAX_ROYALTY_BPS) revert RoyaltyExceedsCap();
        _setDefaultRoyalty(_receiver, _feeNumerator);
        emit DefaultRoyaltySet(_receiver, _feeNumerator);
    }

    function resetTokenRoyalty(uint256 _tokenId) external onlyOwner {
        _resetTokenRoyalty(_tokenId);
    }

    function setTokenURI(uint256 _id, string memory _tokenURI) external onlyOwner {
        tokenURIs[_id] = _tokenURI;

        emit URI(_tokenURI, _id);
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        _setURI(_baseURI);

        emit BaseURISet(_baseURI);
        // Note: standard URI event not emitted here as base URI changes affect all token IDs (dynamic/programmatic change per EIP-1155)
    }

    function uri(uint256 _id) public view override returns (string memory) {
        if (bytes(tokenURIs[_id]).length > 0) {
            return tokenURIs[_id];
        }
        string memory baseURI = super.uri(_id);
        return bytes(baseURI).length > 0 ? string.concat(baseURI, Strings.toString(_id)) : "";
    }

    function setLicenseVersion(LicenseVersion _licenseVersion) external onlyOwner {
        licenseVersion = _licenseVersion;
        emit LicenseVersionSet(_licenseVersion);
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
        override(ERC1155Upgradeable, CantBeEvilUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return ERC1155Upgradeable.supportsInterface(interfaceId) || CantBeEvilUpgradeable.supportsInterface(interfaceId)
            || ERC2981Upgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev UUPS Upgrade authorization - only owner can upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        emit ContractUpgraded(newImplementation, version());
    }
}
