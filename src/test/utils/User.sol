// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import { Vm } from "forge-std/Vm.sol";
import { DSTest } from "ds-test/test.sol";

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct User {
    uint256 privateKey;
}

library UserLib {
    address constant HEVM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256('hevm cheat code')))));

    function label(User memory user, string memory name) external {
        Vm hevm = Vm(HEVM_ADDRESS);
        hevm.label(hevm.addr(user.privateKey), name);
    }

    function addr(User memory user) external returns (address) {
        Vm hevm = Vm(HEVM_ADDRESS);

        return hevm.addr(user.privateKey);
    }

    function sign(User memory user, bytes32 message) public returns (Signature memory signature) {
        Vm hevm = Vm(HEVM_ADDRESS);

        (uint8 v, bytes32 r, bytes32 s) =  hevm.sign(user.privateKey, message);
        return Signature(v, r, s);
    }

    function signEIP712(
        User memory user,
        bytes32 domainSeparator,
        bytes memory body
    ) external returns (Signature memory) {        
        return sign(
            user,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(body)
                )
            )
        );
    }
}
