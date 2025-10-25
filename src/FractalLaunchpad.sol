// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MinimalProxy} from "./Factory.sol";
import {FractalERC721Impl} from "./FractalERC721.sol";
import {FractalERC1155Impl} from "./FractalERC1155.sol";

contract FractalLaunchpad is Ownable, ReentrancyGuard {
    enum TokenType { ERC721, ERC1155 }
    
    address public immutable ERC721_IMPLEMENTATION;
    address public immutable ERC1155_IMPLEMENTATION;
    uint256 public platformFee;
    address public feeRecipient;
    uint256 public nextLaunchId;
    MinimalProxy public immutable nftFactory; 

    mapping(address => address[]) public creatorToERC721s;
    mapping(address => address[]) public creatorToERC1155s;
    address[] public allERC721s;
    address[] public allERC1155s;

    constructor(address _feeRecipient,uint256 fee, address _erc1155, address _erc721, address _factory) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
        platformFee = fee;
        nftFactory = MinimalProxy(_factory);
        ERC1155_IMPLEMENTATION = _erc1155;
        ERC721_IMPLEMENTATION = _erc721;
    }

    struct LaunchConfig {
        TokenType tokenType;
        address tokenContract;
        address creator;
        uint256 totalSupply;
        string tokenURI;
    }
    

    
    mapping(uint256 => LaunchConfig) public launches;
    mapping(uint256 => mapping(address => uint256)) public userPurchases;
    mapping(address => bool) public authorizedCreators;

    event LaunchCreated(
        uint256 indexed launchId,
        TokenType tokenType,
        address indexed tokenContract,
        address indexed creator
    );
    
    event TokensPurchased(
        uint256 indexed launchId,
        address indexed buyer,
        uint256 quantity,
        uint256 totalCost
    );
    
    function createLaunch(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        string memory baseURI,
        TokenType tokenType
    ) external payable returns (uint256 launchId) {
        require(maxSupply > 0, "Max supply must be > 0");
        
        launchId = nextLaunchId++;

        if(!authorizedCreators[msg.sender] && msg.sender != owner()){
            //charge fee
            require(msg.value >= platformFee, "Insufficient fee");
            (bool sent, ) = feeRecipient.call{value: platformFee}("");
            require(sent, "Failed to send fee");
        }

        if(tokenType == TokenType.ERC721) {
            address tokenContract = nftFactory.createClone(ERC721_IMPLEMENTATION, name, symbol, maxSupply, baseURI, address(this));

            launches[launchId] = LaunchConfig({
                tokenType: TokenType.ERC721,
                tokenContract: tokenContract,
                creator: msg.sender,
                totalSupply: maxSupply,
                tokenURI: baseURI
            });

            creatorToERC721s[msg.sender].push(tokenContract);
            allERC721s.push(tokenContract);

            emit LaunchCreated(launchId, TokenType.ERC721, tokenContract, msg.sender);
        } else {
            address tokenContract = nftFactory.createClone(ERC1155_IMPLEMENTATION, name, symbol, maxSupply, baseURI, address(this));
            launches[launchId] = LaunchConfig({
                tokenType: TokenType.ERC1155,
                tokenContract: tokenContract,
                creator: msg.sender,
                totalSupply: maxSupply,
                tokenURI: baseURI
            });

            creatorToERC1155s[msg.sender].push(tokenContract);
            allERC1155s.push(tokenContract);
            emit LaunchCreated(launchId, TokenType.ERC1155, tokenContract, msg.sender);
        }

    }
    

    // function _mintERC721Tokens(address tokenContract, address to, uint256 quantity) internal {
    //     FractalERC721Impl token = FractalERC721Impl(tokenContract);
    //     uint256 currentSupply = token.totalSupply();
        
    //     uint256[] memory tokenIds = new uint256[](quantity);
    //     for (uint256 i = 0; i < quantity; i++) {
    //         tokenIds[i] = currentSupply + i + 1;
    //     }
        
    //     token.batchMint(to, tokenIds);
    // }
    

    // function _mintERC1155Tokens(address tokenContract, address to, uint256 quantity) internal {
    //     FractalERC1155Impl token = FractalERC1155Impl(tokenContract);
    //     uint256 currentSupply = token.totalSupply(1);
        
    //     uint256[] memory tokenIds = new uint256[](quantity);
    //     for (uint256 i = 0; i < quantity; i++) {
    //         tokenIds[i] = currentSupply + i + 1;
    //     }
        
    //     token.batchMint(to, tokenIds);
    // }
    
    // Admin functions
    function setAuthorizedCreator(address creator, bool authorized) external onlyOwner {
        authorizedCreators[creator] = authorized;
    }
    
    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }
    
    
    // View functions
    function getLaunchInfo(uint256 launchId) external view returns (LaunchConfig memory) {
        return launches[launchId];
    }

    function getERC721sByCreator(address creator) external view returns (address[] memory) {
        return creatorToERC721s[creator];
    }
    
    function getERC1155sByCreator(address creator) external view returns (address[] memory) {
        return creatorToERC1155s[creator];
    }


    // Check if an address is a clone of our implementations
    function isERC721Clone(address query) external view returns (bool) {
        return _isClone(ERC721_IMPLEMENTATION, query);
    }
    
    function isERC1155Clone(address query) external view returns (bool) {
        return _isClone(ERC1155_IMPLEMENTATION, query);
    }

    function _isClone(address implementation, address query) internal view returns (bool) {
        return nftFactory.isClone(implementation, query);
    }

}
