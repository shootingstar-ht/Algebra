export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer, proxyAdmin } = await getNamedAccounts()

  const factory = await deployments.get('AlgebraFactory')
  const factoryAddress = factory.address //'0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  console.log('factory: ', { factoryAddress })
  const weth = await deployments.get('WrappedEther')
  const wethAddress = weth.address //'0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  console.log('weth: ', { wethAddress })
  const poolDeployer = await deployments.get('AlgebraPoolDeployer')
  const poolAddress = poolDeployer.address //'0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270'
  console.log('poolDeployer: ', { poolAddress })

  await deploy('TickLens', {
    from: deployer,
    args: [],
    log: true,
  })

  await deploy('Quoter', {
    from: deployer,
    args: [factoryAddress, wethAddress, poolAddress],
    log: true,
  })

  await deploy('SwapRouter', {
    from: deployer,
    args: [factoryAddress, wethAddress, poolAddress],
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
    args: [wethAddress],
    proxy: true,
    log: true,
  })

  const nftPositionManager = await deploy('NonfungiblePositionManager', {
    from: deployer,
    args: [factoryAddress, wethAddress, nftPositionDescriptor.address, poolAddress],
    log: true,
  })

  await deploy('LimitOrderManager', {
    from: deployer,
    args: [factoryAddress, wethAddress, poolAddress],
    log: true,
  })

  await deploy('V3Migrator', {
    from: deployer,
    args: [factoryAddress, wethAddress, nftPositionManager.address, poolAddress],
    log: true,
  })
}

export const tags = ['SwapRouter']
export const dependencies = ['AlgebraFactory']
