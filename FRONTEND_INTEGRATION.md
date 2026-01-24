# Frontend Integration Guide

This guide provides detailed information on how to interact with the FractalLaunchpad smart contracts from a frontend application.

## Table of Contents
- [Contract Addresses](#contract-addresses)
- [ABI Files](#abi-files)
- [Core Workflows](#core-workflows)
- [Function Reference](#function-reference)
- [Events to Listen For](#events-to-listen-for)
- [Error Handling](#error-handling)

---

## Contract Addresses

### Base Sepolia Testnet

```javascript
const CONTRACTS = {
  LAUNCHPAD: "0x22797574900038d794234B4fBE0446288ee46c91",
  ERC721_IMPLEMENTATION: "0x89Fbe4c8D8ff2679Bc97dE1140f7c6Ac01b9B1Ef",
  ERC1155_IMPLEMENTATION: "0xEC151c90047aF420cF62f32840580Eb8764862b6",
  FACTORY: "0xfB86636532Dec2F7e2006261Eda917d97D3E58c5"
};
```

---

## ABI Files

The ABIs can be generated using:
```bash
forge build
```

The ABIs will be located in:
- `out/FractalLaunchpad.sol/FractalLaunchpad.json`
- `out/FractalERC721.sol/FractalERC721Impl.json`
- `out/FractalERC1155.sol/FractalERC1155Impl.json`

---

## User Flows

### Complete ERC721 Creator Flow

#### Step 1: Prepare Your Collection
```javascript
// 1. Upload your artwork to IPFS/Arweave
// 2. Ensure metadata follows ERC721 standard
// 3. baseURI should end with "/" e.g., "ipfs://QmXXX/"
// 4. Token metadata will be at: baseURI + tokenId (e.g., ipfs://QmXXX/1)

// License types enum (0-5)
const LICENSE_TYPES = {
  PUBLIC: 0,              // CC0 - Public Domain
  EXCLUSIVE: 1,           // Full exclusive commercial rights
  COMMERCIAL: 2,          // Commercial use allowed
  COMMERCIAL_NO_HATE: 3,  // Commercial use, no hate speech
  PERSONAL: 4,            // Personal use only
  PERSONAL_NO_HATE: 5     // Personal use, no hate speech
};

// Token type enum (0-1)
const TOKEN_TYPES = {
  ERC721: 0,
  ERC1155: 1
};
```

#### Step 2: Create Your ERC721 Collection
```javascript

   const LAUNCHPAD_ADDRESS = "0x22797574900038d794234B4fBE0446288ee46c91";

  const launchpad = new ethers.Contract(LAUNCHPAD_ADDRESS, LAUNCHPAD_ABI, signer);
  
  // Check platform fee
  const platformFee = await launchpad.platformFee();
  const isAuthorized = await launchpad.authorizedCreators(signer.address);
  
  
  // Configure your collection
  const params = {
    name: "My NFT Collection",
    symbol: "MNFT",
    maxSupply: 10000,              // 0 for unlimited
    baseURI: "ipfs://YOUR_CID/",   // Must end with /
    royaltyFee: 500,               // 500 = 5% (in basis points, max 10000)
    licenseVersion: LICENSE_TYPES.PUBLIC,
    tokenType: TOKEN_TYPES.ERC721
  };
  

   launchpad.createLaunch(
      params.name,
      params.symbol,
      params.maxSupply,
      params.baseURI,
      params.royaltyFee,
      params.licenseVersion,
      params.tokenType,
      {
        value: isAuthorized ? 0 : platformFee
      }
    );
```

#### Step 3: Mint Your ERC721 Tokens
```javascript
  const erc721 = new ethers.Contract(tokenContract, ERC721_ABI, signer);
    
  // Single mint
  const recipientAddress = "0x...";
  const tokenId = 1;
  
  erc721.mint(recipientAddress, tokenId);

  
  // Batch mint (more gas efficient for multiple tokens)
  const tokenIds = [2, 3, 4, 5, 6, 7, 8, 9, 10];
  erc721.batchMint(recipientAddress, tokenIds);

```

#### Step 4: Manage Your ERC721 Collection
```javascript
  const erc721 = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  
  // Update max supply (can only decrease or set if 0)
   erc721.setMaxSupply(5000);
  
  // Update base URI for reveals
  erc721.setBaseURI("ipfs://NEW_CID/");
  
  // Query collection info
  erc721.name();
  erc721.symbol();
  erc721.totalSupply();
  erc721.maxSupply();
  erc721.baseTokenURI();
  
  // Get royalty info
  const salePrice = ethers.parseEther("1"); // 1 ETH sale price
  const [receiver, royaltyAmount] = await erc721.royaltyInfo(1, salePrice);

```

---

### Complete ERC1155 Creator Flow

#### Step 1: Prepare Your Multi-Token Collection
```javascript
// 1. Upload artwork for each token type
// 2. For ERC1155, you can set custom URIs per token ID
// 3. Base URI format: "ipfs://QmXXX/{id}.json" where {id} will be replaced
```

#### Step 2: Create Your ERC1155 Collection
```javascript
async function createERC1155Collection() {
  const launchpad = new ethers.Contract(LAUNCHPAD_ADDRESS, LAUNCHPAD_ABI, signer);
  
  // Check platform fee
  const platformFee = await launchpad.platformFee();
  const isAuthorized = await launchpad.authorizedCreators(signer.address);
  
  // Configure your collection
  const params = {
    name: "My Gaming Items",
    symbol: "MGI",
    maxSupply: 0,                   // 0 for unlimited (applied to token ID 0 initially)
    baseURI: "ipfs://YOUR_CID/{id}.json",
    royaltyFee: 750,                // 7.5%
    licenseVersion: LICENSE_TYPES.COMMERCIAL,
    tokenType: TOKEN_TYPES.ERC1155
  };
  
 launchpad.createLaunch(
      params.name,
      params.symbol,
      params.maxSupply,
      params.baseURI,
      params.royaltyFee,
      params.licenseVersion,
      params.tokenType,
      {
        value: isAuthorized ? 0 : platformFee
      }
    );

}
```

#### Step 3: Mint Your ERC1155 Tokens
```javascript
  const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
  
  const recipientAddress = "0x...";
  const data = "0x"; // Empty bytes data
  
  // Single mint - mint 100 of token ID 0
  erc1155.mint(recipientAddress, 0, 100, data);

  
  // Batch mint - mint multiple token types at once
  const tokenIds = [1, 2, 3];
  const amounts = [50, 75, 100];
  
  rc1155.batchMint(recipientAddress,tokenIds, amounts,data);
  
```

#### Step 4: Manage Your ERC1155 Collection
```javascript

  const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
  
  // Set max supply for specific token ID
   erc1155.setMaxSupply(1, 1000); // Token ID 1 max: 1000
  
  // Set custom URI for specific token ID
   erc1155.setTokenURI(1, "ipfs://CUSTOM_CID/special.json");
  
  // Query token info
  erc1155.totalSupply(0);
  erc1155.maxSupply(1);
  erc1155.uri(1);
  
  // Get balance for an address
  erc1155.balanceOf(signer.address, 0);
  
  // Batch balance query
  const accounts = [signer.address, signer.address];
  const tokenIds = [0, 1];
  erc1155.balanceOfBatch(accounts, tokenIds);
  
```

---

## Core Workflows

### 1. Querying Launch Information

```javascript
  let launch = launchpad.getLaunchInfo(launchId);
  
  return {
    tokenType: launch.tokenType === 0 ? 'ERC721' : 'ERC1155',
    tokenContract: launch.tokenContract,
    creator: launch.creator,
    maxSupply: launch.maxSupply.toString(),
    baseURI: launch.baseURI,
    royaltyFee: launch.royaltyFee,
    licenseVersion: launch.licenseVersion
  };

// Get all ERC721 collections by creator
 launchpad.getERC721sByCreator(creatorAddress);


// Get all ERC1155 collections by creator
 launchpad.getERC1155sByCreator(creatorAddress);

```

### 3. Royalty Information (ERC2981)

```javascript
// Query royalty info for both ERC721 and ERC1155
 token.royaltyInfo(tokenId, salePrice);
    
```

### 4. License Information

```javascript

  token.getLicenseURI();
  token.getLicenseName();
  

// License name mappings
const LICENSE_NAMES = {
  0: "CC0 (Public Domain)",
  1: "Exclusive",
  2: "Commercial",
  3: "Commercial - No Hate",
  4: "Personal",
  5: "Personal - No Hate"
};
```

## Function Reference

### FractalLaunchpad Functions

#### Write Functions (Require Transaction)

| # | Function | Selector | Parameters | Description | Fee Required | Access |
|---|----------|----------|-----------|-------------|--------------|--------|
| 1 | `createLaunch` | 0x2ccf8879 | string, string, uint256, string, uint96, uint8, uint8 | Create new collection | Yes (unless authorized) | Anyone |
| 2 | `renounceOwnership` | 0x715018a6 | - | Renounce ownership | No | Owner only |
| 3 | `setAuthorizedCreator` | 0xe1434f4e | address, bool | Authorize/revoke creator | No | Owner only |
| 4 | `setFeeRecipient` | 0xe74b981b | address | Update fee recipient | No | Owner only |
| 5 | `setPlatformFee` | 0x12e8e2c3 | uint256 | Update platform fee | No | Owner only |
| 6 | `transferOwnership` | 0xf2fde38b | address | Transfer ownership | No | Owner only |
| 7 | `withdrawLockedFunds` | 0x0f7624ae | - | Withdraw balance | No | Owner only |

#### Read Functions (No Transaction)

| # | Function | Selector | Parameters | Returns | Description |
|---|----------|----------|-----------|---------|-------------|
| 1 | `ERC1155_IMPLEMENTATION` | 0xde7b604e | - | address | ERC1155 implementation address |
| 2 | `ERC721_IMPLEMENTATION` | 0xed307d65 | - | address | ERC721 implementation address |
| 3 | `allERC1155s` | 0x1ac4e43c | uint256 | address | All ERC1155 contracts by index |
| 4 | `allERC721s` | 0xa0ebd2c7 | uint256 | address | All ERC721 contracts by index |
| 5 | `authorizedCreators` | 0xc695502a | address | bool | Check if creator is authorized |
| 6 | `creatorToERC1155s` | 0x2468e189 | address, uint256 | address | Creator's ERC1155 at index |
| 7 | `creatorToERC721s` | 0xb9aa6dc4 | address, uint256 | address | Creator's ERC721 at index |
| 8 | `feeRecipient` | 0x46904840 | - | address | Fee recipient address |
| 9 | `getERC1155sByCreator` | 0x0fe2ea5d | address | address[] | All ERC1155s by creator |
| 10 | `getERC721sByCreator` | 0x3188e9a0 | address | address[] | All ERC721s by creator |
| 11 | `getLaunchInfo` | 0x02029a39 | uint256 | LaunchConfig | Launch configuration struct |
| 12 | `isERC1155Clone` | 0x80ecca2a | address | bool | Check if ERC1155 clone |
| 13 | `isERC721Clone` | 0x6c633325 | address | bool | Check if ERC721 clone |
| 14 | `launches` | 0x7b443a76 | uint256 | LaunchConfig | Launch config by ID |
| 15 | `nextLaunchId` | 0x979bd9cc | - | uint256 | Next launch ID |
| 16 | `nftFactory` | 0xd63843cd | - | address | MinimalProxy factory address |
| 17 | `owner` | 0x8da5cb5b | - | address | Contract owner |
| 18 | `platformFee` | 0x26232a2e | - | uint256 | Current platform fee |

### MinimalProxy Factory Functions

The Factory contract is used internally by the Launchpad but can also be called directly for advanced use cases.

#### Write Functions (Require Transaction)

| # | Function | Selector | Parameters | Description | Access |
|---|----------|----------|-----------|-------------|--------|
| 1 | `createClone` | 0xf50c48ab | address, string, string, uint256, string, address, uint96, uint8 | Create new minimal proxy clone | Anyone |

#### Read Functions (No Transaction)

| # | Function | Selector | Parameters | Returns | Description |
|---|----------|----------|-----------|---------|-------------|
| 1 | `allClonedContracts` | 0x6c61093f | uint256 | address | Get clone at index |
| 2 | `deployerToContracts` | 0xbe9a3a36 | address, uint256 | address | Deployer's contract at index |
| 3 | `getAllCreatedAddresses` | 0x6b1dc540 | - | address[] | All clone addresses |
| 4 | `getAllProxiesByDeployer` | 0x2091186c | address | address[] | All clones by deployer |
| 5 | `getCloneAddress` | 0x7a8f0786 | uint256 | address | Clone address at index |
| 6 | `getCurrentIndex` | 0x0d9005ae | - | uint256 | Total clones created |
| 7 | `isClone` | 0x43b66dac | address, address | bool | Check if clone of implementation |



### FractalERC721 Functions

#### Write Functions (Require Transaction)

| # | Function | Selector | Parameters | Description | Access |
|---|----------|----------|-----------|-------------|--------|
| 1 | `approve` | 0x095ea7b3 | address, uint256 | Approve address to transfer token | Token owner/approved |
| 2 | `batchMint` | 0x4684d7e9 | address, uint256[] | Mint multiple tokens | Owner only |
| 3 | `burn` | 0x42966c68 | uint256 | Burn token | Owner or approved |
| 4 | `initialize` | 0x76742810 | string, string, uint256, string, address, uint96, uint8 | Initialize proxy instance | Called once |
| 5 | `mint` | 0x40c10f19 | address, uint256 | Mint single token | Owner only |
| 6 | `renounceOwnership` | 0x715018a6 | - | Renounce ownership | Owner only |
| 7 | `safeTransferFrom` | 0x42842e0e | address, address, uint256 | Safe transfer token | Owner or approved |
| 8 | `safeTransferFrom` | 0xb88d4fde | address, address, uint256, bytes | Safe transfer with data | Owner or approved |
| 9 | `setApprovalForAll` | 0xa22cb465 | address, bool | Approve operator for all | Token owner |
| 10 | `setBaseURI` | 0x55f804b3 | string | Update base URI | Owner only |
| 11 | `setMaxSupply` | 0x6f8b44b0 | uint256 | Update max supply | Owner only |
| 12 | `transferFrom` | 0x23b872dd | address, address, uint256 | Transfer token | Owner or approved |
| 13 | `transferOwnership` | 0xf2fde38b | address | Transfer ownership | Owner only |
| 14 | `upgradeToAndCall` | 0x4f1ef286 | address, bytes | Upgrade implementation | Owner only |

#### Read Functions (No Transaction)

| # | Function | Selector | Parameters | Returns | Description |
|---|----------|----------|-----------|---------|-------------|
| 1 | `UPGRADE_INTERFACE_VERSION` | 0xad3cb1cc | - | string | UUPS interface version |
| 2 | `balanceOf` | 0x70a08231 | address | uint256 | Token count for owner |
| 3 | `baseTokenURI` | 0xd547cfb7 | - | string | Base token URI |
| 4 | `getApproved` | 0x081812fc | uint256 | address | Approved address for token |
| 5 | `getLicenseName` | 0xa341793b | - | string | License name |
| 6 | `getLicenseURI` | 0xc7db2893 | - | string | License URI |
| 7 | `isApprovedForAll` | 0xe985e9c5 | address, address | bool | Check operator approval |
| 8 | `maxSupply` | 0xd5abeb01 | - | uint256 | Maximum supply |
| 9 | `name` | 0x06fdde03 | - | string | Token name |
| 10 | `owner` | 0x8da5cb5b | - | address | Contract owner |
| 11 | `ownerOf` | 0x6352211e | uint256 | address | Token owner |
| 12 | `proxiableUUID` | 0x52d1902d | - | bytes32 | UUPS proxy UUID |
| 13 | `royaltyInfo` | 0x2a55205a | uint256, uint256 | address, uint256 | Royalty receiver & amount |
| 14 | `supportsInterface` | 0x01ffc9a7 | bytes4 | bool | Check interface support |
| 15 | `symbol` | 0x95d89b41 | - | string | Token symbol |
| 16 | `tokenURI` | 0xc87b56dd | uint256 | string | Full token URI |
| 17 | `totalSupply` | 0x18160ddd | - | uint256 | Total minted tokens |

### FractalERC1155 Functions

#### Write Functions (Require Transaction)

| # | Function | Selector | Parameters | Description | Access |
|---|----------|----------|-----------|-------------|--------|
| 1 | `batchMint` | 0xb48ab8b6 | address, uint256[], uint256[], bytes | Mint multiple token types | Owner only |
| 2 | `burn` | 0xf5298aca | address, uint256, uint256 | Burn tokens | Owner or approved |
| 3 | `burnBatch` | 0x6b20c454 | address, uint256[], uint256[] | Burn multiple token types | Owner or approved |
| 4 | `initialize` | 0x76742810 | string, string, uint256, string, address, uint96, uint8 | Initialize proxy instance | Called once |
| 5 | `mint` | 0x731133e9 | address, uint256, uint256, bytes | Mint tokens | Owner only |
| 6 | `renounceOwnership` | 0x715018a6 | - | Renounce ownership | Owner only |
| 7 | `safeBatchTransferFrom` | 0x2eb2c2d6 | address, address, uint256[], uint256[], bytes | Batch transfer safely | Owner or approved |
| 8 | `safeTransferFrom` | 0xf242432a | address, address, uint256, uint256, bytes | Safe transfer tokens | Owner or approved |
| 9 | `setApprovalForAll` | 0xa22cb465 | address, bool | Approve operator for all | Any holder |
| 10 | `setMaxSupply` | 0x37da577c | uint256, uint256 | Set max supply for token ID | Owner only |
| 11 | `setTokenURI` | 0x162094c4 | uint256, string | Set URI for token ID | Owner only |
| 12 | `transferOwnership` | 0xf2fde38b | address | Transfer ownership | Owner only |
| 13 | `upgradeToAndCall` | 0x4f1ef286 | address, bytes | Upgrade implementation | Owner only |

#### Read Functions (No Transaction)

| # | Function | Selector | Parameters | Returns | Description |
|---|----------|----------|-----------|---------|-------------|
| 1 | `UPGRADE_INTERFACE_VERSION` | 0xad3cb1cc | - | string | UUPS interface version |
| 2 | `balanceOf` | 0x00fdd58e | address, uint256 | uint256 | Balance of token ID |
| 3 | `balanceOfBatch` | 0x4e1273f4 | address[], uint256[] | uint256[] | Batch balance query |
| 4 | `getLicenseName` | 0xa341793b | - | string | License name |
| 5 | `getLicenseURI` | 0xc7db2893 | - | string | License URI |
| 6 | `isApprovedForAll` | 0xe985e9c5 | address, address | bool | Check operator approval |
| 7 | `maxSupply` | 0x869f7594 | uint256 | uint256 | Max supply of token ID |
| 8 | `name` | 0x06fdde03 | - | string | Collection name |
| 9 | `owner` | 0x8da5cb5b | - | address | Contract owner |
| 10 | `proxiableUUID` | 0x52d1902d | - | bytes32 | UUPS proxy UUID |
| 11 | `royaltyInfo` | 0x2a55205a | uint256, uint256 | address, uint256 | Royalty receiver & amount |
| 12 | `supportsInterface` | 0x01ffc9a7 | bytes4 | bool | Check interface support |
| 13 | `symbol` | 0x95d89b41 | - | string | Collection symbol |
| 14 | `tokenURIs` | 0x6c8b703f | uint256 | string | Custom token URI mapping |
| 15 | `totalSupply` | 0xbd85b039 | uint256 | uint256 | Total supply of token ID |
| 16 | `uri` | 0x0e89341c | uint256 | string | Token URI (custom or base) |

---

## Resources

- **Blockscout Explorer**: https://base-sepolia.blockscout.com
- **Base Sepolia Faucet**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Ethers.js Docs**: https://docs.ethers.org/v6/
- **ERC721 Standard**: https://eips.ethereum.org/EIPS/eip-721
- **ERC1155 Standard**: https://eips.ethereum.org/EIPS/eip-1155
- **ERC2981 (Royalties)**: https://eips.ethereum.org/EIPS/eip-2981

