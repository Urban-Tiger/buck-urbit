// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "forge-std/Script.sol";
import "../contracts/UrbitToken.sol";
import "../contracts/UstarToken.sol";
import "../contracts/UrbitVault.sol";
import "../contracts/mocks/MockAzimuth.sol";
import "../contracts/mocks/MockEcliptic.sol";

/**
 * @title DeployLocal
 * @notice Forge deploy script for local anvil testing.
 *         Uses MockAzimuth + MockEcliptic (0.8.20, Forge-compatible).
 *         No env vars needed — uses default anvil key.
 *
 * Usage:
 *   anvil                  # in one terminal
 *   forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
 */
contract DeployLocal is Script {
    // Default anvil private key #0
    uint256 constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        vm.startBroadcast(ANVIL_KEY);

        MockAzimuth azimuth = new MockAzimuth();
        MockEcliptic ecliptic = new MockEcliptic();

        azimuth.setContractOwner(address(ecliptic));

        UrbitToken urbitToken = new UrbitToken();
        UstarToken ustarToken = new UstarToken();
        UrbitVault vault = new UrbitVault(
            address(azimuth),
            address(urbitToken),
            address(ustarToken),
            false
        );

        urbitToken.transferOwnership(address(vault));
        ustarToken.transferOwnership(address(vault));

        vm.stopBroadcast();

        console.log("MockAzimuth: ", address(azimuth));
        console.log("MockEcliptic:", address(ecliptic));
        console.log("UrbitToken:  ", address(urbitToken));
        console.log("UstarToken:  ", address(ustarToken));
        console.log("UrbitVault:  ", address(vault));
    }
}
