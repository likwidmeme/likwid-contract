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
  if (chain == 'Vizing') {
    instance = await ethers.getContractAt(
      'TokenMaster',
      args.addr ? args.addr : (await deployments.get('TokenMaster')).address,
    );
    console.log(`master(${instance.address})`);
    console.log(`totalSupply:${await instance.totalSupply()}`);
    console.log(
      `omniSupply(${ethers.utils.formatEther(
        await instance.omniSupply(),
      )}),presaleAccumulate(${ethers.utils.formatEther(
        await instance.presaleAccumulate(),
      )}),presaleNative(${ethers.utils.formatEther(
        await instance.presaleNative(),
      )}),presaleSupply(${ethers.utils.formatEther(
        await instance.presaleSupply(),
      )}),presaleRefundRatio(${ethers.utils.formatEther(
        await instance.presaleRefundRatio(),
      )}),claimDebitAmount(${await instance.claimDebitAmount()}),lockedDebitAmount(${await instance.lockedDebitAmount()}),getReserves(${await instance.getReserves()})`,
    );
  } 
  const logs = await hre.ethers.provider.getLogs({
    fromBlock: (await ethers.provider.getBlockNumber()) - 100,
    address: instance!.address,
  });
  console.log(
    logs.length,
    `MessageFailed.Topic(${instance!.interface.getEventTopic(
      'MessageFailed',
    )}),PongfeeFailed.Topic(${instance!.interface.getEventTopic('PongfeeFailed')})`,
  );
  for (const log of logs) {
    const desc = instance!.interface.parseLog(log);
    if (desc.name == 'MessageFailed') {
      try {
        const reason = instance!.interface.parseError(desc.args._reason);
        if (reason.name != 'NotImplement') console.log(reason, desc.args);
        else console.log(reason.name);
      } catch (err) {
        if ((desc.args._reason as string).startsWith('0x08c379a0'))
          //Error(string)
          console.log(
            hre.ethers.utils.defaultAbiCoder.decode(['string'], hre.ethers.utils.hexDataSlice(desc.args._reason, 4)),
          );
        else console.error('other', desc);
      }
    } else if (desc.name == 'PongfeeFailed') {
      console.log('PongfeeFailed', desc);
    } else if (args.message && desc.name == 'MessageReceived') {
      console.log('MessageReceived', desc);
    }
  }
  // while (true) {
    console.log(
      `getAmountOut:${await instance!.getAmountOut(1, false)}`,
      `messageReceived:${await instance!.messageReceived()}`,
      `messageFailed:${await instance!.messageFailed()}`,

      `pool.balanceOf:${await instance!.balanceOf(instance!.address)}`,
      `pool.ether:${await ethers.provider.getBalance(instance!.address)}`,
      
      `presaleAccumulate:${await instance!.presaleAccumulate()}`,
      `presaleNative:${await instance!.presaleNative()}`,
      `presaleSupply:${await instance!.presaleSupply()}`,

      `getReserves:${await instance!.getReserves()}`,
      `claimDebitAmount:${await instance!.claimDebitAmount()}`,
      `lockedDebitAmount:${await instance!.lockedDebitAmount()}`,
      `presaleRefundRatio:${await instance!.presaleRefundRatio()}`,
      `totalSupply:${await instance!.totalSupply()}`,
    );
  // }
};
