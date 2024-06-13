import { task } from 'hardhat/config';
import { types } from 'hardhat/config';
import devAdapter from './devAdapter';
import devMessage from './devMessage';
import devLaunch from './devLaunch';
import devLaunchToSlave from './devLaunchToSlave';
import transfer from './transfer';
import devSlaveVerify from './devSlaveVerify';
import devMasterVerify from './devMasterVerify';
import devSupply from './devSupply';
task('devSlaveVerify').setAction(devSlaveVerify);
task('devMasterVerify').setAction(devMasterVerify);
task('devAdapter').setAction(devAdapter);
task('devMessage').setAction(devMessage).addOptionalParam<boolean>('message', 'show message').addOptionalParam('addr');
task('devLaunch').setAction(devLaunch);
task('devLaunchToSlave').setAction(devLaunchToSlave);
task('transfer').setAction(transfer).addParam('target').addParam('amount');
task('devSupply').setAction(devSupply);

