// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UrbitToken ($URBIT)
 * @notice ERC20 token representing spawnable Urbit planets.
 *         This contract is intended to be owned by, and used in conjunction with, the UrbitVault contract.
 *
 * @author Urbit Foundation
 */
contract UrbitToken is ERC20, ERC20Permit, Ownable {
    /// @notice Initialize the UrbitToken contract
    constructor()
        ERC20("Urbit Token", "URBIT")
        ERC20Permit("Urbit Token")
        Ownable(msg.sender)
    {}

    /// @notice Mint new URBIT tokens
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn URBIT tokens
    function burnFrom(address account, uint256 amount) external onlyOwner {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}
