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
    const total = hre.ethers.utils.parseEther('2000000');
    const presale = hre.ethers.utils.parseEther('1000000');
    const refundRadio = hre.ethers.utils.parseEther('0.0909');
    if (!(await instance.launched())) {
      const tx1 = await instance!.launch(total, presale, refundRadio, deployer.address);
      console.log(`pending tx ${tx1.hash}`);
      await tx1.wait();
      for (const chainId of [421614, 2442 ]) {
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
    
  } else if (chain == 'arbitrum_sepolia') {
    instance = await ethers.getContractAt('TokenSlave', (await deployments.get('TokenSlave')).address);
    console.log(`slave(${instance.address})`);
    console.log(await instance.launched());
  }
};
