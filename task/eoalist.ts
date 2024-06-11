import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
export default async (args: { master: string; block: number }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;

  const instance = await ethers.getContractAt(
    'ERC314PlusCore',
    args.master ?? (await deployments.get('TokenMaster')).address,
  );
  const logs = await hre.ethers.provider.getLogs({
    fromBlock: (await ethers.provider.getBlockNumber()) - (args.block ?? 10000),
    address: instance.address,
  });

  const eoas = new Set();
  for (const log of logs) {
    const desc = instance!.interface.parseLog(log);
    if (desc.name == 'MessageReceived') {
      console.log(desc.args._srcChainId.toString(), desc.args._srcAddress);
      eoas.add(desc.args._srcAddress);
    }
  }
  console.log(eoas.size);
};
