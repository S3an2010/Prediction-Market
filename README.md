# Prediction Market Smart Contract

A decentralized prediction market smart contract built on the Stacks blockchain using Clarity. This contract allows users to create prediction markets, buy positions on outcomes, and claim winnings based on resolved results.

## Features

- **Market Creation**: Contract owner can create prediction markets with custom questions and durations
- **Position Trading**: Users can buy positions predicting "Yes" or "No" outcomes
- **Automatic Payouts**: Winners receive proportional payouts based on the total pool
- **Market Resolution**: Contract owner resolves markets with final outcomes
- **Transparent Odds**: Real-time odds calculation based on current positions

## Contract Overview

The contract implements a simple prediction market mechanism where:
1. Users stake STX tokens on binary outcomes (Yes/No)
2. Payouts are distributed proportionally to winners based on pool sizes
3. Winners receive `(their_stake * total_pool) / winning_pool`

## Data Structures

### Markets
```clarity
{
  question: (string-ascii 200),        // Market question
  description: (string-ascii 500),     // Detailed description
  end-block: uint,                     // Block height when market closes
  resolved: bool,                      // Whether market has been resolved
  outcome: (optional bool),            // Final outcome (true = Yes, false = No)
  total-yes: uint,                     // Total STX staked on "Yes"
  total-no: uint                       // Total STX staked on "No"
}
```

### Positions
```clarity
{
  trader: principal,                   // Address of the position holder
  market-id: uint,                     // ID of the associated market
  prediction: bool,                    // Predicted outcome (true = Yes, false = No)
  amount: uint,                        // Amount of STX staked
  claimed: bool                        // Whether winnings have been claimed
}
```

## Public Functions

### `create-market`
Creates a new prediction market (owner only).

**Parameters:**
- `question`: Market question (max 200 characters)
- `description`: Detailed description (max 500 characters)
- `duration`: Market duration in blocks

**Returns:** Market ID

**Example:**
```clarity
(contract-call? .prediction-market create-market 
  "Will Bitcoin reach $100k by end of 2024?" 
  "Market resolves based on CoinGecko price data" 
  u144000) ;; ~100 days
```

### `buy-position`
Purchase a position in an active prediction market.

**Parameters:**
- `market-id`: ID of the market
- `prediction`: Predicted outcome (true = Yes, false = No)
- `amount`: Amount of STX to stake

**Returns:** Position ID

**Example:**
```clarity
(contract-call? .prediction-market buy-position u1 true u1000000) ;; 1 STX on "Yes"
```

### `resolve-market`
Resolve a market with the final outcome (owner only).

**Parameters:**
- `market-id`: ID of the market to resolve
- `outcome`: Final outcome (true = Yes, false = No)

**Returns:** `true` on success

### `claim-winnings`
Claim winnings for a winning position.

**Parameters:**
- `position-id`: ID of the winning position

**Returns:** Payout amount

## Read-Only Functions

### `get-market`
Retrieve market information by ID.

### `get-position`
Retrieve position information by ID.

### `get-market-odds`
Get current odds for a market.

**Returns:**
```clarity
{
  yes-pool: uint,     // Total STX on "Yes"
  no-pool: uint,      // Total STX on "No"
  total-pool: uint    // Total STX in market
}
```

### `calculate-payout`
Calculate potential payout for a position.

### `is-market-active`
Check if a market is still active for trading.

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u200 | `err-owner-only` | Function restricted to contract owner |
| u201 | `err-not-found` | Market or position not found |
| u202 | `err-market-closed` | Market is closed for trading |
| u203 | `err-already-resolved` | Market already resolved |
| u204 | `err-insufficient-funds` | Insufficient funds for operation |
| u205 | `err-invalid-amount` | Invalid amount provided |
| u206 | `err-market-not-resolved` | Market not yet resolved |
| u207 | `err-already-claimed` | Winnings already claimed |
| u208 | `err-not-winner` | Position did not win |
| u209 | `err-invalid-input` | Invalid input parameters |

## Usage Example

```clarity
;; 1. Create a market (owner only)
(contract-call? .prediction-market create-market 
  "Will it rain tomorrow?" 
  "Resolves based on local weather data" 
  u144) ;; 1 day

;; 2. Buy positions
(contract-call? .prediction-market buy-position u1 true u500000)   ;; 0.5 STX on "Yes"
(contract-call? .prediction-market buy-position u1 false u1000000) ;; 1 STX on "No"

;; 3. Check market odds
(contract-call? .prediction-market get-market-odds u1)

;; 4. Resolve market (owner only, after end-block)
(contract-call? .prediction-market resolve-market u1 true) ;; It rained!

;; 5. Claim winnings
(contract-call? .prediction-market claim-winnings u1) ;; Position 1 wins
```

## Security Considerations

- All user inputs are validated before use
- STX transfers are handled securely using `stx-transfer?`
- Market resolution is restricted to contract owner
- Winners must claim their own winnings
- Positions cannot be claimed multiple times

## Static Analysis Note

This contract may show warnings about "potentially unchecked data" in static analysis tools like Clarinet. These warnings are expected and safe - all user inputs are properly validated before use. This is a known limitation of Clarinet's static analyzer and appears in most production contracts.

## Deployment

1. Deploy the contract to Stacks blockchain
2. The deployer becomes the contract owner
3. Owner can create markets and resolve them
4. Users can interact with active markets

## License

This contract is provided as-is for educational and development purposes. Use at your own risk in production environments.

## Contributing

Contributions are welcome! Please ensure all changes maintain the security properties and add appropriate tests.