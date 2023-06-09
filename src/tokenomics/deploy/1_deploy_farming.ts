export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const poolDeployer = '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  const nftPositionManager = '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'

  const eternalFarming = await deploy('AlgebraEternalFarming', {
    from: deployer,
    args: [poolDeployer, nftPositionManager],
    log: true,
  })

  const farmCenter = await deploy('FarmingCenter', {
    from: deployer,
    args: [eternalFarming.address, nftPositionManager],
    log: true,
  })

  console.log('Updated farming center address in eternal(incentive) farming')
  await deployments.execute('AlgebraEternalFarming', { from: deployer }, 'setFarmingCenterAddress', farmCenter.address)

  console.log('Updated farming center address in factory')
  await deployments.execute('AlgebraFactory', { from: deployer }, 'setFarmingAddress', farmCenter.address)
  await deployments.execute('NonfungiblePositionManager', { from: deployer }, 'setFarmingCenter', farmCenter.address)
}

export const tags = ['AlgebraEternalFarming']
