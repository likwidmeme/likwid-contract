import { HardhatRuntimeEnvironment, HttpNetworkConfig } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { validator: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  let instance: types.contracts.DemoTokenMaster | types.contracts.DemoTokenSlave;
  if (chain == 'vizing_testnet') {
    instance = await ethers.getContractAt('DemoTokenMaster', (await deployments.get('DemoTokenMaster')).address);
    console.log(
      `master(${
        instance.address
      }),presaleSupply(${await instance.presaleSupply()}),presaleAccumulate(${await instance.presaleAccumulate()})`,
    );
    console.log(
      `address(${
        deployer.address
      }),presaleNative(${await instance.presaleNative()}),balance(${await ethers.provider.getBalance(
        instance.address,
      )})`,
    );
    console.log('getReserves', await instance.getReserves());
    console.log('getAmountOut(buy)', await instance.getAmountOut(ethers.utils.parseEther('0.0001'), true));
    console.log('getAmountOut(sell)', await instance.getAmountOut(ethers.utils.parseEther('0.0001'), false));
  } else if (chain == 'arbitrum_sepolia') {
    const masterAddr = getDeploymentAddresses('vizing_testnet')['DemoTokenMaster'];
    const masterProvider = new ethers.providers.JsonRpcProvider(
      (hre.config.networks['vizing_testnet'] as HttpNetworkConfig).url,
    );
    const master = new ethers.Contract(
      masterAddr,
      (await ethers.getContractFactory('DemoTokenMaster')).interface,
      masterProvider,
    ) as types.MasterTokenBase;
    instance = await ethers.getContractAt('DemoTokenSlave', (await deployments.get('DemoTokenSlave')).address);
    console.log(`slave(${instance.address})`);

    const buyValue = ethers.utils.parseEther('0.01');
    const pongFee = await master.buyPongEstimateGas(
      (await instance.provider.getNetwork()).chainId,
      deployer.address,
      buyValue,
    );
    const pingFee = await instance.buyPingEstimateGas(pongFee, deployer.address, buyValue);
    console.log(`transfer value to slave:${buyValue.add(pongFee)}`);
    const tx = await instance.swapExactETHForTokens(pongFee, deployer.address, 0, {
      value: buyValue.add(pongFee).add(pingFee),
    });
    console.log(tx.hash);
  }
};
