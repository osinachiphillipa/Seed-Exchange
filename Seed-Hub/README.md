# Decentralized Seed Marketplace Smart Contract

A comprehensive Clarity smart contract for the Stacks blockchain that enables a decentralized marketplace for buying and selling seeds with built-in quality assurance, reputation systems, and dispute resolution.

## Overview

This smart contract creates a trustless marketplace where sellers can list various types of seeds and buyers can purchase them with confidence through an escrow system, seller staking mechanism, and community-driven rating system.

## Key Features

### **Seed Listings**
- Create detailed seed listings with variety, description, and growing information
- Include germination rates, harvest times, and organic certification status
- Set expiration dates and manage inventory automatically

### **Escrow & Payment System**
- Secure escrow holds buyer payments until delivery confirmation
- Automatic fee calculation and distribution
- Marketplace fee system (default 2.5%)

### **Seller Staking**
- Sellers must stake STX tokens to build trust
- Minimum stake requirement (default 1 STX)
- Stake withdrawal with minimum balance protection

### **Reputation System**
- Buyer and seller rating system (1-5 stars)
- Aggregate seller profiles with average ratings
- Review system with detailed feedback

### **Dispute Resolution**
- Built-in dispute creation and resolution system
- Contract owner arbitration
- Evidence submission and fair resolution process

### **Order Management**
- Complete order lifecycle tracking
- Status updates: Active → Sold → Shipped → Delivered → Completed
- Shipping address management

## Contract Architecture

### Data Structures

#### Seed Listings
```clarity
{
    seller: principal,
    seed-type: string,
    variety: string,
    description: string,
    price-per-unit: uint,
    available-quantity: uint,
    germination-rate: uint,
    harvest-time: uint,
    organic-certified: bool,
    created-at: uint,
    expires-at: uint,
    status: uint
}
```

#### Orders
```clarity
{
    listing-id: uint,
    buyer: principal,
    seller: principal,
    quantity: uint,
    total-price: uint,
    shipping-address: string,
    created-at: uint,
    shipped-at: optional uint,
    delivered-at: optional uint,
    status: uint
}
```

#### Seller Profiles
```clarity
{
    total-sales: uint,
    total-ratings: uint,
    average-rating: uint,
    stake-amount: uint,
    reputation-score: uint,
    joined-at: uint
}
```

## Usage Guide

### For Sellers

#### 1. Register as a Seller
```clarity
(contract-call? .seed-marketplace register-seller u1000000) ;; Stake 1 STX
```

#### 2. Create a Seed Listing
```clarity
(contract-call? .seed-marketplace create-listing
    "Tomato"                    ;; seed-type
    "Cherry Roma"               ;; variety
    "Organic cherry tomatoes"   ;; description
    u50000                      ;; price per unit (0.05 STX)
    u100                        ;; available quantity
    u85                         ;; germination rate (85%)
    u75                         ;; harvest time (75 days)
    true                        ;; organic certified
    u1000                       ;; expires in 1000 blocks
)
```

#### 3. Manage Orders
```clarity
;; Mark order as shipped
(contract-call? .seed-marketplace mark-shipped u1)

;; Withdraw stake (maintaining minimum)
(contract-call? .seed-marketplace withdraw-stake u500000)
```

### For Buyers

#### 1. Purchase Seeds
```clarity
(contract-call? .seed-marketplace purchase-seeds
    u1                          ;; listing-id
    u10                         ;; quantity
    "123 Farm Road, City, State" ;; shipping address
)
```

#### 2. Confirm Delivery
```clarity
(contract-call? .seed-marketplace confirm-delivery u1) ;; order-id
```

#### 3. Rate the Transaction
```clarity
(contract-call? .seed-marketplace rate-order
    u1                          ;; order-id
    u5                          ;; rating (5 stars)
    "Excellent quality seeds!"  ;; review
)
```

### Dispute Process

#### Create a Dispute
```clarity
(contract-call? .seed-marketplace create-dispute
    u1                          ;; order-id
    "Seeds did not germinate"   ;; reason
    "Planted 20 seeds, only 2 sprouted after 2 weeks" ;; evidence
)
```

## Order Status Flow

```
STATUS-ACTIVE (0) → STATUS-SOLD (1) → STATUS-SHIPPED (2) → STATUS-DELIVERED (3) → STATUS-COMPLETED (4)
                                                     ↓
                                               STATUS-DISPUTED (5)
```

## Read-Only Functions

### Query Listings and Orders
- `get-listing(listing-id)` - Get listing details
- `get-order(order-id)` - Get order information
- `get-seller-profile(seller)` - Get seller reputation data
- `get-rating(order-id, rater)` - Get specific rating
- `get-dispute(dispute-id)` - Get dispute details

### Check Balances and Settings
- `get-escrow-balance(order-id)` - Check escrowed funds
- `get-seller-stake(seller)` - Check seller's stake
- `get-marketplace-fee-rate()` - Current fee rate
- `calculate-marketplace-fee(amount)` - Calculate fees

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-OWNER-ONLY | Function restricted to contract owner |
| 101 | ERR-NOT-FOUND | Resource not found |
| 102 | ERR-INSUFFICIENT-FUNDS | Insufficient balance |
| 103 | ERR-UNAUTHORIZED | Unauthorized access |
| 104 | ERR-INVALID-AMOUNT | Invalid amount specified |
| 105 | ERR-ALREADY-EXISTS | Resource already exists |
| 106 | ERR-INVALID-STATUS | Invalid status for operation |
| 107 | ERR-EXPIRED | Listing or offer expired |
| 108 | ERR-INVALID-RATING | Rating outside valid range |
| 109 | ERR-ALREADY-RATED | Already rated this order |
| 110 | ERR-DISPUTE-EXISTS | Dispute already exists |
| 111 | ERR-INVALID-RESOLUTION | Invalid dispute resolution |

## Administrative Functions

### Fee Management
```clarity
;; Update marketplace fee (max 10%)
(contract-call? .seed-marketplace set-marketplace-fee-rate u300) ;; 3%

;; Update minimum stake requirement
(contract-call? .seed-marketplace set-min-stake-amount u2000000) ;; 2 STX
```

### Dispute Resolution
```clarity
;; Resolve dispute (contract owner only)
(contract-call? .seed-marketplace resolve-dispute
    u1                          ;; dispute-id
    "Refund approved due to quality issues"
    true                        ;; refund-to-buyer
)
```

## Security Features

- **Seller Staking**: Requires sellers to lock funds, ensuring commitment
- **Escrow System**: Protects buyer funds until delivery confirmation
- **Multi-party Rating**: Both buyers and sellers can rate transactions
- **Dispute Arbitration**: Built-in resolution mechanism
- **Access Controls**: Function-level permissions and validations

## Development and Testing

### Prerequisites
- Stacks blockchain development environment
- Clarity CLI tools
- STX tokens for testing