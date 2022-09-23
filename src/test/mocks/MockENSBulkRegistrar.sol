// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IBulkRegistrarController } from "../../interfaces/IBulkRegistrarController.sol";
import { IBaseRegistrar } from "../../interfaces/IBaseRegistrar.sol";

contract MockENSBulkRegistrar is IBulkRegistrarController {
    address public immutable baseRegistrar;
    uint256 public immutable minimumWait;

    uint256 constant REGISTRATION_FEE = 0.01 ether;
    uint256 constant SHORT_NAME_REGISTRATION_FEE = 0.1 ether;

    mapping(bytes32 => uint256) public commitments;

    constructor(address _baseRegistrar, uint256 _minimumWait) {
        baseRegistrar = _baseRegistrar;
        minimumWait = _minimumWait;
    }

    function commit(bytes32 commitment) external {
        commitments[commitment] = block.timestamp;
    }

    function namePrice(string memory name) public pure returns (uint256) {
        return bytes(name).length > 4 ? REGISTRATION_FEE : SHORT_NAME_REGISTRATION_FEE;
    }

    function makeCommitment(Registration memory registration) public pure returns (bytes32) {
        bytes32 label = keccak256(bytes(registration.name));
        if (registration.data.length > 0) {
            require(
                registration.resolver != address(0),
                "BulkRegistrarController: resolver required when data supplied"
            );
        }
        return
            keccak256(
                abi.encode(
                    label,
                    registration.owner,
                    registration.duration,
                    registration.resolver,
                    registration.data,
                    registration.secret,
                    registration.reverseRecord,
                    registration.fuses,
                    registration.wrapperExpiry
                )
            );
    }

    function makeBulkCommitment(Registration[] memory registrations) public pure returns (bytes32 commitment) {
        bytes32[] memory registrationHashes = new bytes32[](registrations.length);
        for (uint i = 0; i < registrations.length; i += 1) {
            if (bytes(registrations[i].name).length == 0) {
                registrationHashes[i] = bytes32(registrations[i].duration);
            } else {
                bytes32 hash = makeCommitment(registrations[i]);
                registrationHashes[i] = hash;
            }
        }
        commitment = keccak256(abi.encodePacked(registrationHashes));
    }

    function register(Registration[] calldata registrations) external payable {
        uint256 remainingBudget = msg.value;
        bytes32[] memory registrationHashes = new bytes32[](registrations.length);
        for (uint i = 0; i < registrations.length; i += 1) {
            if (bytes(registrations[i].name).length == 0) {
                registrationHashes[i] = bytes32(registrations[i].duration);
            } else {
                bytes32 hash = makeCommitment(registrations[i]);
                registrationHashes[i] = hash;
                uint256 price = _registerName(registrations[i]);

                require(price <= remainingBudget, "Not enough ETH");
                unchecked {
                    remainingBudget -= price;
                }
            }
        }
        bytes32 commitment = keccak256(abi.encodePacked(registrationHashes));

        require(commitments[commitment] + minimumWait < block.timestamp, "Must wait longer");

        if (remainingBudget > 0) {
            payable(msg.sender).transfer(remainingBudget);
        }
    }

    function _registerName(Registration calldata registration) internal returns (uint256) {
        IBaseRegistrar(baseRegistrar).register(
            uint256(keccak256(bytes(registration.name))),
            registration.owner,
            registration.duration
        );

        return namePrice(registration.name);
    }
}
