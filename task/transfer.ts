import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
export default async (args: { target: string; amount: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const amount = ethers.utils.parseEther(args.amount);
  const balance = await ethers.provider.getBalance(deployer.address);
  const gasPrice = (await ethers.provider.getGasPrice()).mul(11).div(10);
  const gasFee = gasPrice.mul(21000);
  console.log(
    `ether balance:${ethers.utils.formatEther(balance)},gasPrice:${gasPrice},gasFee:${ethers.utils.formatEther(
      gasFee,
    )}`,
  );
  if (amount.eq('0')) {
  } else if (ethers.utils.isAddress(args.target) && amount.lt(balance)) {
    const sendValue = amount.lt(balance.sub(gasFee)) ? amount : balance.sub(gasFee);
    console.log(`send value(${ethers.utils.formatEther(sendValue)}),to(${args.target})`);
    const tx = await deployer.sendTransaction({
      to: args.target,
      value: sendValue,
      gasPrice,
      //gasLimit: 21000,
    });
    console.log(`pending tx(${tx.hash})`);
  }
};
