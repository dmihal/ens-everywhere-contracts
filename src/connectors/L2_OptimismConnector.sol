// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../interfaces/iOVM_BaseCrossDomainMessenger.sol";
import "./Connector.sol";

contract L2_OptimismConnector is Connector {
    iOVM_BaseCrossDomainMessenger public messenger;
    uint32 public defaultGasLimit;

    constructor (
        address _owner,
        iOVM_BaseCrossDomainMessenger _messenger,
        uint32 _defaultGasLimit
    )
        Connector(_owner)
    {
        messenger = _messenger;
        defaultGasLimit = _defaultGasLimit;
    }

    /* ========== Override Functions ========== */

    function _forwardCrossDomainMessage() internal override {
        messenger.sendMessage(
            xDomainAddress,
            msg.data,
            defaultGasLimit
        );
    }

    function _verifySender() internal override {
        require(msg.sender == address(messenger), "L2_OVM_CNR: Caller is not the expected sender");
        // Verify that cross-domain sender is expectedSender
        require(messenger.xDomainMessageSender() == xDomainAddress, "L2_OVM_CNR: Invalid cross-domain sender");
    }
}
