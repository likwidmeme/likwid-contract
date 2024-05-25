import { utils } from 'ethers';
import { HardhatUserConfig, task } from 'hardhat/config';
import { HardhatNetworkHDAccountsConfig } from 'hardhat/types';
import 'dotenv/config';
//import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomicfoundation/hardhat-network-helpers';
import '@nomiclabs/hardhat-ethers';
//import '@nomiclabs/hardhat-etherscan';//replace to hardhat-verify
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'solidity-coverage';
//end of hardhat-toolbox
import '@nomicfoundation/hardhat-verify';
import 'hardhat-deploy';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-tracer';
import './task';

task('accounts', 'list ethers accounts with balance').setAction(async (taskArgs, hre) => {
  for (const account of await hre.ethers.getSigners())
    console.log(account.address, hre.ethers.utils.formatEther(await account.getBalance()));
});
task('prikey', '').setAction(async (taskArgs, hre) => {
  const config = hre.network.config.accounts as HardhatNetworkHDAccountsConfig;
  if (config.mnemonic) {
    const wallet1 = hre.ethers.Wallet.fromMnemonic(config.mnemonic, config.path + `/${0}`);
    console.log(`use mnemonic, publicKey:(${wallet1.publicKey}), privateKey:(${wallet1.privateKey})`);
  } else console.log(`${config}`);
});
const getMnemonic = (networkName?: string) => {
  const mnemonic = networkName ? process.env['MNEMONIC_' + networkName.toUpperCase()] : process.env.MNEMONIC;
  if (!mnemonic || mnemonic === '') return 'test test test test test test test test test test test junk';
  return mnemonic;
};
const getPrivateKey = (networkName?: string) => {
  return networkName ? process.env['PRIKEY_' + networkName.toUpperCase()] : process.env.PRIKEY;
};
const getScanApiKey = (networkName?: string) => {
  const key = (
    networkName ? process.env['ETHERSCAN_API_KEY_' + networkName.toUpperCase()] : process.env.ETHERSCAN_API_KEY
  ) as string;
  return key;
};
const accounts = (chain?: string) => {
  const privateKey = getPrivateKey(chain);
  return privateKey ? [privateKey] : { mnemonic: getMnemonic(chain) };
};
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.4.24',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
          },
        },
      },
      {
        version: '0.8.23',
        settings: { optimizer: { enabled: true, runs: 100 } },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
  sourcify: {
    enabled: false,
  },
  etherscan: {
    enabled: true,
    apiKey: {
      Base: getScanApiKey('Base'),
      Arbitrum: getScanApiKey('Arbitrum'),
      Linea: getScanApiKey('Linea'),
      Scroll: getScanApiKey('Scroll'),
      Blast: getScanApiKey('Blast'),
      Optimism: getScanApiKey('Optimism'),
      zkEVM: getScanApiKey('zkEVM'),
      Vizing: 'NULL',
      Bob: 'NULL',
    },
    customChains: [
      {
        network: 'Base',
        chainId: 8453,
        urls: {
          apiURL: 'https://api.basescan.org/api',
          browserURL: 'https://basescan.org/',
        },
      },
      {
        network: 'Arbitrum',
        chainId: 42161,
        urls: {
          apiURL: 'https://api.arbiscan.io/api',
          browserURL: 'https://arbiscan.io/',
        },
      },
      {
        network: 'Linea',
        chainId: 59144,
        urls: {
          apiURL: 'https://api.lineascan.build/api',
          browserURL: 'https://lineascan.build/',
        },
      },
      {
        network: 'Scroll',
        chainId: 534352,
        urls: {
          apiURL: 'https://api.scrollscan.com/api',
          browserURL: 'https://scrollscan.com/',
        },
      },
      {
        network: 'Blast',
        chainId: 81457,
        urls: {
          apiURL: 'https://api.blastscan.io/api',
          browserURL: 'https://blastscan.io/',
        },
      },
      {
        network: 'Optimism',
        chainId: 10,
        urls: {
          apiURL: 'https://api-optimistic.etherscan.io/api',
          browserURL: 'https://optimistic.etherscan.io/',
        },
      },
      {
        network: 'zkEVM',
        chainId: 1101,
        urls: {
          apiURL: 'https://api-zkevm.polygonscan.com/api',
          browserURL: 'https://zkevm.polygonscan.com/',
        },
      },
      {
        network: 'Vizing',
        chainId: 28518,
        urls: {
          apiURL: 'https://explorer-api.vizing.com/api',
          browserURL: 'https://explorer.vizing.com/',
        },
      },
      {
        network: 'Bob',
        chainId: 60808,
        urls: {
          apiURL: 'https://explorer.gobob.xyz/api',
          browserURL: 'https://explorer.gobob.xyz/',
        },
      },
    ],
  },

  networks: {
    hardhat: {},
    localhost: {
      accounts: accounts(),
    },
    Base: {
      url: 'https://mainnet.base.org',
      chainId: 8453,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Vizing: {
      url: 'https://rpc.vizing.com',
      chainId: 28518,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Linea: {
      url: 'https://rpc.linea.build',
      chainId: 59144,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Scroll: {
      url: 'https://rpc.scroll.io',
      chainId: 534352,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Optimism: {
      url: 'https://mainnet.optimism.io',
      chainId: 10,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Arbitrum: {
      url: 'https://arbitrum-one.publicnode.com',
      chainId: 42161,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    zkEVM: {
      url: 'https://zkevm-rpc.com',
      chainId: 1101,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Blast: {
      url: 'https://rpc.blast.io',
      chainId: 81457,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
    Bob: {
      url: 'https://rpc.gobob.xyz',
      chainId: 60808,
      accounts: accounts(),
      gasMultiplier: 1.2,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
  },
};

export default config;
