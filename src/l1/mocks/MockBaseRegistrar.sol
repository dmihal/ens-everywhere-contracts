// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { ERC721 } from "solmate/tokens/ERC721.sol";
// import { IBaseRegistrar } from "../interfaces/IBaseRegistrar.sol";

contract MockBaseRegistrar is ERC721 /* , IBaseRegistrar */ {
    constructor() ERC721("ENS", "ENS") {}

    function register(
        uint256 id,
        address owner,
        uint256 /* duration */
    ) external returns (uint256) {
        _mint(owner, id);
        return id;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return "";
    }

    function setResolver(address resolver) external {}

    function renew(uint256 id, uint256 duration) external returns (uint256) {}

    function addController(address controller) external {}

    function removeController(address controller) external {}
    
    function reclaim(uint256 id, address owner) external {}

    function nameExpires(uint256 id) external view returns (uint256) {}

    function available(uint256 id) external view returns (bool) {}

}
