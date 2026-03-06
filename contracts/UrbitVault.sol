// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IAzimuth.sol";
import "./interfaces/IEcliptic.sol";
import "./UrbitToken.sol";
import "./UstarToken.sol";

/**
 * @title UrbitVault
 * @notice Deposit virgin Urbit stars to receive 65,535 $URBIT + 1 $USTAR tokens.
 *         Deposited stars may be redeemed by burning the tokens.
 */
contract UrbitVault is ReentrancyGuard, Ownable2Step {
    IAzimuth public immutable azimuth;
    UrbitToken public immutable urbitToken;
    UstarToken public immutable ustarToken;

    /// @notice Number of $URBIT tokens minted per deposited star
    uint256 public constant PLANETS_PER_STAR = 65535;

    /// @notice Maximum number of stars that can be deposited in a single transaction
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @notice Whether the deposit whitelist is active
    bool public whitelistEnabled;

    /// @notice Tracks which addresses are whitelisted for deposits
    mapping(address => bool) public whitelisted;

    /// @notice Tracks which stars have been deposited
    mapping(uint32 => bool) public depositedStars;

    /// @notice Emitted when a star is deposited into the vault
    /// @param starId The Azimuth point ID of the deposited star
    /// @param depositor The address that deposited the star
    event StarDeposited(uint32 indexed starId, address indexed depositor);

    /// @notice Emitted when a star is redeemed from the vault
    /// @param starId The Azimuth point ID of the redeemed star
    /// @param redeemer The address that redeemed the star
    event StarRedeemed(uint32 indexed starId, address indexed redeemer);

    /// @notice Emitted when the whitelist is toggled on or off
    /// @param enabled Whether the whitelist is now enabled
    event WhitelistToggled(bool enabled);

    /// @notice Emitted when an address is added to or removed from the whitelist
    /// @param account The address being updated
    /// @param status Whether the address is now whitelisted
    event WhitelistUpdated(address indexed account, bool status);

    /// @notice Thrown when the provided point ID is not a star (256–65535)
    error InvalidAzimuthPoint();
    /// @notice Thrown when the star has been linked or has a spawn proxy set
    error StarNotVirgin();
    /// @notice Thrown when the star is already held by this vault
    error StarAlreadyDeposited();
    /// @notice Thrown when the star is not currently deposited in this vault
    error StarNotDeposited();
    /// @notice Thrown when the caller lacks sufficient URBIT or USTAR tokens
    error InsufficientTokens();
    /// @notice Thrown when an empty array is provided
    error EmptyArray();
    /// @notice Thrown when the array exceeds MAX_BATCH_SIZE
    error ExceedsMaxBatchSize();
    /// @notice Thrown when a non-whitelisted address attempts to deposit
    error NotWhitelisted();
    /// @notice Thrown when a zero address is provided
    error ZeroAddress();
    /// @notice Thrown when attempting to renounce ownership while whitelist is enabled
    error WhitelistStillEnabled();

    /**
     * @notice Initialize the UrbitVault contract
     * @param _azimuth Address of the Azimuth contract
     * @param _urbitToken Address of the $URBIT token contract
     * @param _ustarToken Address of the $USTAR token contract
     * @param _whitelistEnabled Whether to enable the deposit whitelist at launch
     */
    constructor(
        address _azimuth,
        address _urbitToken,
        address _ustarToken,
        bool _whitelistEnabled
    ) Ownable(msg.sender) {
        if (_azimuth == address(0)) revert ZeroAddress();
        if (_urbitToken == address(0)) revert ZeroAddress();
        if (_ustarToken == address(0)) revert ZeroAddress();
        azimuth = IAzimuth(_azimuth);
        urbitToken = UrbitToken(_urbitToken);
        ustarToken = UstarToken(_ustarToken);
        whitelistEnabled = _whitelistEnabled;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                          DEPOSITS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Deposit a virgin star and receive 65,535 $URBIT + 1 $USTAR tokens
     * @dev The `_recipient` parameter allows router contracts to deposit stars
     *      on behalf of users and direct the minted tokens to the original owner.
     *      The star is always transferred from `msg.sender`.
     * @param _starId The ID of the star to deposit
     * @param _recipient The address to receive the minted tokens
     */
    function depositStar(uint32 _starId, address _recipient) external nonReentrant {
        if (_recipient == address(0)) revert ZeroAddress();
        _checkWhitelist();
        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        _depositStar(_starId, ecliptic);
        urbitToken.mint(_recipient, PLANETS_PER_STAR * 10**18);
        ustarToken.mint(_recipient, 1 * 10**18);
    }

    /**
     * @notice Deposit multiple virgin stars in a single transaction
     * @dev The `_recipient` parameter allows router contracts to deposit stars
     *      on behalf of users and direct the minted tokens to the original owner.
     *      The stars are always transferred from `msg.sender`.
     * @param _starIds Array of star IDs to deposit
     * @param _recipient The address to receive the minted tokens
     */
    function depositMultipleStars(uint32[] calldata _starIds, address _recipient) external nonReentrant {
        if (_recipient == address(0)) revert ZeroAddress();
        _checkWhitelist();
        uint256 count = _starIds.length;
        if (count == 0) revert EmptyArray();
        if (count > MAX_BATCH_SIZE) revert ExceedsMaxBatchSize();

        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        for (uint256 i = 0; i < count; i++) {
            _depositStar(_starIds[i], ecliptic);
        }

        urbitToken.mint(_recipient, count * PLANETS_PER_STAR * 10**18);
        ustarToken.mint(_recipient, count * 1 * 10**18);
    }

    /**
     * @dev Validate and deposit a single star into the vault
     * @param _starId The star to deposit
     * @param _ecliptic Cached Ecliptic reference
     */
    function _depositStar(uint32 _starId, IEcliptic _ecliptic) internal {
        if (azimuth.getPointSize(_starId) != uint8(IAzimuth.Size.Star)) {
            revert InvalidAzimuthPoint();
        }

        if (!_isVirginStar(_starId)) {
            revert StarNotVirgin();
        }

        if (depositedStars[_starId]) {
            revert StarAlreadyDeposited();
        }

        depositedStars[_starId] = true;
        _ecliptic.transferFrom(msg.sender, address(this), _starId);

        emit StarDeposited(_starId, msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                         REDEMPTIONS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Redeem a star by burning 65,535 $URBIT + 1 $USTAR tokens
     * @param _starId The ID of the star to redeem
     */
    function redeemStar(uint32 _starId) external nonReentrant {
        if (!depositedStars[_starId]) {
            revert StarNotDeposited();
        }

        if (urbitToken.balanceOf(msg.sender) < PLANETS_PER_STAR * 10**18) {
            revert InsufficientTokens();
        }

        if (ustarToken.balanceOf(msg.sender) < 1 * 10**18) {
            revert InsufficientTokens();
        }

        // Effects
        depositedStars[_starId] = false;

        // Interactions
        urbitToken.burn(msg.sender, PLANETS_PER_STAR * 10**18);
        ustarToken.burn(msg.sender, 1 * 10**18);

        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        ecliptic.transferFrom(address(this), msg.sender, _starId);

        emit StarRedeemed(_starId, msg.sender);
    }

    /**
     * @notice Redeem multiple stars in a single transaction
     * @param _starIds Array of star IDs to redeem
     */
    function redeemMultipleStars(uint32[] calldata _starIds) external nonReentrant {
        uint256 count = _starIds.length;
        if (count == 0) revert EmptyArray();
        if (count > MAX_BATCH_SIZE) revert ExceedsMaxBatchSize();

        uint256 totalUrbit = count * PLANETS_PER_STAR * 10**18;
        uint256 totalUstar = count * 1 * 10**18;

        if (urbitToken.balanceOf(msg.sender) < totalUrbit) {
            revert InsufficientTokens();
        }

        if (ustarToken.balanceOf(msg.sender) < totalUstar) {
            revert InsufficientTokens();
        }

        // Effects
        for (uint256 i = 0; i < count; i++) {
            if (!depositedStars[_starIds[i]]) {
                revert StarNotDeposited();
            }
            depositedStars[_starIds[i]] = false;
        }

        // Interactions
        urbitToken.burn(msg.sender, totalUrbit);
        ustarToken.burn(msg.sender, totalUstar);

        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        for (uint256 i = 0; i < count; i++) {
            ecliptic.transferFrom(address(this), msg.sender, _starIds[i]);
            emit StarRedeemed(_starIds[i], msg.sender);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                            VIEWS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Internal function to check if a star is virgin.
     *      A star cannot spawn planets without first calling `configureKeys`,
     *      which permanently sets `hasBeenLinked = true`. Other proxies
     *      (management, voting, transfer) are cleared by Ecliptic's
     *      `transferFrom`, which calls `transferPoint` with `_reset = true`.
     * @param _starId The Azimuth point ID to check
     * @return True if the star has never been linked and has no spawn proxy
     */
    function _isVirginStar(uint32 _starId) internal view returns (bool) {
        if (azimuth.hasBeenLinked(_starId)) {
            return false;
        }

        // Check if spawn proxy is set (prevent layer 2 spawning)
        address spawnProxy = azimuth.getSpawnProxy(_starId);
        if (spawnProxy != address(0)) {
            return false;
        }

        return true;
    }

    /**
     * @notice Check if a star is eligible for deposit (virgin check)
     * @param _starId The Azimuth point ID to check
     * @return True if the point is a virgin star that can be deposited
     */
    function isEligibleStar(uint32 _starId) external view returns (bool) {
        if (azimuth.getPointSize(_starId) != uint8(IAzimuth.Size.Star)) return false;
        if (depositedStars[_starId]) return false;
        return _isVirginStar(_starId);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                          WHITELIST
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @dev Revert if the whitelist is enabled and caller is not whitelisted
     */
    function _checkWhitelist() internal view {
        if (whitelistEnabled && !whitelisted[msg.sender]) {
            revert NotWhitelisted();
        }
    }

    /**
     * @notice Add or remove addresses from the deposit whitelist
     * @param _accounts Array of addresses to update
     * @param _status Whether to whitelist (true) or remove (false)
     */
    function setWhitelist(address[] calldata _accounts, bool _status) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            whitelisted[_accounts[i]] = _status;
            emit WhitelistUpdated(_accounts[i], _status);
        }
    }

    /**
     * @notice Toggle the deposit whitelist on or off.
     *         To permanently disable, call this then renounceOwnership().
     * @param _enabled Whether to enable the whitelist
     */
    function setWhitelistEnabled(bool _enabled) external onlyOwner {
        whitelistEnabled = _enabled;
        emit WhitelistToggled(_enabled);
    }

    /// @notice Prevents renouncing ownership while the whitelist is active,
    ///         which would permanently restrict deposits to whitelisted addresses.
    function renounceOwnership() public override onlyOwner {
        if (whitelistEnabled) revert WhitelistStillEnabled();
        super.renounceOwnership();
    }

}
