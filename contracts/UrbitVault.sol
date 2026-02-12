// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IAzimuth.sol";
import "./interfaces/IEcliptic.sol";
import "./UrbitToken.sol";
import "./UstarToken.sol";

/**
 * @title UrbitVault
 * @notice Deposit virgin Urbit stars to receive 65,535 $URBIT + 1 $USTAR tokens.
 *         Deposited stars may be redeemed by burning the tokens.
 *         This contract is ownerless and immutable — no admin functions exist.

 * @author Urbit Foundation
 */
contract UrbitVault is ReentrancyGuard {
    IAzimuth public immutable azimuth;
    UrbitToken public immutable urbitToken;
    UstarToken public immutable ustarToken;

    /// @notice Number of $URBIT tokens minted per deposited star
    uint256 public constant PLANETS_PER_STAR = 65535;

    /// @notice Tracks which stars have been deposited
    mapping(uint32 => bool) public depositedStars;

    event StarDeposited(uint32 indexed starId, address indexed depositor);

    event StarRedeemed(uint32 indexed starId, address indexed redeemer);

    error InvalidAzimuthPoint();
    error StarNotVirgin();
    error StarAlreadyDeposited();
    error StarNotDeposited();
    error InsufficientTokens();

    /**
     * @notice Initialize the UrbitVault contract
     * @param _azimuth Address of the Azimuth contract
     * @param _urbitToken Address of the $URBIT token contract
     * @param _ustarToken Address of the $USTAR token contract
     */
    constructor(
        address _azimuth,
        address _urbitToken,
        address _ustarToken
    ) {
        require(_azimuth != address(0), "Zero azimuth address");
        require(_urbitToken != address(0), "Zero urbitToken address");
        require(_ustarToken != address(0), "Zero ustarToken address");
        azimuth = IAzimuth(_azimuth);
        urbitToken = UrbitToken(_urbitToken);
        ustarToken = UstarToken(_ustarToken);
    }

    /**
     * @notice Deposit a virgin star and receive 65,535 $URBIT + 1 $USTAR tokens
     * @param _starId The ID of the star to deposit
     */
    function depositStar(uint32 _starId) external nonReentrant {
        if (azimuth.getPointSize(_starId) != uint8(IAzimuth.Size.Star)) {
            revert InvalidAzimuthPoint();
        }

        if (!_isVirginStar(_starId)) {
            revert StarNotVirgin();
        }

        if (depositedStars[_starId]) {
            revert StarAlreadyDeposited();
        }

        // Effects
        depositedStars[_starId] = true;

        // Interactions
        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        ecliptic.transferFrom(msg.sender, address(this), _starId);

        urbitToken.mint(msg.sender, PLANETS_PER_STAR * 10**18);
        ustarToken.mint(msg.sender, 1 * 10**18);

        emit StarDeposited(_starId, msg.sender);
    }

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
        urbitToken.burnFrom(msg.sender, PLANETS_PER_STAR * 10**18);
        ustarToken.burnFrom(msg.sender, 1 * 10**18);

        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        ecliptic.transferFrom(address(this), msg.sender, _starId);

        emit StarRedeemed(_starId, msg.sender);
    }

    /**
     * @notice Redeem a star using permit signatures for gasless token approval
     * @param _starId The ID of the star to redeem
     * @param _urbitDeadline Deadline for the $URBIT token permit signature
     * @param _urbitV Recovery byte for $URBIT token permit signature
     * @param _urbitR First 32 bytes for $URBIT token permit signature
     * @param _urbitS Second 32 bytes for $URBIT token permit signature
     * @param _ustarDeadline Deadline for the $USTAR token permit signature
     * @param _ustarV Recovery byte for $USTAR token permit signature
     * @param _ustarR First 32 bytes for $USTAR token permit signature
     * @param _ustarS Second 32 bytes for $USTAR token permit signature
     */
    function redeemStarWithPermit(
        uint32 _starId,
        uint256 _urbitDeadline,
        uint8 _urbitV,
        bytes32 _urbitR,
        bytes32 _urbitS,
        uint256 _ustarDeadline,
        uint8 _ustarV,
        bytes32 _ustarR,
        bytes32 _ustarS
    ) external nonReentrant {
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
        urbitToken.permit(
            msg.sender,
            address(this),
            PLANETS_PER_STAR * 10**18,
            _urbitDeadline,
            _urbitV,
            _urbitR,
            _urbitS
        );

        ustarToken.permit(
            msg.sender,
            address(this),
            1 * 10**18,
            _ustarDeadline,
            _ustarV,
            _ustarR,
            _ustarS
        );

        urbitToken.burnFrom(msg.sender, PLANETS_PER_STAR * 10**18);
        ustarToken.burnFrom(msg.sender, 1 * 10**18);

        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        ecliptic.transferFrom(address(this), msg.sender, _starId);

        emit StarRedeemed(_starId, msg.sender);
    }

    /**
     * @dev Internal function to check if a star is virgin
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
     * @notice External function to check if a star is eligible for deposit
     */
    function isEligibleStar(uint32 _starId) external view returns (bool) {
        return _isVirginStar(_starId);
    }

}
