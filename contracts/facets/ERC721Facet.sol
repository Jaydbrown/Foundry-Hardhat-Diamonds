// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "../interfaces/IERC721.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC721} from "../libraries/LibERC721.sol";

contract ERC721Facet is ERC721 {


    function initERC721(string calldata _name, string calldata _symbol) external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        require(bytes(es.name).length == 0, "ERC721: already initialized");
        es.name   = _name;
        es.symbol = _symbol;
    }


    function name() external view returns (string memory) {
        return LibERC721.erc721Storage().name;
    }

    function symbol() external view returns (string memory) {
        return LibERC721.erc721Storage().symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(LibERC721.erc721Storage().owners[tokenId] != address(0), "ERC721: nonexistent token");
        return LibERC721.erc721Storage().tokenURIs[tokenId];
    }


    function balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0), "ERC721: zero address");
        return LibERC721.erc721Storage().balances[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = LibERC721.erc721Storage().owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function approve(address _approved, uint256 _tokenId) external payable {
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        address owner = es.owners[_tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        require(_approved != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || es.operatorApprovals[owner][msg.sender],
            "ERC721: not owner nor approved for all"
        );
        es.tokenApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        require(LibERC721.erc721Storage().owners[_tokenId] != address(0), "ERC721: nonexistent token");
        return LibERC721.erc721Storage().tokenApprovals[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        require(_operator != msg.sender, "ERC721: approve to caller");
        LibERC721.erc721Storage().operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return LibERC721.erc721Storage().operatorApprovals[_owner][_operator];
    }

    function safeTransferToken(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata data
    ) external payable {
        require(!LibERC721.erc721Storage().paused, "ERC721: paused");
        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: not approved");
        _transfer(_from, _to, _tokenId);
        require(
            _checkOnERC721Received(_from, _to, _tokenId, data),
            "ERC721: non ERC721Receiver"
        );
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        require(!LibERC721.erc721Storage().paused, "ERC721: paused");
        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: not approved");
        _transfer(_from, _to, _tokenId);
        require(
            _checkOnERC721Received(_from, _to, _tokenId, ""),
            "ERC721: non ERC721Receiver"
        );
    }


    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        address owner = es.owners[tokenId];
        return (
            spender == owner ||
            es.tokenApprovals[tokenId] == spender ||
            es.operatorApprovals[owner][spender]
        );
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        LibERC721.ERC721Storage storage es = LibERC721.erc721Storage();
        require(es.owners[tokenId] == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to zero address");
        delete es.tokenApprovals[tokenId];
        es.balances[from]--;
        es.balances[to]++;
        es.owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal returns (bool) {
        if (to.code.length == 0) return true;
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
            returns (bytes4 retval)
        {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}