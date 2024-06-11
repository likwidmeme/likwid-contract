import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: {}, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  let instance: types.contracts.DemoTokenMaster | types.contracts.DemoTokenSlave;
  if (chain == 'vizing_testnet') {
    instance = await ethers.getContractAt('DemoTokenMaster', (await deployments.get('DemoTokenMaster')).address);
    console.log(`master(${instance.address})`);

    //buy
    const buyAmountIn = ethers.utils.parseEther('0.001');
    const estimateBuyOut = await instance.getAmountOut(buyAmountIn, true);

    console.log(
      `balance(${await instance.balanceOf(deployer.address)}),amountIn(${buyAmountIn}),estimateOut(${estimateBuyOut})`,
    );
    const tx1 = await instance.swapExactETHForTokens(0, deployer.address, 0, { value: buyAmountIn });
    console.log(`buy peding tx:${tx1.hash}`);
    await tx1.wait();
    console.log(`balance(${await instance.balanceOf(deployer.address)})`);

    //sell
    const sellAmountIn = await instance.balanceOf(deployer.address);
    const estimateSellOut = await instance.getAmountOut(sellAmountIn, false);
    console.log(
      `balance(${await instance.balanceOf(
        deployer.address,
      )}),amountIn(${sellAmountIn}),estimateOut(${estimateSellOut})`,
    );
    /*
    (await instance.approve(instance.address, sellAmountIn)).wait();
    console.log(`${await instance.allowance(deployer.address, instance.address)}`);
    */
    const tx2 = await instance.swapExactTokensForETH(0, sellAmountIn, deployer.address, 0);
    console.log(`sell peding tx:${tx2.hash}`);
    await tx2.wait();
    console.log(`balance(${await instance.balanceOf(deployer.address)})`);
  }
};
