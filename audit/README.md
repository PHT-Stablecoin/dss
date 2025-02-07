# PHT MakerDAO Integration Security Audit Documentation

## Table of Contents

- [PHT MakerDAO Integration Security Audit Documentation](#pht-makerdao-integration-security-audit-documentation)
  - [Table of Contents](#table-of-contents)
  - [Files under audit](#files-under-audit)
  - [System Overview](#system-overview)
    - [Key Modifications](#key-modifications)
  - [Architecture](#architecture)
    - [System Components](#system-components)
  - [Core Components](#core-components)
    - [PHT Integration (`pht/`)](#pht-integration-pht)
    - [FiatToken Integration (`fiattoken/`)](#fiattoken-integration-fiattoken)
    - [Deployment System (`script/`)](#deployment-system-script)
    - [Key Deviations from MCD](#key-deviations-from-mcd)

## Files under audit

**Runtime helpers**

- pht/PHTCollateralHelper.sol
- pht/PHTTokenHelper.sol
- pht/lib/Roles.sol
- pht/lib/ArrayHelpers.sol
- pht/helpers/ProxyActions.sol
- pht/helpers/ChainlinkPip.sol
- pht/factory/PriceFeedAggregator.sol
- pht/factory/PriceJoinFeedFactory.sol
- pht/factory/PriceJoinFeedAggregator.sol
- pht/factory/PriceFeedFactory.sol

**Deployment related**

- script/PHTDeployment.s.sol
- script/PHTDeployConfig.sol
- script/PHTDeploy.sol

**Fiat Token related**

- fiattoken/MasterMinterDeployer.sol
- fiattoken/ProxyInitializer.sol
- fiattoken/FiatTokenFactory.sol
- fiattoken/TokenTypes.sol
- fiattoken/interfaces/IMasterMinterDeployer.sol
- fiattoken/interfaces/IImplementationDeployer.sol
- fiattoken/interfaces/IProxyInitializer.sol
- fiattoken/ImplementationDeployer.sol

## System Overview

This project extends MakerDAO's Multi-Collateral Dai (MCD) system to support a PHP-denominated stablecoin. The system maintains the core MCD architecture while introducing new components for PHP collateral management and price feed integration.

### Key Modifications

1. Integration with Circle's stablecoin framework for self managed token collateral
1. Custom price feed system supporting both direct and composite (join) feeds
1. Streamlined deployment process with configuration management

## Architecture

### System Components

```
MCD Core (External)                  PHT Integration                 Circle Integration
+----------------+                 +------------------+            +------------------+
|                |                 |                  |            |                  |
|   Vat          |<---------------+|  CollateralJoin  |           |   FiatToken      |
|                |                 |                  |           |                  |
+----------------+                 +------------------+            +------------------+
        ^                                   ^                              ^
        |                                   |                              |
+----------------+                 +------------------+            +------------------+
|                |                 |                  |            |                  |
|   Spotter      |<---------------+|  PriceFeed      |            |   MasterMinter   |
|                |                 |                  |            |                  |
+----------------+                 +------------------+            +------------------+
```

## Core Components

### PHT Integration (`pht/`)

1. **PHTCollateralHelper.sol**

   - Primary interface for collateral management
   - Handles collateral onboarding and configuration

2. **Price Feed System**

   - `PriceFeedAggregator.sol`: Direct price feed management
   - `PriceJoinFeedAggregator.sol`: Composite price feed handling

3. **Factory Contracts**
   - `PriceFeedFactory.sol`: Price feed deployment
   - `PriceJoinFeedFactory.sol`: Composite feed deployment

### FiatToken Integration (`fiattoken/`)

1. **FiatTokenFactory.sol**

   - Self managed collateral tokens
   - Uses Circle's [Stablecoin EVM standard](https://github.com/circlefin/stablecoin-evm)

2. **Implementation Management**
   - `ImplementationDeployer.sol`: Token implementation deployment
   - `ProxyInitializer.sol`: Proxy configuration

### Deployment System (`script/`)

1. **PHTDeploy.sol**
   - System deployment orchestration
   - Configuration management

### Key Deviations from MCD

1. **Price Feed System**

   - Enhanced aggregation capabilities
   - Support for join feeds with inverse rates:
     - `COLLAT_TOKEN:PHP` is expressed as a join of 2 Chainlink price feeds `COLLAT_TOKEN:USD` + `PHP:USD`

2. **Collateral Management**
   - PHP-specific adaptations
   - Integration with Circle's framework
