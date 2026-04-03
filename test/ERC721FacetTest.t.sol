// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721Facet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";

contract ERC721FacetTest is Test {

    Diamond         internal diamond;
    DiamondCutFacet internal diamondCutFacet;
    ERC721Facet     internal erc721Facet;
    ERC721Facet     internal token;     // cast diamond as ERC721Facet directly
    ERC721Facet     internal tokenFull;

    address internal owner   = makeAddr("owner");
    address internal alice   = makeAddr("alice");
    address internal bob     = makeAddr("bob");
    address internal charlie = makeAddr("charlie");

    function setUp() public {
        vm.startPrank(owner);

        diamondCutFacet = new DiamondCutFacet();
        diamond         = new Diamond(owner, address(diamondCutFacet));
        erc721Facet     = new ERC721Facet();

        bytes4[] memory selectors = new bytes4[](11);
        selectors[0]  = ERC721Facet.initERC721.selector;
        selectors[1]  = ERC721Facet.erc721Name.selector;
        selectors[2]  = ERC721Facet.erc721Symbol.selector;
        selectors[3]  = ERC721Facet.tokenURI.selector;
        selectors[4]  = ERC721Facet.erc721BalanceOf.selector;  // renamed
        selectors[5]  = ERC721Facet.ownerOf.selector;
        selectors[6]  = ERC721Facet.erc721Approve.selector;
        selectors[7]  = ERC721Facet.getApproved.selector;
        selectors[8]  = ERC721Facet.setApprovalForAll.selector;
        selectors[9]  = ERC721Facet.isApprovedForAll.selector;
        selectors[10] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        bytes memory initCalldata = abi.encodeWithSelector(
            ERC721Facet.initERC721.selector,
            "TestNFT",
            "TNFT"
        );

        IDiamondCut(address(diamond)).diamondCut(
            cut,
            address(erc721Facet),
            initCalldata
        );

        token     = ERC721Facet(address(diamond));
        tokenFull = ERC721Facet(address(diamond));

        vm.stopPrank();
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    function test_InitName() public {
        assertEq(tokenFull.erc721Name(), "TestNFT");
    }

    function test_InitSymbol() public {
        assertEq(tokenFull.erc721Symbol(), "TNFT");
    }

    function test_CannotReinitialize() public {
        vm.prank(owner);
        vm.expectRevert("ERC721: already initialized");
        tokenFull.initERC721("Other", "OTH");
    }

    function test_OnlyOwnerCanInit() public {
        DiamondCutFacet dcf2 = new DiamondCutFacet();
        Diamond         d2   = new Diamond(owner, address(dcf2));
        ERC721Facet     ef2  = new ERC721Facet();

        bytes4[] memory sel = new bytes4[](1);
        sel[0] = ERC721Facet.initERC721.selector;
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(ef2),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sel
        });

        vm.prank(owner);
        IDiamondCut(address(d2)).diamondCut(cut, address(0), "");

        vm.prank(alice);
        vm.expectRevert();
        ERC721Facet(address(d2)).initERC721("X", "X");
    }

    // ── erc721BalanceOf ───────────────────────────────────────────────────────

    function test_BalanceOfZeroForNewAddress() public {
        assertEq(token.erc721BalanceOf(alice), 0);
    }

    function test_BalanceOfRevertsOnZeroAddress() public {
        vm.expectRevert("ERC721: zero address");
        token.erc721BalanceOf(address(0));
    }

    // ── ownerOf ───────────────────────────────────────────────────────────────

    function test_OwnerOfRevertsOnNonexistentToken() public {
        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(999);
    }

    // ── approve ───────────────────────────────────────────────────────────────

    function test_ApproveRevertsOnNonexistentToken() public {
        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(alice);
        token.erc721Approve(bob, 999);
    }

    function test_ApproveRevertsIfNotOwner() public {
        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(charlie);
        token.erc721Approve(bob, 0);
    }

    // ── setApprovalForAll ─────────────────────────────────────────────────────

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);
        assertTrue(token.isApprovedForAll(alice, bob));
    }

    function test_RevokeApprovalForAll() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);
        vm.prank(alice);
        token.setApprovalForAll(bob, false);
        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAllRevertsOnSelf() public {
        vm.prank(alice);
        vm.expectRevert("ERC721: approve to caller");
        token.setApprovalForAll(alice, true);
    }
}