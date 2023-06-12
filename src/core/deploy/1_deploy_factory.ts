import hre from 'hardhat'
export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const [deployerContract] = await hre.ethers.getSigners()
  // precompute
  const poolDeployerAddress = hre.ethers.utils.getContractAddress({
    from: deployerContract.address,
    nonce: (await deployerContract.getTransactionCount()) + 1,
  })
  console.log('poolDeployerAddress precompute: ', poolDeployerAddress)

  await deploy('AlgebraFactory', {
    from: deployer,
    args: [poolDeployerAddress],
    log: true,
  })
}

export const tags = ['AlgebraFactory']
