# $URBIT - Urbit Fungible Token System

These contracts implement a fungible token system for Urbit stars, allowing users to deposit stars and receive ERC20 tokens in return.

## Overview

This system allows users to:

- Deposit "virgin" stars (Urbit stars without networking keys set)
- Receive 65,535 $URBIT tokens (representing spawnable planets) and 1 $USTAR token (representing the star itself)
- Redeem a star by burning the equivalent $USTAR and $URBIT tokens

## Contracts

### Core Contracts

- **UrbitVault.sol** - Main contract managing star deposits and redemptions
- **UrbitToken.sol** - ERC20 token representing spawnable planets ($URBIT)
- **UstarToken.sol** - ERC20 token representing star ownership ($USTAR)

## Setup

1. Install dependencies:

```bash
npm install
```

2. Copy the environment template and configure:

```bash
cp .env.example .env
```

Edit `.env` with your configuration (for testnet or mainnet deployment):

- Network URLs (Infura, Alchemy, etc.)
- Private key for deployment
- Etherscan API key for contract verification

## Usage

### Compile contracts

```bash
npm run compile
```

### Run tests

```bash
npm test
```

### Deploy to networks

```bash
# Deploy to Sepolia testnet
npm run deploy:sepolia

# Deploy to Mainnet
npm run deploy:mainnet

# Deploy to local Hardhat network
npm run deploy:local
```

### Start local node

```bash
npm run node
```

## Contract Architecture

### UrbitVault

The main contract that handles:

- Validation of virgin stars
- Accepting star deposits and minting tokens
- Burning tokens and redeeming stars

### Token System

- **$URBIT**: Represents the spawnable planets of a star (65,535 per star)
- **$USTAR**: Represents the star itself (1 per star)

## Key Functions

### For Users

**Deposit Star:**

```solidity
function depositStar(uint32 _starId) external
```

- Deposits a star and receives tokens
- Requires star to be virgin (no networking keys set)
- Mints 65,535 $URBIT and 1 $USTAR tokens

**Redeem Star:**

```solidity
function redeemStar(uint32 _starId) external
```

- Burns tokens and returns a specified star
- Requires 65,535 $URBIT and 1 $USTAR tokens

### For Admins

**Emergency Functions:**

- `pause()` / `unpause()` - Halt operations

## Contract Addresses

### Mainnet

- Azimuth: `0x223c067f8cf28ae173ee5cafea60ca44c335fecb`
- Ecliptic: `0x33EeCbf908478C10614626A9D304bfe18B78DD73`

### Sepolia Testnet

- **UrbitToken**: `0x3C615fF007Fd1CF11862BAb5220dbe822E023F29`
- **UstarToken**: `0xDFBad2CAe32d0E609a01F1ba32e07a12E9EBf967`
- **UrbitVault**: `0x7a766d69beDf94B1b8924Df916c414f3930451Af`
- Azimuth: `0xE6532b92148615418c1b4150dA4caC122b1C7F1a`
- Ecliptic: `0xf49C4d09C0b98Fb2d199820eC99D22d39174D1A3`

### Deployed Contracts

Contract addresses are saved in deployment files after running deployment scripts.

## Testing

The test suite covers:

- Star deposit functionality
- Token redemption
- Virgin star validation
- Access control
- Edge cases and error conditions

## License

MIT License
