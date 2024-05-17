// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExcessivelySafeCall.sol";

abstract contract NonblockingApp {
    //mapping(uint64 => mapping(address => bytes32)) public failedMessages;
    uint public messageFailed;

    event MessageFailed(
        uint64 _srcChainId,
        address _srcAddress,
        bytes _payload,
        bytes _reason,
        uint _value,
        uint _callValue
    );
    event RetryMessageSuccess(uint64 _srcChainId, address _srcAddress, bytes32 _payloadHash);

    function _nonblockingReceive(
        uint64 srcChainId,
        address sender,
        uint8 action,
        uint pongFee,
        bytes calldata message
    ) public payable virtual;

    function _storeFailedMessage(
        uint64 _srcChainId,
        address _srcAddress,
        bytes memory _payload,
        bytes memory _reason,
        uint _callValue
    ) internal virtual {
        messageFailed += 1;
        //failedMessages[_srcChainId][_srcAddress] = keccak256(_payload);
        emit MessageFailed(_srcChainId, _srcAddress, _payload, _reason, msg.value, _callValue);
    }
    /*
    function retryMessage(uint64 _srcChainId, address _srcAddress, bytes calldata _payload) public payable virtual {
        // assert there is message to retry
        bytes32 payloadHash = failedMessages[_srcChainId][_srcAddress];
        require(payloadHash != bytes32(0), "NonblockingApp: no stored message");
        require(keccak256(_payload) == payloadHash, "NonblockingApp: invalid payload");
        // clear the stored message
        failedMessages[_srcChainId][_srcAddress] = bytes32(0);
        // execute the message. revert if it fails again
        _nonblockingReceive(_srcChainId, _srcAddress, _payload);
        emit RetryMessageSuccess(_srcChainId, _srcAddress, payloadHash);
    }
    */
}
