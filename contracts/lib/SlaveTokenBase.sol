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

    function slave_deposit(uint64 srcChainId, address sender, address target, uint amount) internal virtual override {
        deposited[target] += amount;
    }

    function slave_claim(
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint token
    ) internal virtual override {
        if (token > 0) _mint(target, token);
        if (native > 0) payable(target).transfer(native);
        claimed[target] = true;
    }

    function slave_buy(
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint token
    ) internal virtual override {
        if (token > 0) _mint(target, token);
        if (native > 0) payable(target).transfer(native);
    }

    function slave_sell(
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint token
    ) internal virtual override {
        if (token > 0) _mint(target, token);
        if (native > 0) payable(target).transfer(native);
    }

    //----deposit
    function depositPingEstimateGas(
        uint pongFee,
        address target,
        uint amount
    ) public view virtual returns (uint pingFee) {
        pingFee = paramsEstimateGas(
            masterChainId,
            masterContract,
            amount + pongFee,
            _depositPingPongSignature(target, pongFee, amount)
        );
    }

    function deposit(uint pongFee, uint amount) public payable virtual override nonReentrant {
        require(!launched, "launched");
        uint pingFee = depositPingEstimateGas(pongFee, _msgSender(), amount);
        require(msg.value >= amount + pingFee + pongFee, "bridge fee not enough");
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            amount + pongFee,
            _depositPingPongSignature(_msgSender(), pongFee, amount),
            _msgSender()
        );
    }

    //----claim

    function claimPingEstimateGas(uint pongFee, address target) public view virtual returns (uint pingFee) {
        pingFee = paramsEstimateGas(masterChainId, masterContract, pongFee, _claimPingSignature(target, pongFee));
    }

    function claim(uint pongFee) public payable virtual override nonReentrant {
        require(launched, "unlaunched");
        require(!claimed[_msgSender()], "claimed");
        uint pingFee = claimPingEstimateGas(pongFee, _msgSender());
        require(msg.value >= pingFee + pongFee, "bridge fee not enough");
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            pongFee,
            _claimPingSignature(_msgSender(), pongFee),
            _msgSender()
        );
    }

    //----_buy

    function buyPingEstimateGas(
        uint pongFee,
        address target,
        uint amountIn
    ) public view virtual returns (uint pingFee) {
        pingFee = paramsEstimateGas(
            masterChainId,
            masterContract,
            pongFee,
            _buyPingSignature(target, pongFee, amountIn)
        );
    }

    function _buy(uint pongFee, address to, uint deadline) internal {
        require(launched, "unlaunched");
        require(deadline == 0 || deadline > block.timestamp, "deadline err.");
        uint pingFee = buyPingEstimateGas(pongFee, to, msg.value);
        uint amountIn = msg.value - pingFee - pongFee;
        require(amountIn > 0, "amount in err.");
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            amountIn + pongFee,
            _buyPingSignature(to, pongFee, amountIn),
            _msgSender()
        );
    }

    //----_sell

    function sellPingEstimateGas(
        uint pongFee,
        address target,
        uint amountIn
    ) public view virtual returns (uint pingFee) {
        pingFee = paramsEstimateGas(
            masterChainId,
            masterContract,
            pongFee,
            _sellPingSignature(target, pongFee, amountIn)
        );
    }

    function _sell(uint pongFee, address from, address to, uint amountIn, uint deadline) internal {
        require(launched, "unlaunched");
        require(amountIn > 0, "amount in err.");
        require(deadline == 0 || deadline > block.timestamp, "deadline err.");
        require(balanceOf(from) >= amountIn, "sell amount exceeds balance");
        uint pingFee = sellPingEstimateGas(pongFee, to, amountIn);
        require(msg.value >= pingFee + pongFee, "bridge fee not enough");
        _burn(from, amountIn);
        paramsEmit2LaunchPad(
            pingFee,
            masterChainId,
            masterContract,
            pongFee,
            _sellPingSignature(to, pongFee, amountIn),
            _msgSender()
        );
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
    ) external payable virtual override nonReentrant {
        _buy(pongFee, to, deadline);
    }

    function swapExactTokensForETH(
        uint pongFee,
        uint amountIn,
        address to,
        uint deadline
    ) external payable virtual override nonReentrant {
        _sell(pongFee, _msgSender(), to, amountIn, deadline);
    }

    receive() external payable {
        //_buy(_msgSender(), block.timestamp);
    }

    function withdrawFee(address to, uint amount) public onlyOwner {
        payable(to).transfer(amount);
    }
}
