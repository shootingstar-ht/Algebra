import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-chai-matchers'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import 'solidity-coverage'
import 'solidity-docgen'

import { HardhatUserConfig } from 'hardhat/config'
import { SolcUserConfig } from 'hardhat/types'

import baseConfig from '../../hardhat.base.config'

const DEFAULT_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 2023,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const config: HardhatUserConfig = {
  namedAccounts: baseConfig.namedAccounts,
  networks: baseConfig.networks,
  etherscan: baseConfig.etherscan,
  paths: baseConfig.paths,
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
  },
  typechain: {
    outDir: '../../typechain',
  },
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: true,
    runOnCompile: false,
  },
  docgen: {
    outputDir: '../../docs/Contracts/Tokenomics',
    pages: (x: any) => x.name.toString() + '.md',
    templates: '../../docs/doc_templates/public',
    collapseNewlines: true,
  },
}

export default config
