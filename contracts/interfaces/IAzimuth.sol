// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IAzimuth {
    enum Size {
        Galaxy, // = 0
        Star,   // = 1
        Planet  // = 2
    }

    function hasBeenLinked(uint32 _point) external view returns (bool result);
    function getKeys(
        uint32 _point
    )
        external
        view
        returns (bytes32 crypt, bytes32 auth, uint32 suite, uint32 revision);
    function points(
        uint32 _point
    )
        external
        view
        returns (
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
        );
    function getPointSize(uint32 _point) external pure returns (uint8 _size);
    function getOwner(uint32 _point) external view returns (address owner);
    function getSpawnProxy(
        uint32 _point
    ) external view returns (address spawnProxy);
    function owner() external view returns (address);
}
