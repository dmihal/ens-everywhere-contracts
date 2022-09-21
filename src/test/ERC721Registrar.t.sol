// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { DSTest } from "ds-test/test.sol";
import { Utilities } from "./utils/Utilities.sol";
import { console } from "./utils/Console.sol";
import { UserLib, User, Signature } from "./utils/User.sol";
import { Vm } from "forge-std/Vm.sol";

import { MockBaseRegistrar } from "../l1/mocks/MockBaseRegistrar.sol";
import { MockENSBulkRegistrar } from "../l1/mocks/MockENSBulkRegistrar.sol";
import { ERC712Registrar } from "../l1/ERC712Registrar.sol";

contract ERC721RegistrarTest is DSTest {
    using UserLib for User;
    
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    User[] internal users;

    MockBaseRegistrar baseRegistrar;
    MockENSBulkRegistrar bulkRegistrar;
    ERC712Registrar erc712Registrar;

    uint256 MINIMUM_WAIT = 1 minutes;

    function setUp() public {
        utils = new Utilities();
        User[] memory _users = utils.createUsers(5);
        for (uint256 i = 0; i < _users.length; i += 1) {
            users.push(_users[i]);
        }

        baseRegistrar = new MockBaseRegistrar();
        bulkRegistrar = new MockENSBulkRegistrar(address(baseRegistrar), MINIMUM_WAIT);
        erc712Registrar = new ERC712Registrar(address(bulkRegistrar));
    }

    function generateCommitSignature(
        User memory user,
        bytes32 commitment,
        address feeToken,
        uint256 amount
    ) internal returns (Signature memory) {
        return user.signEIP712(
            erc712Registrar.DOMAIN_SEPARATOR(),
            abi.encode(erc712Registrar.COMMIT_TYPEHASH(), commitment, feeToken, amount)
        );
    }

    function generateRegistrationSignature(
        User memory user,
        string memory name,
        address owner,
        uint256 duration,
        bytes12 secret,
        address feeToken,
        uint256 feeAmount
    ) internal returns (Signature memory) {
        return user.signEIP712(
            erc712Registrar.DOMAIN_SEPARATOR(),
            abi.encode(
                erc712Registrar.REGISTER_TYPEHASH(),
                name,
                owner,
                duration,
                secret,
                feeToken,
                feeAmount
            )
        );
    }

    function testCommitAndRegister() public {
        User memory relayer = users[0];
        User memory vitalik = users[1];
        string memory name = "vitalik.eth";
        uint256 expectedID = uint256(keccak256(bytes(name))); // Note: we don't use the real namehash

        uint32 duration = 1 days;
        uint256 relayerStartDaiBalance = utils.dai().balanceOf(relayer.addr());

        bytes12 secret = 0x000000000000000000042069;
        bytes32 commitment = erc712Registrar.generateCommitment(name, vitalik.addr(), secret, duration);

        {
        Signature memory commitSignature = generateCommitSignature(
            vitalik,
            commitment,
            address(utils.dai()),
            0.001 ether
        );

        console.log('vitalik', vitalik.addr());

        vm.startPrank(vitalik.addr());
        utils.dai().approve(address(erc712Registrar), 0.001 ether);
        vm.stopPrank();

        vm.startPrank(relayer.addr());
        ERC712Registrar.Commitment[] memory commitmentArray = new ERC712Registrar.Commitment[](1);
        commitmentArray[0] = ERC712Registrar.Commitment({
            commitment: commitment,
            feeAmount: 0.001 ether,
            feeToken: address(utils.dai()),
            v: commitSignature.v,
            r: commitSignature.r,
            s: commitSignature.s
        });
        erc712Registrar.commit(commitmentArray);

        vm.stopPrank();

        assertEq(utils.dai().balanceOf(relayer.addr()) - relayerStartDaiBalance, 0.001 ether);
        }

        // Register
        {
        vm.warp(block.timestamp + MINIMUM_WAIT + 1);

        vm.startPrank(vitalik.addr());
        utils.dai().approve(address(erc712Registrar), 0.001 ether);
        vm.stopPrank();

        Signature memory registerSignature = generateRegistrationSignature(
            vitalik,
            name,
            vitalik.addr(),
            duration,
            secret,
            address(utils.dai()),
            0.001 ether
        );

        vm.startPrank(relayer.addr());
        ERC712Registrar.Registration[] memory registrationData = new ERC712Registrar.Registration[](1);
        registrationData[0] = ERC712Registrar.Registration({
            name: name,
            owner: vitalik.addr(),
            secret: secret,
            feeAmount: 0.001 ether,
            feeToken: address(utils.dai()),
            duration: duration,
            v: registerSignature.v,
            r: registerSignature.r,
            s: registerSignature.s
        });

        uint256 registrationFees = bulkRegistrar.namePrice(name);

        erc712Registrar.register{ value: registrationFees }(registrationData);

        vm.stopPrank();
        }

        assertEq(utils.dai().balanceOf(relayer.addr()) - relayerStartDaiBalance, 0.002 ether);
        assertEq(baseRegistrar.ownerOf(expectedID), vitalik.addr());
    }
}
