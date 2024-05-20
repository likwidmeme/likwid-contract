// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MasterTokenBase} from "./lib/MasterTokenBase.sol";

contract TokenMaster is MasterTokenBase {
    constructor(
        address _vizingPad,
        uint64 _masterChainId
    ) MasterTokenBase("Orbit Guy", "ORBGUY", _vizingPad, address(0), _masterChainId, 1716480000) {}
}
