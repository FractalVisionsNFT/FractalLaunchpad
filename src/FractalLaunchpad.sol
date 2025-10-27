// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MinimalProxy} from "./Factory.sol";
import {FractalERC721Impl} from "./FractalERC721.sol";
import {FractalERC1155Impl} from "./FractalERC1155.sol";

contract FractalLaunchpad is Ownable {
    enum TokenType { ERC721, ERC1155 }
    
    address public immutable ERC721_IMPLEMENTATION;
    address public immutable ERC1155_IMPLEMENTATION;
    uint256 public platformFee;
    address public feeRecipient;
    uint256 public nextLaunchId;
    MinimalProxy public immutable nftFactory; 


    mapping(address => address[]) public creatorToERC721s;
    mapping(address => address[]) public creatorToERC1155s;
    mapping(uint256 => LaunchConfig) public launches;
    mapping(address => bool) public authorizedCreators;
    address[] public allERC721s;
    address[] public allERC1155s;


    struct LaunchConfig {
        TokenType tokenType;
        address tokenContract;
        address creator;
        uint256 maxSupply;
        string baseURI;
    }


    event LaunchCreated(
        uint256  launchId,
        TokenType indexed tokenType,
        address indexed tokenContract,
        address indexed creator
    );
    
    event TokensPurchased(
        uint256 indexed launchId,
        address indexed buyer,
        uint256 quantity,
        uint256 totalCost
    );

    constructor(address _feeRecipient,uint256 _fee, address _erc1155, address _erc721, address _factory) Ownable(msg.sender) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_erc1155 != address(0), "Invalid ERC1155 implementation");
        require(_erc721 != address(0), "Invalid ERC721 implementation");
        require(_factory != address(0), "Invalid factory");


        feeRecipient = _feeRecipient;
        platformFee = _fee;
        nftFactory = MinimalProxy(_factory);
        ERC1155_IMPLEMENTATION = _erc1155;
        ERC721_IMPLEMENTATION = _erc721;
    }
    
    function createLaunch(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        TokenType _tokenType
    ) external payable returns (uint256 launchId) {
        require(_maxSupply > 0, "Max supply must be > 0");
        
        launchId = nextLaunchId++;

        if(!authorizedCreators[msg.sender] && msg.sender != owner()){
            //charge fee
            require(msg.value >= platformFee, "Insufficient fee");
            (bool sent, ) = feeRecipient.call{value: platformFee}("");
            require(sent, "Failed to send fee");
        }

        if(_tokenType == TokenType.ERC721) {
            address tokenContract = nftFactory.createClone(ERC721_IMPLEMENTATION, _name, _symbol, _maxSupply, _baseURI, msg.sender);

            launches[launchId] = LaunchConfig({
                tokenType: TokenType.ERC721,
                tokenContract: tokenContract,
                creator: msg.sender,
                maxSupply: _maxSupply,
                baseURI: _baseURI
            });

            creatorToERC721s[msg.sender].push(tokenContract);
            allERC721s.push(tokenContract);

            emit LaunchCreated(launchId, TokenType.ERC721, tokenContract, msg.sender);
        } else {
            address tokenContract = nftFactory.createClone(ERC1155_IMPLEMENTATION, _name, _symbol, _maxSupply, _baseURI, msg.sender);
            launches[launchId] = LaunchConfig({
                tokenType: TokenType.ERC1155,
                tokenContract: tokenContract,
                creator: msg.sender,
                maxSupply: _maxSupply,
                baseURI: _baseURI
            });

            creatorToERC1155s[msg.sender].push(tokenContract);
            allERC1155s.push(tokenContract);
            emit LaunchCreated(launchId, TokenType.ERC1155, tokenContract, msg.sender);
        }

    }
    
    // Admin functions
    function setAuthorizedCreator(address _creator, bool _authorized) external onlyOwner {
        authorizedCreators[_creator] = _authorized;
    }
    
    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }
    function withdrawLockedFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "Failed to withdraw funds");
    }
    
    // View functions
    function getLaunchInfo(uint256 _launchId) external view returns (LaunchConfig memory) {
        return launches[_launchId];
    }

    function getERC721sByCreator(address _creator) external view returns (address[] memory) {
        return creatorToERC721s[_creator];
    }
    
    function getERC1155sByCreator(address _creator) external view returns (address[] memory) {
        return creatorToERC1155s[_creator];
    }


    // Check if an address is a clone of our implementations
    function isERC721Clone(address _query) external view returns (bool) {
        return _isClone(ERC721_IMPLEMENTATION, _query);
    }
    
    function isERC1155Clone(address _query) external view returns (bool) {
        return _isClone(ERC1155_IMPLEMENTATION, _query);
    }

    function _isClone(address _implementation, address _query) internal view returns (bool) {
        return nftFactory.isClone(_implementation, _query);
    }

}
