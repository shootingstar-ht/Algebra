export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('CircleStable', {
    from: deployer,
    args: [],
    log: true,
  })
}

export const tags = ['ERC20Permit']
