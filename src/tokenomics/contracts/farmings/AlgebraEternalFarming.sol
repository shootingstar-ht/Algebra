// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

import './EternalVirtualPool.sol';
import '../libraries/IncentiveId.sol';
import '../libraries/NFTPositionInfo.sol';
import '../interfaces/IAlgebraEternalFarming.sol';
import '../interfaces/IAlgebraEternalVirtualPool.sol';
import '../interfaces/IFarmingCenter.sol';

import '@alkaswap/core/contracts/interfaces/IAlgebraPoolDeployer.sol';
import '@alkaswap/core/contracts/interfaces/IAlgebraPool.sol';
import '@alkaswap/core/contracts/interfaces/IAlgebraFactory.sol';
import '@alkaswap/core/contracts/interfaces/IERC20Minimal.sol';
import '@alkaswap/core/contracts/libraries/SafeCast.sol';
import '@alkaswap/core/contracts/libraries/FullMath.sol';
import '@alkaswap/core/contracts/libraries/Constants.sol';
import '@alkaswap/core/contracts/libraries/TickMath.sol';
import '@alkaswap/core/contracts/libraries/LowGasSafeMath.sol';

import '@alkaswap/periphery/contracts/libraries/TransferHelper.sol';

/// @title Algebra eternal (v2-like) farming
contract AlgebraEternalFarming is IAlgebraEternalFarming {
  using SafeCast for int256;
  using LowGasSafeMath for uint256;
  using LowGasSafeMath for uint128;

  /// @notice Represents a farming incentive
  struct Incentive {
    uint128 totalReward;
    uint128 bonusReward;
    address virtualPoolAddress;
    uint24 minimalPositionWidth;
    bool deactivated;
  }

  /// @notice Represents the farm for nft
  struct Farm {
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
    uint256 innerRewardGrowth0;
    uint256 innerRewardGrowth1;
  }

  /// @inheritdoc IAlgebraEternalFarming
  INonfungiblePositionManager public immutable override nonfungiblePositionManager;

  IAlgebraPoolDeployer private immutable deployer;
  IAlgebraFactory private immutable factory;

  IFarmingCenter public farmingCenter;

  /// @dev bytes32 refers to the return value of IncentiveId.compute
  /// @inheritdoc IAlgebraEternalFarming
  mapping(bytes32 => Incentive) public override incentives;

  /// @dev farms[tokenId][incentiveHash] => Farm
  /// @inheritdoc IAlgebraEternalFarming
  mapping(uint256 => mapping(bytes32 => Farm)) public override farms;

  uint256 public numOfIncentives;

  bytes32 public constant INCENTIVE_MAKER_ROLE = keccak256('INCENTIVE_MAKER_ROLE');
  bytes32 public constant FARMINGS_ADMINISTRATOR_ROLE = keccak256('FARMINGS_ADMINISTRATOR_ROLE');

  /// @dev rewards[owner][rewardToken] => uint256
  /// @inheritdoc IAlgebraEternalFarming
  mapping(address => mapping(IERC20Minimal => uint256)) public override rewards;

  modifier onlyIncentiveMaker() {
    _checkHasRole(INCENTIVE_MAKER_ROLE);
    _;
  }

  modifier onlyAdministrator() {
    _checkHasRole(FARMINGS_ADMINISTRATOR_ROLE);
    _;
  }

  modifier onlyFarmingCenter() {
    _checkIsFarmingCenter();
    _;
  }

  /// @param _deployer pool deployer contract address
  /// @param _nonfungiblePositionManager the NFT position manager contract address
  constructor(IAlgebraPoolDeployer _deployer, INonfungiblePositionManager _nonfungiblePositionManager) {
    (deployer, nonfungiblePositionManager) = (_deployer, _nonfungiblePositionManager);
    factory = IAlgebraFactory(_nonfungiblePositionManager.factory());
  }

  /// @inheritdoc IAlgebraEternalFarming
  function isIncentiveActiveInPool(bytes32 incentiveId, IAlgebraPool pool) external view override returns (bool res) {
    Incentive storage incentive = incentives[incentiveId];
    if (incentive.deactivated) return false;

    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentive.virtualPoolAddress);
    if (_getCurrentVirtualPool(pool) != address(virtualPool)) return false; // pool can "detach" by itself

    return true;
  }

  function _checkIsFarmingCenter() internal view {
    require(msg.sender == address(farmingCenter));
  }

  function _checkHasRole(bytes32 role) internal view {
    require(factory.hasRoleOrOwner(role, msg.sender));
  }

  /// @inheritdoc IAlgebraEternalFarming
  function createEternalFarming(
    IncentiveKey memory key,
    IncentiveParams memory params
  ) external override onlyIncentiveMaker returns (address virtualPool) {
    if (_getCurrentVirtualPool(key.pool) != address(0)) revert farmingAlreadyExists();

    virtualPool = address(new EternalVirtualPool(address(this), address(key.pool)));
    _connectPoolToVirtualPool(key.pool, virtualPool);

    key.nonce = numOfIncentives++;
    bytes32 incentiveId = IncentiveId.compute(key);
    Incentive storage newIncentive = incentives[incentiveId];

    (params.reward, params.bonusReward) = _receiveRewards(key, params.reward, params.bonusReward, newIncentive);
    if (params.reward == 0) revert zeroRewardAmount();

    unchecked {
      if (int256(uint256(params.minimalPositionWidth)) > (int256(TickMath.MAX_TICK) - int256(TickMath.MIN_TICK)))
        revert minimalPositionWidthTooWide();
    }
    (newIncentive.virtualPoolAddress, newIncentive.minimalPositionWidth) = (virtualPool, params.minimalPositionWidth);

    emit EternalFarmingCreated(
      key.rewardToken,
      key.bonusRewardToken,
      key.pool,
      virtualPool,
      key.nonce,
      params.reward,
      params.bonusReward,
      params.minimalPositionWidth
    );

    _addRewards(IAlgebraEternalVirtualPool(virtualPool), params.reward, params.bonusReward, incentiveId);
    _setRewardRates(IAlgebraEternalVirtualPool(virtualPool), params.rewardRate, params.bonusRewardRate, incentiveId);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function deactivateIncentive(IncentiveKey memory key) external override onlyIncentiveMaker {
    (bytes32 incentiveId, Incentive storage incentive) = _getIncentiveByKey(key);
    if (incentive.deactivated) revert incentiveStopped();

    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentive.virtualPoolAddress);
    if (address(virtualPool) == address(0)) revert incentiveNotExist();

    incentive.deactivated = true;

    (uint128 rewardRate0, uint128 rewardRate1) = virtualPool.rewardRates();
    if (rewardRate0 | rewardRate1 != 0) _setRewardRates(virtualPool, 0, 0, incentiveId);

    if (address(virtualPool) == _getCurrentVirtualPool(key.pool)) {
      _connectPoolToVirtualPool(key.pool, address(0));
    }
    emit IncentiveDeactivated(incentiveId);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function decreaseRewardsAmount(IncentiveKey memory key, uint128 rewardAmount, uint128 bonusRewardAmount) external override onlyAdministrator {
    (bytes32 incentiveId, Incentive storage incentive) = _getIncentiveByKey(key);
    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentive.virtualPoolAddress);

    virtualPool.distributeRewards();
    (uint128 rewardReserve0, uint128 rewardReserve1) = virtualPool.rewardReserves();
    if (rewardAmount > rewardReserve0) rewardAmount = rewardReserve0;
    if (rewardAmount >= incentive.totalReward) rewardAmount = incentive.totalReward - 1; // to not trigger 'non-existent incentive'
    incentive.totalReward = incentive.totalReward - rewardAmount;

    if (bonusRewardAmount > rewardReserve1) bonusRewardAmount = rewardReserve1;
    incentive.bonusReward = incentive.bonusReward - bonusRewardAmount;

    virtualPool.decreaseRewards(rewardAmount, bonusRewardAmount);

    if (rewardAmount > 0) TransferHelper.safeTransfer(address(key.rewardToken), msg.sender, rewardAmount);
    if (bonusRewardAmount > 0) TransferHelper.safeTransfer(address(key.bonusRewardToken), msg.sender, bonusRewardAmount);

    emit RewardAmountsDecreased(rewardAmount, bonusRewardAmount, incentiveId);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function setFarmingCenterAddress(address _farmingCenter) external override onlyAdministrator {
    require(_farmingCenter != address(farmingCenter));
    farmingCenter = IFarmingCenter(_farmingCenter);
    emit FarmingCenter(_farmingCenter);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function addRewards(IncentiveKey memory key, uint128 rewardAmount, uint128 bonusRewardAmount) external override {
    (bytes32 incentiveId, Incentive storage incentive) = _getIncentiveByKey(key);
    if (incentive.deactivated) revert incentiveStopped();

    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentive.virtualPoolAddress);
    if (_getCurrentVirtualPool(key.pool) != address(virtualPool)) revert incentiveStopped(); // pool can "detach" by itself

    (rewardAmount, bonusRewardAmount) = _receiveRewards(key, rewardAmount, bonusRewardAmount, incentive);

    if (rewardAmount | bonusRewardAmount > 0) {
      _addRewards(virtualPool, rewardAmount, bonusRewardAmount, incentiveId);
    }
  }

  /// @inheritdoc IAlgebraEternalFarming
  function setRates(IncentiveKey memory key, uint128 rewardRate, uint128 bonusRewardRate) external override onlyIncentiveMaker {
    bytes32 incentiveId = IncentiveId.compute(key);
    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentives[incentiveId].virtualPoolAddress);

    if ((incentives[incentiveId].deactivated || _getCurrentVirtualPool(key.pool) != address(virtualPool)) && (rewardRate | bonusRewardRate != 0))
      revert incentiveStopped();
    _setRewardRates(virtualPool, rewardRate, bonusRewardRate, incentiveId);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function enterFarming(IncentiveKey memory key, uint256 tokenId) external override onlyFarmingCenter {
    (bytes32 incentiveId, int24 tickLower, int24 tickUpper, uint128 liquidity, address virtualPoolAddress) = _enterFarming(key, tokenId);

    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(virtualPoolAddress);
    (uint256 innerRewardGrowth0, uint256 innerRewardGrowth1) = _getInnerRewardsGrowth(virtualPool, tickLower, tickUpper);

    farms[tokenId][incentiveId] = Farm(liquidity, tickLower, tickUpper, innerRewardGrowth0, innerRewardGrowth1);

    emit FarmEntered(tokenId, incentiveId, liquidity);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function exitFarming(IncentiveKey memory key, uint256 tokenId, address _owner) external override onlyFarmingCenter {
    bytes32 incentiveId = IncentiveId.compute(key);
    Farm memory farm = farms[tokenId][incentiveId];
    if (farm.liquidity == 0) revert farmDoesNotExist();

    (uint256 reward, uint256 bonusReward) = _updatePosition(farm, key, incentiveId, _owner, -int256(uint256(farm.liquidity)).toInt128());

    delete farms[tokenId][incentiveId];

    emit FarmEnded(tokenId, incentiveId, address(key.rewardToken), address(key.bonusRewardToken), _owner, reward, bonusReward);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function claimReward(IERC20Minimal rewardToken, address to, uint256 amountRequested) external override returns (uint256 reward) {
    return _claimReward(rewardToken, msg.sender, to, amountRequested);
  }

  /// @inheritdoc IAlgebraEternalFarming
  function claimRewardFrom(
    IERC20Minimal rewardToken,
    address from,
    address to,
    uint256 amountRequested
  ) external override onlyFarmingCenter returns (uint256 reward) {
    return _claimReward(rewardToken, from, to, amountRequested);
  }

  function _updatePosition(
    Farm memory farm,
    IncentiveKey memory key,
    bytes32 incentiveId,
    address _owner,
    int128 liquidityDelta
  ) internal returns (uint256 reward, uint256 bonusReward) {
    Incentive storage incentive = incentives[incentiveId];
    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentive.virtualPoolAddress);

    if (_getCurrentVirtualPool(key.pool) != address(virtualPool)) incentive.deactivated = true; // pool can "detach" by itself
    int24 tick = incentive.deactivated ? virtualPool.globalTick() : _getTickInPool(key.pool);

    // update rewards, as ticks may be cleared when liquidity decreases
    virtualPool.distributeRewards();

    (reward, bonusReward, , ) = _getNewRewardsForFarm(virtualPool, farm);

    if (liquidityDelta != 0) {
      _updatePositionInVirtualPool(address(virtualPool), uint32(block.timestamp), farm.tickLower, farm.tickUpper, liquidityDelta, tick);
    }

    mapping(IERC20Minimal => uint256) storage rewardBalances = rewards[_owner];
    unchecked {
      if (reward != 0) rewardBalances[key.rewardToken] += reward; // user must claim before overflow
      if (bonusReward != 0) rewardBalances[key.bonusRewardToken] += bonusReward; // user must claim before overflow
    }
  }

  /// @notice reward amounts can be outdated, actual amounts could be obtained via static call of `collectRewards` in FarmingCenter
  /// @inheritdoc IAlgebraEternalFarming
  function getRewardInfo(IncentiveKey memory key, uint256 tokenId) external view override returns (uint256 reward, uint256 bonusReward) {
    bytes32 incentiveId = IncentiveId.compute(key);
    Farm memory farm = farms[tokenId][incentiveId];
    if (farm.liquidity == 0) revert farmDoesNotExist();

    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentives[incentiveId].virtualPoolAddress);
    (reward, bonusReward, , ) = _getNewRewardsForFarm(virtualPool, farm);
  }

  /// @notice reward amounts should be updated before calling this method
  /// @inheritdoc IAlgebraEternalFarming
  function collectRewards(
    IncentiveKey memory key,
    uint256 tokenId,
    address _owner
  ) external override onlyFarmingCenter returns (uint256 reward, uint256 bonusReward) {
    (bytes32 incentiveId, Incentive storage incentive) = _getIncentiveByKey(key);
    Farm memory farm = farms[tokenId][incentiveId];
    if (farm.liquidity == 0) revert farmDoesNotExist();

    IAlgebraEternalVirtualPool virtualPool = IAlgebraEternalVirtualPool(incentive.virtualPoolAddress);
    virtualPool.distributeRewards();

    uint256 innerRewardGrowth0;
    uint256 innerRewardGrowth1;
    (reward, bonusReward, innerRewardGrowth0, innerRewardGrowth1) = _getNewRewardsForFarm(virtualPool, farm);

    farms[tokenId][incentiveId].innerRewardGrowth0 = innerRewardGrowth0;
    farms[tokenId][incentiveId].innerRewardGrowth1 = innerRewardGrowth1;

    mapping(IERC20Minimal => uint256) storage rewardBalances = rewards[_owner];
    unchecked {
      if (reward != 0) rewardBalances[key.rewardToken] += reward; // user must claim before overflow
      if (bonusReward != 0) rewardBalances[key.bonusRewardToken] += bonusReward; // user must claim before overflow
    }

    emit RewardsCollected(tokenId, incentiveId, reward, bonusReward);
  }

  function _getInnerRewardsGrowth(IAlgebraEternalVirtualPool virtualPool, int24 tickLower, int24 tickUpper) private view returns (uint256, uint256) {
    return virtualPool.getInnerRewardsGrowth(tickLower, tickUpper);
  }

  function _getNewRewardsForFarm(
    IAlgebraEternalVirtualPool virtualPool,
    Farm memory farm
  ) private view returns (uint256 reward, uint256 bonusReward, uint256 innerRewardGrowth0, uint256 innerRewardGrowth1) {
    (innerRewardGrowth0, innerRewardGrowth1) = _getInnerRewardsGrowth(virtualPool, farm.tickLower, farm.tickUpper);

    (reward, bonusReward) = (
      FullMath.mulDiv(innerRewardGrowth0 - farm.innerRewardGrowth0, farm.liquidity, Constants.Q128),
      FullMath.mulDiv(innerRewardGrowth1 - farm.innerRewardGrowth1, farm.liquidity, Constants.Q128)
    );
  }

  function _addRewards(IAlgebraEternalVirtualPool virtualPool, uint128 amount0, uint128 amount1, bytes32 incentiveId) private {
    virtualPool.addRewards(amount0, amount1);
    emit RewardsAdded(amount0, amount1, incentiveId);
  }

  function _setRewardRates(IAlgebraEternalVirtualPool virtualPool, uint128 rate0, uint128 rate1, bytes32 incentiveId) private {
    virtualPool.setRates(rate0, rate1);
    emit RewardsRatesChanged(rate0, rate1, incentiveId);
  }

  function _connectPoolToVirtualPool(IAlgebraPool pool, address virtualPool) private {
    farmingCenter.connectVirtualPool(pool, virtualPool);
  }

  function _getCurrentVirtualPool(IAlgebraPool pool) internal view returns (address virtualPool) {
    return pool.activeIncentive();
  }

  function _receiveRewards(
    IncentiveKey memory key,
    uint128 reward,
    uint128 bonusReward,
    Incentive storage incentive
  ) internal returns (uint128 receivedReward, uint128 receivedBonusReward) {
    if (reward > 0) receivedReward = _receiveToken(key.rewardToken, reward);
    if (bonusReward > 0) receivedBonusReward = _receiveToken(key.bonusRewardToken, bonusReward);

    incentive.totalReward = incentive.totalReward + receivedReward;
    incentive.bonusReward = incentive.bonusReward + receivedBonusReward;
  }

  function _receiveToken(IERC20Minimal token, uint128 amount) private returns (uint128) {
    uint256 balanceBefore = token.balanceOf(address(this));
    TransferHelper.safeTransferFrom(address(token), msg.sender, address(this), amount);
    uint256 balanceAfter = token.balanceOf(address(this));
    require(balanceAfter > balanceBefore);
    unchecked {
      uint256 received = uint128(balanceAfter - balanceBefore);
      require(received <= type(uint128).max, 'invalid token amount');
      return (uint128(received));
    }
  }

  function _enterFarming(
    IncentiveKey memory key,
    uint256 tokenId
  ) internal returns (bytes32 incentiveId, int24 tickLower, int24 tickUpper, uint128 liquidity, address virtualPool) {
    Incentive storage incentive;
    (incentiveId, incentive) = _getIncentiveByKey(key);
    virtualPool = incentive.virtualPoolAddress;

    if (farms[tokenId][incentiveId].liquidity != 0) revert tokenAlreadyFarmed();
    if (_getCurrentVirtualPool(key.pool) != address(virtualPool) || incentive.deactivated) revert incentiveStopped(); // pool can "detach" by itself

    IAlgebraPool pool;
    (pool, tickLower, tickUpper, liquidity) = NFTPositionInfo.getPositionInfo(deployer, nonfungiblePositionManager, tokenId);

    if (pool != key.pool) revert invalidPool();
    if (liquidity == 0) revert zeroLiquidity();

    uint24 minimalAllowedTickWidth = incentive.minimalPositionWidth;
    unchecked {
      if (int256(tickUpper) - int256(tickLower) < int256(uint256(minimalAllowedTickWidth))) revert positionIsTooNarrow();
    }

    int24 tick = _getTickInPool(pool);
    _updatePositionInVirtualPool(virtualPool, uint32(block.timestamp), tickLower, tickUpper, int256(uint256(liquidity)).toInt128(), tick);
  }

  function _claimReward(IERC20Minimal rewardToken, address from, address to, uint256 amountRequested) internal returns (uint256 reward) {
    if (to == address(0)) revert claimToZeroAddress();
    reward = rewards[from][rewardToken];

    if (amountRequested == 0 || amountRequested > reward) amountRequested = reward;

    if (amountRequested > 0) {
      unchecked {
        rewards[from][rewardToken] = reward - amountRequested;
      }
      TransferHelper.safeTransfer(address(rewardToken), to, amountRequested);
      emit RewardClaimed(to, amountRequested, address(rewardToken), from);
    }
  }

  function _getIncentiveByKey(IncentiveKey memory key) internal view returns (bytes32 incentiveId, Incentive storage incentive) {
    incentiveId = IncentiveId.compute(key);
    incentive = incentives[incentiveId];
    if (incentive.totalReward == 0) revert incentiveNotExist();
  }

  function _getTickInPool(IAlgebraPool pool) internal view returns (int24 tick) {
    (, tick, , , , , ) = pool.globalState();
  }

  function _updatePositionInVirtualPool(
    address virtualPool,
    uint32 timestamp,
    int24 tickLower,
    int24 tickUpper,
    int128 liquidityDelta,
    int24 currentTick
  ) internal {
    IAlgebraEternalVirtualPool(virtualPool).applyLiquidityDeltaToPosition(timestamp, tickLower, tickUpper, liquidityDelta, currentTick);
  }
}
