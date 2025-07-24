// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAzimuth {
    mapping(uint32 => uint8) public pointSizes;
    mapping(uint32 => bool) public virginStars;
    mapping(uint32 => bool) public linkedPoints;
    mapping(uint32 => address) public owners;
    mapping(uint32 => address) public spawnProxies;
    address public contractOwner; // Contract owner (ecliptic address)

    function setPointSize(uint32 _point, uint8 _size) external {
        pointSizes[_point] = _size;
    }

    function setVirginStar(uint32 _point, bool _isVirgin) external {
        virginStars[_point] = _isVirgin;
        linkedPoints[_point] = !_isVirgin;
    }

    function setOwner(uint32 _point, address _owner) external {
        owners[_point] = _owner;
    }

    function hasBeenLinked(uint32 _point) external view returns (bool result) {
        return linkedPoints[_point];
    }

    function getKeys(uint32 _point) external view returns (
        bytes32 crypt,
        bytes32 auth,
        uint32 suite,
        uint32 revision
    ) {
        if (virginStars[_point]) {
            return (bytes32(0), bytes32(0), 0, 0);
        } else {
            return (bytes32(uint256(1)), bytes32(uint256(2)), 1, 1);
        }
    }

    function points(uint32 _point) external view returns (
        bytes32 encryptionKey,
        bytes32 authenticationKey,
        bool hasSponsor,
        bool active,
        bool escapeRequested,
        uint32 sponsor,
        uint32 escapeRequestedTo,
        uint32 cryptoSuiteVersion,
        uint32 keyRevisionNumber,
        uint32 continuityNumber
    ) {
        if (virginStars[_point]) {
            return (bytes32(0), bytes32(0), false, false, false, 0, 0, 0, 0, 0);
        } else {
            return (bytes32(uint256(1)), bytes32(uint256(2)), false, true, false, 0, 0, 1, 1, 0);
        }
    }

    function getPointSize(uint32 _point) external view returns (uint8 _size) {
        return pointSizes[_point];
    }

    function getOwner(uint32 _point) external view returns (address pointOwner) {
        return owners[_point];
    }

    function setSpawnProxy(uint32 _point, address _proxy) external {
        spawnProxies[_point] = _proxy;
    }

    function getSpawnProxy(uint32 _point) external view returns (address spawnProxy) {
        return spawnProxies[_point];
    }

    function setContractOwner(address _owner) external {
        contractOwner = _owner;
    }

    function owner() external view returns (address) {
        return contractOwner;
    }
}