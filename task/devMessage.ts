import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (
  args: { message: boolean | undefined; addr: string | undefined },
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  let instance: types.contracts.TokenMaster | types.contracts.TokenSlave;
  if (chain == 'vizing_testnet') {
    instance = await ethers.getContractAt('TokenMaster', (await deployments.get('TokenMaster')).address);
    console.log(`master(${instance.address})`);

    console.log(`claimDebitAmount(${await instance.claimDebitAmount()})`);
    console.log(`poolInitNative(${await instance.poolInitNative()})`);
    console.log(`poolInitSupply(${await instance.poolInitSupply()})`);
    console.log(`getReserves(${await instance.getReserves()})`);


  }
  // }
};
