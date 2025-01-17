const path = require('path')
const config = require('dotenv').config({ path: path.resolve(__dirname, '.env') })
const { ETHERSCAN_API_KEY, ZKSYNC_MAINNET_MNEMONIC, ZKSYNC_TESTNET_MNEMONIC, LINEA_TESTNET_MNEMONIC } = config.parsed || {}

export default {
  zksolc: {
    version: '1.3.10',
    compilerSource: 'binary',
    settings: {},
  },
  namedAccounts: {
    deployer: 0,
    proxyAdmin: 1,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      loggingEnabled: false,
    },
    hhnode: {
      url: `http://127.0.0.1:8545`,
      accounts: [`0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`],
      allowUnlimitedContractSize: true,
      gas: 10000000,
      loggingEnabled: false,
    },
    zkSync: {
      url: `https://mainnet.era.zksync.io`,
      ethNetwork: `https://eth.llamarpc.com`,
      chainId: 324,
      accounts: {
        mnemonic: `${ZKSYNC_MAINNET_MNEMONIC}`,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: '',
      },
      zksync: true,
    },
    zkTestnet: {
      url: `https://testnet.era.zksync.dev`,
      ethNetwork: `https://rpc.ankr.com/eth_goerli`,
      gasPrice: 100_000_000,
      chainId: 280,
      accounts: {
        mnemonic: `${ZKSYNC_TESTNET_MNEMONIC}`,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: '',
      },
      zksync: true,
    },
    zkLocal: {
      url: 'http://localhost:3050',
      ethNetwork: 'http://localhost:8545',
      accounts: ['0x850683b40d4a740aa6e745f889a6fdc8327be76e122f5aba645a5b02d0248db8'],
      zksync: true,
    },
    linea: {
      url: `https://rpc.goerli.linea.build/`,
      accounts: {
        mnemonic: `${LINEA_TESTNET_MNEMONIC}`,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: '',
      },
      zksync: false,
    },
  },
  defaultNetwork: 'zkLocal',
  solidity: {
    version: '0.8.17',
    settings: {
      metadata: {
        bytecodeHash: 'none',
      },
    },
  },
  etherscan: {
    apiKey: `${ETHERSCAN_API_KEY}`,
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: '../../cache',
    'cache-zk': '../../cache-zk',
    artifacts: '../../artifacts',
    'artifacts-zk': '../../artifacts-zk',
    deploy: './deploy',
    deployments: '../../deployments',
  },
}
