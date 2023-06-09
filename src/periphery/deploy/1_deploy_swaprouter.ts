export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer, proxyAdmin } = await getNamedAccounts()

  const factory = '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  const weth = '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  const poolDeployer = '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'

  await deploy('TickLens', {
    from: deployer,
    args: [],
    log: true,
  })

  await deploy('Quoter', {
    from: deployer,
    args: [factory, weth, poolDeployer],
    log: true,
  })

  await deploy('SwapRouter', {
    from: deployer,
    args: [factory, weth, poolDeployer],
    log: true,
  })

  const nftDescriptor = await deploy('NFTDescriptor', {
    from: deployer,
    args: [],
    log: true,
  })

  const nftPositionDescriptor = await deploy('NonfungibleTokenPositionDescriptor', {
    from: deployer,
    libraries: {
      NFTDescriptor: nftDescriptor.address,
    },
    args: [weth],
    proxy: {
      owner: proxyAdmin,
      proxyContract: 'TransparentUpgradeableProxy',
    },
    log: true,
  })

  const nftPositionManager = await deploy('NonfungiblePositionManager', {
    from: deployer,
    args: [factory, weth, nftPositionDescriptor.address, poolDeployer],
    log: true,
  })

  await deploy('LimitOrderManager', {
    from: deployer,
    args: [factory, weth, poolDeployer],
    log: true,
  })

  await deploy('V3Migrator', {
    from: deployer,
    args: [factory, weth, nftPositionManager.address, poolDeployer],
    log: true,
  })

  await deploy('AlgebraInterfaceMulticall', {
    from: deployer,
    args: [],
    log: true,
  })
}

export const tags = ['SwapRouter']
export const dependencies = ['AlgebraFactory']
