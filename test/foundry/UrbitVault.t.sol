// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../contracts/UrbitVault.sol";
import "../../contracts/UrbitToken.sol";
import "../../contracts/UstarToken.sol";
import "../../contracts/mocks/MockAzimuth.sol";
import "../../contracts/mocks/MockEcliptic.sol";

contract UrbitVaultTest is Test {
    event StarDeposited(uint32 indexed starId, address indexed depositor);
    event StarRedeemed(uint32 indexed starId, address indexed redeemer);

    UrbitVault public vault;
    UrbitToken public urbitToken;
    UstarToken public ustarToken;
    MockAzimuth public azimuth;
    MockEcliptic public ecliptic;

    address public user1;
    uint256 public user1Key;
    address public user2;

    uint32 constant STAR_ID = 256;
    uint32 constant STAR_ID_2 = 512;
    uint32 constant STAR_ID_3 = 768;
    uint32 constant GALAXY_ID = 1;
    uint32 constant PLANET_ID = 65792; // 256 * 256 + 256
    uint256 constant PLANETS_PER_STAR = 65535;
    uint256 constant URBIT_AMOUNT = PLANETS_PER_STAR * 1e18;
    uint256 constant USTAR_AMOUNT = 1e18;

    // ═══════════════════════════════════════════════════════════════════
    //                            SETUP
    // ═══════════════════════════════════════════════════════════════════

    function setUp() public {
        (user1, user1Key) = makeAddrAndKey("user1");
        user2 = makeAddr("user2");

        // Deploy mocks
        azimuth = new MockAzimuth();
        ecliptic = new MockEcliptic();

        // Deploy tokens
        urbitToken = new UrbitToken();
        ustarToken = new UstarToken();

        // Point azimuth at ecliptic
        azimuth.setContractOwner(address(ecliptic));

        // Deploy vault
        vault = new UrbitVault(
            address(azimuth),
            address(urbitToken),
            address(ustarToken)
        );

        // Transfer token ownership to vault
        urbitToken.transferOwnership(address(vault));
        ustarToken.transferOwnership(address(vault));

        // Configure default star
        _configureVirginStar(STAR_ID, user1);
        _configureVirginStar(STAR_ID_2, user1);
        _configureVirginStar(STAR_ID_3, user1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                           HELPERS
    // ═══════════════════════════════════════════════════════════════════

    function _configureVirginStar(uint32 starId, address starOwner) internal {
        azimuth.setPointSize(starId, 1); // Size.Star
        azimuth.setVirginStar(starId, true);
        ecliptic.mint(starOwner, starId);
    }

    function _depositStar(uint32 starId, address depositor) internal {
        vm.startPrank(depositor);
        ecliptic.approve(address(vault), starId);
        vault.depositStar(starId, depositor);
        vm.stopPrank();
    }

    function _approveTokensForRedeem(address redeemer) internal {
        vm.startPrank(redeemer);
        urbitToken.approve(address(vault), URBIT_AMOUNT);
        ustarToken.approve(address(vault), USTAR_AMOUNT);
        vm.stopPrank();
    }

    function _signPermit(
        address token,
        string memory name,
        address signer,
        uint256 signerKey,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                token
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (v, r, s) = vm.sign(signerKey, digest);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                          DEPLOYMENT
    // ═══════════════════════════════════════════════════════════════════

    function test_deployment_addresses() public view {
        assertEq(address(vault.azimuth()), address(azimuth));
        assertEq(address(vault.urbitToken()), address(urbitToken));
        assertEq(address(vault.ustarToken()), address(ustarToken));
    }

    function test_deployment_constants() public view {
        assertEq(vault.PLANETS_PER_STAR(), PLANETS_PER_STAR);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     VIRGIN STAR VALIDATION
    // ═══════════════════════════════════════════════════════════════════

    function test_isEligibleStar_virgin() public view {
        assertTrue(vault.isEligibleStar(STAR_ID));
    }

    function test_isEligibleStar_linked() public {
        azimuth.setVirginStar(STAR_ID, false);
        assertFalse(vault.isEligibleStar(STAR_ID));
    }

    function test_isEligibleStar_spawnProxy() public {
        azimuth.setSpawnProxy(STAR_ID, address(0x1111));
        assertFalse(vault.isEligibleStar(STAR_ID));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                         STAR DEPOSIT
    // ═══════════════════════════════════════════════════════════════════

    function test_depositStar_happy() public {
        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);
        vault.depositStar(STAR_ID, user1);
        vm.stopPrank();

        assertTrue(vault.depositedStars(STAR_ID));
    }

    function test_depositStar_mintsUrbit() public {
        _depositStar(STAR_ID, user1);
        assertEq(urbitToken.balanceOf(user1), URBIT_AMOUNT);
    }

    function test_depositStar_mintsUstar() public {
        _depositStar(STAR_ID, user1);
        assertEq(ustarToken.balanceOf(user1), USTAR_AMOUNT);
    }

    function test_depositStar_transfersStar() public {
        _depositStar(STAR_ID, user1);
        assertEq(ecliptic.ownerOf(STAR_ID), address(vault));
    }

    function test_depositStar_emitsEvent() public {
        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);

        vm.expectEmit(true, true, false, true);
        emit StarDeposited(STAR_ID, user1);
        vault.depositStar(STAR_ID, user1);
        vm.stopPrank();
    }

    function test_depositStar_reverts_notStar() public {
        azimuth.setPointSize(GALAXY_ID, 0); // Galaxy
        ecliptic.mint(user1, GALAXY_ID);

        vm.startPrank(user1);
        ecliptic.approve(address(vault), GALAXY_ID);

        vm.expectRevert(UrbitVault.InvalidAzimuthPoint.selector);
        vault.depositStar(GALAXY_ID, user1);
        vm.stopPrank();
    }

    function test_depositStar_reverts_planet() public {
        azimuth.setPointSize(PLANET_ID, 2); // Planet
        ecliptic.mint(user1, PLANET_ID);

        vm.startPrank(user1);
        ecliptic.approve(address(vault), PLANET_ID);

        vm.expectRevert(UrbitVault.InvalidAzimuthPoint.selector);
        vault.depositStar(PLANET_ID, user1);
        vm.stopPrank();
    }

    function test_depositStar_reverts_notVirgin() public {
        azimuth.setVirginStar(STAR_ID, false);

        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);

        vm.expectRevert(UrbitVault.StarNotVirgin.selector);
        vault.depositStar(STAR_ID, user1);
        vm.stopPrank();
    }

    function test_depositStar_reverts_spawnProxy() public {
        azimuth.setSpawnProxy(STAR_ID, address(0x1111));

        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);

        vm.expectRevert(UrbitVault.StarNotVirgin.selector);
        vault.depositStar(STAR_ID, user1);
        vm.stopPrank();
    }

    function test_depositStar_reverts_alreadyDeposited() public {
        _depositStar(STAR_ID, user1);

        vm.startPrank(user1);
        vm.expectRevert(UrbitVault.StarAlreadyDeposited.selector);
        vault.depositStar(STAR_ID, user1);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        STAR REDEMPTION
    // ═══════════════════════════════════════════════════════════════════

    function test_redeemStar_happy() public {
        _depositStar(STAR_ID, user1);
        _approveTokensForRedeem(user1);

        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertFalse(vault.depositedStars(STAR_ID));
    }

    function test_redeemStar_burnsTokens() public {
        _depositStar(STAR_ID, user1);
        _approveTokensForRedeem(user1);

        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertEq(urbitToken.balanceOf(user1), 0);
        assertEq(ustarToken.balanceOf(user1), 0);
    }

    function test_redeemStar_transfersStar() public {
        _depositStar(STAR_ID, user1);
        _approveTokensForRedeem(user1);

        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertEq(ecliptic.ownerOf(STAR_ID), user1);
    }

    function test_redeemStar_emitsEvent() public {
        _depositStar(STAR_ID, user1);
        _approveTokensForRedeem(user1);

        vm.expectEmit(true, true, false, true);
        emit StarRedeemed(STAR_ID, user1);

        vm.prank(user1);
        vault.redeemStar(STAR_ID);
    }

    function test_redeemStar_reverts_notDeposited() public {
        vm.prank(user1);
        vm.expectRevert(UrbitVault.StarNotDeposited.selector);
        vault.redeemStar(999);
    }

    function test_redeemStar_reverts_insufficientUrbit() public {
        _depositStar(STAR_ID, user1);

        // Transfer away 1 wei of URBIT so balance is insufficient
        vm.prank(user1);
        urbitToken.transfer(user2, 1);

        vm.prank(user1);
        vm.expectRevert(UrbitVault.InsufficientTokens.selector);
        vault.redeemStar(STAR_ID);
    }

    function test_redeemStar_reverts_insufficientUstar() public {
        _depositStar(STAR_ID, user1);

        // Transfer away 1 wei of USTAR so balance is insufficient
        vm.prank(user1);
        ustarToken.transfer(user2, 1);

        vm.prank(user1);
        vm.expectRevert(UrbitVault.InsufficientTokens.selector);
        vault.redeemStar(STAR_ID);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                    REDEMPTION WITH PERMIT
    // ═══════════════════════════════════════════════════════════════════

    function test_redeemStarWithPermit_happy() public {
        _depositStar(STAR_ID, user1);

        uint256 deadline = block.timestamp + 1 hours;

        (uint8 urbitV, bytes32 urbitR, bytes32 urbitS) = _signPermit(
            address(urbitToken), "Urbit Token", user1, user1Key, address(vault),
            URBIT_AMOUNT, 0, deadline
        );

        (uint8 ustarV, bytes32 ustarR, bytes32 ustarS) = _signPermit(
            address(ustarToken), "Urbit Star Token", user1, user1Key, address(vault),
            USTAR_AMOUNT, 0, deadline
        );

        vm.prank(user1);
        vault.redeemStarWithPermit(
            STAR_ID,
            deadline, urbitV, urbitR, urbitS,
            deadline, ustarV, ustarR, ustarS
        );

        assertFalse(vault.depositedStars(STAR_ID));
        assertEq(ecliptic.ownerOf(STAR_ID), user1);
        assertEq(urbitToken.balanceOf(user1), 0);
        assertEq(ustarToken.balanceOf(user1), 0);
    }

    function test_redeemStarWithPermit_emitsEvent() public {
        _depositStar(STAR_ID, user1);

        uint256 deadline = block.timestamp + 1 hours;

        (uint8 urbitV, bytes32 urbitR, bytes32 urbitS) = _signPermit(
            address(urbitToken), "Urbit Token", user1, user1Key, address(vault),
            URBIT_AMOUNT, 0, deadline
        );

        (uint8 ustarV, bytes32 ustarR, bytes32 ustarS) = _signPermit(
            address(ustarToken), "Urbit Star Token", user1, user1Key, address(vault),
            USTAR_AMOUNT, 0, deadline
        );

        vm.expectEmit(true, true, false, true);
        emit StarRedeemed(STAR_ID, user1);

        vm.prank(user1);
        vault.redeemStarWithPermit(
            STAR_ID,
            deadline, urbitV, urbitR, urbitS,
            deadline, ustarV, ustarR, ustarS
        );
    }

    function test_redeemStarWithPermit_reverts_expiredDeadline() public {
        _depositStar(STAR_ID, user1);

        uint256 deadline = block.timestamp - 1;

        (uint8 urbitV, bytes32 urbitR, bytes32 urbitS) = _signPermit(
            address(urbitToken), "Urbit Token", user1, user1Key, address(vault),
            URBIT_AMOUNT, 0, deadline
        );

        (uint8 ustarV, bytes32 ustarR, bytes32 ustarS) = _signPermit(
            address(ustarToken), "Urbit Star Token", user1, user1Key, address(vault),
            USTAR_AMOUNT, 0, deadline
        );

        vm.prank(user1);
        vm.expectRevert();
        vault.redeemStarWithPermit(
            STAR_ID,
            deadline, urbitV, urbitR, urbitS,
            deadline, ustarV, ustarR, ustarS
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    //                          EDGE CASES
    // ═══════════════════════════════════════════════════════════════════

    function test_depositRedeemRedeposit_cycle() public {
        // Deposit
        _depositStar(STAR_ID, user1);
        assertTrue(vault.depositedStars(STAR_ID));

        // Redeem
        _approveTokensForRedeem(user1);
        vm.prank(user1);
        vault.redeemStar(STAR_ID);
        assertFalse(vault.depositedStars(STAR_ID));

        // Re-deposit
        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);
        vault.depositStar(STAR_ID, user1);
        vm.stopPrank();
        assertTrue(vault.depositedStars(STAR_ID));
    }

    function test_multipleStars_deposit() public {
        _depositStar(STAR_ID, user1);
        _depositStar(STAR_ID_2, user1);

        assertTrue(vault.depositedStars(STAR_ID));
        assertTrue(vault.depositedStars(STAR_ID_2));
        assertEq(urbitToken.balanceOf(user1), URBIT_AMOUNT * 2);
        assertEq(ustarToken.balanceOf(user1), USTAR_AMOUNT * 2);
    }

    function test_selectiveRedemption() public {
        // Deposit two stars
        _depositStar(STAR_ID, user1);
        _depositStar(STAR_ID_2, user1);

        // Redeem only the first
        _approveTokensForRedeem(user1);
        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertFalse(vault.depositedStars(STAR_ID));
        assertTrue(vault.depositedStars(STAR_ID_2));
        assertEq(urbitToken.balanceOf(user1), URBIT_AMOUNT);
        assertEq(ustarToken.balanceOf(user1), USTAR_AMOUNT);
    }

}
