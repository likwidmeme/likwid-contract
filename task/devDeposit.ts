import { HardhatRuntimeEnvironment, HttpNetworkConfig } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { validator: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  if (chain == 'arbitrum_sepolia') {
    const masterAddr = getDeploymentAddresses('vizing_testnet')['DemoTokenMaster'];
    const masterProvider = new ethers.providers.JsonRpcProvider(
      (hre.config.networks['vizing_testnet'] as HttpNetworkConfig).url,
    );
    const master = new ethers.Contract(
      masterAddr,
      (await ethers.getContractFactory('DemoTokenMaster')).interface,
      masterProvider,
    ) as types.MasterTokenBase;
    const slave = await ethers.getContractAt('DemoTokenSlave', (await deployments.get('DemoTokenSlave')).address);

    const amount = hre.ethers.utils.parseEther('0.00123456');

    const pongFee = await master.depositPongEstimateGas(
      (await slave.provider.getNetwork()).chainId,
      deployer.address,
      amount,
    );
    const pingFee = await slave.depositPingEstimateGas(pongFee, deployer.address, amount);

    const value = amount.add(pingFee).add(pongFee);
    console.log(pingFee, pongFee);
    const gasLimit = await slave.estimateGas.deposit(pongFee, amount, {
      value,
    });
    console.log(`master(${await slave.masterContract()}),value(${value}),gas(${gasLimit})`);
    const tx = await slave.deposit(pongFee, amount, { value });
    console.log(tx.hash);
  }
};
