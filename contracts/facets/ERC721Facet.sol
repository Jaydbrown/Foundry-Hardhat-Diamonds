// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Base} from "../interfaces/IERC721Base.sol";
import {AppStorage, NFTAttributes} from "../storage/AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ERC721Facet is IERC721Base {

    AppStorage internal s;

    event Paused(address account);
    event Unpaused(address account);

    function initERC721(string calldata _name, string calldata _symbol) external {
        LibAppStorage.enforceIsContractOwner();
        require(bytes(s.erc721Name).length == 0, "ERC721: already initialized");
        s.erc721Name   = _name;
        s.erc721Symbol = _symbol;
    }

    function erc721Name()   external view returns (string memory) { return s.erc721Name; }
    function erc721Symbol() external view returns (string memory) { return s.erc721Symbol; }
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(s.erc721Owners[tokenId] != address(0), "ERC721: nonexistent token");
        return s.erc721TokenURIs[tokenId];
    }

    function erc721BalanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ERC721: zero address");
        return s.erc721Balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = s.erc721Owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function erc721Approve(address to, uint256 tokenId) external {
        address owner = s.erc721Owners[tokenId];
        require(owner != address(0),                      "ERC721: invalid token ID");
        require(to != owner,                              "ERC721: approval to current owner");
        require(
            msg.sender == owner ||
            s.erc721OperatorApprovals[owner][msg.sender], "ERC721: not authorized"
        );
        s.erc721TokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        require(s.erc721Owners[tokenId] != address(0), "ERC721: nonexistent token");
        return s.erc721TokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(operator != msg.sender, "ERC721: approve to caller");
        s.erc721OperatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return s.erc721OperatorApprovals[owner][operator];
    }

    function erc721TransferFrom(address from, address to, uint256 tokenId) external {
        require(!s.erc721Paused,                         "ERC721: paused");
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: not approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(!s.erc721Paused,                         "ERC721: paused");
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: not approved");
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, ""), "ERC721: non receiver");
    }

    function mint(
        address to,
        string calldata uri,
        NFTAttributes calldata attrs
    ) external returns (uint256) {
        require(!s.erc721Paused, "ERC721: paused");
        require(
            s.minters[msg.sender] || msg.sender == LibDiamond.contractOwner(),
            "ERC721: not minter"
        );
        require(to != address(0), "ERC721: mint to zero address");
        uint256 tokenId = s.nextTokenId++;
        s.erc721Balances[to]++;
        s.erc721Owners[tokenId]    = to;
        s.erc721TokenURIs[tokenId] = uri;
        s.nftAttributes[tokenId]   = attrs;
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    function burn(uint256 tokenId) external {
        require(!s.erc721Paused,                         "ERC721: paused");
        address owner = s.erc721Owners[tokenId];
        require(owner != address(0),                     "ERC721: invalid token ID");
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: not approved");
        delete s.erc721TokenApprovals[tokenId];
        s.erc721Balances[owner]--;
        delete s.erc721Owners[tokenId];
        delete s.erc721TokenURIs[tokenId];
        delete s.nftAttributes[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function pause() external {
        LibAppStorage.enforceIsContractOwner();
        s.erc721Paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        LibAppStorage.enforceIsContractOwner();
        s.erc721Paused = false;
        emit Unpaused(msg.sender);
    }

    function paused() external view returns (bool) { return s.erc721Paused; }

    function addMinter(address account) external {
        LibAppStorage.enforceIsContractOwner();
        s.minters[account] = true;
    }

    function getNFTAttributes(uint256 tokenId) external view returns (NFTAttributes memory) {
        return s.nftAttributes[tokenId];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = s.erc721Owners[tokenId];
        return (
            spender == owner ||
            s.erc721TokenApprovals[tokenId] == spender ||
            s.erc721OperatorApprovals[owner][spender]
        );
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(s.erc721Owners[tokenId] == from, "ERC721: wrong owner");
        require(to != address(0),                "ERC721: to zero address");
        delete s.erc721TokenApprovals[tokenId];
        s.erc721Balances[from]--;
        s.erc721Balances[to]++;
        s.erc721Owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from, address to, uint256 tokenId, bytes memory data
    ) internal returns (bool) {
        if (to.code.length == 0) return true;
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
            returns (bytes4 ret) {
            return ret == IERC721Receiver.onERC721Received.selector;
        } catch { return false; }
    }
}

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}
