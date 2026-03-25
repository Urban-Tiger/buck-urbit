// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UrbitToken ($URBIT)
 * @notice ERC20 token representing spawnable Urbit planets.
 *         This contract is intended to be owned by, and used in conjunction with, the UrbitVault contract.
 */
contract UrbitToken is ERC20Permit, Ownable {
    /// @notice Initialize the UrbitToken contract
    constructor()
        ERC20("Urbit Token", "URBIT")
        ERC20Permit("Urbit Token")
        Ownable(msg.sender)
    {}

    /// @notice Mint new URBIT tokens
    /// @param to The address to receive the minted tokens
    /// @param amount The number of tokens to mint (18 decimals)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn URBIT tokens from an account
    /// @dev Only callable by the owner (UrbitVault). The vault ensures
    ///      this is only called when the account holder initiates redemption.
    /// @param account The address to burn tokens from
    /// @param amount The number of tokens to burn (18 decimals)
    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
