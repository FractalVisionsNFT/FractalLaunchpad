// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

    enum SavingsFrequency {Daily, Weekly, BiWeekly, Monthly}

interface IFractalLaunhchpad {
    function initialize(string memory name, string memory symbol, uint256 _maxSupply, string memory baseURI, address owner) external;
}

contract MinimalProxy {
    event ContractCreated(address indexed newThrift, uint256 position);

    mapping(uint256 => address) cloneAddresses;
    uint256 contractIndex = 1;

    mapping(address => address[]) public _deployerAddrs; //deployer => contract addressses

    address[] allClonedMultiSigContractAddresses;

    function createClone(
        address _implementationContract,
        string memory name, string memory symbol, uint256 _maxSupply, string memory baseURI, address owner ) external returns (address) {
        // convert the address to 20 bytes
        bytes20 implementationContractInBytes = bytes20(
            _implementationContract
        );

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
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )

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
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

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
        IFractalLaunhchpad(proxy).initialize( name, symbol, _maxSupply, baseURI, owner );

        cloneAddresses[contractIndex] = proxy;

        // Add the newly deployed contract address to the deployer's array
        _deployerAddrs[msg.sender].push(proxy);
        allClonedMultiSigContractAddresses.push(proxy);

        contractIndex = contractIndex + 1;

        emit ContractCreated(proxy, allClonedMultiSigContractAddresses.length);
        return proxy;
    }

    /**
     * @dev Returns the clone contract address at the specified index.
     */
    function getCloneAddress(uint256 _index) external view returns (address) {
        return cloneAddresses[_index];
    }

    /**
     * @dev Returns the current index
     */
    function getCurrentIndex() external view returns (uint256) {
        return allClonedMultiSigContractAddresses.length;
    }

    // Check if an address is a clone of a particular contract address
    function isClone(
        address _implementationContract,
        address query
    ) external view returns (bool result) {
        bytes20 implementationContractInBytes = bytes20(
            _implementationContract
        );
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000
            )
            mstore(add(clone, 0xa), implementationContractInBytes)
            mstore(
                add(clone, 0x1e),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            let other := add(clone, 0x40)
            extcodecopy(query, other, 0, 0x2d)
            result := and(
                eq(mload(clone), mload(other)),
                eq(mload(add(clone, 0xd)), mload(add(other, 0xd)))
            )
        }
    }

    function getAllCreatedAddresses() external view returns (address[] memory) {
        return allClonedMultiSigContractAddresses;
    }

    function getAllProxiesByDeployer(
        address deployerAddr
    ) external view returns (address[] memory) {
        return _deployerAddrs[deployerAddr];
    }

    

}