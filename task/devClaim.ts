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
    console.log(`address(${deployer.address}),${await instance.slaveClaimed(421614, deployer.address)}`);
    const status = await instance!.presaleOf(421614, deployer.address);
    console.log(status);
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
    console.log(
      `address(${deployer.address}),deposited(${await instance!.deposited(
        deployer.address,
      )}),claimed(${await instance!.claimed(deployer.address)})`,
    );
    if (await instance!.claimed(deployer.address)) {
      console.log(
        `address(${deployer.address}),deposited(${await instance!.deposited(
          deployer.address,
        )}),claimed(${await instance!.claimed(deployer.address)}),balance(${await instance!.balanceOf(
          deployer.address,
        )})`,
      );
    } else {
      const pongFee = await master.claimPongEstimateGas(
        (await instance.provider.getNetwork()).chainId,
        deployer.address,
      );
      console.log(pongFee);
      const pingFee = await instance.claimPingEstimateGas(pongFee, deployer.address);
      const tx = await instance.claim(pongFee, { value: pingFee.add(pongFee) });
      console.log(`pending tx ${tx.hash}`);
      await tx.wait();
    }
  }
};
