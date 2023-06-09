export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const factory = await deployments.get('AlgebraFactory')
  const factoryAddress = factory.address
  const vaultAddress = await deployments.read('AlgebraFactory', 'communityVault')

  await deploy('AlgebraPoolDeployer', {
    from: deployer,
    args: [factoryAddress, vaultAddress],
    log: true,
  })
}

export const tags = ['AlgebraPoolDeployer']
export const dependencies = ['AlgebraFactory']
