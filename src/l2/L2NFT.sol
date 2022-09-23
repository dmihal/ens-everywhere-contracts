// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { Ownable } from "../lib/Ownable.sol";

contract L2NFT is ERC721, Ownable {
    address public controller;

    mapping(uint256 => string) public namesById;

    constructor(address _controller) ERC721("ENSEverywhere", "ENS") {
        controller = _controller;
    }

    modifier onlyController {
        require(msg.sender == controller);
        _;
    }

    function setController(address newController) external {
        controller = newController;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return "";
    }

    function mint(address recipient, uint256 id, string calldata name) external onlyController {
        _mint(recipient, id);
        namesById[id] = name;
    }

    function burn() external onlyController {}
}
