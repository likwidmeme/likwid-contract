// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {MessageTypeLib} from "@vizing/contracts/library/MessageTypeLib.sol";

import "./ExcessivelySafeCall.sol";
import "./NonblockingApp.sol";

abstract contract ERC314PlusCore is ERC20, Ownable, ReentrancyGuard, VizingOmni, NonblockingApp {
    using ExcessivelySafeCall for address;

    enum ActionType {
        deposit,
        launch,
        claimPing,
        claimPong,
        buyPing,
        buyPong,
        sellPing,
        sellPong
    }
    struct DebitAmount {
        uint native;
        uint token;
    }

    event MessageReceived(uint64 _srcChainId, address _srcAddress, uint value, bytes _payload);
    event PongfeeFailed(uint64 _srcChainId, address _srcAddress, uint8 _action, uint _pongFee, uint _expectPongFee);
    event Launch(
        address indexed _sender,
        uint _native,
        uint _token,
        uint _presaleToken,
        uint _refundNative,
        address _feeAddr
    );
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out);

    uint64 public immutable override minArrivalTime;
    uint64 public immutable override maxArrivalTime;
    uint24 public immutable override minGasLimit;
    uint24 public immutable override maxGasLimit;
    bytes1 public immutable override defaultBridgeMode;
    address public immutable override selectedRelayer;

    uint64 public masterChainId;
    bool public launched;
    uint public messageReceived;
    address public feeAddress;

    mapping(address => uint) public deposited; //local chain deposited address=>amount
    mapping(address => bool) public claimed;

    uint MAX_INT = 2 ** 256 - 1;

    constructor(
        string memory _name,
        string memory _symbol,
        address _vizingPad,
        uint64 _masterChainId
    ) VizingOmni(_vizingPad) ERC20(_name, _symbol) {
        masterChainId = _masterChainId;
        launched = false;
        defaultBridgeMode = MessageTypeLib.STANDARD_ACTIVATE;
    }

    //----vizing bridge common----
    function paramsEstimateGas(
        uint64 dstChainId,
        address dstContract,
        uint value,
        bytes memory params
    ) public view virtual returns (uint) {
        bytes memory message = PacketMessage(
            defaultBridgeMode,
            dstContract,
            maxGasLimit,
            _fetchPrice(dstContract, dstChainId),
            abi.encode(_msgSender(), params)
        );
        return LaunchPad.estimateGas(value, dstChainId, new bytes(0), message);
    }

    function paramsEmit2LaunchPad(
        uint bridgeFee,
        uint64 dstChainId,
        address dstContract,
        uint value,
        bytes memory params,
        address sender
    ) internal virtual {
        bytes memory message = PacketMessage(
            defaultBridgeMode,
            dstContract,
            maxGasLimit,
            _fetchPrice(dstContract, dstChainId),
            abi.encode(_msgSender(), params)
        );
        /*
        emit2LaunchPad(
            0, //uint64(block.timestamp + minArrivalTime),
            0, //uint64(block.timestamp + maxArrivalTime),
            selectedRelayer,
            sender,
            value,
            dstChainId,
            new bytes(0),
            message
        );
        */
        uint bridgeValue = value + bridgeFee;
        require(msg.value >= bridgeValue, "bridgeFee err.");
        LaunchPad.Launch{value: bridgeValue}(0, 0, selectedRelayer, sender, value, dstChainId, new bytes(0), message);
    }

    //----  message call function----

    function master_deposit(
        uint pongFee,
        uint64 srcChainId,
        address sender,
        address target,
        uint amount
    ) internal virtual {
        revert NotImplement();
    }

    function master_claim(uint pongFee, uint64 srcChainId, address sender, address target) internal virtual {
        revert NotImplement();
    }

    function master_buy(uint pongFee, uint64 srcChainId, address sender, address target, uint native) internal virtual {
        revert NotImplement();
    }

    function master_sell(uint pongFee, uint64 srcChainId, address sender, address target, uint token) internal virtual {
        revert NotImplement();
    }

    function slave_launch(uint64 srcChainId, address sender) internal virtual {
        revert NotImplement();
    }

    function slave_deposit(uint64 srcChainId, address sender, address target, uint amount) internal virtual {
        revert NotImplement();
    }

    function slave_claim(uint64 srcChainId, address sender, address target, uint native, uint token) internal virtual {
        revert NotImplement();
    }

    function slave_buy(uint64 srcChainId, address sender, address target, uint native, uint token) internal virtual {
        revert NotImplement();
    }

    function slave_sell(uint64 srcChainId, address sender, address target, uint native, uint token) internal virtual {
        revert NotImplement();
    }

    function action_master(
        uint64 srcChainId,
        address sender,
        uint8 action,
        uint pongFee,
        bytes memory params
    ) internal virtual {
        if (action == uint8(ActionType.deposit)) {
            (address target, uint amount) = abi.decode(params, (address, uint));
            master_deposit(pongFee, srcChainId, sender, target, amount);
        } else if (action == uint8(ActionType.claimPing)) {
            address target = abi.decode(params, (address));
            master_claim(pongFee, srcChainId, sender, target);
        } else if (action == uint8(ActionType.buyPing)) {
            (address target, uint native) = abi.decode(params, (address, uint));
            master_buy(pongFee, srcChainId, sender, target, native);
        } else if (action == uint8(ActionType.sellPing)) {
            (address target, uint token) = abi.decode(params, (address, uint));
            master_sell(pongFee, srcChainId, sender, target, token);
        } else revert NotImplement();
    }

    function action_slave(
        uint64 srcChainId,
        address sender,
        uint8 action,
        uint pongFee,
        bytes memory params
    ) internal virtual {
        if (action == uint8(ActionType.deposit)) {
            (address target, uint amount) = abi.decode(params, (address, uint));
            slave_deposit(srcChainId, sender, target, amount);
        } else if (action == uint8(ActionType.claimPong)) {
            (address target, uint native, uint token) = abi.decode(params, (address, uint, uint));
            slave_claim(srcChainId, sender, target, native, token);
        } else if (action == uint8(ActionType.buyPong)) {
            (address target, uint native, uint token) = abi.decode(params, (address, uint, uint));
            slave_buy(srcChainId, sender, target, native, token);
        } else if (action == uint8(ActionType.sellPong)) {
            (address target, uint token, uint native) = abi.decode(params, (address, uint, uint));
            slave_sell(srcChainId, sender, target, native, token);
        } else if (action == uint8(ActionType.launch)) {
            slave_launch(srcChainId, sender);
        } else revert NotImplement();
    }

    //---- message----

    function _computePongValueWithOutPongFee(
        uint8 action,
        uint64 srcChainId,
        uint pongFee,
        bytes memory params
    ) internal view virtual returns (uint value, uint sendToFee) {
        value = msg.value - pongFee;
        sendToFee = 0;
    }

    function _nonblockingReceive(
        uint64 srcChainId,
        address sender,
        uint8 action,
        uint pongFee,
        bytes calldata params
    ) public payable virtual override {
        require(_msgSender() == address(this), "ERC314PlusCore: caller must be self");
        if (srcChainId == masterChainId) action_slave(srcChainId, sender, action, pongFee, params);
        else action_master(srcChainId, sender, action, pongFee, params);
    }

    function _callSelf(
        uint64 srcChainId,
        address sender,
        uint8 action,
        uint pongFee,
        uint callValue,
        bytes memory params
    ) internal returns (bool success, bytes memory reason) {
        (success, reason) = address(this).excessivelySafeCall(
            gasleft(),
            callValue,
            150,
            abi.encodeWithSelector(this._nonblockingReceive.selector, srcChainId, sender, action, pongFee, params)
        );
    }

    function verifySource(uint64 srcChainId, address srcContract) internal view virtual returns (bool authorized);

    function _receiveMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata _payload
    ) internal virtual override {
        require(verifySource(srcChainId, address(uint160(srcContract))), "unauthorized.");
        (address sender, bytes memory message) = abi.decode(_payload, (address, bytes));
        messageReceived += 1;
        emit MessageReceived(srcChainId, sender, msg.value, message);

        (uint8 action, uint pongFee, bytes memory params) = abi.decode(message, (uint8, uint, bytes));

        (uint value, uint sendToFee) = _computePongValueWithOutPongFee(action, srcChainId, pongFee, params);
        uint callValue = pongFee + value - sendToFee;
        if (sendToFee > 0) payable(feeAddress).transfer(sendToFee);
        (bool success, bytes memory reason) = _callSelf(srcChainId, sender, action, pongFee, callValue, params);
        if (!success) {
            _storeFailedMessage(srcChainId, sender, message, reason, callValue);
        }
    }

    //---- interface ----
    function deposit(uint pongFee, uint amount) public payable virtual;

    function claim(uint pongFee) public payable virtual;

    function swapExactETHForTokens(uint pongFee, address to, uint deadline) external payable virtual;

    function swapExactTokensForETH(uint pongFee, uint amountIn, address to, uint deadline) external payable virtual;

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        if (_msgSender() != address(this) && to == address(this)) {
            revert("Unsupported");
        } else {
            super._transfer(from, to, amount);
        }
    }

    //----Signature---
    /*
    function _fetchSignature(bytes memory message) internal view virtual returns (bytes memory signature) {
        //signature = abi.encodeCall(this.receiveMessage, (deployChainId, address(this), msg.sender, message));
        signature = message;
    }
    */

    function _depositPingPongSignature(
        address target,
        uint pongFee,
        uint amount
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.deposit), pongFee, abi.encode(target, amount));
    }

    function _claimPingSignature(address target, uint pongFee) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.claimPing), pongFee, abi.encode(target));
    }

    function _claimPongSignature(
        address target,
        uint refund,
        uint amount
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.claimPong), 0, abi.encode(target, refund, amount));
    }

    function _buyPingSignature(
        address target,
        uint pongFee,
        uint amountIn
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.buyPing), pongFee, abi.encode(target, amountIn));
    }

    function _buyPongSignature(address target, uint native, uint token) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.buyPong), 0, abi.encode(target, native, token));
    }

    function _sellPingSignature(
        address target,
        uint pongFee,
        uint amountIn
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.sellPing), pongFee, abi.encode(target, amountIn));
    }

    function _sellPongSignature(address target, uint native, uint token) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.sellPong), 0, abi.encode(target, native, token));
    }
}
