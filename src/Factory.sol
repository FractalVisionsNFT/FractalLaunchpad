// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LicenseVersion} from "./a16z/CantBeEvilUpgradeable.sol";

interface IFractalLaunchpad {
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner,
        uint96 _royaltyFee,
        LicenseVersion _licenseVersion
    ) external;
}

contract MinimalProxy {
    // Custom errors
    error InvalidImplementation();
    error ImplementationHasNoCode();

    mapping(address => address[]) public deployerToContracts; //deployer => contract addressses

    address[] public allClonedContracts;

    /**
     * @dev Creates a minimal proxy clone of the implementation contract.
     * @param _implementationContract The address of the implementation contract to clone.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _maxSupply The maximum supply of the token.
     * @param _baseURI The base URI for the token metadata.
     * @param _owner The owner of the cloned contract.
     * @param _royaltyFee The royalty fee in basis points (500 = 5%).
     * @param _licenseVersion The license version for the token.
     */
    function createClone(
        address _implementationContract,
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _owner,
        uint96 _royaltyFee,
        LicenseVersion _licenseVersion
    ) external returns (address) {
        if (_implementationContract == address(0)) revert InvalidImplementation();
        if (_implementationContract.code.length == 0) revert ImplementationHasNoCode();

        // convert the address to 20 bytes
        bytes20 implementationContractInBytes = bytes20(_implementationContract);

        //address to assign cloned proxy
        address proxy;

        // as stated earlier, the minimal proxy has this bytecode
        // <3d602d80600a3d3981f3363d3d373d3d3d363d73><address of implementation contract><5af43d82803e903d91602b57fd5bf3>

        // <3d602d80600a3d3981f3> == creation code which copy runtime code into memory and deploy it

        // <363d3d373d3d3d363d73> <address of implementation contract> <5af43d82803e903d91602b57fd5bf3> == runtime code that makes a delegatecall to the implentation contract

        assembly {
            /*
            reads the 32 bytes of memory starting at pointer stored in 0x40
            In solidity, the 0x40 slot in memory is special: it contains the "free memory pointer"
            which points to the end of the currently allocated memory.
            */
            let clone := mload(0x40)
            // store 32 bytes to memory starting at "clone"
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)

            /*
              |              20 bytes                |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
                                                      ^
                                                      pointer
            */
            // store 32 bytes to memory starting at "clone" + 20 bytes
            // 0x14 = 20
            mstore(add(clone, 0x14), implementationContractInBytes)

            /*
              |               20 bytes               |                 20 bytes              |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe
                                                                                              ^
                                                                                              pointer
            */
            // store 32 bytes to memory starting at "clone" + 40 bytes
            // 0x28 = 40
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

            /*
            |                 20 bytes                  |          20 bytes          |           15 bytes          |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73b<implementationContractInBytes>5af43d82803e903d91602b57fd5bf3 == 45 bytes in total
            */

            // create a new contract
            // send 0 Ether
            // code starts at pointer stored in "clone"
            // code size == 0x37 (55 bytes)
            proxy := create(0, clone, 0x37)
        }
        IFractalLaunchpad(proxy).initialize(_name, _symbol, _maxSupply, _baseURI, _owner, _royaltyFee, _licenseVersion);

        // Add the newly deployed contract address to the deployer's array
        deployerToContracts[msg.sender].push(proxy);
        allClonedContracts.push(proxy);

        return proxy;
    }

    /**
     * @dev Returns the clone contract address at the specified index.
     */
    function getCloneAddress(uint256 _index) external view returns (address) {
        return allClonedContracts[_index];
    }

    /**
     * @dev Returns the current index
     */
    function getCurrentIndex() external view returns (uint256) {
        return allClonedContracts.length;
    }
    /**
     * @dev Checks if a given address is a clone of a specific implementation contract.
     * @param _implementationContract The address of the implementation contract.
     * @param _query The address to check.
     */

    function isClone(address _implementationContract, address _query) external view returns (bool result) {
        bytes20 implementationContractInBytes = bytes20(_implementationContract);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000)
            mstore(add(clone, 0xa), implementationContractInBytes)
            mstore(add(clone, 0x1e), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

            let other := add(clone, 0x40)
            extcodecopy(_query, other, 0, 0x2d)
            result := and(eq(mload(clone), mload(other)), eq(mload(add(clone, 0xd)), mload(add(other, 0xd))))
        }
    }
    /**
     * @dev Returns all created clone contract addresses.
     */

    function getAllCreatedAddresses() external view returns (address[] memory) {
        return allClonedContracts;
    }
    /**
     * @dev Returns all proxy contract addresses created by a specific deployer.
     * @param _deployerAddr The address of the deployer whose proxies are to be retrieved.
     */

    function getAllProxiesByDeployer(address _deployerAddr) external view returns (address[] memory) {
        return deployerToContracts[_deployerAddr];
    }
}
