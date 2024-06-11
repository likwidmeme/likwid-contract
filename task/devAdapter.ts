import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { validator: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  const slaveChains = ['Base', 'Linea', 'Scroll', 'Optimism', 'Arbitrum', 'zkEVM', 'Blast', 'Bob'];
  if (chain == 'Vizing') {
    for (const chainName of slaveChains) {
      const slaveAddr = getDeploymentAddresses(chainName)['TokenSlave'];
      const master = await ethers.getContractAt('TokenMaster', (await deployments.get('TokenMaster')).address);
      console.log(`master(${master.address}),slave@${chainName}(${slaveAddr})`);
      const chainId = hre.config.networks[chainName].chainId;
      console.log(`slave chain(${chainName}),chainId(${chainId}),slaveAddr(${slaveAddr})`);
      await (await master.setDstContract(chainId!, slaveAddr)).wait();
    }
  }
  if (slaveChains.includes(chain)) {
    const masterAddr = getDeploymentAddresses('Vizing')['TokenMaster'];
    const slave = await ethers.getContractAt('TokenSlave', (await deployments.get('TokenSlave')).address);
    console.log(
      `master(${masterAddr}),slave(${
        slave.address
      }),slave.masterChainId(${await slave.masterChainId()}),slave.masterContract(${await slave.masterContract()})`,
    );
    await (await slave.setMasterContract(masterAddr)).wait();
  }
};
