import path from 'path';
import fs from 'fs';

function getDeploymentAddresses(networkName: string) {
  const PROJECT_ROOT = path.resolve(__dirname, '..');
  const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, 'deployments');

  let folderName = networkName;
  if (networkName === 'hardhat') {
    folderName = 'localhost';
  }

  const networkFolderName = fs.readdirSync(DEPLOYMENT_PATH).filter((f) => f === folderName)[0];
  if (networkFolderName === undefined) {
    throw new Error('missing deployment files for endpoint ' + folderName);
  }

  let rtnAddresses = {} as Record<string, string>;
  const networkFolderPath = path.resolve(DEPLOYMENT_PATH, folderName);
  const files = fs.readdirSync(networkFolderPath).filter((f) => f.includes('.json'));
  files.forEach((file) => {
    const filepath = path.resolve(networkFolderPath, file);
    const data = JSON.parse(fs.readFileSync(filepath, 'utf8'));
    const contractName = file.split('.')[0];
    rtnAddresses[contractName] = data.address;
  });

  return rtnAddresses;
}
export default getDeploymentAddresses;
