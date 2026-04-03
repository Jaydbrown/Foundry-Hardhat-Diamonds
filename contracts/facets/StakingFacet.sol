// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, StakeInfo} from "../storage/AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract StakingFacet {

    AppStorage internal s;

    event Staked(address indexed user, uint256 indexed tokenId);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event RewardClaimed(address indexed user, uint256 amount);

    function initStaking(uint256 rewardRatePerSecond) external {
        LibAppStorage.enforceIsContractOwner();
        s.rewardRatePerSecond = rewardRatePerSecond;
    }

    function stake(uint256 tokenId) external {
        require(s.erc721Owners[tokenId] == msg.sender, "Staking: not owner");
        require(!_isStaked(msg.sender, tokenId),        "Staking: already staked");
        delete s.erc721TokenApprovals[tokenId];
        s.erc721Balances[msg.sender]--;
        s.erc721Owners[tokenId] = address(this);
        s.erc721Balances[address(this)]++;
        s.stakes[msg.sender].push(StakeInfo({
            tokenId:     tokenId,
            stakedAt:    block.timestamp,
            lastClaimed: block.timestamp
        }));
        s.totalStaked++;
        emit Staked(msg.sender, tokenId);
    }

    function unstake(uint256 tokenId) external {
        (bool found, uint256 idx) = _findStake(msg.sender, tokenId);
        require(found, "Staking: not staked");
        _claimReward(msg.sender, idx);
        s.erc721Owners[tokenId] = msg.sender;
        s.erc721Balances[address(this)]--;
        s.erc721Balances[msg.sender]++;
        StakeInfo[] storage userStakes = s.stakes[msg.sender];
        userStakes[idx] = userStakes[userStakes.length - 1];
        userStakes.pop();
        s.totalStaked--;
        emit Unstaked(msg.sender, tokenId);
    }

    function claimRewards() external {
        StakeInfo[] storage userStakes = s.stakes[msg.sender];
        uint256 total;
        for (uint256 i; i < userStakes.length; i++) {
            uint256 pending = _pendingReward(userStakes[i]);
            userStakes[i].lastClaimed = block.timestamp;
            total += pending;
        }
        require(total > 0, "Staking: nothing to claim");
        s.erc20Balances[msg.sender] += total;
        s.erc20TotalSupply          += total;
        emit RewardClaimed(msg.sender, total);
    }

    function pendingRewards(address user) external view returns (uint256 total) {
        StakeInfo[] storage userStakes = s.stakes[user];
        for (uint256 i; i < userStakes.length; i++) {
            total += _pendingReward(userStakes[i]);
        }
    }

    function getStakes(address user) external view returns (StakeInfo[] memory) {
        return s.stakes[user];
    }

    function setRewardRate(uint256 rate) external {
        LibAppStorage.enforceIsContractOwner();
        s.rewardRatePerSecond = rate;
    }

    function _pendingReward(StakeInfo storage info) internal view returns (uint256) {
        return (block.timestamp - info.lastClaimed) * s.rewardRatePerSecond;
    }

    function _isStaked(address user, uint256 tokenId) internal view returns (bool) {
        StakeInfo[] storage userStakes = s.stakes[user];
        for (uint256 i; i < userStakes.length; i++) {
            if (userStakes[i].tokenId == tokenId) return true;
        }
        return false;
    }

    function _findStake(address user, uint256 tokenId) internal view returns (bool, uint256) {
        StakeInfo[] storage userStakes = s.stakes[user];
        for (uint256 i; i < userStakes.length; i++) {
            if (userStakes[i].tokenId == tokenId) return (true, i);
        }
        return (false, 0);
    }

    function _claimReward(address user, uint256 idx) internal {
        StakeInfo storage info = s.stakes[user][idx];
        uint256 pending        = _pendingReward(info);
        info.lastClaimed       = block.timestamp;
        if (pending > 0) {
            s.erc20Balances[user] += pending;
            s.erc20TotalSupply    += pending;
            emit RewardClaimed(user, pending);
        }
    }
}