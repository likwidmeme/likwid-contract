import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { validator: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  const slaveChains = ['arbitrum_sepolia', 'polygon_zkevm_cardona'];
  if (slaveChains.includes(chain)) {
    const slaveAddr = getDeploymentAddresses(chain)['TokenSlave'];
    const slave = await ethers.getContractAt('TokenSlave', slaveAddr);
    console.log(`Chain(${chain})`);
    console.log(`Contract(${slave.address})`);
    console.log(`totalSupply:\n${await slave.totalSupply()}`);
  } 
  if (chain == 'vizing_testnet') {
    const masterAddr = getDeploymentAddresses(chain)['TokenMaster'];
    const master = await ethers.getContractAt('TokenMaster', masterAddr);
    console.log(`Chain(Vizing)`);
    console.log(`Contract(${master.address})`);
    console.log(`totalSupply:\n${await master.totalSupply()}`);
  }
};
