# $URBIT - Urbit Fungible Token System

These contracts implement a fungible token system for Urbit stars, allowing users to deposit stars and receive ERC20 tokens in return.

## Overview

This system allows users to:

- Deposit "virgin" stars (Urbit stars that have never been booted — no networking keys set and no spawn proxy configured)
- Receive 65,535 URBIT tokens (representing spawnable planets) and 1 USTAR token (representing the star itself)
- Redeem a star by burning the equivalent USTAR and URBIT tokens

## Contracts

### Core Contracts

- **UrbitVault.sol** - Main contract managing star deposits, redemptions, and deposit whitelist
- **UrbitToken.sol** - ERC20 + ERC20Permit token representing spawnable planets (URBIT)
- **UstarToken.sol** - ERC20 + ERC20Permit token representing star ownership (USTAR)

### Interfaces

- **IAzimuth.sol** - Interface for the Azimuth point registry
- **IEcliptic.sol** - Interface for the Ecliptic contract (Azimuth's ERC721 logic)

### Mocks (Testing)

- **MockAzimuth.sol** - Mock Azimuth contract for local testing
- **MockEcliptic.sol** - Mock Ecliptic contract for local testing

## Setup

1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:

```bash
npm install
```

3. Copy the environment template and configure:

```bash
cp .env.example .env
```

Edit `.env` with your configuration (for testnet or mainnet deployment):

- `PRIVATE_KEY` — deployer wallet private key
- `AZIMUTH_ADDRESS` — Azimuth contract address on target network
- `SEPOLIA_URL` / `MAINNET_URL` — RPC endpoint URLs
- `ETHERSCAN_API_KEY` — for contract verification

## Usage

### Build contracts

```bash
forge build
```

### Run tests

```bash
forge test -vvv
```

### Deploy to networks

```bash
# Deploy to Sepolia testnet (with Etherscan verification)
npm run deploy:sepolia

# Deploy to Mainnet (with Etherscan verification)
npm run deploy:mainnet

# Deploy to local anvil node (uses mock contracts)
npm run deploy:local
```

### Start local node

```bash
anvil
```

## Contract Architecture

### UrbitVault

The main contract that handles:

- Validation of virgin stars (checks both networking keys and spawn proxy)
- Accepting star deposits and minting tokens
- Burning tokens and redeeming stars
- Deposit whitelist management (optional, toggleable by owner)

The vault uses `Ownable2Step` for safe ownership management. The owner can manage a deposit whitelist and toggle it on or off. Once the whitelist is disabled and ownership is renounced, the vault becomes fully immutable.

Inherits: `ReentrancyGuard`, `Ownable2Step`

### Token System

- **URBIT**: Represents the spawnable planets of a star (65,535 per star, 18 decimals)
- **USTAR**: Represents the star itself (1 per star, 18 decimals)

Both tokens support ERC20Permit (EIP-2612) for gasless approvals. Minting and burning are restricted to the vault (contract owner).

## Key Functions

### For Users

**Deposit Star:**

```solidity
function depositStar(uint32 _starId, address _recipient) external
```

- Transfers a star to the vault and mints tokens to `_recipient`
- Requires the star to be virgin (no networking keys set, no spawn proxy)
- Mints 65,535 URBIT and 1 USTAR tokens

**Deposit Multiple Stars:**

```solidity
function depositMultipleStars(uint32[] calldata _starIds, address _recipient) external
```

- Deposits multiple stars in a single transaction (max 100)
- More gas-efficient than individual deposits (single token mint call)

**Redeem Star:**

```solidity
function redeemStar(uint32 _starId) external
```

- Burns tokens and returns a specified deposited star
- Requires 65,535 URBIT and 1 USTAR tokens

**Redeem Multiple Stars:**

```solidity
function redeemMultipleStars(uint32[] calldata _starIds) external
```

- Redeems multiple stars in a single transaction (max 100)
- More gas-efficient than individual redemptions (single token burn call)

**Check Star Eligibility:**

```solidity
function isEligibleStar(uint32 _starId) external view returns (bool)
```

- Returns whether a star is eligible for deposit (checks star size, not already deposited, and virgin status)

### For Owner

**Whitelist Management:**

```solidity
function setWhitelist(address[] calldata _accounts, bool _status) external onlyOwner
function setWhitelistEnabled(bool _enabled) external onlyOwner
```

- Add or remove addresses from the deposit whitelist
- Toggle the whitelist on or off
- To permanently disable: turn off the whitelist, then call `renounceOwnership()`

## Contract Addresses

### Mainnet

- UrbitVault: `0x1f7738e782d8d3788892bf89edc8bab51ab2b4fc`
- UrbitToken (URBIT): `0x91ab642dbbee7de690f541ae939776791a8ecbb8`
- UstarToken (USTAR): `0xc70c300b1ef1688f57e2e173ef89dff9c1e3a16b`
- Azimuth: `0x223c067f8cf28ae173ee5cafea60ca44c335fecb`
- Ecliptic: `0x33EeCbf908478C10614626A9D304bfe18B78DD73`

### Sepolia Testnet

- UrbitVault: `0xeE06A61bFD5c7e157A7CE3D7C058baB959eeA3C5`
- UrbitToken (URBIT): `0x31473371715a8bA5471455d89a2137f3fbCc7dBd`
- UstarToken (USTAR): `0x6eF4C3166e47FE073516e1535B3321a98f431538`
- Azimuth: `0xE6532b92148615418c1b4150dA4caC122b1C7F1a`
- Ecliptic: `0xf49C4d09C0b98Fb2d199820eC99D22d39174D1A3`

## Testing

The test suite covers:

- Single and batch star deposits
- Single and batch star redemptions
- Recipient routing (`_recipient != msg.sender`)
- Cross-user redemption (token transfer then redeem)
- Virgin star validation
- Zero-address and boundary condition reverts
- Whitelist enforcement and toggling
- Edge cases (deposit-redeem-redeposit cycles, duplicate IDs, selective redemption)
- Constructor validation
- Invariant fuzz testing (token supply ratios, deposit/redeem accounting)

## License

MIT License
