// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { Ownable } from "../lib/Ownable.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IL2Controller } from "../interfaces/IL2Controller.sol";

contract L2Controller is Ownable, IL2Controller {
    address public controller;

    struct Commitment {
        address creator;
        address feeToken;
        uint256 feeAmount;
        uint256 withdrawTime;
    }

    mapping(bytes32 => Commitment) private commitments;
    mapping(address => mapping(address => uint256)) private depositBalances;

    address public immutable bridge;
    uint256 public commitmentCooldownPeriod;
    uint256 public registrationCooldownPeriod;

    event CommitmentCreated(bytes32 indexed commitment);
    event CommitmentCooldownStarted(bytes32 indexed commitment);
    event UnknownCommitment(bytes32 indexed commitment);

    constructor(
        address _bridge,
        uint256 _commitmentCooldownPeriod,
        uint256 _registrationCooldownPeriod
    ) {
        bridge = _bridge;
        commitmentCooldownPeriod = _commitmentCooldownPeriod;
        registrationCooldownPeriod = _registrationCooldownPeriod;
    }

    function getCommitment(bytes32 commitment) external view returns (Commitment memory) {
        return commitments[commitment];
    }

    function depositted(address addr, address token) external view returns (uint256) {
        return depositBalances[addr][token];
    }

    function createCommitment(bytes32 commitment, address feeToken, uint256 commitmentFee, uint256 registrationFee) external {
        commitments[commitment] = Commitment({
            creator: msg.sender,
            feeToken: feeToken,
            feeAmount: commitmentFee,
            withdrawTime: 0
        });

        IERC20(feeToken).transferFrom(msg.sender, address(this), commitmentFee + registrationFee);

        depositBalances[msg.sender][feeToken] += commitmentFee + registrationFee;

        emit CommitmentCreated(commitment);
    }

    function cancelCommitment(bytes32 commitment) external {
        Commitment memory commitmentData = commitments[commitment];

        require(commitmentData.creator == msg.sender);
        require(commitmentData.withdrawTime == 0);

        commitments[commitment].withdrawTime = block.timestamp + commitmentCooldownPeriod;

        emit CommitmentCooldownStarted(commitment);
    }

    function withdrawCommitment(bytes32 commitment) external {
        Commitment memory commitmentData = commitments[commitment];

        require(commitmentData.creator == msg.sender);
        require(commitmentData.withdrawTime <= block.timestamp);

        commitments[commitment] = Commitment(address(0), address(0), 0, 0);
        depositBalances[msg.sender][commitmentData.feeToken] -= commitmentData.feeAmount;
        IERC20(commitmentData.feeToken).transfer(msg.sender, commitmentData.feeAmount);
    }

    function recordCommitment(address relayer, bytes calldata l1Commitments) external {
        require(msg.sender == bridge);
        require(l1Commitments.length % 32 == 0);

        for (uint256 i = 0; i < l1Commitments.length; i += 32) {
            bytes32 commitment = bytes32(l1Commitments[i:i + 32]);

            Commitment memory processedCommitment = commitments[commitment];
            if (processedCommitment.creator != address(0)) {
                commitments[commitment] = Commitment(address(0), address(0), 0, 0);

                depositBalances[processedCommitment.creator][processedCommitment.feeToken] -= processedCommitment.feeAmount;

                IERC20(processedCommitment.feeToken).transfer(relayer, processedCommitment.feeAmount);
            } else {
                emit UnknownCommitment(commitment);
            }
        }
    }
}
