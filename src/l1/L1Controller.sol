// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { Ownable } from "../lib/Ownable.sol";
import { IERC20 } from "../interfaces/IERC20.sol";

import { IBulkRegistrarController } from "../interfaces/IBulkRegistrarController.sol";
import { IL2Controller } from "../interfaces/IL2Controller.sol";

contract L1Controller is Ownable {
    struct Registration {
        string name; // Slot 1
        bytes12 secret; // 12 bytes
        uint32 duration; // 4 bytes
        bytes32 commitment; // Only for skipped registrations, TODO: gas optimize this
    }

    IBulkRegistrarController public immutable ensBulkRegistrar;
    IL2Controller public immutable l2Bridge;

    constructor(address _ensBulkRegistrar, address _l2Bridge) {
        ensBulkRegistrar = IBulkRegistrarController(_ensBulkRegistrar);
        l2Bridge = IL2Controller(_l2Bridge);
    }

    function commit() external {
        require(msg.data.length - 4 % 32 == 0);
        // Todo: maximum commitment size

        bytes32 bulkCommitment = keccak256(abi.encodePacked(msg.data[4:]));

        ensBulkRegistrar.commit(bulkCommitment);

        l2Bridge.recordCommitment(msg.sender, msg.data[4:]);
    }

    function register(Registration[] calldata registrations) external payable {
        IBulkRegistrarController.Registration[] memory fullRegistrations =
            new IBulkRegistrarController.Registration[](registrations.length);

        string[] memory registeredNames = new string[](registrations.length);
        bytes32[] memory skippedCommitments = new bytes32[](registrations.length);

        for (uint256 i = 0; i < registrations.length; i += 1) {
            fullRegistrations[i] = generateRegistration(
                registrations[i].name,
                registrations[i].secret,
                registrations[i].duration
            );

            if (registrations[i].commitment == bytes32(0)) {
                // If the name is empty, then the user didn't provide their data to the relayer
                skippedCommitments[i] = registrations[i].commitment;
            } else {
                registeredNames[i] = registrations[i].name;
            }
        }

        ensBulkRegistrar.register{ value: msg.value }(fullRegistrations);

        // l2Bridge.recordRegistration(msg.sender, registeredNames, skippedCommitments);
    }

    function generateCommitment(
        string calldata name,
        bytes12 secret,
        uint32 duration
    ) external view returns (bytes32) {
        return ensBulkRegistrar.makeCommitment(generateRegistration(name, secret, duration));
    }

    function generateRegistration(
        string calldata name,
        bytes12 secret,
        uint32 duration
    ) internal view returns (IBulkRegistrarController.Registration memory) {
        return IBulkRegistrarController.Registration({
            name: name,
            owner: address(this),
            duration: duration,
            resolver: address(0),
            secret: secret,
            data: new bytes[](0),
            reverseRecord: false,
            fuses: 0,
            wrapperExpiry: 0
        });
    }
}
