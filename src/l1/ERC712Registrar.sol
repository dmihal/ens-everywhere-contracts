// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IBulkRegistrarController } from "./interfaces/IBulkRegistrarController.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IERC721 } from "./interfaces/IERC721.sol";
import { console } from "../test/utils/Console.sol";

contract ERC712Registrar {
    struct Commitment {
        bytes32 commitment;
        uint256 feeAmount;
        address feeToken;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Registration {
        string name; // Slot 1
        address owner; // 20 bytes - Slot 2
        bytes12 secret; // 12 bytes
        uint256 feeAmount; // Slot 3
        address feeToken; // 20 bytes - Slot 4
        uint32 duration; // 4 bytes
        uint8 v; // 1 byte
        bytes32 r; // Slot 5
        bytes32 s; // Slot 6
    }

    IBulkRegistrarController public immutable ensBulkRegistrar;
    
    bytes32 public constant COMMIT_TYPEHASH =
        keccak256("Commit(bytes32 commitment,address feeToken,uint256 feeAmount)");

    bytes32 public constant REGISTER_TYPEHASH =
        keccak256("Register(bytes32 commitment,address feeToken,uint256 feeAmount)");

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    constructor(address _ensBulkRegistrar) {
        ensBulkRegistrar = IBulkRegistrarController(_ensBulkRegistrar);

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    function generateCommitment(
        string calldata name,
        address owner,
        bytes12 secret,
        uint32 duration
    ) public view returns (bytes32) {
        return ensBulkRegistrar.makeCommitment(generateRegistration(
            name, owner, secret, duration
        ));
    }

    function commit(Commitment[] calldata commitments) external {
        for (uint256 i = 0; i < commitments.length; i += 1) {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(
                        COMMIT_TYPEHASH,
                        commitments[i].commitment,
                        commitments[i].feeToken,
                        commitments[i].feeAmount
                    ))
                )
            );

            address recoveredAddress = ecrecover(digest, commitments[i].v, commitments[i].r, commitments[i].s);

            IERC20(commitments[i].feeToken).transferFrom(recoveredAddress, msg.sender, commitments[i].feeAmount);
        }

        bytes32 bulkCommitment = keccak256(abi.encode(commitments));

        ensBulkRegistrar.commit(bulkCommitment);
    }

    function register(Registration[] calldata registrations) external payable {
        IBulkRegistrarController.Registration[] memory fullRegistrations =
            new IBulkRegistrarController.Registration[](registrations.length);

        for (uint256 i = 0; i < registrations.length; i += 1) {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(
                        REGISTER_TYPEHASH,
                        registrations[i].name,
                        registrations[i].owner,
                        registrations[i].duration,
                        registrations[i].secret,
                        registrations[i].feeToken,
                        registrations[i].feeAmount
                    ))
                )
            );

            address recoveredAddress = ecrecover(digest, registrations[i].v, registrations[i].r, registrations[i].s);

            fullRegistrations[i] = generateRegistration(
                registrations[i].name,
                registrations[i].owner == address(0) ? recoveredAddress : registrations[i].owner,
                registrations[i].secret,
                registrations[i].duration
            );

            IERC20(registrations[i].feeToken).transferFrom(recoveredAddress, msg.sender, registrations[i].feeAmount);
        }

        ensBulkRegistrar.register{ value: msg.value }(fullRegistrations);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes("ENSEverywhere - 721")),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function generateRegistration(
        string calldata name,
        address owner,
        bytes12 secret,
        uint32 duration
    ) internal pure returns (IBulkRegistrarController.Registration memory) {
        return IBulkRegistrarController.Registration({
            name: name,
            owner: owner,
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
