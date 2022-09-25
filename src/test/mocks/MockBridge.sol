// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract MockBridge {
    address l1;
    address l2;

    function setAddresses(address _l1, address _l2) external {
        l1 = _l1;
        l2 = _l2;
    }

    fallback() external {
        require(msg.sender == l1);
        (bool success, bytes memory result) = l2.call(msg.data);
        require(success, string(result));
    }
}
