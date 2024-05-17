// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SlaveTokenBase} from "./lib/SlaveTokenBase.sol";

contract TokenSlave is SlaveTokenBase {
    constructor(
        address _vizingPad,
        uint64 _masterChainId
    ) SlaveTokenBase("Token Name", "TNT", _vizingPad, address(0), _masterChainId) {}
}
