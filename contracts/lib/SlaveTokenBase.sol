// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ERC314PlusCore} from "./ERC314PlusCore.sol";
import {IMessageStruct} from "@vizing/contracts/interface/IMessageStruct.sol";


contract SlaveTokenBase is ERC314PlusCore {
    address public masterContract;

    constructor(
        string memory _name,
        string memory _symbol,
        address _vizingPad,
        address _defaultRelayer,
        uint64 _masterChainId
    ) ERC314PlusCore(_name, _symbol, _vizingPad, _masterChainId) {
        minArrivalTime = 1 minutes;
        maxArrivalTime = 1 days;
        minGasLimit = 100000;
        maxGasLimit = 1000000;
        selectedRelayer = _defaultRelayer;
    }
    mapping(address => uint) public deposited; //local chain deposited address=>amount
    mapping(address => uint) public depositPing;
    mapping(address => bool) public claimed;
    mapping(address => uint) public depositNonce;
    mapping(address => mapping(uint => bool)) public depositNoncePong;

    mapping(address => uint) public claimNonce;
    mapping(address => mapping(uint => bool)) public claimNoncePong;

    mapping(address => uint) public buyNonce;
    mapping(address => mapping(uint => bool)) public buyNoncePong;

    mapping(address => uint) public sellNonce;
    mapping(address => mapping(uint => bool)) public sellNoncePong;

    function setMasterContract(address addr) public virtual onlyOwner {
        masterContract = addr;
    }

    function verifySource(
        uint64 srcChainId,
        address srcContract
    ) internal view virtual override returns (bool authorized) {
        return masterContract == srcContract && masterChainId == srcChainId;
    }

    //----slave call
    function slave_launch(uint64 srcChainId, address sender) internal virtual override {
        launched = true;
    }

    function slave_deposit(uint64 srcChainId, address sender, address target, uint amount,uint nonce) internal virtual override {
        require(!depositNoncePong[target][nonce], "nonce repetition");
        depositNoncePong[target][nonce] = true;
        deposited[target] += amount;
    }

    function slave_claim(
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint token,
        uint nonce
    ) internal virtual override {
        require(!claimNoncePong[target][nonce], "nonce repetition");
        claimNoncePong[target][nonce] = true;
        require(!claimed[target], "claim repetition");
        if (token > 0) _mint(target, token);
        if (native > 0) payable(target).transfer(native);
        claimed[target] = true;
    }

    function slave_buy(
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint token,
        uint nonce
    ) internal virtual override {
        require(!buyNoncePong[target][nonce], "nonce repetition");
        buyNoncePong[target][nonce] = true;
        if (token > 0) _mint(target, token);
        if (native > 0) payable(target).transfer(native);
    }

    function slave_sell(
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint token,
        uint nonce
    ) internal virtual override {
        require(!sellNoncePong[target][nonce], "nonce repetition");
        sellNoncePong[target][nonce] = true;
        if (token > 0) _mint(target, token);
        if (native > 0) payable(target).transfer(native);
    }

    //----deposit
    function depositPingEstimateGas(
        uint pongFee,
        address target,
        uint amount
    ) public view virtual returns (uint pingFee) {
        uint nonce = depositNonce[target];
        pingFee = paramsEstimateGas(
            masterChainId,
            masterContract,
            amount + pongFee,
            _depositPingPongSignature(nonce+1, target, pongFee, amount)
        );
    }

    function deposit(uint pongFee, uint amount) public payable virtual nonReentrant whenNotPaused {
        require(!launchIsEnd(),"deposit end");
        require(!launched, "launched");
        uint pingFee = depositPingEstimateGas(pongFee, _msgSender(), amount);
        require(msg.value >= amount + pingFee + pongFee, "bridge fee not enough");
        require(depositPing[_msgSender()] + amount <= nativeMax,"exceeding the maximum value");
        depositPing[_msgSender()] += amount;
        uint nonce = depositNonce[_msgSender()];
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            amount + pongFee,
            _depositPingPongSignature(nonce+1, _msgSender(), pongFee, amount),
            _msgSender()
        );
        depositNonce[_msgSender()]++;
    }

    //----claim

    function claimPingEstimateGas(uint pongFee, address target) public view virtual returns (uint pingFee) {
        uint nonce = claimNonce[_msgSender()];
        pingFee = paramsEstimateGas(masterChainId, masterContract, pongFee, _claimPingSignature(nonce+1,target, pongFee));
    }

    function claim(uint pongFee) public payable virtual nonReentrant whenNotPaused{
        require(launched, "unlaunched");
        require(!claimed[_msgSender()], "claimed");
        uint pingFee = claimPingEstimateGas(pongFee, _msgSender());
        require(msg.value >= pingFee + pongFee, "bridge fee not enough");
        uint nonce = claimNonce[_msgSender()];
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            pongFee,
            _claimPingSignature(nonce+1,_msgSender(), pongFee),
            _msgSender()
        );
        claimNonce[_msgSender()]++;
    }

    //----_buy

    function buyPingEstimateGas(
        uint pongFee,
        address target,
        uint amountIn
    ) public view virtual returns (uint pingFee) {
        uint nonce = buyNonce[_msgSender()];
        pingFee = paramsEstimateGas(
            masterChainId,
            masterContract,
            pongFee,
            _buyPingSignature(nonce+1,target, pongFee, amountIn)
        );
    }

    function _buy(uint pongFee, address to, uint deadline) internal {
        require(launched, "unlaunched");
        require(deadline == 0 || deadline > block.timestamp, "deadline err.");
        uint pingFee = buyPingEstimateGas(pongFee, to, msg.value);
        uint amountIn = msg.value - pingFee - pongFee;
        require(amountIn > nativeMin, "amount in err.");
        require(amountIn < nativeMax,"exceeding the maximum value");
        uint nonce = buyNonce[_msgSender()];
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            amountIn + pongFee,
            _buyPingSignature(nonce+1,to, pongFee, amountIn),
            _msgSender()
        );
        buyNonce[_msgSender()]++;
    }

    //----_sell

    function sellPingEstimateGas(
        uint pongFee,
        address target,
        uint amountIn
    ) public view virtual returns (uint pingFee) {
        uint nonce = sellNonce[_msgSender()];

        pingFee = paramsEstimateGas(
            masterChainId,
            masterContract,
            pongFee,
            _sellPingSignature(nonce+1,target, pongFee, amountIn)
        );
    }

    function _sell(uint pongFee, address from, address to, uint amountIn, uint deadline) internal {
        require(launched, "unlaunched");
        require(amountIn > 0, "amount in err.");
        require(deadline == 0 || deadline > block.timestamp, "deadline err.");
        require(balanceOf(from) >= amountIn, "sell amount exceeds balance");
        uint pingFee = sellPingEstimateGas(pongFee, to, amountIn);
        require(msg.value >= pingFee + pongFee, "bridge fee not enough");

        require(amountIn > tokenMin, "amount in err.");

        uint nonce = sellNonce[_msgSender()];

        _burn(from, amountIn);
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            pongFee,
            _sellPingSignature(nonce+1,to, pongFee, amountIn),
            _msgSender()
        );
        sellNonce[_msgSender()]++;
    }

    //----314token
    function getReserves() public view returns (uint, uint) {
        revert NotImplement();
    }

    function getAmountOut(uint value, bool isBuy) public view returns (uint) {
        revert NotImplement();
    }

    function swapExactETHForTokens(
        uint pongFee,
        address to,
        uint deadline
    ) external payable virtual nonReentrant whenNotPaused{
        _buy(pongFee, to, deadline);
    }

    function swapExactTokensForETH(
        uint pongFee,
        uint amountIn,
        address to,
        uint deadline
    ) external payable virtual nonReentrant whenNotPaused{
        _sell(pongFee, _msgSender(), to, amountIn, deadline);
    }

    receive() external payable {
        //_buy(_msgSender(), block.timestamp);
    }

    function withdrawFee(address to, uint amount) public onlyOwner nonReentrant {
        transferNative(to, amount);
    }

    function slave_cross(uint64 srcChainId, address sender, uint64 dstChainId, address to, uint token,uint nonce) internal virtual override {
        require(!crossNoncePing[srcChainId][sender][nonce], "nonce repetition");
        crossNoncePing[srcChainId][sender][nonce] = true;
        require(dstChainId == block.chainid, "chain id err");
        if (token > 0) _mint(to, token);
        emit Crossed(srcChainId, sender, to, token, nonce);
    }

    function crossToEstimateGas(uint64 dstChainId, address to, uint amount) public view virtual returns (uint pingFee) {
        require(dstChainId == masterChainId, "not master chain");
        uint nonce = crossNonce[dstChainId][to];
        pingFee = paramsEstimateGas(masterChainId, masterContract, 0, _crossPingSignature(nonce+1,dstChainId, to, amount));
    }

    function crossTo(uint64 dstChainId, address to, uint amount) external payable virtual whenNotPaused{
        require(dstChainId == masterChainId, "not master chain");
        address owner = _msgSender();
        require(balanceOf(owner) >= amount, "insufficient balance");
        _burn(owner, amount);
        uint nonce = crossNonce[block.chainid][_msgSender()];
        uint pingFee = crossToEstimateGas(dstChainId, to, amount);
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            0,
            _crossPingSignature(nonce+1,dstChainId, to, amount),
            _msgSender()
        );
        crossNonce[block.chainid][_msgSender()]++;
    }
}
