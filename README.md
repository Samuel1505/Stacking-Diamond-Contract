# Diamond Staking Contract

## Overview
This project implements a Diamond Proxy-based staking contract that allows users to stake ERC-20, ERC-721, and ERC-1155 tokens in exchange for rewards. The contract manages staking, unstaking, reward distribution, and token support dynamically through a modular architecture.

## Features
- **Multi-Token Staking:** Supports ERC-20, ERC-721, and ERC-1155 token staking.
- **Rewards System:** Distributes rewards based on staking duration and contribution.
- **Diamond Standard:** Implements the Diamond Proxy pattern for upgradeability.
- **Configurable Reward Parameters:** Supports reward rate and duration modifications.
- **Secure Access Control:** Only the contract owner can modify supported tokens and reward settings.

## Contract Components
- **StakingFacet.sol:** Handles staking, unstaking, and rewards.
- **DiamondCutFacet.sol:** Manages facet upgrades following the Diamond standard.
- **MockERC20.sol, MockERC721.sol, MockERC1155.sol:** Test token implementations.

## Deployment
### Prerequisites
- [Foundry](https://github.com/foundry-rs/foundry) for testing and deployment.
- Solidity ^0.8.28.

### Steps
1. Compile contracts:
   ```sh
   forge build
   ```

   ```
2. Testing Deployment:
   ```sh
   forge t 
   ```

## Usage
### Staking ERC-20
```solidity
StakingFacet(address(diamond)).stakeERC20(tokenAddress, amount);
```

### Staking ERC-721
```solidity
StakingFacet(address(diamond)).stakeERC721(tokenAddress, tokenId);
```

### Staking ERC-1155
```solidity
StakingFacet(address(diamond)).stakeERC1155(tokenAddress, tokenId, amount);
```

### Claiming Rewards
```solidity
StakingFacet(address(diamond)).getReward();
```

## Testing
Run the test suite using:
```sh
forge test
```

## Events
- `Staked(address user, address token, uint256 amountOrId)`
- `Unstaked(address user, address token, uint256 amountOrId)`
- `RewardsClaimed(address user, uint256 amount)`
- `RewardDurationSet(uint256 duration)`
- `RewardAmountNotified(uint256 amount)`

## Security Considerations
- Only the contract owner can modify supported tokens and reward parameters.
- The contract prevents reentrancy by ensuring state updates before external calls.
- Reward rate is checked to prevent overflows and invalid configurations.

## License
This project is licensed under the MIT License.

