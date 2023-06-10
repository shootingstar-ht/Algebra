export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const poolDeployer = await deployments.get('AlgebraPoolDeployer')
  const poolAddress = poolDeployer.address //'0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  console.log('poolDeployer: ', { poolAddress })
  const nftPositionManager = await deployments.get('NonfungiblePositionManager')
  const nftManagerAddress = nftPositionManager.address //'0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  console.log('nftPositionManager: ', { nftManagerAddress })

  const eternalFarming = await deploy('AlgebraEternalFarming', {
    from: deployer,
    args: [poolAddress, nftManagerAddress],
    log: true,
  })

  const farmCenter = await deploy('FarmingCenter', {
    from: deployer,
    args: [eternalFarming.address, nftManagerAddress],
    log: true,
  })

  console.log('Updated farming center address in eternal(incentive) farming')
  await deployments.execute('AlgebraEternalFarming', { from: deployer }, 'setFarmingCenterAddress', farmCenter.address)

  console.log('Updated farming center address in factory')
  await deployments.execute('AlgebraFactory', { from: deployer }, 'setFarmingAddress', farmCenter.address)
  await deployments.execute('NonfungiblePositionManager', { from: deployer }, 'setFarmingCenter', farmCenter.address)
}

export const tags = ['AlgebraEternalFarming']
