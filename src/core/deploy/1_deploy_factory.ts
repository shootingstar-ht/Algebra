export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('AlgebraFactory', {
    from: deployer,
    args: [deployer],
    log: true,
  })
}

export const tags = ['AlgebraFactory']
