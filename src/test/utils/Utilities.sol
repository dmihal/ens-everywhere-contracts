// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { UserLib, User } from "./User.sol";

contract Dai is ERC20("Dai", "DAI", 18) {
    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}

//common utilities for forge tests
contract Utilities is DSTest {
    using UserLib for User;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    bytes32 internal nextKey = keccak256(abi.encodePacked("private key"));

    Dai internal _dai;

    function dai() public returns (Dai) {
        if (address(_dai) == address(0)) {
            _dai = new Dai();
        }
        return _dai;
    }

    function getNextUser() public returns (User memory user) {
        user.privateKey = uint256(nextKey);
        nextKey = keccak256(abi.encodePacked(nextKey));
    }

    //create users with 100 ether balance
    function createUsers(uint256 userNum)
        public
        returns (User[] memory users)
    {
        users = new User[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            User memory user = getNextUser();
            vm.deal(user.addr(), 100 ether);
            dai().mint(user.addr(), 100 ether);
            users[i] = user;
        }
        return users;
    }

    //move block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) public {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }
}
