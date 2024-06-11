import { HardhatRuntimeEnvironment } from 'hardhat/types';
import * as types from '../typechain-types';
import getDeploymentAddresses from './readStatic';
import jsonProtocol from '../constants/protocol.json';
const protocols = jsonProtocol as Record<string, { vizingPad: string }>;
export default async (args: { name: string }, hre: HardhatRuntimeEnvironment) => {
  const { ethers, getNamedAccounts, deployments } = hre;
  const [deployer] = await ethers.getSigners();
  const chain = hre.network.name;
  const contractAddress = getDeploymentAddresses(chain)['TokenMaster'];
  const result = await hre.run('verify:verify', {
    address: contractAddress,
    constructorArguments: [protocols[chain!].vizingPad, hre.network.config.chainId],
    contract: 'contracts/TokenMaster.sol:TokenMaster',
  });
  console.log(result);
};
