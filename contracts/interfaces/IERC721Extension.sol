// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "./IERC721.sol";


interface IERC721Extension is ERC721 {


    event Paused(address account);
    event Unpaused(address account);
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    function mint(address to, string calldata uri) external returns (uint256);
    function batchMint(address to, string[] calldata uris) external returns (uint256[] memory);
    function burn(uint256 tokenId) external;
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    function addMinter(address account) external;
    function removeMinter(address account) external;
    function isMinter(address account) external view returns (bool);
}