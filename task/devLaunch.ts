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

    if (!(await instance.launched())) {
      const launchAmount = await instance.launchPay();
      console.log(`launch amount:${launchAmount}`);
      const tx = await instance.launch({
        value: launchAmount,
      });
      console.log(`pending tx ${tx.hash}`);
      await tx.wait();
      console.log(`
      master launched(${await instance.launched()}),
      totalSupplyInit(${await instance.totalSupplyInit()}),
      launchFunds(${await instance.launchFunds()}),
      tokenomics(${await instance.tokenomics()})
      `);

      // earmarkedSupply,earmarkedNative,presaleRefundRatio,presaleSupply,presaleNative,omniSupply,presaleAccumulate
      console.log(`
      earmarkedSupply(${await instance.earmarkedSupply()}),
      earmarkedNative(${await instance.earmarkedNative()}),
      presaleRefundRatio(${await instance.presaleRefundRatio()}),
      presaleSupply(${await instance.presaleSupply()}),
      presaleNative(${await instance.presaleNative()}),
      omniSupply(${await instance.omniSupply()}),
      presaleAccumulate(${await instance.presaleAccumulate()})
      `);
      console.log(`pool.balanceOf:${await instance!.balanceOf(instance!.address)}`);
      console.log(`pool.ether:${await ethers.provider.getBalance(instance!.address)}`);
    }
  } 
};
