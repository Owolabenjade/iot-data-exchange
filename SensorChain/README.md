# IoT Sensor Data Marketplace Smart Contract

The IoT Sensor Data Marketplace is a decentralized platform built on Stacks blockchain using Clarity smart contracts. It enables IoT device owners to monetize their sensor data while providing data buyers with verified, quality-assured environmental data through a transparent and automated marketplace.

## Features

### Core Functionality
- Sensor registration with stake-based verification
- Tiered subscription system (Bronze, Silver, Gold)
- Quality-scored data submissions
- Automated payment distribution
- Access control for different data tiers
- Data integrity verification through hashing

### Key Components

#### Sensor Management
- Sensor registration with required staking
- Sensor deactivation with stake return
- Quality score tracking
- Location and sensor type metadata storage

#### Data Management
- Secure data submission with hash verification
- Quality score calculation for submitted data
- Metadata storage for each data point
- Pricing mechanism based on quality and tier

#### Subscription System
- Three-tier subscription model (Bronze, Silver, Gold)
- Time-based subscription validity
- Tier-based pricing
- Automatic subscription status tracking

#### Access Control
- Time-limited data access rights
- Tier-based access restrictions
- Automated access verification

## Technical Specifications

### Constants
```clarity
BRONZE (u1)
SILVER (u2)
GOLD (u3)
MIN-STAKE-AMOUNT (u1000)
MIN-QUALITY-SCORE (u60)
MINIMUM-PRICE (u100)
```

### Data Maps
1. `sensors`: Stores sensor registration details
   - sensor-id (uint)
   - owner (principal)
   - stake-amount (uint)
   - registration-time (uint)
   - sensor-type (string-utf8)
   - location (string-utf8)
   - active (bool)
   - quality-score (uint)

2. `sensor-data`: Stores sensor readings
   - data-hash (buff 32)
   - quality-score (uint)
   - price (uint)
   - metadata (string-utf8)

3. `subscriptions`: Manages buyer subscriptions
   - tier (uint)
   - expiry (uint)
   - active (bool)

4. `data-access`: Controls data access rights
   - access-until (uint)
   - tier (uint)

## Usage Guide

### For Sensor Owners

1. Register a Sensor:
```clarity
(contract-call? 
    .iot-marketplace 
    register-sensor 
    u1 
    "air-quality" 
    "40.7128,-74.0060")
```

2. Submit Sensor Data:
```clarity
(contract-call? 
    .iot-marketplace 
    submit-sensor-data 
    u1 
    0x4f3ea7 
    u1000 
    "temperature:22.5,humidity:65")
```

3. Deactivate Sensor:
```clarity
(contract-call? 
    .iot-marketplace 
    deactivate-sensor 
    u1)
```

### For Data Buyers

1. Purchase Subscription:
```clarity
(contract-call? 
    .iot-marketplace 
    purchase-subscription 
    GOLD 
    u1000)
```

2. Purchase Data Access:
```clarity
(contract-call? 
    .iot-marketplace 
    purchase-data-access 
    u1 
    u100)
```

### Read-Only Functions

1. Check Sensor Information:
```clarity
(contract-call? 
    .iot-marketplace 
    get-sensor-info 
    u1)
```

2. Verify Data Access:
```clarity
(contract-call? 
    .iot-marketplace 
    check-data-access 
    tx-sender 
    u1)
```

## Error Codes

- `ERR-UNAUTHORIZED (u401)`: Access denied or unauthorized operation
- `ERR-INVALID-PARAMS (u400)`: Invalid parameters provided
- `ERR-NOT-FOUND (u404)`: Requested resource not found
- `ERR-INSUFFICIENT-FUNDS (u402)`: Insufficient funds for operation

## Quality Scoring System

The quality score is calculated based on:
- Historical data consistency
- Sensor uptime
- Data volume
- Cross-validation with nearby sensors
- Sensor calibration status

Current implementation uses a simplified scoring system that can be enhanced based on specific requirements.

## Platform Economics

### Fees and Payments
- Platform fee: 5% (50 basis points)
- Minimum stake amount: 1000 STX
- Subscription pricing varies by tier
- Data access pricing is set by sensor owners

### Staking Mechanism
- Sensors require minimum stake to participate
- Stake is locked during active registration
- Stake is returned upon proper deactivation
- Stake may be slashed for malicious behavior

## Security Considerations

1. Access Control
   - All sensitive functions verify caller identity
   - Subscription-based access control
   - Time-limited access rights

2. Data Integrity
   - Data hashing for verification
   - Quality scoring mechanism
   - Stake-based accountability

3. Economic Security
   - Minimum stake requirements
   - Minimum pricing thresholds
   - Tiered access control

## Future Enhancements

1. Advanced Quality Scoring
   - Implementation of machine learning-based scoring
   - Cross-validation with trusted oracles
   - Real-time quality adjustments

2. Enhanced Data Access
   - Granular data access controls
   - Time-series data aggregation
   - Custom data formats and protocols

3. Economic Incentives
   - Dynamic pricing models
   - Reward mechanisms for high-quality data
   - Staking rewards for long-term participants

## Best Practices for Integration

1. Data Submission
   - Regular submission intervals
   - Proper metadata formatting
   - Quality score monitoring

2. Access Management
   - Regular subscription renewal
   - Proper access right verification
   - Efficient data retrieval patterns

3. Error Handling
   - Proper error code handling
   - Transaction retry mechanisms
   - State verification before operations

## Support and Development

For questions, issues, or contributions:
- Review the Clarity documentation
- Test thoroughly on testnet before mainnet deployment
- Follow secure smart contract development practices
- Consider audit requirements for production deployment