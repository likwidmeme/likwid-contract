import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { validator: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  let instance: types.contracts.TokenMaster | types.contracts.TokenSlave;
  if (chain == 'Vizing') {
    instance = await ethers.getContractAt('TokenMaster', (await deployments.get('TokenMaster')).address);
    console.log(`master(${instance.address})`);
    const total = hre.ethers.utils.parseEther('20000000');
    const presale = hre.ethers.utils.parseEther('10000000');
    const refundRadio = hre.ethers.utils.parseEther('0.9987');
    const feeAddr = "0xc04f47EA0b0EF62E1220C7174bF2296E9FcE01dC";
    if (!(await instance.launched())) {
      const tx1 = await instance!.launch(total, presale, refundRadio, feeAddr);
      console.log(`pending tx ${tx1.hash}`);
      await tx1.wait();
      for (const chainId of [8453, 59144, 534352, 10, 42161, 1101, 81457, 60808 ]) {
        const pingFee = await instance.launchToSlaveEstimateGas(chainId);
        const tx2 = await instance!.launchToSlave(chainId, { value: pingFee });
        console.log(`pending tx ${tx2.hash}`);
        await tx2.wait();
      }
    }
    console.log(
      `master launched(${await instance.launched()}),totalSupply(${await instance.totalSupply()}),balance(${await instance.balanceOf(
        instance.address,
      )})`,
    );

    const presaleNative = (await instance.presaleAccumulate()).sub(
      (await instance.presaleAccumulate()).mul(refundRadio).div(ethers.constants.WeiPerEther),
    );
    console.log(`presaleNative(${await instance.presaleNative()})=compute(${presaleNative})`);
    
  } else if (chain == 'Arbitrum') {
    instance = await ethers.getContractAt('TokenSlave', (await deployments.get('TokenSlave')).address);
    console.log(`slave(${instance.address})`);
    console.log(await instance.launched());
  }
};
