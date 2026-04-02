// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUpgradeHelper} from "../test/helpers/DiamondUpgradeHelper.sol";
import {ERC721MintFacet} from "../contracts/facets/ERC721MintFacet.sol";

contract UpgradeERC721Mint is Script, DiamondUpgradeHelper {
    function run() external {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");

        vm.startBroadcast();
        ERC721MintFacet mintFacet = new ERC721MintFacet();
        vm.stopBroadcast();

        // Action.Add — triggers LibDiamond.addFunctions internally
        // only selectors that do NOT exist on the diamond yet
        address[] memory addFacetAddresses = new address[](1);
        addFacetAddresses[0] = address(mintFacet);

        string[] memory addFacetNames = new string[](1);
        addFacetNames[0] = "ERC721MintFacet";

        // Nothing to replace or remove
        address[] memory replaceFacetAddresses = new address[](0);
        string[] memory replaceFacetNames     = new string[](0);
        bytes4[] memory removeSelectors        = new bytes4[](0);

        // No init — storage already initialized from first deployment
        address init             = address(0);
        bytes memory initCalldata = hex"";

        IDiamondCut.FacetCut[] memory addCuts = buildAddCutsByNames(
            addFacetAddresses,
            addFacetNames
        );
        IDiamondCut.FacetCut[] memory repCuts = buildReplaceCutsByNames(
            IDiamondLoupe(diamond),
            replaceFacetAddresses,
            replaceFacetNames
        );
        uint256 extra = removeSelectors.length > 0 ? 1 : 0;
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](
            addCuts.length + repCuts.length + extra
        );
        uint256 k = 0;
        for (uint256 i = 0; i < addCuts.length; i++) cuts[k++] = addCuts[i];
        for (uint256 j = 0; j < repCuts.length; j++) cuts[k++] = repCuts[j];
        if (removeSelectors.length > 0)
            cuts[k++] = buildRemoveCut(removeSelectors);

        vm.startBroadcast();
        executeDiamondCut(IDiamondCut(diamond), cuts, init, initCalldata);
        vm.stopBroadcast();
    }
}