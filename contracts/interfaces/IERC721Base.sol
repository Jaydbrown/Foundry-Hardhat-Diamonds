// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721Base {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function erc721BalanceOf(address owner)                                        external view returns (uint256);
    function ownerOf(uint256 tokenId)                                              external view returns (address);
    function erc721Approve(address to, uint256 tokenId)                            external;
    function getApproved(uint256 tokenId)                                          external view returns (address);
    function setApprovalForAll(address operator, bool approved)                    external;
    function isApprovedForAll(address owner, address operator)                     external view returns (bool);
    function erc721TransferFrom(address from, address to, uint256 tokenId)         external;
    function safeTransferFrom(address from, address to, uint256 tokenId)           external;
}
