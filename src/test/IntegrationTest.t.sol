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
import { L2NFT } from "../l2/L2NFT.sol";

contract L2ControllerTest is DSTest {
    using UserLib for User;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    User[] internal users;

    MockBaseRegistrar baseRegistrar;
    MockENSBulkRegistrar bulkRegistrar;

    L2NFT nft;
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
        nft = new L2NFT(address(0));
        l2Controller = new L2Controller(address(bridge), address(nft), COOLDOWN_PERIOD, COOLDOWN_PERIOD);
        nft.setController(address(l2Controller));
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

    function testRegistrationCompleted() public {
        User memory vitalik = users[1];
        User memory relayer = users[2];

        string memory name = "vitalik.eth";
        bytes32 label = keccak256(bytes(name));
        bytes12 secret = 0x000000000000000000042069;
        uint32 duration = 1 days;

        bytes32 commitment = l2Controller.generateCommitment(name, secret, duration);

        uint256 vitalikStartDaiBalance = utils.dai().balanceOf(vitalik.addr());
        uint256 relayerStartDaiBalance = utils.dai().balanceOf(relayer.addr());

        vm.startPrank(vitalik.addr());

        utils.dai().approve(address(l2Controller), 20 ether);
        l2Controller.createCommitment(commitment, address(utils.dai()), 10 ether, 10 ether);

        L2Controller.Commitment memory commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.creator, vitalik.addr());
        assertEq(commitmentData.feeToken, address(utils.dai()));
        assertEq(commitmentData.feeAmount, 10 ether);
        assertEq(commitmentData.withdrawTime, 0);

        vm.stopPrank();

        vm.startPrank(relayer.addr());

        (bool success,) = address(l1Controller).call(abi.encodePacked(l1Controller.commit.selector, commitment));
        require(success, "Commit failed");

        commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.feeAmount, 0);

        vm.stopPrank();

        vm.startPrank(vitalik.addr());

        l2Controller.revealCommitment(name, secret, duration);
        assertEq(l2Controller.commitmentsByLabel(label), commitment);

        vm.stopPrank();

        vm.warp(block.timestamp + MINIMUM_WAIT + 1);

        vm.startPrank(relayer.addr());

        L1Controller.Registration[] memory registrations = new L1Controller.Registration[](1);
        registrations[0] = L1Controller.Registration({
            name: name,
            secret: secret,
            duration: duration,
            commitment: bytes32(0)
        });
        uint256 price = bulkRegistrar.namePrice(name);
        l1Controller.register{ value: price }(registrations);

        assertEq(nft.ownerOf(uint256(label)), vitalik.addr(), "L2 NFT not created");

        vm.stopPrank();
    }
}
