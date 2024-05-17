// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC314PlusCore} from "./ERC314PlusCore.sol";

contract MasterTokenBase is ERC314PlusCore {
    mapping(uint64 => address) dstContracts;
    mapping(address => uint) public omniDeposited; //total chain deposited address=>amount
    mapping(uint64 => mapping(address => uint)) public slaveDeposited; //slave chain deposited chainId=>address=>amount
    mapping(uint64 => mapping(address => uint)) public slaveClaimed;
    DebitAmount public claimDebitAmount;
    mapping(address => DebitAmount) public locked;
    DebitAmount public lockedDebitAmount;

    uint public presaleAccumulate;
    uint public presaleRefundRatio;
    uint public presaleSupply;
    uint public presaleNative;

    uint public omniSupply;

    uint public launchTime;

    constructor(
        string memory _name,
        string memory _symbol,
        address _vizingPad,
        address _defaultRelayer,
        uint64 _masterChainId,
        uint _launchTime
    ) ERC314PlusCore(_name, _symbol, _vizingPad, _masterChainId) {
        minArrivalTime = 1 minutes;
        maxArrivalTime = 1 days;
        minGasLimit = 100000;
        maxGasLimit = 1000000;
        selectedRelayer = _defaultRelayer;

        launchTime = _launchTime;
    }

    function setDstContract(uint64 chainId, address addr) public virtual onlyOwner {
        dstContracts[chainId] = addr;
    }

    function delDstContract(uint64 chainId) public virtual onlyOwner {
        delete dstContracts[chainId];
    }

    function setFeeAddress(address addr) public virtual onlyOwner {
        feeAddress = addr;
    }

    function verifySource(
        uint64 srcChainId,
        address srcContract
    ) internal view virtual override returns (bool authorized) {
        return dstContracts[srcChainId] == srcContract;
    }

    function launch(
        uint _totalSupply,
        uint _presaleSupply,
        uint _refundRatio,
        address _feeAddr
    ) public virtual onlyOwner nonReentrant {
        require(_totalSupply > presaleSupply && _refundRatio <= 1 ether);
        require(!launched, "launched");
        require(address(this).balance >= presaleAccumulate && presaleAccumulate > 0, "pool insufficient quantity");
        presaleRefundRatio = _refundRatio;
        presaleSupply = _presaleSupply;
        omniSupply = _totalSupply;
        feeAddress = _feeAddr;
        launched = true;
        _mint(address(this), _totalSupply);
        presaleNative = (presaleAccumulate * (1 ether - presaleRefundRatio)) / 1 ether;
        claimDebitAmount = DebitAmount(presaleAccumulate - presaleNative, presaleSupply);
        emit Launch(
            _msgSender(),
            presaleNative,
            omniSupply,
            presaleSupply,
            presaleAccumulate - presaleNative,
            _feeAddr
        );
    }

    function launchToSlaveEstimateGas(uint64 dstChainId) public view virtual returns (uint pingFee) {
        pingFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            0,
            abi.encode(uint8(ActionType.launch), uint(0), bytes(""))
        );
    }

    function launchToSlave(uint64 dstChainId) public payable virtual onlyOwner nonReentrant {
        require(launched, "need launched");
        require(dstContracts[dstChainId] != address(0), "need dest chain contract");
        uint pingFee = launchToSlaveEstimateGas(dstChainId);
        if (msg.value > pingFee) payable(feeAddress).transfer(msg.value - pingFee);
        paramsEmit2LaunchPad(
            pingFee,
            dstChainId,
            dstContracts[dstChainId],
            0,
            abi.encode(uint8(ActionType.launch), uint(0), bytes("")),
            _msgSender()
        );
    }

    function getReserves() public view returns (uint native, uint token) {
        if (!launched) return (0, 0);
        else {
            native = address(this).balance - claimDebitAmount.native - lockedDebitAmount.native;
            token = balanceOf(address(this)) - claimDebitAmount.token - lockedDebitAmount.token;
        }
    }

    function _getAmountOut(
        uint reserveETH,
        uint reserveToken,
        uint value,
        bool _buy
    ) internal view returns (uint amount, uint fee) {
        if (value == 0) return (0, 0);
        if (!launched || (launched && (presaleNative == 0 || reserveETH == 0 || reserveToken == 0))) return (0, 0);
        if (_buy) {
            if (value + reserveETH >= presaleNative) {
                amount = reserveToken - (presaleNative * presaleSupply) / (value + reserveETH);
            } else {
                amount = (presaleSupply * value) / presaleNative;
            }
        } else {
            if (value + reserveToken >= presaleSupply) {
                amount = (presaleNative * value) / presaleSupply;
            } else {
                amount = reserveETH - (presaleNative * presaleSupply) / (value + reserveToken);
            }
        }
        fee = (amount * 10) / 1000;
        amount = amount - fee;
    }

    function getAmountOut(uint value, bool _buy) public view returns (uint amount, uint fee) {
        (uint reserveETH, uint reserveToken) = getReserves();
        return _getAmountOut(reserveETH, reserveToken, value, _buy);
    }

    function _getAmountOutAtSend(uint value, bool _buy) internal view returns (uint amount, uint fee) {
        (uint reserveETH, uint reserveToken) = getReserves();
        return _getAmountOut(reserveETH - msg.value, reserveToken, value, _buy);
    }

    function _debitDeposit(uint64 srcChainId, address target, uint amount) internal virtual {
        slaveDeposited[srcChainId][target] -= amount;
        omniDeposited[target] -= amount;
        presaleAccumulate -= amount;
    }

    function _creditDeposit(uint64 srcChainId, address target, uint amount) internal virtual {
        slaveDeposited[srcChainId][target] += amount;
        omniDeposited[target] += amount;
        presaleAccumulate += amount;
    }

    function _debitLocked(address owner, uint native, uint token) internal virtual {
        lockedDebitAmount.native -= native;
        lockedDebitAmount.token -= token;
        locked[owner].native -= native;
        locked[owner].token -= token;
    }

    function _creditLocked(address owner, uint native, uint token) internal virtual {
        lockedDebitAmount.native += native;
        lockedDebitAmount.token += token;
        locked[owner].native += native;
        locked[owner].token += token;
    }

    function _creditClaim(uint64 srcChainId, address owner, uint native, uint token) internal virtual {
        slaveClaimed[srcChainId][owner] += slaveDeposited[srcChainId][owner];
        require(claimDebitAmount.native >= native, "_creditClaim.native");
        claimDebitAmount.native -= native;
        //claimDebitAmount.native = claimDebitAmount.native > native ? claimDebitAmount.native - native : 0;
        require(claimDebitAmount.token >= token, "_creditClaim.token");
        claimDebitAmount.token -= token;
        //claimDebitAmount.token = claimDebitAmount.token > token ? claimDebitAmount.token - token : 0;
    }

    function master_deposit(
        uint pongFee,
        uint64 srcChainId,
        address sender,
        address target,
        uint amount
    ) internal virtual override {
        require(!launched, "launched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");
        require(msg.value == amount + pongFee, "value err.");
        uint expectPongFee = depositPongEstimateGas(srcChainId, target, amount);
        if (pongFee < expectPongFee) {
            _creditLocked(sender, amount, 0);
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.deposit), pongFee, expectPongFee);
        } else {
            if (pongFee > expectPongFee) payable(feeAddress).transfer(pongFee - expectPongFee);
            _creditDeposit(srcChainId, target, amount);
            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                0,
                _depositPingPongSignature(target, uint(0), amount),
                address(this)
            );
        }
    }

    function _computeClaim(uint64 srcChainId, address target) internal view virtual returns (uint refund, uint amount) {
        refund = presaleRefundRatio == 0 ? 0 : (slaveDeposited[srcChainId][target] * presaleRefundRatio) / 1 ether;
        uint offset = refund % 2 == 1 ? 1 : 0;
        uint fund = slaveDeposited[srcChainId][target] - refund - offset;
        amount = presaleNative == 0 ? 0 : (presaleSupply * fund) / presaleNative;
    }

    function presaleOf(
        uint64 srcChainId,
        address target
    ) public view virtual returns (uint _deposited, uint _claimed, uint refund, uint amount) {
        (refund, amount) = _computeClaim(srcChainId, target);
        _deposited = slaveDeposited[srcChainId][target];
        _claimed = slaveClaimed[srcChainId][target];
    }

    function _computePongValueWithOutPongFee(
        uint8 action,
        uint64 srcChainId,
        uint pongFee,
        bytes memory params
    ) internal view virtual override returns (uint value, uint sendToFee) {
        if (action == uint8(ActionType.claimPing)) {
            address target = abi.decode(params, (address));
            (value, ) = _computeClaim(srcChainId, target);
        } else if (action == uint8(ActionType.sellPing)) {
            (, uint token) = abi.decode(params, (address, uint));
            (value, ) = _getAmountOutAtSend(token, false);
        } else return super._computePongValueWithOutPongFee(action, srcChainId, pongFee, params);
    }

    function master_claim(uint pongFee, uint64 srcChainId, address sender, address target) internal virtual override {
        require(launched, "unlaunched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");
        require(slaveClaimed[srcChainId][target] == 0, "claimed");
        uint expectPongFee = claimPongEstimateGas(srcChainId, target);
        if (pongFee < expectPongFee) {
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.claimPing), pongFee, expectPongFee);
        } else {
            if (pongFee > expectPongFee) payable(feeAddress).transfer(pongFee - expectPongFee);
            (uint refund, uint amount) = _computeClaim(srcChainId, target);
            require(msg.value == pongFee + refund, "value err.");
            _burn(address(this), amount);
            _creditClaim(srcChainId, target, refund, amount);
            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                refund,
                _claimPongSignature(target, refund, amount),
                address(this)
            );
        }
    }

    function master_buy(
        uint pongFee,
        uint64 srcChainId,
        address sender,
        address target,
        uint native
    ) internal virtual override {
        require(launched, "unlaunched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");
        require(msg.value == native + pongFee, "value err.");
        uint expectPongFee = buyPongEstimateGas(srcChainId, target, native);

        if (pongFee < expectPongFee) {
            _creditLocked(sender, native + pongFee, 0);
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.buyPing), pongFee, expectPongFee);
        } else {
            (uint amount, uint fee) = _getAmountOutAtSend(native, true);
            /*
            _burn(address(this), amount + fee);
            _mint(feeAddress, fee);
            */
            _burn(address(this), amount);
            _transfer(address(this), feeAddress, fee);
            emit Swap(target, native, 0, 0, amount);

            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                0,
                _buyPongSignature(target, 0, amount),
                address(this)
            );
            if (pongFee > expectPongFee) payable(feeAddress).transfer(pongFee - expectPongFee);
        }
    }

    function _getSellAmountOutAtSelfCall(uint value, uint pongFee) internal view returns (uint amount, uint fee) {
        (uint reserveETH, uint reserveToken) = getReserves();
        return _getAmountOut(reserveETH - pongFee, reserveToken, value, false);
    }

    function master_sell(
        uint pongFee,
        uint64 srcChainId,
        address sender,
        address target,
        uint token
    ) internal virtual override {
        require(launched, "unlaunched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");

        uint expectPongFee = sellPongEstimateGas(srcChainId, dstContracts[srcChainId], token);
        if (pongFee < expectPongFee) {
            _mint(address(this), token);
            _creditLocked(sender, pongFee, token);
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.sellPing), pongFee, expectPongFee);
        } else {
            (uint amountOut, uint fee) = _getSellAmountOutAtSelfCall(token, pongFee);
            require(msg.value == pongFee + amountOut, "value err.");
            _mint(address(this), token);
            payable(feeAddress).transfer(fee);
            emit Swap(target, 0, token, amountOut, 0);
            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                amountOut,
                _sellPongSignature(target, 0, amountOut),
                address(this)
            );
            if (pongFee > expectPongFee) payable(feeAddress).transfer(pongFee - expectPongFee);
        }
    }

    function deposit(uint pongFee, uint amount) public payable virtual override nonReentrant {
        require(!launched, "launched");
        require(pongFee == 0 && msg.value == amount, "value err.");
        _creditDeposit(uint64(block.chainid), _msgSender(), amount);
        deposited[_msgSender()] += amount;
    }

    function claim(uint pongFee) public payable virtual override nonReentrant {
        require(launched, "unlaunched");
        require(pongFee == 0 && msg.value == 0, "value err.");
        address target = _msgSender();
        (uint refund, uint amount) = _computeClaim(uint64(block.chainid), target);
        _creditClaim(uint64(block.chainid), target, refund, amount);
        _transfer(address(this), target, amount);
        payable(target).transfer(refund);
        claimed[target] = true;
    }

    function unlock(address to) external virtual nonReentrant {
        address owner = _msgSender();
        uint native = locked[owner].native;
        uint token = locked[owner].token;
        _debitLocked(owner, native, token);
        payable(to).transfer(native);
        _transfer(address(this), to, token);
    }

    function swapExactETHForTokens(
        uint pongFee,
        address to,
        uint deadline
    ) external payable virtual override nonReentrant {
        require(launched, "unlaunched");
        require(deadline == 0 || deadline > block.timestamp, "deadline err.");
        require(pongFee == 0 && msg.value > 0, "value err.");
        uint amountIn = msg.value;
        require(amountIn > 0, "amount in err.");
        (uint amount, uint fee) = _getAmountOutAtSend(amountIn, true);

        _transfer(address(this), to, amount);
        _transfer(address(this), feeAddress, fee);
        emit Swap(_msgSender(), amountIn, 0, 0, amount);
    }

    function swapExactTokensForETH(
        uint pongFee,
        uint amountIn,
        address to,
        uint deadline
    ) external payable virtual override nonReentrant {
        require(launched, "unlaunched");
        require(deadline == 0 || deadline > block.timestamp, "deadline err.");
        require(pongFee == 0 && msg.value == 0, "value err.");
        require(amountIn > 0, "amount in err.");
        (uint amount, uint fee) = _getAmountOutAtSend(amountIn, false);

        //_spendAllowance(_msgSender(), address(this), amountIn);
        ERC20._transfer(_msgSender(), address(this), amountIn);

        payable(to).transfer(amount);
        payable(feeAddress).transfer(fee);
        emit Swap(_msgSender(), 0, amountIn, amount, 0);
    }

    //----EstimateGas----
    function depositPongEstimateGas(
        uint64 dstChainId,
        address target,
        uint amount
    ) public view virtual returns (uint pongFee) {
        pongFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            0,
            _depositPingPongSignature(target, 0, amount)
        );
    }

    function claimPongEstimateGas(uint64 dstChainId, address target) public view virtual returns (uint pongFee) {
        (uint refund, uint amount) = _computeClaim(dstChainId, target);
        pongFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            refund,
            _claimPongSignature(target, refund, amount)
        );
    }

    function buyPongEstimateGas(
        uint64 dstChainId,
        address target,
        uint amountIn
    ) public view virtual returns (uint pongFee) {
        (uint amountOut, uint fee) = getAmountOut(amountIn, true);
        pongFee = paramsEstimateGas(dstChainId, dstContracts[dstChainId], 0, _buyPongSignature(target, 0, amountOut));
    }

    function sellPongEstimateGas(
        uint64 dstChainId,
        address target,
        uint amountIn
    ) public view virtual returns (uint pongFee) {
        (uint amountOut, uint fee) = getAmountOut(amountIn, false);
        pongFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            amountOut,
            _sellPongSignature(target, amountOut, 0)
        );
    }
}
