// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/UrbitToken.sol";
import "../contracts/UstarToken.sol";
import "../contracts/UrbitVault.sol";

/**
 * @title Deploy
 * @notice Forge deploy script for mainnet/sepolia.
 *         Reads PRIVATE_KEY and AZIMUTH_ADDRESS from environment.
 *
 * Usage:
 *   forge script script/Deploy.s.sol --rpc-url $SEPOLIA_URL --broadcast --verify
 *   forge script script/Deploy.s.sol --rpc-url $MAINNET_URL --broadcast --verify
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address azimuthAddress = vm.envAddress("AZIMUTH_ADDRESS");

        vm.startBroadcast(deployerKey);

        UrbitToken urbitToken = new UrbitToken();
        UstarToken ustarToken = new UstarToken();
        UrbitVault vault = new UrbitVault(
            azimuthAddress,
            address(urbitToken),
            address(ustarToken)
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
