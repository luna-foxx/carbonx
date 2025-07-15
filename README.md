# CarbonX - Carbon Credit Trading Smart Contract

A comprehensive smart contract for trading verified carbon offset certificates on the Stacks blockchain, built with Clarity.

## Overview

CarbonX enables the creation, verification, and trading of carbon offset certificates as digital assets. The contract provides a secure marketplace for carbon credits with proper verification mechanisms and transparent trading.

## Features

### Core Functionality
- **Certificate Issuance**: Create new carbon offset certificates with project details
- **Verification System**: Authorized verifiers can validate certificates
- **Marketplace Trading**: List and buy certificates with STX payments
- **Direct Transfers**: Send certificates to other users
- **Certificate Retirement**: Remove certificates from circulation after use

### Security Features
- Ownership validation for all operations
- Comprehensive error handling
- Prevention of self-trading
- Automatic marketplace cleanup
- Platform fee collection

## Contract Architecture

### Data Structures

#### Certificates
```clarity
{
  issuer: principal,
  project-name: (string-ascii 100),
  project-location: (string-ascii 100),
  carbon-amount: uint, // in tons CO2
  verification-standard: (string-ascii 50),
  issuance-date: uint,
  expiry-date: uint,
  verified: bool,
  retired: bool
}
```

#### Marketplace Listings
```clarity
{
  seller: principal,
  price: uint, // in microSTX
  listed-at: uint
}
```

## Usage Guide

### 1. Certificate Issuance

Project owners can issue new certificates:

```clarity
(contract-call? .carbonx issue-certificate 
  "Solar Farm Project Alpha" 
  "California, USA" 
  u1000 
  "VCS" 
  u1000000)
```

### 2. Certificate Verification

Only authorized verifiers can verify certificates:

```clarity
(contract-call? .carbonx verify-certificate u1)
```

### 3. Marketplace Trading

List a certificate for sale:
```clarity
(contract-call? .carbonx list-certificate-for-sale u1 u5000000)
```

Buy a certificate:
```clarity
(contract-call? .carbonx buy-certificate u1)
```

### 4. Direct Transfers

Transfer certificates directly:
```clarity
(contract-call? .carbonx transfer-certificate-to u1 'SP1PRINCIPAL...)
```

### 5. Certificate Retirement

Remove certificates from circulation:
```clarity
(contract-call? .carbonx retire-certificate u1)
```

## Read-Only Functions

### Certificate Information
- `(get-certificate certificate-id)` - Get certificate details
- `(get-certificate-owner certificate-id)` - Get certificate owner
- `(get-marketplace-listing certificate-id)` - Get listing details

### User Information
- `(get-user-balance user)` - Get user's certificate count
- `(is-verifier user)` - Check if user is authorized verifier

### Contract Information
- `(get-platform-fee-percentage)` - Current platform fee
- `(get-next-certificate-id)` - Next certificate ID
- `(calculate-platform-fee amount)` - Calculate fee for amount

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Certificate not found |
| u102 | Insufficient balance |
| u103 | Invalid amount |
| u104 | Certificate not verified |
| u105 | Already verified |
| u106 | Invalid price |
| u107 | Self-trade attempted |
| u108 | Certificate not for sale |

## Admin Functions

### Verifier Management
```clarity
(contract-call? .carbonx add-verifier 'SP1VERIFIER...)
(contract-call? .carbonx remove-verifier 'SP1VERIFIER...)
```

### Platform Fee Management
```clarity
(contract-call? .carbonx set-platform-fee u300) // 3%
```

## Trading Workflow

1. **Project Registration**: Organizations issue certificates for their carbon offset projects
2. **Verification**: Authorized third parties verify the certificates
3. **Marketplace**: Verified certificates can be listed for sale
4. **Trading**: Buyers purchase certificates with STX payments
5. **Usage**: Certificate owners can retire certificates to claim carbon offsets

## Platform Economics

- **Platform Fee**: Default 2.5% on all marketplace transactions
- **Fee Distribution**: Platform fees go to contract owner
- **Payment Method**: All transactions use STX (microSTX)

## Testing

### Prerequisites
- Clarinet installed
- Node.js and npm/yarn

### Running Tests
```bash
# Check contract syntax
clarinet check

# Run unit tests
clarinet test

# Start local devnet
clarinet integrate
```

### Test Scenarios
- Certificate issuance and verification
- Marketplace listing and buying
- Direct transfers
- Certificate retirement
- Error handling

## Deployment

### Testnet Deployment
```bash
clarinet deploy --testnet
```

### Mainnet Deployment
```bash
clarinet deploy --mainnet
```

## Integration Guide

### Frontend Integration
```javascript
// Example using @stacks/connect
import { openContractCall } from '@stacks/connect';

const issueCarbon = async (projectName, location, amount) => {
  await openContractCall({
    contractAddress: 'SP1CONTRACT...',
    contractName: 'carbonx',
    functionName: 'issue-certificate',
    functionArgs: [
      stringAsciiCV(projectName),
      stringAsciiCV(location),
      uintCV(amount),
      stringAsciiCV('VCS'),
      uintCV(futureBlockHeight)
    ]
  });
};
```

### Backend Integration
```javascript
// Example using @stacks/transactions
import { makeContractCall } from '@stacks/transactions';

const verifyCarbon = async (certificateId) => {
  const txOptions = {
    contractAddress: 'SP1CONTRACT...',
    contractName: 'carbonx',
    functionName: 'verify-certificate',
    functionArgs: [uintCV(certificateId)]
  };
  
  const transaction = await makeContractCall(txOptions);
  // Broadcast transaction
};
```