import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-chai-matchers'
import '@nomiclabs/hardhat-etherscan'
import '@matterlabs/hardhat-zksync-solc'
import '@matterlabs/hardhat-zksync-deploy'
import '@matterlabs/hardhat-zksync-verify'
import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import 'solidity-coverage'
import 'solidity-docgen'

import { SolcUserConfig } from 'hardhat/types'
import baseConfig from '../../hardhat.base.config'

const HIGHEST_OPTIMIZER_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const DEFAULT_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const LOWEST_COMPILER_SETTINGS: SolcUserConfig = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 0,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

if (process.env.RUN_COVERAGE == '1') {
  /**
   * Updates the default compiler settings when running coverage.
   *
   * See https://github.com/sc-forks/solidity-coverage/issues/417#issuecomment-730526466
   */
  console.info('Using coverage compiler settings')
  const details = {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  }

  HIGHEST_OPTIMIZER_COMPILER_SETTINGS.settings.details = details
  DEFAULT_COMPILER_SETTINGS.settings.details = details
}

export default {
  namedAccounts: baseConfig.namedAccounts,
  networks: baseConfig.networks,
  etherscan: baseConfig.etherscan,
  paths: baseConfig.paths,
  zksolc: baseConfig.zksolc,
  typechain: {
    outDir: './typechain',
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS],
    overrides: {
      'contracts/AlgebraFactory.sol': HIGHEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/DataStorageOperator.sol': HIGHEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/test/simulation/SimulationTimePoolDeployer.sol': LOWEST_COMPILER_SETTINGS,
    },
  },
  docgen: {
    outputDir: '../../docs/Contracts/Core',
    pages: (x: any) => x.name.toString() + '.md',
    templates: '../../docs/doc_templates/public',
    collapseNewlines: true,
  },
}
