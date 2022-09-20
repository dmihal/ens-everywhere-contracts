// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import { UserLib, User } from "./utils/User.sol";

contract ContractTest is DSTest {
    using UserLib for User;
    
		Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    User[] internal users;

    function setUp() public {
        utils = new Utilities();

        User[] memory _users = utils.createUsers(5);
        for (uint256 i = 0; i < _users.length; i += 1) {
            users.push(_users[i]);
        }
		}

    function testExample() public {
        User memory alice = users[0];
        // labels alice's address in call traces as "Alice [<address>]"
        alice.label("Alice");
        console.log("alice's address", alice.addr());
        User memory bob = users[1];
        bob.label("Bob");

        vm.prank(alice.addr());
        (bool sent, ) = bob.addr().call{value: 10 ether}("");
        assertTrue(sent);
        assertGt(bob.addr().balance, alice.addr().balance);
    }
}
