// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { DSTest } from "ds-test/test.sol";
import { Utilities } from "./utils/Utilities.sol";
import { console } from "./utils/Console.sol";
import { UserLib, User, Signature } from "./utils/User.sol";
import { Vm } from "forge-std/Vm.sol";

import { MockBaseRegistrar } from "./mocks/MockBaseRegistrar.sol";
import { MockBridge } from "./mocks/MockBridge.sol";
import { MockENSBulkRegistrar } from "./mocks/MockENSBulkRegistrar.sol";
import { L1Controller } from "../l1/L1Controller.sol";
import { L2Controller } from "../l2/L2Controller.sol";

contract L2ControllerTest is DSTest {
    using UserLib for User;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    User[] internal users;

    MockBaseRegistrar baseRegistrar;
    MockENSBulkRegistrar bulkRegistrar;

    L1Controller l1Controller;
    L2Controller l2Controller;

    uint256 MINIMUM_WAIT = 1 minutes;
    uint256 COOLDOWN_PERIOD = 1 minutes;

    function setUp() public {
        utils = new Utilities();
        User[] memory _users = utils.createUsers(5);
        for (uint256 i = 0; i < _users.length; i += 1) {
            users.push(_users[i]);
        }

        MockBridge bridge = new MockBridge();

        baseRegistrar = new MockBaseRegistrar();
        bulkRegistrar = new MockENSBulkRegistrar(address(baseRegistrar), MINIMUM_WAIT);
        l1Controller = new L1Controller(address(bulkRegistrar), address(bridge));
        l2Controller = new L2Controller(address(bridge), address(0), COOLDOWN_PERIOD, COOLDOWN_PERIOD);
        l2Controller.setL1Controller(address(l1Controller));
        bridge.setAddresses(address(l1Controller), address(l2Controller));
    }

    function testCommitmentCompleted() public {
        string memory name = "vitalik.eth";
        bytes12 secret = 0x000000000000000000042069;
        uint32 duration = 1 days;

        bytes32 l1Commitment = l1Controller.generateCommitment(name, secret, duration);
        bytes32 l2Commitment = l2Controller.generateCommitment(name, secret, duration);

        assertEq(l1Commitment, l2Commitment);
    }
}
