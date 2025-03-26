// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

struct Stake {
    uint256 erc20Amount; // Total ERC20 staked
    uint256[] erc721Ids; // Array of ERC721 token IDs
    mapping(uint256 => uint256) erc1155IdsToAmounts; // ERC1155 ID => amount
}

struct AppStorage {
    string name;
    string symbol;
    uint8 decimals;
    uint256 totalSupply;
    address owner;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) approves;
    mapping(address => mapping(address => uint256)) allowances;
    // Staking-related state
    mapping(address => Stake) stakes;
    mapping(address => bool) supportedERC20;
    mapping(address => bool) supportedERC721;
    mapping(address => bool) supportedERC1155;
    uint256 duration; // Duration of rewards in seconds
    uint256 finishAt; // Timestamp when rewards finish
    uint256 updatedAt; // Last update timestamp
    uint256 rewardRate; // Rewards per second
    uint256 rewardPerTokenStored; // Cumulative reward per staked token
    mapping(address => uint256) userRewardPerTokenPaid; // User’s last paid reward per token
    mapping(address => uint256) rewards; // Rewards claimable by user
    uint256 totalStakedValue; // Total staked value (normalized)
}

library LibAppStorage {
    bytes32 constant STORAGE_POSITION = keccak256("diamond.standard.appstorage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}