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

## Core Workflows

### 1. Creating an ERC721 Collection

This is the most common workflow for launching an NFT collection.

```javascript
import { ethers } from 'ethers';

// Contract setup
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const launchpad = new ethers.Contract(CONTRACTS.LAUNCHPAD, LAUNCHPAD_ABI, signer);

// Get platform fee
const platformFee = await launchpad.platformFee();

// Check if user is authorized (no fee required)
const isAuthorized = await launchpad.authorizedCreators(userAddress);

// License types enum (0-5)
const LICENSE_TYPES = {
  PUBLIC: 0,
  EXCLUSIVE: 1,
  COMMERCIAL: 2,
  COMMERCIAL_NO_HATE: 3,
  PERSONAL: 4,
  PERSONAL_NO_HATE: 5
};

// Token type enum (0-1)
const TOKEN_TYPES = {
  ERC721: 0,
  ERC1155: 1
};

// Create ERC721 launch
async function createERC721Launch() {
  const params = {
    name: "My NFT Collection",
    symbol: "MNFT",
    maxSupply: 10000,              // 0 for unlimited
    baseURI: "ipfs://YOUR_CID/",   // Must end with /
    royaltyFee: 500,                // 500 = 5% (in basis points)
    licenseVersion: LICENSE_TYPES.PUBLIC,
    tokenType: TOKEN_TYPES.ERC721
  };

}
```

### 2. Creating an ERC1155 Collection

```javascript
async function createERC1155Launch() {
  const params = {
    name: "My Multi-Token Collection",
    symbol: "MMTC",
    maxSupply: 1000,                // Max for token ID 0 (0 for unlimited)
    baseURI: "ipfs://YOUR_CID/",
    royaltyFee: 750,                 // 7.5%
    licenseVersion: LICENSE_TYPES.COMMERCIAL,
    tokenType: TOKEN_TYPES.ERC1155
  };
}
```

### 3. Minting Tokens (After Launch)

Once a collection is created, the creator (owner) can mint tokens.

#### ERC721 Minting

```javascript
// Get the deployed token contract
const erc721 = new ethers.Contract(tokenContract, ERC721_ABI, signer);

// Single mint
async function mintERC721(to, tokenId) {
  const tx = await erc721.mint(to, tokenId);
  await tx.wait();
  console.log(`Minted token #${tokenId} to ${to}`);
}

// Batch mint (more gas efficient)
async function batchMintERC721(to, tokenIds) {
  const tx = await erc721.batchMint(to, tokenIds);
  await tx.wait();
  console.log(`Minted ${tokenIds.length} tokens to ${to}`);
}

// Example usage
await mintERC721(userAddress, 1);
await batchMintERC721(userAddress, [2, 3, 4, 5, 6]);
```

#### ERC1155 Minting

```javascript
const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);

// Single mint
async function mintERC1155(to, tokenId, amount) {
  const data = "0x"; // Empty bytes data
  const tx = await erc1155.mint(to, tokenId, amount, data);
  await tx.wait();
  console.log(`Minted ${amount} of token #${tokenId} to ${to}`);
}

// Batch mint
async function batchMintERC1155(to, tokenIds, amounts) {
  const data = "0x";
  const tx = await erc1155.batchMint(to, tokenIds, amounts, data);
  await tx.wait();
  console.log(`Batch minted tokens to ${to}`);
}

// Example usage
await mintERC1155(userAddress, 0, 10);  // Mint 10 of token ID 0
await batchMintERC1155(
  userAddress,
  [1, 2, 3],      // Token IDs
  [5, 10, 15]     // Amounts
);
```

### 4. Querying Launch Information

```javascript
// Get launch details by ID
async function getLaunchInfo(launchId) {
  const launch = await launchpad.getLaunchInfo(launchId);
  
  return {
    tokenType: launch.tokenType === 0 ? 'ERC721' : 'ERC1155',
    tokenContract: launch.tokenContract,
    creator: launch.creator,
    maxSupply: launch.maxSupply.toString(),
    baseURI: launch.baseURI,
    royaltyFee: launch.royaltyFee,
    licenseVersion: launch.licenseVersion
  };
}

