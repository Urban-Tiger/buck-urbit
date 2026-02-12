// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../contracts/UrbitVault.sol";
import "../../contracts/UrbitToken.sol";
import "../../contracts/UstarToken.sol";
import "../../contracts/mocks/MockAzimuth.sol";
import "../../contracts/mocks/MockEcliptic.sol";

/**
 * @title VaultHandler
 * @notice Handler contract that exposes bounded actions for invariant testing.
 *         Foundry calls random functions on this contract with random inputs.
 */
contract VaultHandler is Test {
    UrbitVault public vault;
    UrbitToken public urbitToken;
    UstarToken public ustarToken;
    MockAzimuth public azimuth;
    MockEcliptic public ecliptic;

    uint32[] public depositedStars;
    uint256 public depositCount;

    address public actor;

    constructor(
        UrbitVault _vault,
        UrbitToken _urbitToken,
        UstarToken _ustarToken,
        MockAzimuth _azimuth,
        MockEcliptic _ecliptic,
        address _actor
    ) {
        vault = _vault;
        urbitToken = _urbitToken;
        ustarToken = _ustarToken;
        azimuth = _azimuth;
        ecliptic = _ecliptic;
        actor = _actor;
    }

    function deposit(uint32 starId) external {
        // Bound to valid star range (256–65535)
        starId = uint32(bound(uint256(starId), 256, 65535));

        // Skip if already deposited in vault
        if (vault.depositedStars(starId)) return;

        // Configure as virgin star
        azimuth.setPointSize(starId, 1);
        azimuth.setVirginStar(starId, true);

        // Only mint if not already minted
        try ecliptic.ownerOf(starId) {
            return;
        } catch {
            ecliptic.mint(actor, starId);
        }

        vm.startPrank(actor);
        ecliptic.approve(address(vault), starId);
        vault.depositStar(starId);
        vm.stopPrank();

        depositedStars.push(starId);
        depositCount++;
    }

    function redeem(uint256 index) external {
        if (depositCount == 0) return;

        // Find a star that's actually deposited
        index = bound(index, 0, depositedStars.length - 1);
        uint32 starId = depositedStars[index];
        if (!vault.depositedStars(starId)) return;

        vm.startPrank(actor);
        urbitToken.approve(address(vault), 65535 * 1e18);
        ustarToken.approve(address(vault), 1e18);
        vault.redeemStar(starId);
        vm.stopPrank();

        depositCount--;
    }
}

/**
 * @title UrbitVaultInvariantTest
 * @notice Invariant tests verifying core protocol properties hold
 *         across random sequences of deposits and redemptions.
 */
contract UrbitVaultInvariantTest is Test {
    UrbitVault public vault;
    UrbitToken public urbitToken;
    UstarToken public ustarToken;
    MockAzimuth public azimuth;
    MockEcliptic public ecliptic;
    VaultHandler public handler;

    function setUp() public {
        address actor = makeAddr("actor");

        azimuth = new MockAzimuth();
        ecliptic = new MockEcliptic();
        urbitToken = new UrbitToken();
        ustarToken = new UstarToken();

        azimuth.setContractOwner(address(ecliptic));

        vault = new UrbitVault(
            address(azimuth),
            address(urbitToken),
            address(ustarToken)
        );

        urbitToken.transferOwnership(address(vault));
        ustarToken.transferOwnership(address(vault));

        handler = new VaultHandler(
            vault, urbitToken, ustarToken, azimuth, ecliptic, actor
        );

        targetContract(address(handler));
    }

    /// @notice URBIT total supply == depositCount * 65535 * 1e18
    function invariant_urbitSupplyMatchesDeposits() public view {
        assertEq(
            urbitToken.totalSupply(),
            handler.depositCount() * 65535 * 1e18
        );
    }

    /// @notice USTAR total supply == depositCount * 1e18
    function invariant_ustarSupplyMatchesDeposits() public view {
        assertEq(
            ustarToken.totalSupply(),
            handler.depositCount() * 1e18
        );
    }

    /// @notice URBIT:USTAR supply ratio is always 65535:1
    function invariant_tokenSupplyRatio() public view {
        uint256 urbitSupply = urbitToken.totalSupply();
        uint256 ustarSupply = ustarToken.totalSupply();

        if (ustarSupply == 0) {
            assertEq(urbitSupply, 0);
        } else {
            assertEq(urbitSupply, ustarSupply * 65535);
        }
    }

    /// @notice Actor's token balance never exceeds total supply
    function invariant_balanceNeverExceedsSupply() public view {
        assertLe(urbitToken.balanceOf(handler.actor()), urbitToken.totalSupply());
        assertLe(ustarToken.balanceOf(handler.actor()), ustarToken.totalSupply());
    }
}
