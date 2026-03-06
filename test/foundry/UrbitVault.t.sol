// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

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
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mocks
        azimuth = new MockAzimuth();
        ecliptic = new MockEcliptic();

        // Deploy tokens
        urbitToken = new UrbitToken();
        ustarToken = new UstarToken();

        // Point azimuth at ecliptic
        azimuth.setContractOwner(address(ecliptic));

        // Deploy vault (whitelist disabled by default for existing tests)
        vault = new UrbitVault(
            address(azimuth),
            address(urbitToken),
            address(ustarToken),
            false
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


        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertFalse(vault.depositedStars(STAR_ID));
    }

    function test_redeemStar_burnsTokens() public {
        _depositStar(STAR_ID, user1);


        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertEq(urbitToken.balanceOf(user1), 0);
        assertEq(ustarToken.balanceOf(user1), 0);
    }

    function test_redeemStar_transfersStar() public {
        _depositStar(STAR_ID, user1);


        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertEq(ecliptic.ownerOf(STAR_ID), user1);
    }

    function test_redeemStar_emitsEvent() public {
        _depositStar(STAR_ID, user1);


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
    //                          EDGE CASES
    // ═══════════════════════════════════════════════════════════════════

    function test_depositRedeemRedeposit_cycle() public {
        // Deposit
        _depositStar(STAR_ID, user1);
        assertTrue(vault.depositedStars(STAR_ID));

        // Redeem

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

        vm.prank(user1);
        vault.redeemStar(STAR_ID);

        assertFalse(vault.depositedStars(STAR_ID));
        assertTrue(vault.depositedStars(STAR_ID_2));
        assertEq(urbitToken.balanceOf(user1), URBIT_AMOUNT);
        assertEq(ustarToken.balanceOf(user1), USTAR_AMOUNT);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                          WHITELIST
    // ═══════════════════════════════════════════════════════════════════

    function test_whitelist_disabledByDefault() public view {
        assertFalse(vault.whitelistEnabled());
    }

    function test_whitelist_depositWorksWhenDisabled() public {
        // Whitelist is off — anyone can deposit
        _depositStar(STAR_ID, user1);
        assertTrue(vault.depositedStars(STAR_ID));
    }

    function _deployWhitelistedVault() internal returns (UrbitVault wlVault) {
        UrbitToken wlUrbit = new UrbitToken();
        UstarToken wlUstar = new UstarToken();
        wlVault = new UrbitVault(
            address(azimuth), address(wlUrbit), address(wlUstar), true
        );
        wlUrbit.transferOwnership(address(wlVault));
        wlUstar.transferOwnership(address(wlVault));
    }

    function test_whitelist_blocksNonWhitelisted() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        vm.startPrank(user1);
        ecliptic.approve(address(wlVault), STAR_ID);
        vm.expectRevert(UrbitVault.NotWhitelisted.selector);
        wlVault.depositStar(STAR_ID, user1);
        vm.stopPrank();
    }

    function test_whitelist_allowsWhitelisted() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        address[] memory accounts = new address[](1);
        accounts[0] = user1;
        wlVault.setWhitelist(accounts, true);

        vm.startPrank(user1);
        ecliptic.approve(address(wlVault), STAR_ID);
        wlVault.depositStar(STAR_ID, user1);
        vm.stopPrank();

        assertTrue(wlVault.depositedStars(STAR_ID));
    }

    function test_whitelist_toggle() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        assertTrue(wlVault.whitelistEnabled());
        wlVault.setWhitelistEnabled(false);
        assertFalse(wlVault.whitelistEnabled());

        // Can re-enable
        wlVault.setWhitelistEnabled(true);
        assertTrue(wlVault.whitelistEnabled());
    }

    function test_whitelist_permanentViaRenounce() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        // Disable whitelist and renounce — now it's permanent
        wlVault.setWhitelistEnabled(false);
        wlVault.renounceOwnership();

        // Nobody can re-enable
        vm.expectRevert();
        wlVault.setWhitelistEnabled(true);
    }

    function test_whitelist_renounce_reverts_whileEnabled() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        vm.expectRevert(UrbitVault.WhitelistStillEnabled.selector);
        wlVault.renounceOwnership();
    }

    function test_whitelist_disableOpensDeposits() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        // user1 can't deposit yet
        vm.startPrank(user1);
        ecliptic.approve(address(wlVault), STAR_ID);
        vm.expectRevert(UrbitVault.NotWhitelisted.selector);
        wlVault.depositStar(STAR_ID, user1);
        vm.stopPrank();

        // Disable whitelist
        wlVault.setWhitelistEnabled(false);

        // Now user1 can deposit
        vm.startPrank(user1);
        wlVault.depositStar(STAR_ID, user1);
        vm.stopPrank();

        assertTrue(wlVault.depositedStars(STAR_ID));
    }

    function test_whitelist_setWhitelist_onlyOwner() public {
        address[] memory accounts = new address[](1);
        accounts[0] = user1;

        vm.prank(user1);
        vm.expectRevert();
        vault.setWhitelist(accounts, true);
    }

    function test_whitelist_setWhitelistEnabled_onlyOwner() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        vm.prank(user1);
        vm.expectRevert();
        wlVault.setWhitelistEnabled(false);
    }

    function test_whitelist_removeFromWhitelist() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        address[] memory accounts = new address[](1);
        accounts[0] = user1;
        wlVault.setWhitelist(accounts, true);
        assertTrue(wlVault.whitelisted(user1));

        wlVault.setWhitelist(accounts, false);
        assertFalse(wlVault.whitelisted(user1));

        vm.startPrank(user1);
        ecliptic.approve(address(wlVault), STAR_ID);
        vm.expectRevert(UrbitVault.NotWhitelisted.selector);
        wlVault.depositStar(STAR_ID, user1);
        vm.stopPrank();
    }

    function test_whitelist_multipleStars_blocked() public {
        UrbitVault wlVault = _deployWhitelistedVault();

        uint32[] memory starIds = new uint32[](2);
        starIds[0] = STAR_ID;
        starIds[1] = STAR_ID_2;

        vm.prank(user1);
        vm.expectRevert(UrbitVault.NotWhitelisted.selector);
        wlVault.depositMultipleStars(starIds, user1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                      BATCH DEPOSIT
    // ═══════════════════════════════════════════════════════════════════

    function test_depositMultipleStars_happy() public {
        uint32[] memory starIds = new uint32[](3);
        starIds[0] = STAR_ID;
        starIds[1] = STAR_ID_2;
        starIds[2] = STAR_ID_3;

        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);
        ecliptic.approve(address(vault), STAR_ID_2);
        ecliptic.approve(address(vault), STAR_ID_3);
        vault.depositMultipleStars(starIds, user1);
        vm.stopPrank();

        assertTrue(vault.depositedStars(STAR_ID));
        assertTrue(vault.depositedStars(STAR_ID_2));
        assertTrue(vault.depositedStars(STAR_ID_3));
        assertEq(urbitToken.balanceOf(user1), URBIT_AMOUNT * 3);
        assertEq(ustarToken.balanceOf(user1), USTAR_AMOUNT * 3);
        assertEq(ecliptic.ownerOf(STAR_ID), address(vault));
        assertEq(ecliptic.ownerOf(STAR_ID_2), address(vault));
        assertEq(ecliptic.ownerOf(STAR_ID_3), address(vault));
    }

    function test_depositMultipleStars_reverts_emptyArray() public {
        uint32[] memory starIds = new uint32[](0);

        vm.prank(user1);
        vm.expectRevert(UrbitVault.EmptyArray.selector);
        vault.depositMultipleStars(starIds, user1);
    }

    function test_depositMultipleStars_reverts_exceedsMaxBatchSize() public {
        uint32[] memory starIds = new uint32[](101);
        for (uint32 i = 0; i < 101; i++) {
            starIds[i] = 256 + (i * 256);
        }

        vm.prank(user1);
        vm.expectRevert(UrbitVault.ExceedsMaxBatchSize.selector);
        vault.depositMultipleStars(starIds, user1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                      BATCH REDEMPTION
    // ═══════════════════════════════════════════════════════════════════

    function test_redeemMultipleStars_happy() public {
        _depositStar(STAR_ID, user1);
        _depositStar(STAR_ID_2, user1);
        _depositStar(STAR_ID_3, user1);

        uint32[] memory starIds = new uint32[](3);
        starIds[0] = STAR_ID;
        starIds[1] = STAR_ID_2;
        starIds[2] = STAR_ID_3;

        vm.prank(user1);
        vault.redeemMultipleStars(starIds);

        assertFalse(vault.depositedStars(STAR_ID));
        assertFalse(vault.depositedStars(STAR_ID_2));
        assertFalse(vault.depositedStars(STAR_ID_3));
        assertEq(ecliptic.ownerOf(STAR_ID), user1);
        assertEq(ecliptic.ownerOf(STAR_ID_2), user1);
        assertEq(ecliptic.ownerOf(STAR_ID_3), user1);
        assertEq(urbitToken.balanceOf(user1), 0);
        assertEq(ustarToken.balanceOf(user1), 0);
    }

    function test_redeemMultipleStars_reverts_emptyArray() public {
        uint32[] memory starIds = new uint32[](0);

        vm.prank(user1);
        vm.expectRevert(UrbitVault.EmptyArray.selector);
        vault.redeemMultipleStars(starIds);
    }

    function test_redeemMultipleStars_reverts_exceedsMaxBatchSize() public {
        uint32[] memory starIds = new uint32[](101);
        for (uint32 i = 0; i < 101; i++) {
            starIds[i] = 256 + (i * 256);
        }

        vm.prank(user1);
        vm.expectRevert(UrbitVault.ExceedsMaxBatchSize.selector);
        vault.redeemMultipleStars(starIds);
    }

    function test_redeemMultipleStars_reverts_starNotDeposited() public {
        // Deposit two stars so user has enough tokens for a batch of 2
        _depositStar(STAR_ID, user1);
        _depositStar(STAR_ID_2, user1);

        uint32[] memory starIds = new uint32[](2);
        starIds[0] = STAR_ID;
        starIds[1] = STAR_ID_3; // not deposited

        vm.prank(user1);
        vm.expectRevert(UrbitVault.StarNotDeposited.selector);
        vault.redeemMultipleStars(starIds);
    }

    function test_redeemMultipleStars_reverts_duplicateStarIds() public {
        // Deposit two stars so user has enough tokens for a batch of 2
        _depositStar(STAR_ID, user1);
        _depositStar(STAR_ID_2, user1);

        uint32[] memory starIds = new uint32[](2);
        starIds[0] = STAR_ID;
        starIds[1] = STAR_ID; // duplicate — first iteration clears it, second reverts

        vm.prank(user1);
        vm.expectRevert(UrbitVault.StarNotDeposited.selector);
        vault.redeemMultipleStars(starIds);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                      RECIPIENT ROUTING
    // ═══════════════════════════════════════════════════════════════════

    function test_depositStar_recipientReceivesTokens() public {
        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);
        vault.depositStar(STAR_ID, user2);
        vm.stopPrank();

        // user2 gets the tokens, not user1
        assertEq(urbitToken.balanceOf(user2), URBIT_AMOUNT);
        assertEq(ustarToken.balanceOf(user2), USTAR_AMOUNT);
        assertEq(urbitToken.balanceOf(user1), 0);
        assertEq(ustarToken.balanceOf(user1), 0);

        // Star is in the vault
        assertEq(ecliptic.ownerOf(STAR_ID), address(vault));
    }

    function test_depositStar_reverts_zeroRecipient() public {
        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);

        vm.expectRevert(UrbitVault.ZeroAddress.selector);
        vault.depositStar(STAR_ID, address(0));
        vm.stopPrank();
    }

    function test_depositMultipleStars_reverts_zeroRecipient() public {
        uint32[] memory starIds = new uint32[](1);
        starIds[0] = STAR_ID;

        vm.startPrank(user1);
        ecliptic.approve(address(vault), STAR_ID);

        vm.expectRevert(UrbitVault.ZeroAddress.selector);
        vault.depositMultipleStars(starIds, address(0));
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     CROSS-USER REDEMPTION
    // ═══════════════════════════════════════════════════════════════════

    function test_crossUser_redeemWithTransferredTokens() public {
        // user1 deposits a star
        _depositStar(STAR_ID, user1);

        // user1 transfers tokens to user2
        vm.startPrank(user1);
        urbitToken.transfer(user2, URBIT_AMOUNT);
        ustarToken.transfer(user2, USTAR_AMOUNT);
        vm.stopPrank();

        // user2 redeems the star
        vm.prank(user2);
        vault.redeemStar(STAR_ID);

        assertEq(ecliptic.ownerOf(STAR_ID), user2);
        assertEq(urbitToken.balanceOf(user2), 0);
        assertEq(ustarToken.balanceOf(user2), 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                       CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    function test_constructor_reverts_zeroAzimuth() public {
        vm.expectRevert(UrbitVault.ZeroAddress.selector);
        new UrbitVault(address(0), address(urbitToken), address(ustarToken), false);
    }

    function test_constructor_reverts_zeroUrbitToken() public {
        vm.expectRevert(UrbitVault.ZeroAddress.selector);
        new UrbitVault(address(azimuth), address(0), address(ustarToken), false);
    }

    function test_constructor_reverts_zeroUstarToken() public {
        vm.expectRevert(UrbitVault.ZeroAddress.selector);
        new UrbitVault(address(azimuth), address(urbitToken), address(0), false);
    }

}