// Get all ERC721 collections by creator
async function getCreatorERC721s(creatorAddress) {
  const collections = await launchpad.getERC721sByCreator(creatorAddress);
  return collections;
}

// Get all ERC1155 collections by creator
async function getCreatorERC1155s(creatorAddress) {
  const collections = await launchpad.getERC1155sByCreator(creatorAddress);
  return collections;
}

// Example usage
const myLaunch = await getLaunchInfo(0);
const myERC721s = await getCreatorERC721s(userAddress);
const myERC1155s = await getCreatorERC1155s(userAddress);
```

### 5. Using the Factory Contract Directly

While the Launchpad handles most use cases, you can query the Factory for additional information:

```javascript
const factory = new ethers.Contract(CONTRACTS.FACTORY, FACTORY_ABI, provider);

// Get all contracts ever created through the factory
async function getAllClones() {
  const clones = await factory.getAllCreatedAddresses();
  console.log(`Total clones created: ${clones.length}`);
  return clones;
}

// Get contracts created by a specific deployer
// Note: The Launchpad is typically the deployer
async function getClonesbyDeployer(deployerAddress) {
  const clones = await factory.getAllProxiesByDeployer(deployerAddress);
  return clones;
}

// Verify if a contract is a legitimate clone
async function verifyClone(tokenContract, isERC721) {
  const implementation = isERC721 
    ? CONTRACTS.ERC721_IMPLEMENTATION 
    : CONTRACTS.ERC1155_IMPLEMENTATION;
  
  const isValid = await factory.isClone(implementation, tokenContract);
  
  if (!isValid) {
    console.warn("Warning: This contract is not an official clone!");
  }
  
  return isValid;
}

// Get total number of clones
async function getTotalClones() {
  const count = await factory.getCurrentIndex();
  return count;
}

// Example usage
const allClones = await getAllClones();
const launchpadClones = await getClonesbyDeployer(CONTRACTS.LAUNCHPAD);
const isLegitimate = await verifyClone(tokenContract, true);
const totalCount = await getTotalClones();

console.log({
  totalClones: totalCount.toString(),
  allClones,
  launchpadClones,
  isLegitimate
});
```

### 6. Token Operations

#### Setting Max Supply (ERC721)

```javascript
async function setERC721MaxSupply(tokenContract, newMaxSupply) {
  const erc721 = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  const tx = await erc721.setMaxSupply(newMaxSupply);
  await tx.wait();
}
```

#### Setting Max Supply (ERC1155 - per token ID)

```javascript
async function setERC1155MaxSupply(tokenContract, tokenId, newMaxSupply) {
  const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
  const tx = await erc1155.setMaxSupply(tokenId, newMaxSupply);
  await tx.wait();
}
```

#### Setting Base URI (ERC721)

```javascript
async function setERC721BaseURI(tokenContract, newBaseURI) {
  const erc721 = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  const tx = await erc721.setBaseURI(newBaseURI);
  await tx.wait();
}
```

#### Setting Token URI (ERC1155 - per token ID)

```javascript
async function setERC1155TokenURI(tokenContract, tokenId, uri) {
  const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
  const tx = await erc1155.setTokenURI(tokenId, uri);
  await tx.wait();
}
```

#### Burning Tokens

```javascript
// Burn ERC721
async function burnERC721(tokenContract, tokenId) {
  const erc721 = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  const tx = await erc721.burn(tokenId);
  await tx.wait();
}

// Burn ERC1155
async function burnERC1155(tokenContract, from, tokenId, amount) {
  const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
  const tx = await erc1155.burn(from, tokenId, amount);
  await tx.wait();
}

// Batch burn ERC1155
async function batchBurnERC1155(tokenContract, from, tokenIds, amounts) {
  const erc1155 = new ethers.Contract(tokenContract, ERC1155_ABI, signer);
  const tx = await erc1155.burnBatch(from, tokenIds, amounts);
  await tx.wait();
}
```

### 7. Royalty Information (ERC2981)

```javascript
// Get royalty info for a sale
async function getRoyaltyInfo(tokenContract, tokenId, salePrice) {
  const token = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  const [receiver, royaltyAmount] = await token.royaltyInfo(tokenId, salePrice);
  
  return {
    receiver,
    royaltyAmount: royaltyAmount.toString(),
    percentage: (Number(royaltyAmount) / Number(salePrice)) * 100
  };
}

