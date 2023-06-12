const path = require('path')
const config = require('dotenv').config({ path: path.resolve(__dirname, '.env') })
const { ETHERSCAN_API_KEY, ZKSYNC_MAINNET_MNEMONIC, ZKSYNC_TESTNET_MNEMONIC, LINEA_TESTNET_MNEMONIC } = config.parsed || {}

export default {
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
      accounts: ['0xac1e735be8536c6534bb4f17f06f6afc73b2b5ba84ac2cfb12f7461b20c0bbe3'],
      zksync: true,
      gasPrice: 100_000_000,
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
    artifacts: '../../artifacts',
    deploy: './deploy',
    deployments: '../../deployments',
  },
}
