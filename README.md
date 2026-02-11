# $URBIT - Urbit Fungible Token System

These contracts implement a fungible token system for Urbit stars, allowing users to deposit stars and receive ERC20 tokens in return.

## Overview

This system allows users to:

- Deposit "virgin" stars (Urbit stars that have never been booted — no networking keys set and no spawn proxy configured)
- Receive 65,535 URBIT tokens (representing spawnable planets) and 1 USTAR token (representing the star itself)
- Redeem a star by burning the equivalent USTAR and URBIT tokens

## Contracts

### Core Contracts

- **UrbitVault.sol** - Main contract managing star deposits and redemptions
- **UrbitToken.sol** - ERC20 + ERC20Permit token representing spawnable planets (URBIT)
- **UstarToken.sol** - ERC20 + ERC20Permit token representing star ownership (USTAR)

### Interfaces

- **IAzimuth.sol** - Interface for the Azimuth point registry
- **IEcliptic.sol** - Interface for the Ecliptic contract (Azimuth's ERC721 logic)
- **ITreasuryProxy.sol** - Interface for the Treasury proxy

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
- ERC721 receiver for safe star transfers

Inherits: `IERC721Receiver`, `Ownable`, `ReentrancyGuard`, `Pausable`

### Token System

- **URBIT**: Represents the spawnable planets of a star (65,535 per star, 18 decimals)
- **USTAR**: Represents the star itself (1 per star, 18 decimals)

Both tokens support ERC20Permit (EIP-2612) for gasless approvals. Minting and burning are restricted to the vault (contract owner).

## Key Functions

### For Users

**Deposit Star:**

```solidity
function depositStar(uint32 _starId) external
```

- Transfers a star to the vault and mints tokens to the depositor
- Requires the star to be virgin (no networking keys set, no spawn proxy)
- Mints 65,535 URBIT and 1 USTAR tokens

**Redeem Star:**

```solidity
function redeemStar(uint32 _starId) external
```

- Burns tokens and returns a specified deposited star
- Requires 65,535 URBIT and 1 USTAR tokens
- Caller must have approved the vault to spend their tokens

**Redeem Star with Permit:**

```solidity
function redeemStarWithPermit(
    uint32 _starId,
    uint256 _urbitDeadline, uint8 _urbitV, bytes32 _urbitR, bytes32 _urbitS,
    uint256 _ustarDeadline, uint8 _ustarV, bytes32 _ustarR, bytes32 _ustarS
) external
```

- Same as `redeemStar` but uses EIP-2612 permit signatures for token approval
- Allows redemption in a single transaction without a prior `approve` call

**Check Star Eligibility:**

```solidity
function isEligibleStar(uint32 _starId) external view returns (bool)
```

- Returns whether a star is eligible for deposit (virgin check)

### For Admins

**Emergency Functions:**

- `pause()` / `unpause()` - Halt or resume vault operations (owner only)

## Contract Addresses

### Mainnet (Azimuth)

- Azimuth: `0x223c067f8cf28ae173ee5cafea60ca44c335fecb`
- Ecliptic: `0x33EeCbf908478C10614626A9D304bfe18B78DD73`

### Sepolia Testnet

- **UrbitToken**: `0x3C615fF007Fd1CF11862BAb5220dbe822E023F29`
- **UstarToken**: `0xDFBad2CAe32d0E609a01F1ba32e07a12E9EBf967`
- **UrbitVault**: `0x7a766d69beDf94B1b8924Df916c414f3930451Af`
- Azimuth: `0xE6532b92148615418c1b4150dA4caC122b1C7F1a`
- Ecliptic: `0xf49C4d09C0b98Fb2d199820eC99D22d39174D1A3`

## Testing

The test suite covers:

- Star deposit functionality
- Token redemption
- Virgin star validation
- Access control
- Edge cases and error conditions

## License

ISC License
