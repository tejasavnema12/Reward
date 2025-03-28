// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
//we need to pass the address of the nitrotoken
//added functionality of wallet and user can spend the reward and the wallet is updated automatically 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardVesting is Ownable {
    IERC20 public rewardToken;

    struct Reward {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffTime;
        uint256 vestingDuration;
    }

    mapping(address => Reward[]) public rewards;
    mapping(address => uint256) public availableBalance;

    event RewardDistributed(address indexed beneficiary, uint256 amount, uint256 startTime, uint256 cliffTime, uint256 vestingDuration);
    event RewardClaimed(address indexed beneficiary, uint256 amount, uint256 index);
    event RewardSpent(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _rewardToken) Ownable(msg.sender) {
        require(address(_rewardToken) != address(0), "Invalid token address");
        rewardToken = _rewardToken;
    }

    function distributeReward(
        address _beneficiary,
        uint256 _amount,
        uint256 _cliffTime,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(_beneficiary != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater than 0");
        require(
            rewardToken.balanceOf(address(this)) >= _amount,
            "Insufficient contract balance"
        );
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");

        uint256 startTime = block.timestamp;
        rewards[_beneficiary].push(
            Reward({
                totalAmount: _amount,
                releasedAmount: 0,
                startTime: startTime,
                cliffTime: startTime + _cliffTime,
                vestingDuration: _vestingDuration
            })
        );

        emit RewardDistributed(_beneficiary, _amount, startTime, _cliffTime, _vestingDuration);
    }

    function claimReward(uint256 index) external {
        require(index < rewards[msg.sender].length, "Invalid reward index");

        Reward storage reward = rewards[msg.sender][index];
        require(block.timestamp >= reward.cliffTime, "Cliff period not passed");

        uint256 elapsedTime = block.timestamp - reward.startTime;
        if (elapsedTime > reward.vestingDuration) {
            elapsedTime = reward.vestingDuration;
        }

        uint256 vestedAmount = (reward.totalAmount * elapsedTime) / reward.vestingDuration;
        uint256 claimableAmount = vestedAmount - reward.releasedAmount;
        require(claimableAmount > 0, "No rewards available to claim");

        reward.releasedAmount += claimableAmount;
        availableBalance[msg.sender] += claimableAmount; // Add to available balance

        emit RewardClaimed(msg.sender, claimableAmount, index);
    }

    function spendReward(uint256 amount) external {
        require(availableBalance[msg.sender] >= amount, "Insufficient balance");
        availableBalance[msg.sender] -= amount;
        require(rewardToken.transfer(msg.sender, amount), "Token transfer failed");
        emit RewardSpent(msg.sender, amount);
    }

    function getRewards(address _wallet) external view returns (Reward[] memory) {
        return rewards[_wallet];
    }

    function getAvailableBalance(address _wallet) external view returns (uint256) {
        return availableBalance[_wallet];
    }
}
