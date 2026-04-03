// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage} from "../storage/AppStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";

library LibAppStorage {

    function appStorage() internal pure returns (AppStorage storage s) {
        assembly { s.slot := 0 }
    }

    // Delegates to LibDiamond which holds the real owner at its storage slot.
    // AppStorage slot 0 never stores contractOwner — LibDiamond does.
    function enforceIsContractOwner() internal view {
        require(msg.sender == LibDiamond.contractOwner(), "AppStorage: not owner");
    }
}
