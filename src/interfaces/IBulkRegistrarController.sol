// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

// import "./IPriceOracle.sol";

interface IBulkRegistrarController {
    struct Registration {
      string name;
      address owner;
      uint256 duration;
      address resolver;
      bytes12 secret;
      bytes[] data;
      bool reverseRecord;
      uint32 fuses;
      uint64 wrapperExpiry;
    }

    // function rentPrice(string memory, uint256)
    //     external
    //     returns (IPriceOracle.Price memory);

    // function available(string memory) external returns (bool);

    function makeCommitment(Registration memory registration) external pure returns (bytes32);

    function makeBulkCommitment(Registration[] memory registrations) external pure returns (bytes32);

    function commit(bytes32) external;

    function register(Registration[] calldata registrations) external payable;
}
