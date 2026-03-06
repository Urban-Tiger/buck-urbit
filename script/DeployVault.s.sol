// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "forge-std/Script.sol";
import "../contracts/UrbitToken.sol";
import "../contracts/UstarToken.sol";
import "../contracts/UrbitVault.sol";

/**
 * @title DeployVault
 * @notice Deploy the core vault system (UrbitToken, UstarToken, UrbitVault).
 *
 * Usage:
 *   AZIMUTH_ADDRESS=0x... forge script script/DeployVault.s.sol --rpc-url $SEPOLIA_URL --broadcast --verify
 */
contract DeployVault is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address azimuthAddress = vm.envAddress("AZIMUTH_ADDRESS");

        vm.startBroadcast(deployerKey);

        UrbitToken urbitToken = new UrbitToken();
        UstarToken ustarToken = new UstarToken();

        UrbitVault vault = new UrbitVault(
            azimuthAddress,
            address(urbitToken),
            address(ustarToken),
            true
        );

        urbitToken.transferOwnership(address(vault));
        ustarToken.transferOwnership(address(vault));

        vm.stopBroadcast();

        console.log("UrbitToken:", address(urbitToken));
        console.log("UstarToken:", address(ustarToken));
        console.log("UrbitVault:", address(vault));
        console.log("Azimuth:   ", azimuthAddress);
    }
}
