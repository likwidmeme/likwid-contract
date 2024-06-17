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
      arbitrum_sepolia: getScanApiKey('arbitrum_sepolia'),
      polygon_zkevm_cardona: getScanApiKey('polygon_zkevm_cardona'),
      vizing_testnet: 'NULL',
    },
    customChains: [
      {
        network: 'arbitrum_sepolia',
        chainId: 421614,
        urls: {
          apiURL: 'https://api-sepolia.arbiscan.io/api',
          browserURL: 'https://sepolia.arbiscan.io/',
        },
      },
      {
        network: 'vizing_testnet',
        chainId: 28516,
        urls: {
          apiURL: 'https://explorer-sepolia.vizing.com/api',
          browserURL: 'https://explorer-sepolia.vizing.com/',
        },
      },
      {
        network: 'polygon_zkevm_cardona',
        chainId: 2442,
        urls: {
          apiURL: 'https://api-cardona-zkevm.polygonscan.com/api',
          browserURL: 'https://cardona-zkevm.polygonscan.com/',
        },
      },
    ],
  },
  
  networks: {
    hardhat: {},
    localhost: {
      accounts: accounts(),
    },
    arbitrum_sepolia: {
      url: 'https://sepolia-rollup.arbitrum.io/rpc',
      chainId: 421614,
      accounts: accounts(),
      gasMultiplier: 1.5,
    },
    vizing_testnet: {
      url: 'https://rpc-sepolia.vizing.com',
      chainId: 28516,
      accounts: accounts(),
      gasMultiplier: 1.5,
    },
    polygon_zkevm_cardona: {
      url: 'https://rpc.cardona.zkevm-rpc.com',
      chainId: 2442,
      accounts: accounts(),
      gasMultiplier: 1.5,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
  },
};

export default config;