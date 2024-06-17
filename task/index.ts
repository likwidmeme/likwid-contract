import { task } from 'hardhat/config';
import { types } from 'hardhat/config';
import devAdapter from './devAdapter';
import devMessage from './devMessage';
import devLaunch from './devLaunch';
import transfer from './transfer';
import devSlaveVerify from './devSlaveVerify';
import devMasterVerify from './devMasterVerify';
import eoalist from './eoalist';
import devSupply from './devSupply';
task('devSlaveVerify').setAction(devSlaveVerify);
task('devMasterVerify').setAction(devMasterVerify);
task('devAdapter').setAction(devAdapter);
task('devMessage').setAction(devMessage).addOptionalParam<boolean>('message', 'show message').addOptionalParam('addr');
task('devLaunch').setAction(devLaunch);
task('transfer').setAction(transfer).addParam('target').addParam('amount');
task('eoalist').setAction(eoalist);
task('devSupply').setAction(devSupply);

