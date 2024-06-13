// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC314PlusCore} from "./ERC314PlusCore.sol";

contract MasterTokenBase is ERC314PlusCore {
    mapping(uint64 => address) dstContracts;
    mapping(address => uint) public omniDeposited; //total chain deposited address=>amount
    mapping(uint64 => mapping(address => uint)) public slaveDeposited; //slave chain deposited chainId=>address=>amount
    mapping(uint64 => mapping(address => uint)) public slaveClaimed;

    mapping(uint64 => mapping(address => mapping(uint => bool))) public sdNonce;
    mapping(uint64 => mapping(address => mapping(uint => bool))) public scNonce;
    mapping(uint64 => mapping(address => mapping(uint => bool))) public sbNonce;
    mapping(uint64 => mapping(address => mapping(uint => bool))) public ssNonce;

    DebitAmount public claimDebitAmount;
    mapping(address => DebitAmount) public locked;
    DebitAmount public lockedDebitAmount;

    uint public presaleAccumulate;
    uint public presaleRefundRatio;
    uint public presaleSupply;
    uint public presaleNative;
    uint public earmarkedSupply;
    uint public earmarkedNative;

    uint public omniSupply;

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

    function setDstContract(uint64 chainId, address addr) public virtual onlyOwner {
        dstContracts[chainId] = addr;
    }

    function delDstContract(uint64 chainId) public virtual onlyOwner {
        delete dstContracts[chainId];
    }

    function verifySource(
        uint64 srcChainId,
        address srcContract
    ) internal view virtual override returns (bool authorized) {
        return dstContracts[srcChainId] == srcContract;
    }

    function launchPay() public view returns (uint amount) {
        uint poolLocked = 0.5 ether;
        uint presale = 0.4 ether;
        uint earmarked = 0.1 ether;
        uint earmarkedAmount = ((launchFunds * 1 ether) / presale * earmarked) /1 ether;
        return earmarkedAmount;
    }
    
    function launch() public payable virtual onlyOwner nonReentrant {
        require(!launched, "launched");
        require(address(this).balance >= presaleAccumulate && presaleAccumulate > 0, "pool insufficient quantity");
        require(presaleAccumulate > launchFunds, "pool insufficient quantity");
        //50% pool locked in trading curve, 40% presale, 10% Earmarked presale for airdrop
        if(tokenomics == 2){
            uint earmarkedAmount = launchPay();
            uint amountIn = msg.value;
            if(amountIn >= earmarkedAmount){
                // payable(feeAddress).transfer(amountIn - earmarkedAmount);                
                transferNative(feeAddress, amountIn - earmarkedAmount);
                // 10% Earmarked presale for airdrop
                uint poolLocked = 0.5 ether;
                uint presale = 0.4 ether;
                uint earmarked = 0.1 ether;
                earmarkedSupply = (totalSupplyInit * earmarked)/1 ether;
                earmarkedNative = earmarkedAmount;
                presaleRefundRatio = ((presaleAccumulate-launchFunds) * 1 ether)/presaleAccumulate;
                presaleSupply = (totalSupplyInit * presale)/ 1 ether;
                omniSupply = totalSupplyInit;
                // feeAddress = _feeAddr;
                launched = true;
                _mint(address(this), totalSupplyInit);
                _transfer(address(this), airdropAddr, earmarkedSupply);

                presaleNative = (presaleAccumulate * (1 ether - presaleRefundRatio)) / 1 ether;
                claimDebitAmount = DebitAmount(presaleAccumulate - presaleNative, presaleSupply);
                emit Launch(earmarkedSupply,earmarkedNative,presaleRefundRatio,presaleSupply,presaleNative,omniSupply,presaleAccumulate);
            } 
        }
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
        if (msg.value > pingFee) 
        // payable(feeAddress).transfer(msg.value - pingFee);
        transferNative(feeAddress,msg.value - pingFee);
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

    function poolInitNative() public view returns (uint native) {
        return presaleNative+earmarkedNative;
    }
    function poolInitSupply() public view returns (uint supply) {
        return presaleSupply+earmarkedSupply;
    }

    function _getAmountOut(
        uint reserveETH,
        uint reserveToken,
        uint value,
        bool _buy
    ) internal view returns (uint amount, uint fee) {
        if (value == 0) return (0, 0);
        if (!launched || (launched && (poolInitNative() == 0 || reserveETH == 0 || reserveToken == 0))) return (0, 0);
        if (_buy) {
            if (value + reserveETH >= poolInitNative()) {
                amount = reserveToken - (poolInitNative() * poolInitSupply()) / (value + reserveETH);
            } else {
                amount = (poolInitSupply() * value) / poolInitNative();
            }
        } else {
            if (value + reserveToken >= poolInitSupply()) {
                amount = (poolInitNative() * value) / poolInitSupply();
            } else {
                amount = reserveETH - (poolInitNative() * poolInitSupply()) / (value + reserveToken);
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
        uint amount,
        uint nonce
    ) internal virtual override {
        require(!sdNonce[srcChainId][sender][nonce], "nonce repetition");
        sdNonce[srcChainId][sender][nonce] = true;
        require(!launched, "launched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");
        require(msg.value == amount + pongFee, "value err.");
        uint expectPongFee = depositPongEstimateGas(nonce,srcChainId, target, amount);
        if (pongFee < expectPongFee) {
            _creditLocked(sender, amount, 0);
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.deposit), pongFee, expectPongFee);
        } else {
            if (pongFee > expectPongFee) 
            // payable(feeAddress).transfer(pongFee - expectPongFee);
                transferNative(feeAddress,pongFee - expectPongFee);
            _creditDeposit(srcChainId, target, amount);
            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                0,
                _depositPingPongSignature(nonce,target, uint(0), amount),
                address(this)
            );
            emit Deposited(srcChainId, sender, amount, nonce);
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
            (uint nonce ,address target) = abi.decode(params, (uint,address));
            (value, ) = _computeClaim(srcChainId, target);
        } else if (action == uint8(ActionType.sellPing)) {
            (uint nonce,address target, uint token) = abi.decode(params, (uint,address, uint));
            (value, ) = _getAmountOutAtSend(token, false);
        } else return super._computePongValueWithOutPongFee(action, srcChainId, pongFee, params);
    }

    function master_claim(uint pongFee, uint64 srcChainId, address sender, address target,uint nonce) internal virtual override {
        require(!scNonce[srcChainId][sender][nonce], "nonce repetition");
        scNonce[srcChainId][sender][nonce] = true;
        require(launched, "unlaunched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");
        require(slaveClaimed[srcChainId][target] == 0, "claimed");
        uint expectPongFee = claimPongEstimateGas(nonce,srcChainId, target);
        if (pongFee < expectPongFee) {
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.claimPing), pongFee, expectPongFee);
        } else {
            if (pongFee > expectPongFee) 
            // payable(feeAddress).transfer(pongFee - expectPongFee);
                transferNative(feeAddress,pongFee - expectPongFee);
            (uint refund, uint amount) = _computeClaim(srcChainId, target);
            require(msg.value >= expectPongFee + refund, "value err.");
            _burn(address(this), amount);
            _creditClaim(srcChainId, target, refund, amount);
            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                refund,
                _claimPongSignature(nonce,target, refund, amount),
                address(this)
            );
            emit Claimed(srcChainId, sender, target, refund, amount,nonce);
        }
    }

    function master_buy(
        uint pongFee,
        uint64 srcChainId,
        address sender,
        address target,
        uint native,
        uint nonce 
    ) internal virtual override {
        require(!sbNonce[srcChainId][sender][nonce], "nonce repetition");
        sbNonce[srcChainId][sender][nonce] = true;
        require(launched, "unlaunched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");
        require(msg.value == native + pongFee, "value err.");
        uint expectPongFee = buyPongEstimateGas(nonce,srcChainId, target, native);

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
            emit Swap(target, native, 0, 0, amount, nonce);

            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                0,
                _buyPongSignature(nonce,target, 0, amount),
                address(this)
            );
            if (pongFee > expectPongFee) 
                // payable(feeAddress).transfer(pongFee - expectPongFee);
                transferNative(feeAddress,pongFee - expectPongFee);
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
        uint token,
        uint nonce
    ) internal virtual override {
        require(!ssNonce[srcChainId][sender][nonce], "nonce repetition");
        ssNonce[srcChainId][sender][nonce] = true;
        require(launched, "unlaunched");
        require(dstContracts[srcChainId] != address(0), "need dest chain contract");

        uint expectPongFee = sellPongEstimateGas(nonce,srcChainId, dstContracts[srcChainId], token);
        if (pongFee < expectPongFee) {
            _mint(address(this), token);
            _creditLocked(sender, pongFee, token);
            emit PongfeeFailed(srcChainId, sender, uint8(ActionType.sellPing), pongFee, expectPongFee);
        } else {
            (uint amountOut, uint fee) = _getSellAmountOutAtSelfCall(token, pongFee);
            require(msg.value == pongFee + amountOut, "value err.");
            if (amountOut > nativeMax) {
                _creditLocked(sender, 0, token);
                emit AssetLocked(ActionType.sellPing, srcChainId, sender, 0, token, nonce);
                return;
            }
            _mint(address(this), token);
            // payable(feeAddress).transfer(fee);
            transferNative(feeAddress, fee);
            emit Swap(target, 0, token, amountOut, 0,nonce);
            paramsEmit2LaunchPad(
                expectPongFee,
                srcChainId,
                dstContracts[srcChainId],
                amountOut,
                _sellPongSignature(nonce,target, 0, amountOut),
                address(this)
            );
            if (pongFee > expectPongFee) 
            // payable(feeAddress).transfer(pongFee - expectPongFee);
                transferNative(feeAddress,pongFee - expectPongFee);
        }
    }

    function unlock(address to) external virtual nonReentrant {
        address owner = _msgSender();
        uint native = locked[owner].native;
        uint token = locked[owner].token;
        _debitLocked(owner, native, token);
        // payable(to).transfer(native);
        transferNative(to, native);
        _transfer(address(this), to, token);
        emit Unlocked(owner, to, native, token);
    }

    //----EstimateGas----
    function depositPongEstimateGas(
        uint nonce,
        uint64 dstChainId,
        address target,
        uint amount
    ) public view virtual returns (uint pongFee) {
        pongFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            0,
            _depositPingPongSignature(nonce,target, 0, amount)
        );
    }

    function claimPongEstimateGas(uint nonce,uint64 dstChainId, address target) public view virtual returns (uint pongFee) {
        (uint refund, uint amount) = _computeClaim(dstChainId, target);
        pongFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            refund,
            _claimPongSignature(nonce,target, refund, amount)
        );
    }

    function buyPongEstimateGas(
        uint nonce,
        uint64 dstChainId,
        address target,
        uint amountIn
    ) public view virtual returns (uint pongFee) {
        (uint amountOut, uint fee) = getAmountOut(amountIn, true);
        pongFee = paramsEstimateGas(dstChainId, dstContracts[dstChainId], 0, _buyPongSignature(nonce,target, 0, amountOut));
    }

    function sellPongEstimateGas(
        uint nonce,
        uint64 dstChainId,
        address target,
        uint amountIn
    ) public view virtual returns (uint pongFee) {
        (uint amountOut, uint fee) = getAmountOut(amountIn, false);
        pongFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            amountOut,
            _sellPongSignature(nonce,target, amountOut, 0)
        );
    }

    function master_cross(uint64 srcChainId, address sender, uint64 dstChainId, address to, uint token,uint nonce) internal virtual override {
        require(!crossNoncePing[srcChainId][sender][nonce], "nonce repetition");
        crossNoncePing[srcChainId][sender][nonce] = true;
        require(dstChainId == block.chainid, "chain id err");
        if (token > 0) _mint(to, token);
        emit Crossed(srcChainId, sender, to, token, nonce);
    }

    function crossToEstimateGas(uint64 dstChainId, address to, uint amount) public view virtual returns (uint pingFee) {
        uint nonce = crossNonce[dstChainId][to];
        pingFee = paramsEstimateGas(
            dstChainId,
            dstContracts[dstChainId],
            0,
            _crossPingSignature(nonce+1,dstChainId, to, amount)
        );
    }

    function crossTo(uint64 dstChainId, address to, uint amount) external payable virtual whenNotPaused{
        require(dstContracts[dstChainId] != address(0), "not slave chain");
        address owner = _msgSender();
        require(balanceOf(owner) > amount, "insufficient balance");
        _burn(owner, amount);
        uint nonce = crossNonce[block.chainid][_msgSender()];
        uint pingFee = crossToEstimateGas(dstChainId, to, amount);
        paramsEmit2LaunchPad(
            pingFee,
            dstChainId,
            dstContracts[dstChainId] ,
            0,
            _crossPingSignature(nonce+1,dstChainId, to, amount),
            _msgSender()
        );
        crossNonce[block.chainid][_msgSender()]++;
    }
    function withdrawFee(address to, uint amount) public onlyOwner nonReentrant {
        transferNative(to, amount);
    }
}
