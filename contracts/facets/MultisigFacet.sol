// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, MultiSigTx} from "../storage/AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

contract MultisigFacet {

    AppStorage internal s;

    event TxProposed(uint256 indexed txId, address indexed proposer);
    event TxConfirmed(uint256 indexed txId, address indexed confirmer);
    event TxRevoked(uint256 indexed txId, address indexed revoker);
    event TxExecuted(uint256 indexed txId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 newThreshold);

    // ── Init ──────────────────────────────────────────────────────────────────

    function initMultisig(address[] calldata owners, uint256 threshold) external {
        LibAppStorage.enforceIsContractOwner();
        require(s.multisigOwners.length == 0, "Multisig: already initialized");
        require(threshold > 0 && threshold <= owners.length, "Multisig: invalid threshold");
        for (uint256 i; i < owners.length; i++) {
            require(owners[i] != address(0),    "Multisig: zero address");
            require(!s.isMultisigOwner[owners[i]], "Multisig: duplicate owner");
            s.multisigOwners.push(owners[i]);
            s.isMultisigOwner[owners[i]] = true;
            emit OwnerAdded(owners[i]);
        }
        s.multisigThreshold = threshold;
    }

    // ── Propose a diamondCut ──────────────────────────────────────────────────
    // All diamond upgrades must go through here

    function proposeDiamondCut(
        IDiamondCut.FacetCut[] calldata cuts,
        address                         init,
        bytes   calldata                initCalldata
    ) external returns (uint256 txId) {
        require(s.isMultisigOwner[msg.sender], "Multisig: not owner");
        txId = s.multisigTxCount++;
        s.multisigTxs[txId] = MultiSigTx({
            proposer:     msg.sender,
            to:           address(this),
            data:         abi.encodeWithSelector(
                              IDiamondCut.diamondCut.selector,
                              cuts, init, initCalldata
                          ),
            executed:     false,
            confirmCount: 0,
            createdAt:    block.timestamp
        });
        emit TxProposed(txId, msg.sender);
        // auto-confirm from proposer
        _confirm(txId);
    }

    // ── Confirm ───────────────────────────────────────────────────────────────

    function confirmTx(uint256 txId) external {
        require(s.isMultisigOwner[msg.sender],          "Multisig: not owner");
        require(!s.multisigTxs[txId].executed,          "Multisig: already executed");
        require(!s.multisigConfirmations[txId][msg.sender], "Multisig: already confirmed");
        _confirm(txId);
    }

    // ── Revoke ────────────────────────────────────────────────────────────────

    function revokeTx(uint256 txId) external {
        require(s.isMultisigOwner[msg.sender],           "Multisig: not owner");
        require(!s.multisigTxs[txId].executed,           "Multisig: already executed");
        require(s.multisigConfirmations[txId][msg.sender],"Multisig: not confirmed");
        s.multisigConfirmations[txId][msg.sender] = false;
        s.multisigTxs[txId].confirmCount--;
        emit TxRevoked(txId, msg.sender);
    }

    // ── Execute ───────────────────────────────────────────────────────────────

    function executeTx(uint256 txId) external {
        require(s.isMultisigOwner[msg.sender],                            "Multisig: not owner");
        MultiSigTx storage tx_ = s.multisigTxs[txId];
        require(!tx_.executed,                                            "Multisig: already executed");
        require(tx_.confirmCount >= s.multisigThreshold,                  "Multisig: not enough confirmations");
        tx_.executed = true;
        (bool ok, bytes memory err) = tx_.to.call(tx_.data);
        if (!ok) {
            if (err.length > 0) revert(string(err));
            else revert("Multisig: execution failed");
        }
        emit TxExecuted(txId);
    }

    // ── Owner management ──────────────────────────────────────────────────────
    // These also require multisig threshold

    function addOwner(address owner) external {
        _requireSelf();
        require(!s.isMultisigOwner[owner], "Multisig: already owner");
        s.multisigOwners.push(owner);
        s.isMultisigOwner[owner] = true;
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) external {
        _requireSelf();
        require(s.isMultisigOwner[owner],           "Multisig: not owner");
        require(s.multisigOwners.length - 1 >= s.multisigThreshold, "Multisig: below threshold");
        s.isMultisigOwner[owner] = false;
        for (uint256 i; i < s.multisigOwners.length; i++) {
            if (s.multisigOwners[i] == owner) {
                s.multisigOwners[i] = s.multisigOwners[s.multisigOwners.length - 1];
                s.multisigOwners.pop();
                break;
            }
        }
        emit OwnerRemoved(owner);
    }

    function changeThreshold(uint256 threshold) external {
        _requireSelf();
        require(threshold > 0 && threshold <= s.multisigOwners.length, "Multisig: invalid threshold");
        s.multisigThreshold = threshold;
        emit ThresholdChanged(threshold);
    }

    // ── Views ─────────────────────────────────────────────────────────────────

    function getTx(uint256 txId) external view returns (MultiSigTx memory) {
        return s.multisigTxs[txId];
    }

    function getConfirmCount(uint256 txId) external view returns (uint256) {
        return s.multisigTxs[txId].confirmCount;
    }

    function isConfirmed(uint256 txId, address owner) external view returns (bool) {
        return s.multisigConfirmations[txId][owner];
    }

    function getOwners() external view returns (address[] memory) {
        return s.multisigOwners;
    }

    function getThreshold() external view returns (uint256) {
        return s.multisigThreshold;
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    function _confirm(uint256 txId) internal {
        s.multisigConfirmations[txId][msg.sender] = true;
        s.multisigTxs[txId].confirmCount++;
        emit TxConfirmed(txId, msg.sender);
    }

    // addOwner/removeOwner/changeThreshold must be called by the diamond itself
    // (i.e. via executeTx delegatecall path)
    function _requireSelf() internal view {
        require(msg.sender == address(this), "Multisig: must go through multisig");
    }
}