// Example: Get royalty for a 1 ETH sale
const salePrice = ethers.parseEther("1.0");
const royalty = await getRoyaltyInfo(tokenContract, 1, salePrice);
console.log(`Royalty: ${ethers.formatEther(royalty.royaltyAmount)} ETH (${royalty.percentage}%)`);
```

### 8. License Information

```javascript
// Get license URI
async function getLicenseURI(tokenContract) {
  const token = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  const licenseURI = await token.getLicenseURI();
  return licenseURI;
}

// Get license name
async function getLicenseName(tokenContract) {
  const token = new ethers.Contract(tokenContract, ERC721_ABI, signer);
  const licenseName = await token.getLicenseName();
  return licenseName;
}

// Example usage
const licenseURI = await getLicenseURI(tokenContract);
const licenseName = await getLicenseName(tokenContract);
console.log(`License: ${licenseName} - ${licenseURI}`);
```

---

## Function Reference

### FractalLaunchpad Functions

#### Write Functions (Require Transaction)

| Function | Parameters | Returns | Description | Fee Required |
|----------|-----------|---------|-------------|--------------|
| `createLaunch` | name, symbol, maxSupply, baseURI, royaltyFee, licenseVersion, tokenType | launchId | Create new collection | Yes (unless authorized) |
| `setAuthorizedCreator` | creator, authorized | - | Authorize creator (owner only) | No |
| `setPlatformFee` | fee | - | Update platform fee (owner only) | No |
| `setFeeRecipient` | recipient | - | Update fee recipient (owner only) | No |
| `withdrawLockedFunds` | - | - | Withdraw contract balance (owner only) | No |

#### Read Functions (No Transaction)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `getLaunchInfo` | launchId | LaunchConfig | Get launch configuration |
| `getERC721sByCreator` | creator | address[] | Get creator's ERC721 collections |
| `getERC1155sByCreator` | creator | address[] | Get creator's ERC1155 collections |
| `isERC721Clone` | query | bool | Check if address is ERC721 clone |
| `isERC1155Clone` | query | bool | Check if address is ERC1155 clone |
| `platformFee` | - | uint256 | Current platform fee |
| `feeRecipient` | - | address | Fee recipient address |
| `nextLaunchId` | - | uint256 | Next launch ID to be assigned |
| `authorizedCreators` | address | bool | Check if creator is authorized |
| `launches` | launchId | LaunchConfig | Mapping to get launch config |
| `creatorToERC721s` | creator | address[] | Mapping of creator to their ERC721s |
| `creatorToERC1155s` | creator | address[] | Mapping of creator to their ERC1155s |
| `allERC721s` | index | address | Array of all ERC721 contracts |
| `allERC1155s` | index | address | Array of all ERC1155 contracts |
| `ERC721_IMPLEMENTATION` | - | address | ERC721 implementation address |
| `ERC1155_IMPLEMENTATION` | - | address | ERC1155 implementation address |
| `nftFactory` | - | address | MinimalProxy factory address |
| `owner` | - | address | Contract owner (from Ownable) |

### MinimalProxy Factory Functions

The Factory contract is used internally by the Launchpad but can also be called directly for advanced use cases.

#### Read Functions (No Transaction)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `getCloneAddress` | index | address | Get clone address at specific index |
| `getCurrentIndex` | - | uint256 | Get total number of clones created |
| `isClone` | implementation, query | bool | Check if address is a clone of implementation |
| `getAllCreatedAddresses` | - | address[] | Get all clone addresses |
| `getAllProxiesByDeployer` | deployerAddr | address[] | Get all proxies created by deployer |
| `deployerToContracts` | deployer | address[] | Mapping of deployer to their contracts |



### FractalERC721 Functions

#### Write Functions

| Function | Parameters | Description | Access |
|----------|-----------|-------------|--------|
| `mint` | to, tokenId | Mint single token | Owner only |
| `batchMint` | to, tokenIds[] | Mint multiple tokens | Owner only |
| `burn` | tokenId | Burn token | Owner or approved |
| `setMaxSupply` | maxSupply | Update max supply | Owner only |
| `setBaseURI` | baseURI | Update base URI | Owner only |
| `transferOwnership` | newOwner | Transfer ownership | Owner only |
| `renounceOwnership` | - | Renounce ownership | Owner only |
| `upgradeToAndCall` | newImplementation, data | Upgrade to new implementation | Owner only |

#### Read Functions

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `totalSupply` | - | uint256 | Total minted tokens |
| `maxSupply` | - | uint256 | Maximum supply |
| `baseTokenURI` | - | string | Base token URI |
| `tokenURI` | tokenId | string | Full token URI |
| `name` | - | string | Token name |
| `symbol` | - | string | Token symbol |
| `ownerOf` | tokenId | address | Token owner |
| `balanceOf` | owner | uint256 | Owner's token count |
| `getApproved` | tokenId | address | Approved address for token |
| `isApprovedForAll` | owner, operator | bool | Check if operator is approved |
| `royaltyInfo` | tokenId, salePrice | receiver, amount | Royalty information |
| `getLicenseURI` | - | string | License URI |
| `getLicenseName` | - | string | License name |
| `supportsInterface` | interfaceId | bool | Check interface support |
| `owner` | - | address | Contract owner |
| `proxiableUUID` | - | bytes32 | UUPS proxy UUID |

### FractalERC1155 Functions

#### Write Functions

| Function | Parameters | Description | Access |
|----------|-----------|-------------|--------|
| `mint` | to, id, amount, data | Mint tokens | Owner only |
| `batchMint` | to, ids[], amounts[], data | Mint multiple token types | Owner only |
| `burn` | from, id, amount | Burn tokens | Owner or approved |
| `burnBatch` | from, ids[], amounts[] | Burn multiple token types | Owner or approved |
| `setMaxSupply` | id, maxSupply | Set max supply for token ID | Owner only |
| `setTokenURI` | id, uri | Set URI for token ID | Owner only |
| `setApprovalForAll` | operator, approved | Approve operator for all tokens | Any holder |
| `safeTransferFrom` | from, to, id, amount, data | Transfer tokens safely | Owner or approved |
| `safeBatchTransferFrom` | from, to, ids[], amounts[], data | Batch transfer safely | Owner or approved |
| `transferOwnership` | newOwner | Transfer ownership | Owner only |
| `renounceOwnership` | - | Renounce ownership | Owner only |
| `upgradeToAndCall` | newImplementation, data | Upgrade to new implementation | Owner only |

#### Read Functions

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `name` | - | string | Token collection name |
| `symbol` | - | string | Token collection symbol |
| `totalSupply` | tokenId | uint256 | Total supply of token ID |
| `maxSupply` | tokenId | uint256 | Max supply of token ID |
| `tokenURIs` | tokenId | string | Mapping of token URIs |
| `uri` | tokenId | string | Token URI (returns custom or base) |
| `balanceOf` | owner, id | uint256 | Balance of token ID |
| `balanceOfBatch` | owners[], ids[] | uint256[] | Batch balance query |
| `isApprovedForAll` | owner, operator | bool | Check if operator approved |
| `royaltyInfo` | tokenId, salePrice | receiver, amount | Royalty information |
| `getLicenseURI` | - | string | License URI |
| `getLicenseName` | - | string | License name |
| `supportsInterface` | interfaceId | bool | Check interface support |
| `owner` | - | address | Contract owner |
| `proxiableUUID` | - | bytes32 | UUPS proxy UUID |

---

## Resources

- **Blockscout Explorer**: https://base-sepolia.blockscout.com
- **Base Sepolia Faucet**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Ethers.js Docs**: https://docs.ethers.org/v6/
- **ERC721 Standard**: https://eips.ethereum.org/EIPS/eip-721
- **ERC1155 Standard**: https://eips.ethereum.org/EIPS/eip-1155
- **ERC2981 (Royalties)**: https://eips.ethereum.org/EIPS/eip-2981

---

## Support

For questions or issues:
- Check the main README.md
- Review the test files for usage examples
- Submit issues on GitHub
