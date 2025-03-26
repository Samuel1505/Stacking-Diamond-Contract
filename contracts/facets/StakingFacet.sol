// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../libraries/AppStorage.sol";

contract StakingFacet {
    event Staked(address indexed user, address token, uint256 amountOrId);
    event Unstaked(address indexed user, address token, uint256 amountOrId);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardDurationSet(uint256 duration);
    event RewardAmountNotified(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == LibAppStorage.diamondStorage().owner, "Only owner");
        _;
    }

    modifier updateReward(address _account) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.rewardPerTokenStored = rewardPerToken();
        s.updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            s.rewards[_account] = earned(_account);
            s.userRewardPerTokenPaid[_account] = s.rewardPerTokenStored;
        }
        _;
    }

    function initialize(address _owner) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.owner == address(0), "Already initialized");
        s.owner = _owner;
    }

    function addSupportedToken(address token, uint256 tokenType) external onlyOwner {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (tokenType == 20) s.supportedERC20[token] = true;
        else if (tokenType == 721) s.supportedERC721[token] = true;
        else if (tokenType == 1155) s.supportedERC1155[token] = true;
    }

    function stakeERC20(address token, uint256 amount) external updateReward(msg.sender) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.supportedERC20[token], "Unsupported ERC20");
        require(amount > 0, "Amount must be greater than 0");

        Stake storage userStake = s.stakes[msg.sender];
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userStake.erc20Amount += amount;
        s.totalStakedValue += amount;

        emit Staked(msg.sender, token, amount);
    }

    function stakeERC721(address token, uint256 tokenId) external updateReward(msg.sender) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.supportedERC721[token], "Unsupported ERC721");

        Stake storage userStake = s.stakes[msg.sender];
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        userStake.erc721Ids.push(tokenId);
        s.totalStakedValue += 1 ether;

        emit Staked(msg.sender, token, tokenId);
    }

    function stakeERC1155(address token, uint256 id, uint256 amount) external updateReward(msg.sender) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.supportedERC1155[token], "Unsupported ERC1155");
        require(amount > 0, "Amount must be greater than 0");

        Stake storage userStake = s.stakes[msg.sender];
        IERC1155(token).safeTransferFrom(msg.sender, address(this), id, amount, "");
        userStake.erc1155IdsToAmounts[id] += amount;
        s.totalStakedValue += amount * 1e15;

        emit Staked(msg.sender, token, amount);
    }

    function unstakeERC20(address token, uint256 amount) external updateReward(msg.sender) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Stake storage userStake = s.stakes[msg.sender];
        require(userStake.erc20Amount >= amount, "Insufficient staked amount");

        userStake.erc20Amount -= amount;
        s.totalStakedValue -= amount;
        IERC20(token).transfer(msg.sender, amount);

        emit Unstaked(msg.sender, token, amount);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return _min(s.finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (s.totalStakedValue == 0) {
            return s.rewardPerTokenStored;
        }
        return s.rewardPerTokenStored +
            (s.rewardRate * (lastTimeRewardApplicable() - s.updatedAt) * 1e18) / s.totalStakedValue;
    }

    function earned(address _account) public view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Stake storage userStake = s.stakes[_account];
        uint256 userStakedValue = userStake.erc20Amount +
            (userStake.erc721Ids.length * 1 ether) +
            _calculateERC1155Value(_account);
        return (
            (userStakedValue * (rewardPerToken() - s.userRewardPerTokenPaid[_account])) / 1e18
        ) + s.rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 reward = s.rewards[msg.sender];
        if (reward > 0) {
            s.rewards[msg.sender] = 0;
            s.balances[msg.sender] += reward;
            s.totalSupply += reward;
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    // Add getter for duration
    function duration() external view returns (uint256) {
        return LibAppStorage.diamondStorage().duration;
    }

   function setRewardsDuration(uint256 _duration) external onlyOwner {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.finishAt < block.timestamp, "Reward duration not finished");
        s.duration = _duration;
        emit RewardDurationSet(_duration);
    }

    function notifyRewardAmount(uint256 _amount) external onlyOwner updateReward(address(0)) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (block.timestamp >= s.finishAt) {
            s.rewardRate = _amount / s.duration;
        } else {
            uint256 remainingRewards = (s.finishAt - block.timestamp) * s.rewardRate;
            s.rewardRate = (_amount + remainingRewards) / s.duration;
        }

        require(s.rewardRate > 0, "Reward rate = 0");
        require(s.rewardRate * s.duration <= s.totalSupply + _amount, "Reward amount exceeds supply");

        s.finishAt = block.timestamp + s.duration;
        s.updatedAt = block.timestamp;
        s.totalSupply += _amount;
        s.balances[address(this)] += _amount;

        emit RewardAmountNotified(_amount);
    }

    function _calculateERC1155Value(address _account) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Stake storage userStake = s.stakes[_account];
        uint256 totalValue = 0;
        // Simplified: assumes all ERC1155 tokens have IDs mapped; in practice, iterate over known IDs
        for (uint256 i = 0; i < 100; i++) { // Arbitrary limit; adjust based on use case
            totalValue += userStake.erc1155IdsToAmounts[i] * 1e15;
        }
        return totalValue;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function balanceOf(address account) external view returns (uint256) {
        return LibAppStorage.diamondStorage().balances[account];
    }
}