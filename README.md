# Supply Chain Provenance Tracker
### Supply Chain Sentinel

A Clarity smart contract for immutable supply chain provenance tracking using Non-Fungible Tokens (NFTs). This contract provides a transparent, tamper-proof audit trail for manufacturing assets from source to final product.

## Overview

Supply Chain Sentinel creates a blockchain-based provenance system where:
- Each asset or batch is represented as a unique NFT
- Every custody transfer is recorded with metadata (location, timestamp, notes)
- Only authorized participants can handle assets
- All transactions create an immutable audit trail

## Features

- **NFT-Based Asset Tracking**: Each supply chain item is a unique NFT
- **Immutable Provenance Log**: Complete history of custody transfers
- **Participant Management**: Role-based access control for supply chain actors
- **Metadata Recording**: Location and notes for each transfer
- **Input Validation**: Robust validation of all user inputs
- **Event Logging**: Blockchain events for external monitoring

## Contract Architecture

### Core Components

1. **NFT Management**: Uses Clarity's built-in NFT functionality
2. **Provenance Logging**: Stores up to 50 log entries per item
3. **Participant Registry**: Manages authorized supply chain actors
4. **Access Control**: Owner-controlled participant management

### Data Structures

```clarity
;; NFT for tracked items
(define-non-fungible-token supply-item uint)

;; Provenance log entry structure
{
  custodian: principal,
  timestamp-burn-height: uint,
  location: (string-ascii 64),
  notes: (string-ascii 128)
}
```

## Installation & Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) 0.31.1 or compatible
- [Stacks CLI](https://docs.stacks.co/references/stacks-cli)

### Local Development

1. Clone the repository:
```bash
git clone <repository-url>
cd supply-chain-sentinel
```

2. Initialize Clarinet project (if not already done):
```bash
clarinet new supply-chain-project
cd supply-chain-project
```

3. Add the contract:
```bash
# Copy supply-chain-sentinel.clar to contracts/
cp ../supply-chain-sentinel.clar contracts/
```

4. Check contract syntax:
```bash
clarinet check
```

5. Run tests:
```bash
clarinet test
```

## Usage Guide

### Contract Deployment

The contract is deployed with the deployer automatically set as the contract owner.

### Core Functions

#### 1. Participant Management (Owner Only)

**Register a new participant:**
```clarity
(contract-call? .supply-chain-sentinel register-participant 'SP1PARTICIPANT...)
```

**Remove a participant:**
```clarity
(contract-call? .supply-chain-sentinel deregister-participant 'SP1PARTICIPANT...)
```

#### 2. Item Registration (Participants Only)

**Register a new supply chain item:**
```clarity
(contract-call? .supply-chain-sentinel register-new-item 
  "Factory Floor A" 
  "Initial production batch #1001")
```

Returns: `(ok item-id)` where `item-id` is the unique identifier

#### 3. Custody Transfer (Item Owner Only)

**Transfer item to another participant:**
```clarity
(contract-call? .supply-chain-sentinel transfer-custody 
  u1                           ;; item-id
  'SP1NEWCUSTODIAN...         ;; new-custodian
  "Distribution Center B"      ;; new-location
  "Quality check passed")      ;; transfer-notes
```

### Read-Only Functions

#### Check Item Ownership
```clarity
(contract-call? .supply-chain-sentinel get-item-owner u1)
```

#### Get Provenance History
```clarity
(contract-call? .supply-chain-sentinel get-provenance-log u1)
```

#### Check Participant Status
```clarity
(contract-call? .supply-chain-sentinel is-participant-registered 'SP1PARTICIPANT...)
```

#### Get Contract Stats
```clarity
;; Get total number of items registered
(contract-call? .supply-chain-sentinel get-last-item-id)

;; Check if an item exists
(contract-call? .supply-chain-sentinel item-exists u1)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 200 | `ERR_UNAUTHORIZED` | Caller lacks required permissions |
| 201 | `ERR_ITEM_NOT_FOUND` | Item ID does not exist |
| 202 | `ERR_NOT_OWNER` | Caller is not the item owner |
| 203 | `ERR_PARTICIPANT_ALREADY_REGISTERED` | Participant already exists |
| 204 | `ERR_PARTICIPANT_NOT_REGISTERED` | Participant not found |
| 205 | `ERR_INVALID_CUSTODIAN` | Cannot transfer to self |
| 206 | `ERR_METADATA_TOO_LONG` | String input exceeds limits |
| 207 | `ERR_EMPTY_STRING` | Required string is empty |
| 208 | `ERR_LOG_FULL` | Provenance log at maximum capacity |

## Input Validation

The contract enforces strict input validation:

- **Location strings**: 1-64 characters, non-empty
- **Notes strings**: 1-128 characters, non-empty
- **Provenance log**: Maximum 50 entries per item
- **Participant validation**: All custodians must be registered

## Events

The contract emits structured events for monitoring:

### Item Registration
```json
{
  "type": "provenance",
  "event": "item-registered", 
  "item-id": 1,
  "custodian": "SP1CREATOR..."
}
```

### Custody Transfer
```json
{
  "type": "provenance",
  "event": "custody-transferred",
  "item-id": 1,
  "from": "SP1OLDOWNER...",
  "to": "SP1NEWOWNER..."
}
```

## Security Considerations

### Access Control
- **Contract Owner**: Can manage participants only
- **Participants**: Can register items and transfer owned items
- **Item Owners**: Can transfer their specific items only

### Data Integrity
- All inputs are validated before storage
- Provenance logs are append-only (immutable)
- NFT ownership enforces custody rules
- Empty or invalid strings are rejected

### Limitations
- Maximum 50 log entries per item
- String fields have size limits (location: 64, notes: 128)
- No deletion of log entries (by design)

## Use Cases

### Manufacturing
- Track raw materials through production
- Record quality control checkpoints
- Verify authentic components

### Food Industry
- Farm-to-table provenance
- Cold chain monitoring
- Regulatory compliance tracking

### Pharmaceuticals
- Drug authenticity verification
- Supply chain integrity
- Batch recall management

### Luxury Goods
- Anti-counterfeiting measures
- Authenticity certificates
- Ownership history

## Testing

### Sample Test Scenarios

1. **Participant Management**
   - Register/deregister participants
   - Unauthorized access attempts
   - Duplicate registrations

2. **Item Lifecycle**
   - Item registration by participants
   - Multiple custody transfers
   - Invalid transfer attempts

3. **Input Validation**
   - Empty string rejection
   - Maximum length enforcement
   - Log capacity limits

4. **Access Control**
   - Owner-only functions
   - Participant-only functions
   - Item owner transfers

### Running Tests

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/supply-chain-test.ts

# Check contract without warnings
clarinet check
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure `clarinet check` passes without warnings
5. Submit a pull request

## License

[Add your license here]

## Support

For questions or issues:
- Create an issue in the repository
- Review the error codes section
- Check the Clarity documentation

## Changelog

### v1.1.0 (Current)
- ✅ Fixed all clarinet check warnings
- ✅ Added comprehensive input validation
- ✅ Enhanced error handling
- ✅ Added utility read-only functions
- ✅ Improved code robustness

### v1.0.0
- Initial contract implementation
- Basic NFT and provenance functionality
- Participant management system