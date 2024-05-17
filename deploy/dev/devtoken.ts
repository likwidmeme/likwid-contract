import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import jsonProtocol from '../../constants/protocol.json';
const protocols = jsonProtocol as Record<string, { vizingPad: string }>;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chain = hre.hardhatArguments.network;

  if (hre.network.name === 'Vizing') {
    const master = await deploy('TokenMaster', {
      from: deployer,
      args: [jsonProtocol.Vizing.vizingPad, hre.network.config.chainId],
      log: true,
    });
    console.log(`🟢[${chain}]master.address(${master.address})`);
  }
  const slaveChains = Object.keys(protocols).filter((x) => x != 'Vizing');
  if (slaveChains.includes(chain!)) {
    //slave
    const slave = await deploy('TokenSlave', {
      from: deployer,
      args: [protocols[chain!].vizingPad, 28518],
      log: true,
    });
    console.log(`🟢[${chain}]slave.address(${slave.address})`);
  }
};
func.tags = ['dev'];
export default func;
