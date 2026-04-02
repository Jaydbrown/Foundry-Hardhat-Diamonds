// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC721} from "../libraries/LibERC721.sol";
import {IERC721Extension} from "../interfaces/IERC721Extension.sol";

contract ERC721MintFacet is IERC721Extension {

    function balanceOf(address) external pure returns (uint256) { revert("use ERC721Facet"); }
    function ownerOf(uint256) external pure returns (address) { revert("use ERC721Facet"); }
    function safeTransferToken(address, address, uint256, bytes calldata) external payable { revert("use ERC721Facet"); }
    function safeTransferFrom(address, address, uint256) external payable { revert("use ERC721Facet"); }
    function approve(address, uint256) external payable { revert("use ERC721Facet"); }
    function setApprovalForAll(address, bool) external pure { revert("use ERC721Facet"); }
    function getApproved(uint256) external pure returns (address) { revert("use ERC721Facet"); }
    function isApprovedForAll(address, address) external pure returns (bool) { revert("use ERC721Facet"); }


    function mint(address to, string calldata uri) external returns (uint256) {
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        require(!es.paused, "ERC721: paused");
        require(
            es.minters[msg.sender] || msg.sender == LibDiamond.contractOwner(),
            "ERC721: not a minter"
        );
        require(to != address(0), "ERC721: mint to zero address");
        uint256 tokenId = es.nextTokenId++;
        es.balances[to]++;
        es.owners[tokenId] = to;
        if (bytes(uri).length > 0) es.tokenURIs[tokenId] = uri;
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    function batchMint(address to, string[] calldata uris) external returns (uint256[] memory) {
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        require(!es.paused, "ERC721: paused");
        require(
            es.minters[msg.sender] || msg.sender == LibDiamond.contractOwner(),
            "ERC721: not a minter"
        );
        require(to != address(0), "ERC721: mint to zero address");
        uint256[] memory tokenIds = new uint256[](uris.length);
        for (uint256 i; i < uris.length; i++) {
            uint256 tokenId = es.nextTokenId++;
            es.balances[to]++;
            es.owners[tokenId] = to;
            if (bytes(uris[i]).length > 0) es.tokenURIs[tokenId] = uris[i];
            emit Transfer(address(0), to, tokenId);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }


    function burn(uint256 tokenId) external {
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        address owner = es.owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        require(!es.paused, "ERC721: paused");
        require(
            msg.sender == owner ||
            es.tokenApprovals[tokenId] == msg.sender ||
            es.operatorApprovals[owner][msg.sender],
            "ERC721: not approved"
        );
        delete es.tokenApprovals[tokenId];
        es.balances[owner]--;
        delete es.owners[tokenId];
        delete es.tokenURIs[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }


    function pause() external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.erc721Storage().paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.erc721Storage().paused = false;
        emit Unpaused(msg.sender);
    }

    function paused() external view returns (bool) {
        return LibERC721.erc721Storage().paused;
    }


    function addMinter(address account) external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.erc721Storage().minters[account] = true;
        emit MinterAdded(account);
    }

    function removeMinter(address account) external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.erc721Storage().minters[account] = false;
        emit MinterRemoved(account);
    }

    function isMinter(address account) external view returns (bool) {
        return LibERC721.erc721Storage().minters[account];
    }
}