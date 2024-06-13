import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { validator: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  let instance: types.contracts.TokenMaster | types.contracts.TokenSlave;
  if (chain == 'vizing_testnet') {
    instance = await ethers.getContractAt('TokenMaster', (await deployments.get('TokenMaster')).address);
    console.log(`master(${instance.address})`);
    if (instance.launched()) { 
      // ALL Slave Chains ID
      for (const chainId of [421614, 2442 ]) {
        const pingFee = await instance.launchToSlaveEstimateGas(chainId);
        const tx2 = await instance!.launchToSlave(chainId, { value: pingFee });
        console.log(`pending tx ${tx2.hash}`);
        await tx2.wait();
      }
    }
  }
};
