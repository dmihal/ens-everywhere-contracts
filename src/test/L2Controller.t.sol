// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { DSTest } from "ds-test/test.sol";
import { Utilities } from "./utils/Utilities.sol";
import { console } from "./utils/Console.sol";
import { UserLib, User, Signature } from "./utils/User.sol";
import { Vm } from "forge-std/Vm.sol";

import { L2NFT } from "../l2/L2NFT.sol";
import { L2Controller } from "../l2/L2Controller.sol";

contract L2ControllerTest is DSTest {
    using UserLib for User;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    User internal bridge;
    User[] internal users;

    L2NFT nft;
    L2Controller l2Controller;

    uint256 COOLDOWN_PERIOD = 1 minutes;

    function setUp() public {
        utils = new Utilities();
        User[] memory _users = utils.createUsers(5);
        bridge = _users[0];
        for (uint256 i = 1; i < _users.length; i += 1) {
            users.push(_users[i]);
        }

        nft = new L2NFT(address(0));
        l2Controller = new L2Controller(bridge.addr(), address(nft), COOLDOWN_PERIOD, COOLDOWN_PERIOD);
        nft.setController(address(l2Controller));
    }

    function testCommitCancelAndWithdraw() public {
        User memory vitalik = users[1];
        uint256 vitalikStartDaiBalance = utils.dai().balanceOf(vitalik.addr());
        bytes32 commitment = keccak256("Commitment");

        vm.startPrank(vitalik.addr());

        utils.dai().approve(address(l2Controller), 20 ether);
        l2Controller.createCommitment(commitment, address(utils.dai()), 10 ether, 10 ether);

        L2Controller.Commitment memory commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.creator, vitalik.addr());
        assertEq(commitmentData.feeToken, address(utils.dai()));
        assertEq(commitmentData.feeAmount, 10 ether);
        assertEq(commitmentData.withdrawTime, 0);

        assertEq(utils.dai().balanceOf(vitalik.addr()), vitalikStartDaiBalance - 20 ether);
        assertEq(l2Controller.depositted(vitalik.addr(), address(utils.dai())), 20 ether);

        l2Controller.cancelCommitment(commitment);

        commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.withdrawTime, block.timestamp + COOLDOWN_PERIOD);

        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        l2Controller.withdrawCommitment(commitment);

        commitmentData = l2Controller.getCommitment(commitment);

        assertEq(commitmentData.feeAmount, 0);

        assertEq(utils.dai().balanceOf(vitalik.addr()), vitalikStartDaiBalance - 10 ether);
        assertEq(l2Controller.depositted(vitalik.addr(), address(utils.dai())), 10 ether);

        vm.stopPrank();
    }

    function testCommitmentCompleted() public {
        User memory vitalik = users[1];
        User memory relayer = users[2];
        uint256 vitalikStartDaiBalance = utils.dai().balanceOf(vitalik.addr());
        uint256 relayerStartDaiBalance = utils.dai().balanceOf(relayer.addr());
        bytes32 commitment = keccak256("Commitment");

        vm.startPrank(vitalik.addr());

        utils.dai().approve(address(l2Controller), 20 ether);
        l2Controller.createCommitment(commitment, address(utils.dai()), 10 ether, 10 ether);

        L2Controller.Commitment memory commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.creator, vitalik.addr());
        assertEq(commitmentData.feeToken, address(utils.dai()));
        assertEq(commitmentData.feeAmount, 10 ether);
        assertEq(commitmentData.withdrawTime, 0);

        assertEq(utils.dai().balanceOf(vitalik.addr()), vitalikStartDaiBalance - 20 ether);
        assertEq(l2Controller.depositted(vitalik.addr(), address(utils.dai())), 20 ether);

        vm.stopPrank();

        vm.startPrank(bridge.addr());

        l2Controller.recordCommitment(relayer.addr(), abi.encodePacked(commitment));

        commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.feeAmount, 0);

        assertEq(utils.dai().balanceOf(relayer.addr()), relayerStartDaiBalance + 10 ether);
        assertEq(l2Controller.depositted(vitalik.addr(), address(utils.dai())), 10 ether);

        vm.stopPrank();
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

        vm.startPrank(bridge.addr());

        l2Controller.recordCommitment(relayer.addr(), abi.encodePacked(commitment));

        commitmentData = l2Controller.getCommitment(commitment);
        assertEq(commitmentData.feeAmount, 0);

        vm.stopPrank();

        vm.startPrank(vitalik.addr());

        l2Controller.revealCommitment(name, secret, duration);
        assertEq(l2Controller.commitmentsByLabel(label), commitment);

        vm.stopPrank();

        vm.startPrank(bridge.addr());

        string[] memory names = new string[](1);
        names[0] = name;
        l2Controller.recordRegistration(relayer.addr(), names, new bytes32[](0));

        assertEq(nft.ownerOf(uint256(label)), vitalik.addr());

        vm.stopPrank();
    }
}
