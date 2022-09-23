// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IL2Controller {
    function recordCommitment(address relayer, bytes calldata l1Commitments) external;

    function recordRegistration(
        address relayer,
        string[] calldata names,
        bytes32[] calldata skippedCommitments
    ) external;
}
