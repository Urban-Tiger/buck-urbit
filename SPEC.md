# UrbitVault Security Specification

This document describes the intended behavior and design rationale of the UrbitVault system. It is intended for auditors reviewing the contracts.

## System Overview

The UrbitVault allows holders of Urbit stars (ERC721 NFTs on the Ecliptic contract) to deposit them in exchange for fungible ERC20 tokens. Stars can be redeemed later by burning the tokens.

**Contracts:**

| Contract | Inheritance | Owner |
|----------|------------|-------|
| UrbitVault | ReentrancyGuard | None (ownerless) |
| UrbitToken | ERC20, ERC20Permit, Ownable | UrbitVault |
| UstarToken | ERC20, ERC20Permit, Ownable | UrbitVault |

**External dependencies:**

| Contract | Address (mainnet) | Trust assumption |
|----------|------------------|------------------|
| Azimuth | `0x223c067f8cf28ae173ee5cafea60ca44c335fecb` | Trusted — canonical Urbit registry |
| Ecliptic | Retrieved via `azimuth.owner()` | Trusted — Azimuth's ERC721 logic |
| OpenZeppelin v5.3 | npm dependency | Trusted |

## Token Economics

Per star deposited:
- **65,535 URBIT** minted (1 per spawnable planet, 18 decimals)
- **1 USTAR** minted (1 per star, 18 decimals)

Redemption burns the same amounts. Total supply is always `deposited_stars * 65535` URBIT and `deposited_stars * 1` USTAR.

Stars are fungible within the vault — any holder of sufficient tokens can redeem any deposited star, not only the original depositor. This is by design.

## Deposit Flow

1. User calls `ecliptic.approve(vault, starId)`
2. User calls `vault.depositStar(starId)`
3. Vault validates:
   - Point is a star (`azimuth.getPointSize` returns `Size.Star`)
   - Star is virgin: `hasBeenLinked` is false AND `getSpawnProxy` is `address(0)`
   - Star has not already been deposited to this vault
4. State update: `depositedStars[starId] = true`
5. Vault calls `ecliptic.transferFrom(user, vault, starId)`
6. Vault mints 65,535 URBIT + 1 USTAR to user

## Redeem Flow

1. User calls `urbitToken.approve(vault, amount)` and `ustarToken.approve(vault, amount)`
2. User calls `vault.redeemStar(starId)`
3. Vault validates:
   - Star is currently deposited
   - User has sufficient URBIT and USTAR balance
4. State update: `depositedStars[starId] = false`
5. Vault burns tokens via `burnFrom` (requires user's prior approval)
6. Vault calls `ecliptic.transferFrom(vault, user, starId)`

A `redeemStarWithPermit` variant uses EIP-2612 permit signatures instead of requiring prior `approve` calls, enabling single-transaction redemption.

## Virgin Star Definition

A star is considered "virgin" if:
- `azimuth.hasBeenLinked(starId)` returns `false` — networking keys have never been configured
- `azimuth.getSpawnProxy(starId)` returns `address(0)` — no spawn proxy is set

**Why this is sufficient:**
- On L1, `hasBeenLinked` is a prerequisite for spawning planets (enforced by Ecliptic's `spawn` function)
- On L2, spawning requires the spawn proxy to be set to the L2 deposit address (`0x1111...1111`). Once set to the deposit address, the Ecliptic contract prevents clearing it — this is a one-way operation
- Therefore: a star that passes both checks has never spawned planets on L1 or L2

## Design Decisions

### Ownerless vault
The vault has no owner, no pause mechanism, and no admin functions. Once deployed, it operates as an immutable protocol. The token contracts are owned by the vault (not a human), and ownership is transferred at deploy time and never changes.

**Rationale:** The vault holds custody of user-deposited stars. An admin key would be a centralization risk — a compromised or malicious owner could pause the contract and prevent users from redeeming their stars indefinitely. Removing ownership eliminates this trust requirement.

### No IERC721Receiver
The vault does not implement `IERC721Receiver`. The `depositStar` function uses `transferFrom` (not `safeTransferFrom`) to pull stars from the user, so the callback is never invoked during normal operation.

**Rationale:** Any NFT sent to the vault via `safeTransferFrom` (bypassing `depositStar`) would be stuck — no `depositedStars` entry would be created, so it could never be redeemed. By not implementing the interface, `safeTransferFrom` to the vault automatically reverts at the ERC721 level, preventing accidental loss. Note: `transferFrom` cannot be blocked at the receiver level, so direct transfers of arbitrary NFTs remain possible but are not a protocol concern.

### transferFrom on redeem (not safeTransferFrom)
The vault uses `transferFrom` to return stars to the redeemer rather than `safeTransferFrom`.

**Rationale:** The redeemer initiated the transaction, so they are aware they are receiving an NFT. Using `safeTransferFrom` would add gas overhead and introduce an external callback (reentrancy surface) for a marginal edge case (redeemer is a contract without `onERC721Received`). Standard multisig wallets (Gnosis Safe, etc.) can handle ERC721s received via `transferFrom`.

### CEI pattern
All state-changing functions follow checks-effects-interactions ordering. State updates (`depositedStars` mapping) occur before any external calls. All functions also use `nonReentrant` as defense-in-depth.

### Token burn mechanism
`burnFrom` on both token contracts calls `_spendAllowance` then `_burn`. The vault is the `owner` of both tokens and the only address authorized to call `mint` and `burnFrom`. Users must approve the vault to spend their tokens before redeeming (or use the permit variant).

## Invariants

The following should always hold:

1. `URBIT.totalSupply() == count(depositedStars == true) * 65535 * 1e18`
2. `USTAR.totalSupply() == count(depositedStars == true) * 1e18`
3. For every star where `depositedStars[id] == true`, the vault holds that star on the Ecliptic contract
4. Only the vault can mint or burn URBIT and USTAR tokens
5. No admin function exists on the vault — no address has privileged access

## Known Limitations

- **Arbitrary tokens sent via `transferFrom`** to the vault address (ERC20s, ERC721s, ETH) are permanently unrecoverable. This is true of any contract without a sweep function, and is an accepted tradeoff of the ownerless design.
- **No sweep function** exists to recover tokens accidentally sent to the token contracts themselves (as opposed to the vault).

## Compiler Settings

- Solidity 0.8.28
- EVM target: Paris
- Optimizer: enabled (1 run, via IR)
- OpenZeppelin Contracts v5.3
