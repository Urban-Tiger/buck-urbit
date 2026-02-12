// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UstarToken ($USTAR)
 * @notice ERC20 token representing Urbit stars.
 *         This contract is intended to be owned by, and used in conjunction with, the UrbitVault contract.
 *
 * @author Urbit Foundation
 */
contract UstarToken is ERC20, ERC20Permit, Ownable {
    /// @notice Initialize the UstarToken contract
    constructor()
        ERC20("Urbit Star Token", "USTAR")
        ERC20Permit("Urbit Star Token")
        Ownable(msg.sender)
    {}

    /// @notice Mint new USTAR tokens
    /// @param to The address to receive the minted tokens
    /// @param amount The number of tokens to mint (18 decimals)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn USTAR tokens from an account (requires prior approval)
    /// @param account The address to burn tokens from
    /// @param amount The number of tokens to burn (18 decimals)
    function burnFrom(address account, uint256 amount) external onlyOwner {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}
