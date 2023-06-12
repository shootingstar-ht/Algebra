import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { deployContract, initializeWalletAndDeployer } from '../../../scripts/helper'
export default async function (hre: HardhatRuntimeEnvironment) {
  const deployer = initializeWalletAndDeployer(hre)
  const weth = await deployContract('WETH', 'WrappedEther', [])
  const usdc = await deployContract('USDC', 'CircleStable', [])
}
