// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { Ownable } from "../lib/Ownable.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IL2Controller } from "../interfaces/IL2Controller.sol";
import { L2NFT } from "./L2NFT.sol";

contract L2Controller is Ownable, IL2Controller {
    address public controller;

    struct Commitment {
        address creator;
        address feeToken;
        uint256 feeAmount;
        uint256 withdrawTime;
        bytes32 label;
    }

    mapping(bytes32 => Commitment) private commitments;
    mapping(address => mapping(address => uint256)) private depositBalances;
    mapping(bytes32 => bytes32) public commitmentsByLabel;

    address public immutable bridge;
    L2NFT public immutable nft;
    uint256 public commitmentCooldownPeriod;
    uint256 public registrationCooldownPeriod;
    address public l1ControllerAddress;

    event CommitmentCreated(bytes32 indexed commitment);
    event CommitmentCooldownStarted(bytes32 indexed commitment);
    event CommitmentRevealed(
        bytes32 indexed commitment,
        string name,
        bytes12 secret,
        uint32 duration
    );
    event UnknownCommitment(bytes32 indexed commitment);
    event UnknownLabel(bytes32 indexed label);

    constructor(
        address _bridge,
        address _nft,
        uint256 _commitmentCooldownPeriod,
        uint256 _registrationCooldownPeriod
    ) {
        bridge = _bridge;
        nft = L2NFT(_nft);
        commitmentCooldownPeriod = _commitmentCooldownPeriod;
        registrationCooldownPeriod = _registrationCooldownPeriod;
    }

    function setL1Controller(address l1Controller) external onlyOwner {
        l1ControllerAddress = l1Controller;
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
            withdrawTime: 0,
            label: bytes32(0)
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

        commitments[commitment] = Commitment(address(0), address(0), 0, 0, bytes32(0));
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
                commitments[commitment].feeAmount = 0;

                depositBalances[processedCommitment.creator][processedCommitment.feeToken] -= processedCommitment.feeAmount;

                IERC20(processedCommitment.feeToken).transfer(relayer, processedCommitment.feeAmount);
            } else {
                emit UnknownCommitment(commitment);
            }
        }
    }

    function revealCommitment(
        string calldata name,
        bytes12 secret,
        uint32 duration
    ) external {
        bytes32 label = keccak256(bytes(name));
        bytes32 commitment = generateCommitment(name, secret, duration);
        Commitment memory commitmentData = commitments[commitment];

        require(commitmentData.creator != address(0));

        commitmentsByLabel[label] = commitment;

        emit CommitmentRevealed(commitment, name, secret, duration);
    }

    function recordRegistration(
        address relayer,
        string[] calldata names,
        bytes32[] calldata skippedCommitments
    ) external {
        for (uint256 i = 0; i < names.length; i += 1) {
            bytes32 label = keccak256(bytes(names[i]));
            bytes32 commitment = commitmentsByLabel[label];

            if (commitment != bytes32(0)) {
                Commitment memory commitmentData = commitments[commitment];

                nft.mint(commitmentData.creator, uint256(label), names[i]);

                // TODO: Pay relayer
                // TODO: clear commitment data
            } else {
                emit UnknownLabel(label);
            }
        }
        // TODO: what to do with skipped commitments?
    }

    function generateCommitment(
        string calldata name,
        bytes12 secret,
        uint32 duration
    ) public view returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        return
            keccak256(
                abi.encode(
                    label,
                    l1ControllerAddress, // Owner
                    uint256(duration),
                    address(0), // Resolver
                    new bytes[](0), //data
                    bytes32(secret),
                    false, // reverseRecord,
                    0, // fuses,
                    0 // wrapperExpiry
                )
            );
    }
}
