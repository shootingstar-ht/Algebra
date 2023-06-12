export default async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const factory = await deployments.get('AlgebraFactory')
  const weth = '0xC06A49fafa607B029e88eCefA97dF7F97945A08b' //await deployments.get('WrappedEther')
  const usdc = '0xEF00C455678C40F14874bAe72fF6be23dD522F23' //await deployments.get('CircleStable')
  //const wbtc = await deployments.get('WrappedBitcoin')
  //const usdt = await deployments.get('TetherStable')
  //const dai = await deployments.get('DaiStable')

  const ethusdc = await deployments.execute('AlgebraFactory', { from: deployer, log: true, waitConfirmation: 3 }, 'createPool', weth, usdc)
  console.log('ETH/USDC pool pair: ', ethusdc)
}
export const tags = ['CreatePool']
export const dependencies = ['AlgebraPoolDeployer']
