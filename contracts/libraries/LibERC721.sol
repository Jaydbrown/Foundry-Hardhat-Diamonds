// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibERC721 {

    bytes32 constant ERC721_STORAGE_POSITION =
        keccak256("diamond.standard.erc721.storage");

    struct ERC721Storage {
        string name;
        string symbol;
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        mapping(uint256 => string) tokenURIs;
        uint256 nextTokenId;
        bool paused;
        mapping(address => bool) minters;
    }

    function erc721Storage()
        internal
        pure
        returns (ERC721Storage storage es)
    {
        bytes32 position = ERC721_STORAGE_POSITION;
        assembly {
            es.slot := position
        }
    }
}