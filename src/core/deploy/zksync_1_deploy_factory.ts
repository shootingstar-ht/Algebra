import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { deployContract, initializeWalletAndDeployer } from '../../../scripts/helper'
export default async function (hre: HardhatRuntimeEnvironment) {
  const deployer = initializeWalletAndDeployer(hre)
  const [deployerContract] = await hre.ethers.getSigners()
  // precompute
  const poolDeployerAddress = hre.ethers.utils.getContractAddress({
    from: deployerContract.address,
    nonce: (await deployerContract.getTransactionCount()) + 1,
  })
  console.log('poolDeployerAddress precompute: ', poolDeployerAddress)
  const factory = await deployContract('factory', 'AlgebraFactory', [poolDeployerAddress])
  const vaultAddress = await factory.communityVault()
  const poolDeployer = await deployContract('poolDeployer', 'AlgebraPoolDeployer', [factory.address, vaultAddress])
}
