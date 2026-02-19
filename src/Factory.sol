// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LicenseVersion} from "./a16z/CantBeEvilUpgradeable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

contract ProxyFactory is AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    // Custom errors
    error InvalidImplementation();
    error ImplementationHasNoCode();

    mapping(address => address[]) public deployerToContracts;
    address[] public allProxyContracts;
    mapping(address => address) public proxyToImplementation;

    constructor() {
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Creates an ERC1967 proxy pointing to the implementation contract.
     * @param _implementationContract The address of the implementation contract.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _maxSupply The maximum supply of the token.
     * @param _baseURI The base URI for the token metadata.
     * @param _owner The owner of the proxy contract.
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
    ) external onlyRole(CREATOR_ROLE) returns (address) {
        if (_implementationContract == address(0)) revert InvalidImplementation();
        if (_implementationContract.code.length == 0) revert ImplementationHasNoCode();

        bytes memory initData = abi.encodeWithSelector(
            IFractalLaunchpad.initialize.selector,
            _name,
            _symbol,
            _maxSupply,
            _baseURI,
            _owner,
            _royaltyFee,
            _licenseVersion
        );

        ERC1967Proxy proxy = new ERC1967Proxy(_implementationContract, initData);
        address proxyAddr = address(proxy);

        deployerToContracts[msg.sender].push(proxyAddr);
        allProxyContracts.push(proxyAddr);
        proxyToImplementation[proxyAddr] = _implementationContract;

        return proxyAddr;
    }

    /**
     * @dev Returns the proxy contract address at the specified index.
     */
    function getCloneAddress(uint256 _index) external view returns (address) {
        return allProxyContracts[_index];
    }

    /**
     * @dev Returns the current number of deployed proxies.
     */
    function getCurrentIndex() external view returns (uint256) {
        return allProxyContracts.length;
    }

    /**
     * @dev Checks if a given address was deployed as a proxy of a specific implementation.
     * @param _implementationContract The address of the implementation contract.
     * @param _query The address to check.
     */
    function isClone(address _implementationContract, address _query) external view returns (bool) {
        return proxyToImplementation[_query] == _implementationContract;
    }

    /**
     * @dev Returns all created proxy contract addresses.
     */
    function getAllCreatedAddresses() external view returns (address[] memory) {
        return allProxyContracts;
    }

    /**
     * @dev Returns all proxy contract addresses created by a specific deployer.
     * @param _deployerAddr The address of the deployer whose proxies are to be retrieved.
     */
    function getAllProxiesByDeployer(address _deployerAddr) external view returns (address[] memory) {
        return deployerToContracts[_deployerAddr];
    }
}
