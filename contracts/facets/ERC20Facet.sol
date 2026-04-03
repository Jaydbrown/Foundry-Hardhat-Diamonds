// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../interfaces/IERC20.sol";
import {AppStorage} from "../storage/AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract ERC20Facet is IERC20 {

    AppStorage internal s;

    // ── Init ──────────────────────────────────────────────────────────────────

    function initERC20(
        string calldata _name,
        string calldata _symbol,
        uint8  _decimals,
        uint256 _initialSupply
    ) external {
        LibAppStorage.enforceIsContractOwner();
        require(bytes(s.erc20Name).length == 0, "ERC20: already initialized");
        s.erc20Name      = _name;
        s.erc20Symbol    = _symbol;
        s.erc20Decimals  = _decimals;
        s.erc20TotalSupply = _initialSupply;
        s.erc20Balances[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    // ── IERC20 ────────────────────────────────────────────────────────────────

    function name()        external view returns (string memory) { return s.erc20Name; }
    function symbol()      external view returns (string memory) { return s.erc20Symbol; }
    function decimals()    external view returns (uint8)         { return s.erc20Decimals; }
    function totalSupply() external view returns (uint256)       { return s.erc20TotalSupply; }

    function balanceOf(address account) external view returns (uint256) {
        return s.erc20Balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return s.erc20Allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        s.erc20Allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = s.erc20Allowances[from][msg.sender];
        require(allowed >= amount, "ERC20: insufficient allowance");
        s.erc20Allowances[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    // ── Mint / Burn (owner only) ──────────────────────────────────────────────

    function mintERC20(address to, uint256 amount) external {
        LibAppStorage.enforceIsContractOwner();
        s.erc20TotalSupply += amount;
        s.erc20Balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burnERC20(address from, uint256 amount) external {
        LibAppStorage.enforceIsContractOwner();
        require(s.erc20Balances[from] >= amount, "ERC20: insufficient balance");
        s.erc20Balances[from]  -= amount;
        s.erc20TotalSupply     -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0),                        "ERC20: transfer to zero address");
        require(s.erc20Balances[from] >= amount,         "ERC20: insufficient balance");
        s.erc20Balances[from] -= amount;
        s.erc20Balances[to]   += amount;
        emit Transfer(from, to, amount);
    }
}