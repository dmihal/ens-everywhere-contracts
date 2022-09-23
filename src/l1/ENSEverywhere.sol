// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IBulkRegistrarController } from "../interfaces/IBulkRegistrarController.sol";

contract ENSEverywhere {
    IBulkRegistrarController public immutable ensBulkRegistrar;

    constructor(address _ensBulkRegistrar) {
        ensBulkRegistrar = IBulkRegistrarController(_ensBulkRegistrar);
    }

    function commit(bytes32 commitment) external {
        ensBulkRegistrar.commit(commitment);
    }

    function register(
        string[] calldata names,
        address[] calldata owners,
        uint256[] calldata durations,
        bytes12[] calldata secrets
    ) external {
        require(
            names.length == secrets.length
            && names.length == owners.length
            && names.length == durations.length
        );

        IBulkRegistrarController.Registration[] memory registrations =
            new IBulkRegistrarController.Registration[](names.length);

        for (uint256 i = 0; i < names.length; i += 1) {
            registrations[i] = IBulkRegistrarController.Registration({
                name: names[i],
                owner: owners[i],
                duration: durations[i],
                resolver: address(0),
                secret: secrets[i],
                data: new bytes[](0),
                reverseRecord: false,
                fuses: 0,
                wrapperExpiry: 0
            });
        }

        ensBulkRegistrar.register(registrations);
    }
}
