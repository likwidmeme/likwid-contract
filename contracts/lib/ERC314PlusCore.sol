// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {MessageTypeLib} from "@vizing/contracts/library/MessageTypeLib.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


import "./ExcessivelySafeCall.sol";
import "./NonblockingApp.sol";

abstract contract ERC314PlusCore is ERC20, Ownable, ReentrancyGuard, VizingOmni, NonblockingApp, Pausable {
    using ExcessivelySafeCall for address;

    enum ActionType {
        deposit,
        launch,
        claimPing,
        claimPong,
        buyPing,
        buyPong,
        sellPing,
        sellPong,
        crossPing
    }
    struct DebitAmount {
        uint native;
        uint token;
    }
    
    function pause() external onlyOwner {
        bool isPaused = paused() ;
        if(isPaused) {
            _unpause();
        } else {
            _pause();
        }
    }

    event MessageReceived(uint64 _srcChainId, address _srcAddress, uint value, bytes _payload);
    event PongfeeFailed(uint64 _srcChainId, address _srcAddress, uint8 _action, uint _pongFee, uint _expectPongFee);
    event Launch(
        uint earmarkedSupply,
        uint earmarkedNative,
        uint presaleRefundRatio,
        uint presaleSupply,
        uint presaleNative,
        uint omniSupply,
        uint presaleAccumulate
    );
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out,uint nonce);
    event AssetLocked(ActionType _action, uint64 _srcChainId, address _owner, uint _lockedNative, uint _lockedToken,uint nonce);
    event Deposited(uint64 _srcChainId, address _sender, uint _native,uint nonce);
    event Claimed(uint64 _srcChainId, address _sender, address _to, uint _native, uint _token,uint nonce);
    event Crossed(uint64 _srcChainId, address _sender, address _to, uint _token,uint nonce);
    event Unlocked(address _owner,address _to, uint _native, uint _token);

    uint64 public immutable override minArrivalTime;
    uint64 public immutable override maxArrivalTime;
    uint24 public immutable override minGasLimit;
    uint24 public immutable override maxGasLimit;
    bytes1 public immutable override defaultBridgeMode;
    address public immutable override selectedRelayer;

    mapping(uint => mapping(address => uint)) public crossNonce;

    uint64 public masterChainId;
    bool public launched;
    uint public messageReceived;
    address public feeAddress;
    uint public totalSupplyInit = 2000000 ether;
    uint public launchFunds = 1 ether;
    uint public launchHardCap = 10 ether;
    uint public tokenomics = 2;
    address public airdropAddr;
    function setFeeAddress(address addr) public virtual onlyOwner {
        feeAddress = addr;
    }
    function setAirdropAddr(address addr) public virtual onlyOwner {
        airdropAddr = addr;
    }

    uint MAX_INT = 2 ** 256 - 1;
    uint public nativeMax = 5 ether;
    function setNativeMax(uint amount) public virtual onlyOwner {
        nativeMax = amount;
    }

    uint public nativeMin = 0.0001 ether;
    function setNativeMin(uint amount) public virtual onlyOwner {
        nativeMin = amount;
    }

    uint public tokenMin = 1 ether;
    function setTokenMin(uint amount) public virtual onlyOwner {
        tokenMin = amount;
    }
    uint public launchTime = block.timestamp + 3000;//259200 3Days
    function setLaunchTime(uint launchTime_) public virtual onlyOwner {
        launchTime = launchTime_;
    }
    function launchIsEnd() public view returns (bool)  {
        return block.timestamp >= launchTime;
    }
    function nowTime() public view returns (uint)  {
        return block.timestamp;
    }
    constructor(
        string memory _name,
        string memory _symbol,
        address _vizingPad,
        uint64 _masterChainId
    ) VizingOmni(_vizingPad) ERC20(_name, _symbol) {
        masterChainId = _masterChainId;
        launched = false;
        defaultBridgeMode = MessageTypeLib.STANDARD_ACTIVATE;
        feeAddress = owner();
        airdropAddr = owner();
    }

    //----vizing bridge common----
    function paramsEstimateGas(
        uint64 dstChainId,
        address dstContract,
        uint value,
        bytes memory params
    ) public view virtual returns (uint) {
        bytes memory message = _packetMessage(
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
        bytes memory message = _packetMessage(
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
        uint amount,
        uint nonce
    ) internal virtual {
        revert NotImplement();
    }

    function master_claim(uint pongFee, uint64 srcChainId, address sender, address target,uint nonce) internal virtual {
        revert NotImplement();
    }

    function master_buy(uint pongFee, uint64 srcChainId, address sender, address target, uint native,uint nonce ) internal virtual {
        revert NotImplement();
    }

    function master_sell(uint pongFee, uint64 srcChainId, address sender, address target, uint token,uint nonce) internal virtual {
        revert NotImplement();
    }

    function slave_launch(uint64 srcChainId, address sender) internal virtual {
        revert NotImplement();
    }

    function slave_deposit(uint64 srcChainId, address sender, address target, uint amount,uint nonce) internal virtual {
        revert NotImplement();
    }

    function slave_claim(uint64 srcChainId, address sender, address target, uint native, uint token,uint nonce) internal virtual {
        revert NotImplement();
    }

    function slave_buy(uint64 srcChainId, address sender, address target, uint native, uint token,uint nonce) internal virtual {
        revert NotImplement();
    }

    function slave_sell(uint64 srcChainId, address sender, address target, uint native, uint token,uint nonce) internal virtual {
        revert NotImplement();
    }

    function master_cross(
        uint64 srcChainId,
        address sender,
        uint64 dstChainId,
        address to,
        uint token,
        uint nonce
    ) internal virtual {
        revert NotImplement();
    }

    function slave_cross(
        uint64 srcChainId,
        address sender,
        uint64 dstChainId,
        address to,
        uint token,
        uint nonce
    ) internal virtual {
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
            (uint nonce ,address target, uint amount) = abi.decode(params, (uint, address, uint));
            master_deposit(pongFee, srcChainId, sender, target, amount,nonce);
        } else if (action == uint8(ActionType.claimPing)) {
            (uint nonce ,address target) = abi.decode(params, (uint,address));
            master_claim(pongFee, srcChainId, sender, target,nonce);
        } else if (action == uint8(ActionType.buyPing)) {
            (uint nonce ,address target, uint native) = abi.decode(params, (uint,address, uint));
            master_buy(pongFee, srcChainId, sender, target, native,nonce);
        } else if (action == uint8(ActionType.sellPing)) {
            (uint nonce,address target, uint token) = abi.decode(params, (uint,address, uint));
            master_sell(pongFee, srcChainId, sender, target, token,nonce);
        } else if (action == uint8(ActionType.crossPing)) {
            (uint nonce,uint64 chainid, address to, uint token) = abi.decode(params, (uint,uint64, address, uint));
            master_cross(srcChainId, sender, chainid, to, token,nonce);
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
            (uint nonce,address target, uint amount) = abi.decode(params, (uint,address, uint));
            slave_deposit(srcChainId, sender, target, amount,nonce);
        } else if (action == uint8(ActionType.claimPong)) {
            (uint nonce,address target, uint native, uint token) = abi.decode(params, (uint, address, uint, uint));
            slave_claim(srcChainId, sender, target, native, token,nonce);
        } else if (action == uint8(ActionType.buyPong)) {
            (uint nonce,address target, uint native, uint token) = abi.decode(params, (uint,address, uint, uint));
            slave_buy(srcChainId, sender, target, native, token,nonce);
        } else if (action == uint8(ActionType.sellPong)) {
            (uint nonce,address target, uint token, uint native) = abi.decode(params, (uint,address, uint, uint));
            slave_sell(srcChainId, sender, target, native, token,nonce);
        } else if (action == uint8(ActionType.launch)) {
            slave_launch(srcChainId, sender);
        } else if (action == uint8(ActionType.crossPing)) {
            (uint nonce,uint64 chainid, address to, uint token) = abi.decode(params, (uint,uint64, address, uint));
            slave_cross(srcChainId, sender, chainid, to, token,nonce);
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
        if (sendToFee > 0)
            transferNative(feeAddress, sendToFee);
        (bool success, bytes memory reason) = _callSelf(srcChainId, sender, action, pongFee, callValue, params);
        if (!success) {
            _storeFailedMessage(srcChainId, sender, message, reason, callValue);
        }
        require(success, "cross-chain failed");
    }
    
    function transferNative(address to, uint amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed.");
    }

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
        uint nonce,
        address target,
        uint pongFee,
        uint amount
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.deposit), pongFee, abi.encode(nonce,target, amount));
    }

    function _claimPingSignature(uint nonce,address target, uint pongFee) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.claimPing), pongFee, abi.encode(nonce,target));
    }

    function _claimPongSignature(
        uint nonce,
        address target,
        uint refund,
        uint amount
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.claimPong), 0, abi.encode(nonce,target, refund, amount));
    }

    function _buyPingSignature(
        uint nonce,
        address target,
        uint pongFee,
        uint amountIn
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.buyPing), pongFee, abi.encode(nonce,target, amountIn));
    }

    function _buyPongSignature(uint nonce,address target, uint native, uint token) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.buyPong), 0, abi.encode(nonce,target, native, token));
    }

    function _sellPingSignature(
        uint nonce,
        address target,
        uint pongFee,
        uint amountIn
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.sellPing), pongFee, abi.encode(nonce,target, amountIn));
    }

    function _sellPongSignature(uint nonce,address target, uint native, uint token) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.sellPong), 0, abi.encode(nonce,target, native, token));
    }

    function _crossPingSignature(
        uint nonce,
        uint64 dstChainId,
        address target,
        uint token
    ) internal view virtual returns (bytes memory) {
        return abi.encode(uint8(ActionType.crossPing), 0, abi.encode(nonce,dstChainId, target, token));
    }
}
