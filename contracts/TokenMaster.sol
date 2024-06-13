// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MasterTokenBase} from "./lib/MasterTokenBase.sol";

contract TokenMaster is MasterTokenBase {
    constructor(
        address _vizingPad,
        uint64 _masterChainId
    ) MasterTokenBase("EL GATO", "GATO", _vizingPad, address(0), _masterChainId) {}
}
