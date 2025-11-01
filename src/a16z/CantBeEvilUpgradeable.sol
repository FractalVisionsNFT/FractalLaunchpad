// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@a16z/contracts/licenses/ICantBeEvil.sol";

enum LicenseVersion {
    PUBLIC,
    EXCLUSIVE,
    COMMERCIAL,
    COMMERCIAL_NO_HATE,
    PERSONAL,
    PERSONAL_NO_HATE
}

abstract contract CantBeEvilUpgradeable is ERC165Upgradeable, ICantBeEvil {
    using Strings for uint;
    
    string internal constant _BASE_LICENSE_URI = "ar://zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/";
    LicenseVersion internal licenseVersion;
    
    function __CantBeEvil_init(LicenseVersion _licenseVersion) internal onlyInitializing {
        __CantBeEvil_init_unchained(_licenseVersion);
    }
    
    function __CantBeEvil_init_unchained(LicenseVersion _licenseVersion) internal onlyInitializing {
        licenseVersion = _licenseVersion;
    }

    function getLicenseURI() public view returns (string memory) {
        return string.concat(_BASE_LICENSE_URI, uint(licenseVersion).toString());
    }

    function getLicenseName() public view returns (string memory) {
        return _getLicenseVersionKeyByValue(licenseVersion);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(ICantBeEvil).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _getLicenseVersionKeyByValue(LicenseVersion _licenseVersion) internal pure returns (string memory) {
        require(uint8(_licenseVersion) <= 6);
        if (LicenseVersion.PUBLIC == _licenseVersion) return "PUBLIC";
        if (LicenseVersion.EXCLUSIVE == _licenseVersion) return "EXCLUSIVE";
        if (LicenseVersion.COMMERCIAL == _licenseVersion) return "COMMERCIAL";
        if (LicenseVersion.COMMERCIAL_NO_HATE == _licenseVersion) return "COMMERCIAL_NO_HATE";
        if (LicenseVersion.PERSONAL == _licenseVersion) return "PERSONAL";
        else return "PERSONAL_NO_HATE";
    }
}