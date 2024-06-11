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
    console.log('getAmountOut(buy)', await instance.getAmountOut(ethers.utils.parseEther('0.1'), true));
    console.log('getAmountOut(sell)', await instance.getAmountOut(ethers.utils.parseEther('0.1'), false));

    const lockedResult = await instance.locked(deployer.address);
    if (lockedResult.token.gt(0) || lockedResult.native.gt(0)) {
      console.log(`master(${instance.address}),${deployer.address}.locked(${lockedResult}),unlock pending...`);
      await (await instance.unlock(deployer.address)).wait();
    }
    console.log(
      `master(${instance.address}),${deployer.address}.balanceOf(${await instance.balanceOf(deployer.address)}),${
        deployer.address
      }.locked(${await instance.locked(deployer.address)})`,
    );
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

    const sellAmount = ethers.utils.parseEther('0.001');
    console.log(
      `claimDebitAmount:${await master.claimDebitAmount()},lockedDebitAmount:${await master.lockedDebitAmount()},balanceOf:(${await master.balanceOf(
        master.address,
      )})`,
    );
    console.log('getReserves', await master.getReserves());
    console.log('getAmountOut', await master.getAmountOut(sellAmount, false));

    const pongFee = (
      await master.sellPongEstimateGas((await instance.provider.getNetwork()).chainId, deployer.address, sellAmount)
    )
      .mul(11)
      .div(10);
    const pingFee = await instance.sellPingEstimateGas(pongFee, deployer.address, sellAmount);
    const tx = await instance.swapExactTokensForETH(pongFee, sellAmount, deployer.address, 0, {
      value: pongFee.add(pingFee).add(pongFee),
    });
    console.log(tx.hash);
  }
};
