// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721Facet.sol";
import {ERC721MintFacet} from "../contracts/facets/ERC721MintFacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IERC721Extension} from "../contracts/interfaces/IERC721Extension.sol";

contract ERC721MintFacetTest is Test {

    Diamond          internal diamond;
    ERC721Facet      internal token;
    IERC721Extension internal tokenExt;
    ERC721Facet      internal tokenFull;

    address internal owner   = makeAddr("owner");
    address internal alice   = makeAddr("alice");
    address internal bob     = makeAddr("bob");
    address internal charlie = makeAddr("charlie");
    address internal minter  = makeAddr("minter");

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public {
        vm.startPrank(owner);

        DiamondCutFacet dcf     = new DiamondCutFacet();
        diamond                 = new Diamond(owner, address(dcf));
        ERC721Facet erc721Facet = new ERC721Facet();

        bytes4[] memory baseSelectors = new bytes4[](11);
        baseSelectors[0]  = ERC721Facet.initERC721.selector;
        baseSelectors[1]  = ERC721Facet.erc721Name.selector;
        baseSelectors[2]  = ERC721Facet.erc721Symbol.selector;
        baseSelectors[3]  = ERC721Facet.tokenURI.selector;
        baseSelectors[4]  = ERC721Facet.erc721BalanceOf.selector;
        baseSelectors[5]  = ERC721Facet.ownerOf.selector;
        baseSelectors[6]  = ERC721Facet.erc721Approve.selector;
        baseSelectors[7]  = ERC721Facet.getApproved.selector;
        baseSelectors[8]  = ERC721Facet.setApprovalForAll.selector;
        baseSelectors[9]  = ERC721Facet.isApprovedForAll.selector;
        baseSelectors[10] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

        IDiamondCut.FacetCut[] memory baseCut = new IDiamondCut.FacetCut[](1);
        baseCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: baseSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(
            baseCut,
            address(erc721Facet),
            abi.encodeWithSelector(ERC721Facet.initERC721.selector, "TestNFT", "TNFT")
        );

        ERC721MintFacet mintFacet = new ERC721MintFacet();

        bytes4[] memory mintSelectors = new bytes4[](9);
        mintSelectors[0] = ERC721MintFacet.mint.selector;
        mintSelectors[1] = ERC721MintFacet.batchMint.selector;
        mintSelectors[2] = ERC721MintFacet.burn.selector;
        mintSelectors[3] = ERC721MintFacet.pause.selector;
        mintSelectors[4] = ERC721MintFacet.unpause.selector;
        mintSelectors[5] = bytes4(keccak256("paused()"));
        mintSelectors[6] = ERC721MintFacet.addMinter.selector;
        mintSelectors[7] = ERC721MintFacet.removeMinter.selector;
        mintSelectors[8] = ERC721MintFacet.isMinter.selector;

        IDiamondCut.FacetCut[] memory mintCut = new IDiamondCut.FacetCut[](1);
        mintCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(mintFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: mintSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(mintCut, address(0), "");

        token     = ERC721Facet(address(diamond));
        tokenExt  = IERC721Extension(address(diamond));
        tokenFull = ERC721Facet(address(diamond));

        vm.stopPrank();
    }

    // ── Mint ──────────────────────────────────────────────────────────────────

    function test_OwnerCanMint() public {
        vm.prank(owner);
        uint256 tokenId = tokenExt.mint(alice, "ipfs://token/1");
        assertEq(tokenId, 0);
        assertEq(token.ownerOf(0), alice);
        assertEq(token.erc721BalanceOf(alice), 1);
    }

    function test_MintIncrementsTokenId() public {
        vm.startPrank(owner);
        uint256 id0 = tokenExt.mint(alice, "ipfs://1");
        uint256 id1 = tokenExt.mint(alice, "ipfs://2");
        uint256 id2 = tokenExt.mint(bob,   "ipfs://3");
        vm.stopPrank();
        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(token.erc721BalanceOf(alice), 2);
        assertEq(token.erc721BalanceOf(bob),   1);
    }

    function test_MintSetsTokenURI() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://metadata/1");
        assertEq(tokenFull.tokenURI(0), "ipfs://metadata/1");
    }

    function test_MintRevertsForNonMinter() public {
        vm.prank(alice);
        vm.expectRevert("ERC721: not a minter");
        tokenExt.mint(bob, "ipfs://x");
    }

    function test_MintRevertsToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("ERC721: mint to zero address");
        tokenExt.mint(address(0), "ipfs://x");
    }

    function test_MintEmitsTransferEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 0);
        tokenExt.mint(alice, "ipfs://1");
    }

    // ── Minter role ───────────────────────────────────────────────────────────

    function test_AddMinter() public {
        vm.prank(owner);
        tokenExt.addMinter(minter);
        assertTrue(tokenExt.isMinter(minter));
    }

    function test_MinterCanMint() public {
        vm.prank(owner);
        tokenExt.addMinter(minter);
        vm.prank(minter);
        uint256 tokenId = tokenExt.mint(alice, "ipfs://minter/1");
        assertEq(token.ownerOf(tokenId), alice);
    }

    function test_RemoveMinter() public {
        vm.prank(owner);
        tokenExt.addMinter(minter);
        vm.prank(owner);
        tokenExt.removeMinter(minter);
        assertFalse(tokenExt.isMinter(minter));
        vm.prank(minter);
        vm.expectRevert("ERC721: not a minter");
        tokenExt.mint(alice, "ipfs://x");
    }

    function test_OnlyOwnerCanAddMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        tokenExt.addMinter(bob);
    }

    // ── Batch mint ────────────────────────────────────────────────────────────

    function test_BatchMint() public {
        string[] memory uris = new string[](3);
        uris[0] = "ipfs://1";
        uris[1] = "ipfs://2";
        uris[2] = "ipfs://3";
        vm.prank(owner);
        uint256[] memory ids = tokenExt.batchMint(alice, uris);
        assertEq(ids.length, 3);
        assertEq(token.erc721BalanceOf(alice), 3);
        for (uint256 i; i < 3; i++) {
            assertEq(token.ownerOf(ids[i]), alice);
            assertEq(tokenFull.tokenURI(ids[i]), uris[i]);
        }
    }

    function test_BatchMintRevertsForNonMinter() public {
        string[] memory uris = new string[](1);
        uris[0] = "ipfs://1";
        vm.prank(alice);
        vm.expectRevert("ERC721: not a minter");
        tokenExt.batchMint(bob, uris);
    }

    // ── Burn ──────────────────────────────────────────────────────────────────

    function test_OwnerCanBurn() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        tokenExt.burn(0);
        assertEq(token.erc721BalanceOf(alice), 0);
        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(0);
    }

    function test_ApprovedCanBurn() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        token.erc721Approve(bob, 0);
        vm.prank(bob);
        tokenExt.burn(0);
        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(0);
    }

    function test_BurnClearsApproval() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        token.erc721Approve(bob, 0);
        vm.prank(alice);
        tokenExt.burn(0);
        vm.expectRevert("ERC721: nonexistent token");
        token.getApproved(0);
    }

    function test_BurnRevertsIfNotApproved() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(charlie);
        vm.expectRevert("ERC721: not approved");
        tokenExt.burn(0);
    }

    function test_BurnRevertsOnNonexistentToken() public {
        vm.expectRevert("ERC721: invalid token ID");
        tokenExt.burn(999);
    }

    // ── Pause ─────────────────────────────────────────────────────────────────

    function test_OwnerCanPause() public {
        vm.prank(owner);
        tokenExt.pause();
        assertTrue(tokenExt.paused());
    }

    function test_OwnerCanUnpause() public {
        vm.prank(owner);
        tokenExt.pause();
        vm.prank(owner);
        tokenExt.unpause();
        assertFalse(tokenExt.paused());
    }

    function test_MintRevertsWhenPaused() public {
        vm.prank(owner);
        tokenExt.pause();
        vm.prank(owner);
        vm.expectRevert("ERC721: paused");
        tokenExt.mint(alice, "ipfs://1");
    }

    function test_BurnRevertsWhenPaused() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(owner);
        tokenExt.pause();
        vm.prank(alice);
        vm.expectRevert("ERC721: paused");
        tokenExt.burn(0);
    }

    function test_TransferRevertsWhenPaused() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(owner);
        tokenExt.pause();
        vm.prank(alice);
        vm.expectRevert("ERC721: paused");
        token.safeTransferFrom(alice, bob, 0);
    }

    function test_NonOwnerCannotPause() public {
        vm.prank(alice);
        vm.expectRevert();
        tokenExt.pause();
    }

    // ── Transfer ──────────────────────────────────────────────────────────────

    function test_SafeTransferFrom() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 0);
        assertEq(token.ownerOf(0), bob);
        assertEq(token.erc721BalanceOf(alice), 0);
        assertEq(token.erc721BalanceOf(bob), 1);
    }

    function test_TransferClearsApproval() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        token.erc721Approve(bob, 0);
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, 0);
        assertEq(token.getApproved(0), address(0));
    }

    function test_ApprovedAddressCanTransfer() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        token.erc721Approve(bob, 0);
        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, 0);
        assertEq(token.ownerOf(0), charlie);
    }

    function test_OperatorCanTransfer() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(alice);
        token.setApprovalForAll(bob, true);
        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, 0);
        assertEq(token.ownerOf(0), charlie);
    }

    function test_TransferRevertsIfNotApproved() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://1");
        vm.prank(charlie);
        vm.expectRevert("ERC721: not approved");
        token.safeTransferFrom(alice, charlie, 0);
    }

    // ── Storage isolation ─────────────────────────────────────────────────────

    function test_StorageSharedBetweenFacets() public {
        vm.prank(owner);
        tokenExt.mint(alice, "ipfs://shared");
        assertEq(token.ownerOf(0), alice);
        assertEq(token.erc721BalanceOf(alice), 1);
        assertEq(tokenFull.tokenURI(0), "ipfs://shared");
    }
}
