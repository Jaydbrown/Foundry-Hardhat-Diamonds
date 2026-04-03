// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Diamond}          from "../contracts/Diamond.sol";
import {DiamondCutFacet}  from "../contracts/facets/DiamondCutFacet.sol";
import {ERC20Facet}       from "../contracts/facets/ERC20Facet.sol";
import {ERC721Facet}      from "../contracts/facets/ERC721Facet.sol";
import {SVGFacet}         from "../contracts/facets/SVGFacet.sol";
import {MultisigFacet}    from "../contracts/facets/MultisigFacet.sol";
import {StakingFacet}     from "../contracts/facets/StakingFacet.sol";
import {BorrowFacet}      from "../contracts/facets/BorrowFacet.sol";
import {MarketplaceFacet} from "../contracts/facets/MarketplaceFacet.sol";
import {IDiamondCut}      from "../contracts/interfaces/IDiamondCut.sol";
import {NFTAttributes}    from "../contracts/storage/AppStorage.sol";

contract DiamondFullTest is Test {

    Diamond          internal diamond;
    ERC20Facet       internal erc20;
    ERC721Facet      internal erc721;
    SVGFacet         internal svg;
    MultisigFacet    internal multisig;
    StakingFacet     internal staking;
    BorrowFacet      internal borrow;
    MarketplaceFacet internal market;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");
    address internal ms2   = makeAddr("ms2");
    address internal ms3   = makeAddr("ms3");

    NFTAttributes internal defaultAttrs = NFTAttributes({
        name:   "TestNFT",
        level:  50,
        rarity: 1,
        power:  1000
    });

    function setUp() public {
        vm.startPrank(owner);

        DiamondCutFacet  dcf     = new DiamondCutFacet();
        diamond                  = new Diamond(owner, address(dcf));

        ERC20Facet       e20     = new ERC20Facet();
        ERC721Facet      e721    = new ERC721Facet();
        SVGFacet         svgF    = new SVGFacet();
        MultisigFacet    msF     = new MultisigFacet();
        StakingFacet     stakeF  = new StakingFacet();
        BorrowFacet      borrowF = new BorrowFacet();
        MarketplaceFacet mktF    = new MarketplaceFacet();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](7);

        // ── ERC20 ─────────────────────────────────────────────────────────────
        // approve(address,uint256)      = 0x095ea7b3  kept on ERC20
        // transferFrom(address,address,uint256) = 0x23b872dd kept on ERC20
        // balanceOf(address)            = 0x70a08231  kept on ERC20
        bytes4[] memory s20 = new bytes4[](10);
        s20[0] = ERC20Facet.initERC20.selector;
        s20[1] = ERC20Facet.name.selector;
        s20[2] = ERC20Facet.symbol.selector;
        s20[3] = ERC20Facet.decimals.selector;
        s20[4] = ERC20Facet.totalSupply.selector;
        s20[5] = ERC20Facet.balanceOf.selector;
        s20[6] = ERC20Facet.allowance.selector;
        s20[7] = ERC20Facet.approve.selector;
        s20[8] = ERC20Facet.transfer.selector;
        s20[9] = ERC20Facet.transferFrom.selector;
        cuts[0] = _cut(address(e20), s20);

        // ── ERC721 ────────────────────────────────────────────────────────────
        // erc721BalanceOf  — renamed from balanceOf     (no clash)
        // erc721Approve    — renamed from approve        (no clash)
        // erc721TransferFrom — renamed from transferFrom (no clash)
        bytes4[] memory s721 = new bytes4[](13);
        s721[0]  = ERC721Facet.initERC721.selector;
        s721[1]  = ERC721Facet.erc721Name.selector;
        s721[2]  = ERC721Facet.erc721Symbol.selector;
        s721[3]  = ERC721Facet.tokenURI.selector;
        s721[4]  = ERC721Facet.erc721BalanceOf.selector;
        s721[5]  = ERC721Facet.ownerOf.selector;
        s721[6]  = ERC721Facet.erc721Approve.selector;
        s721[7]  = ERC721Facet.getApproved.selector;
        s721[8]  = ERC721Facet.setApprovalForAll.selector;
        s721[9]  = ERC721Facet.isApprovedForAll.selector;
        s721[10] = ERC721Facet.erc721TransferFrom.selector;
        s721[11] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        s721[12] = ERC721Facet.mint.selector;
        cuts[1] = _cut(address(e721), s721);

        // ── SVG ───────────────────────────────────────────────────────────────
        bytes4[] memory sSvg = new bytes4[](4);
        sSvg[0] = SVGFacet.generateSVG.selector;
        sSvg[1] = SVGFacet.tokenMetadata.selector;
        sSvg[2] = SVGFacet.addSVGLayer.selector;
        sSvg[3] = SVGFacet.getSVGLayers.selector;
        cuts[2] = _cut(address(svgF), sSvg);

        // ── Multisig ──────────────────────────────────────────────────────────
        bytes4[] memory sMs = new bytes4[](9);
        sMs[0] = MultisigFacet.initMultisig.selector;
        sMs[1] = MultisigFacet.proposeDiamondCut.selector;
        sMs[2] = MultisigFacet.confirmTx.selector;
        sMs[3] = MultisigFacet.revokeTx.selector;
        sMs[4] = MultisigFacet.executeTx.selector;
        sMs[5] = MultisigFacet.getTx.selector;
        sMs[6] = MultisigFacet.getConfirmCount.selector;
        sMs[7] = MultisigFacet.getOwners.selector;
        sMs[8] = MultisigFacet.getThreshold.selector;
        cuts[3] = _cut(address(msF), sMs);

        // ── Staking ───────────────────────────────────────────────────────────
        bytes4[] memory sStake = new bytes4[](6);
        sStake[0] = StakingFacet.initStaking.selector;
        sStake[1] = StakingFacet.stake.selector;
        sStake[2] = StakingFacet.unstake.selector;
        sStake[3] = StakingFacet.claimRewards.selector;
        sStake[4] = StakingFacet.pendingRewards.selector;
        sStake[5] = StakingFacet.getStakes.selector;
        cuts[4] = _cut(address(stakeF), sStake);

        // ── Borrow ────────────────────────────────────────────────────────────
        bytes4[] memory sBorrow = new bytes4[](6);
        sBorrow[0] = BorrowFacet.listForBorrow.selector;
        sBorrow[1] = BorrowFacet.borrow.selector;
        sBorrow[2] = BorrowFacet.returnNFT.selector;
        sBorrow[3] = BorrowFacet.slashOverdue.selector;
        sBorrow[4] = BorrowFacet.cancelListing.selector;
        sBorrow[5] = BorrowFacet.getBorrowListing.selector;
        cuts[5] = _cut(address(borrowF), sBorrow);

        // ── Marketplace ───────────────────────────────────────────────────────
        bytes4[] memory sMkt = new bytes4[](6);
        sMkt[0] = MarketplaceFacet.initMarketplace.selector;
        sMkt[1] = MarketplaceFacet.listNFT.selector;
        sMkt[2] = MarketplaceFacet.delistNFT.selector;
        sMkt[3] = MarketplaceFacet.buyNFT.selector;
        sMkt[4] = MarketplaceFacet.updatePrice.selector;
        sMkt[5] = MarketplaceFacet.getListing.selector;
        cuts[6] = _cut(address(mktF), sMkt);

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        // ── Bind ──────────────────────────────────────────────────────────────
        erc20    = ERC20Facet(address(diamond));
        erc721   = ERC721Facet(address(diamond));
        svg      = SVGFacet(address(diamond));
        multisig = MultisigFacet(address(diamond));
        staking  = StakingFacet(address(diamond));
        borrow   = BorrowFacet(address(diamond));
        market   = MarketplaceFacet(address(diamond));

        // ── Init ──────────────────────────────────────────────────────────────
        erc20.initERC20("DiamondToken", "DMD", 18, 1_000_000 ether);
        erc721.initERC721("DiamondNFT", "DNFT");

        address[] memory msOwners = new address[](3);
        msOwners[0] = owner; msOwners[1] = ms2; msOwners[2] = ms3;
        multisig.initMultisig(msOwners, 2);

        staking.initStaking(1e15);
        market.initMarketplace(250, owner);

        erc20.transfer(alice, 10_000 ether);
        erc20.transfer(bob,   10_000 ether);

        vm.stopPrank();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _cut(address facet, bytes4[] memory sels) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sels
        });
    }

    function _mintTo(address to) internal returns (uint256) {
        vm.prank(owner);
        return erc721.mint(to, "ipfs://test", defaultAttrs);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ERC20
    // ══════════════════════════════════════════════════════════════════════════

    function test_ERC20_Init() public {
        assertEq(erc20.name(),        "DiamondToken");
        assertEq(erc20.symbol(),      "DMD");
        assertEq(erc20.decimals(),    18);
        assertEq(erc20.totalSupply(), 1_000_000 ether);
    }

    function test_ERC20_Transfer() public {
        vm.prank(alice);
        erc20.transfer(bob, 100 ether);
        assertEq(erc20.balanceOf(bob), 10_100 ether);
    }

    function test_ERC20_Approve_TransferFrom() public {
        vm.prank(alice);
        erc20.approve(bob, 500 ether);
        assertEq(erc20.allowance(alice, bob), 500 ether);
        vm.prank(bob);
        erc20.transferFrom(alice, bob, 200 ether);
        assertEq(erc20.balanceOf(bob), 10_200 ether);
        assertEq(erc20.allowance(alice, bob), 300 ether);
    }

    function test_ERC20_InsufficientAllowance() public {
        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        erc20.transferFrom(alice, bob, 1 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ERC721
    // ══════════════════════════════════════════════════════════════════════════

    function test_ERC721_Mint() public {
        uint256 id = _mintTo(alice);
        assertEq(erc721.ownerOf(id), alice);
        assertEq(erc721.erc721BalanceOf(alice), 1);
    }

    function test_ERC721_Transfer() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        erc721.erc721TransferFrom(alice, bob, id);
        assertEq(erc721.ownerOf(id), bob);
    }

    function test_ERC721_Approve_Transfer() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        erc721.erc721Approve(bob, id);
        vm.prank(bob);
        erc721.erc721TransferFrom(alice, bob, id);
        assertEq(erc721.ownerOf(id), bob);
    }

    function test_ERC721_Burn() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        erc721.burn(id);
        vm.expectRevert("ERC721: invalid token ID");
        erc721.ownerOf(id);
    }

    function test_ERC721_Attributes() public {
        uint256 id = _mintTo(alice);
        NFTAttributes memory attrs = erc721.getNFTAttributes(id);
        assertEq(attrs.level,  50);
        assertEq(attrs.rarity, 1);
        assertEq(attrs.power,  1000);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SVG
    // ══════════════════════════════════════════════════════════════════════════

    function test_SVG_Generate() public {
        uint256 id = _mintTo(alice);
        string memory svgStr = svg.generateSVG(id);
        assertTrue(bytes(svgStr).length > 0);
        assertTrue(_contains(svgStr, "<svg"));
        assertTrue(_contains(svgStr, "</svg>"));
    }

    function test_SVG_Metadata_IsBase64() public {
        uint256 id = _mintTo(alice);
        string memory meta = svg.tokenMetadata(id);
        assertTrue(_contains(meta, "data:application/json;base64,"));
    }

    function test_SVG_AddLayer() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        svg.addSVGLayer(id, "halo", '<circle cx="150" cy="50" r="20" fill="gold"/>');
        assertEq(svg.getSVGLayers(id).length, 1);
        assertEq(svg.getSVGLayers(id)[0].layerName, "halo");
    }

    function test_SVG_AddLayer_RevertsIfNotOwner() public {
        uint256 id = _mintTo(alice);
        vm.prank(bob);
        vm.expectRevert("SVG: not authorized");
        svg.addSVGLayer(id, "x", "<g/>");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Multisig
    // ══════════════════════════════════════════════════════════════════════════

    function test_Multisig_Init() public {
        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 3);
        assertEq(multisig.getThreshold(), 2);
    }

    function test_Multisig_ProposeAndConfirm() public {
        ERC20Facet newFacet = new ERC20Facet();
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = ERC20Facet.mintERC20.selector;
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = _cut(address(newFacet), sels);

        vm.prank(owner);
        uint256 txId = multisig.proposeDiamondCut(cuts, address(0), "");
        assertEq(multisig.getConfirmCount(txId), 1);

        vm.prank(ms2);
        multisig.confirmTx(txId);
        assertEq(multisig.getConfirmCount(txId), 2);
    }

    function test_Multisig_CannotExecuteBeforeThreshold() public {
        ERC20Facet newFacet = new ERC20Facet();
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = ERC20Facet.burnERC20.selector;
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = _cut(address(newFacet), sels);

        vm.prank(owner);
        uint256 txId = multisig.proposeDiamondCut(cuts, address(0), "");

        vm.prank(owner);
        vm.expectRevert("Multisig: not enough confirmations");
        multisig.executeTx(txId);
    }

    function test_Multisig_RevokeConfirmation() public {
        ERC20Facet newFacet = new ERC20Facet();
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = bytes4(keccak256("someFn()"));
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = _cut(address(newFacet), sels);

        vm.prank(owner);
        uint256 txId = multisig.proposeDiamondCut(cuts, address(0), "");

        vm.prank(owner);
        multisig.revokeTx(txId);
        assertEq(multisig.getConfirmCount(txId), 0);
    }

    function test_Multisig_NonOwnerCannotPropose() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        vm.prank(alice);
        vm.expectRevert("Multisig: not owner");
        multisig.proposeDiamondCut(cuts, address(0), "");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Staking
    // ══════════════════════════════════════════════════════════════════════════

    function test_Staking_Stake() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        staking.stake(id);
        assertEq(erc721.ownerOf(id), address(diamond));
        assertEq(staking.getStakes(alice).length, 1);
    }

    function test_Staking_AccruesRewards() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        staking.stake(id);
        vm.warp(block.timestamp + 1000);
        assertEq(staking.pendingRewards(alice), 1000 * 1e15);
    }

    function test_Staking_ClaimRewards() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        staking.stake(id);
        vm.warp(block.timestamp + 1000);
        uint256 balBefore = erc20.balanceOf(alice);
        vm.prank(alice);
        staking.claimRewards();
        assertGt(erc20.balanceOf(alice), balBefore);
    }

    function test_Staking_Unstake() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        staking.stake(id);
        vm.warp(block.timestamp + 500);
        vm.prank(alice);
        staking.unstake(id);
        assertEq(erc721.ownerOf(id), alice);
        assertEq(staking.getStakes(alice).length, 0);
    }

    function test_Staking_CannotStakeTwice() public {
        uint256 id = _mintTo(alice);
        vm.startPrank(alice);
        staking.stake(id);
        vm.expectRevert("Staking: already staked");
        staking.stake(id);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Borrow
    // ══════════════════════════════════════════════════════════════════════════

    function test_Borrow_List() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        borrow.listForBorrow(id, 10 ether, 100 ether, 7 days);
        assertEq(erc721.ownerOf(id), address(diamond));
        assertTrue(borrow.getBorrowListing(id).active);
    }

    function test_Borrow_BorrowAndReturn() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        borrow.listForBorrow(id, 10 ether, 100 ether, 7 days);
        vm.prank(bob);
        borrow.borrow(id);
        assertEq(erc721.ownerOf(id), bob);
        vm.warp(block.timestamp + 1 days);
        uint256 aliceBefore = erc20.balanceOf(alice);
        vm.prank(bob);
        borrow.returnNFT(id);
        assertEq(erc721.ownerOf(id), alice);
        assertGt(erc20.balanceOf(alice), aliceBefore);
    }

    function test_Borrow_InsufficientCollateral() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        borrow.listForBorrow(id, 10 ether, 999_999 ether, 7 days);
        vm.prank(bob);
        vm.expectRevert("Borrow: insufficient collateral");
        borrow.borrow(id);
    }

    function test_Borrow_SlashOverdue() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        borrow.listForBorrow(id, 10 ether, 100 ether, 1 days);
        vm.prank(bob);
        borrow.borrow(id);
        vm.warp(block.timestamp + 2 days);
        uint256 aliceBefore = erc20.balanceOf(alice);
        vm.prank(alice);
        borrow.slashOverdue(id);
        assertGt(erc20.balanceOf(alice), aliceBefore);
    }

    function test_Borrow_Cancel() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        borrow.listForBorrow(id, 10 ether, 100 ether, 7 days);
        vm.prank(alice);
        borrow.cancelListing(id);
        assertEq(erc721.ownerOf(id), alice);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Marketplace
    // ══════════════════════════════════════════════════════════════════════════

    function test_Market_List() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 500 ether);
        assertTrue(market.getListing(id).active);
        assertEq(market.getListing(id).price, 500 ether);
    }

    function test_Market_Buy() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 500 ether);
        uint256 aliceBefore = erc20.balanceOf(alice);
        vm.prank(bob);
        market.buyNFT(id);
        assertEq(erc721.ownerOf(id), bob);
        assertGt(erc20.balanceOf(alice), aliceBefore);
        assertFalse(market.getListing(id).active);
    }

    function test_Market_Fee() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 1000 ether);
        uint256 ownerBefore = erc20.balanceOf(owner);
        vm.prank(bob);
        market.buyNFT(id);
        assertEq(erc20.balanceOf(owner) - ownerBefore, 25 ether);
    }

    function test_Market_Delist() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 500 ether);
        vm.prank(alice);
        market.delistNFT(id);
        assertEq(erc721.ownerOf(id), alice);
        assertFalse(market.getListing(id).active);
    }

    function test_Market_UpdatePrice() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 500 ether);
        vm.prank(alice);
        market.updatePrice(id, 750 ether);
        assertEq(market.getListing(id).price, 750 ether);
    }

    function test_Market_CannotBuyOwnListing() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 500 ether);
        vm.prank(alice);
        vm.expectRevert("Marketplace: cannot buy own listing");
        market.buyNFT(id);
    }

    function test_Market_InsufficientBalance() public {
        uint256 id = _mintTo(alice);
        vm.prank(alice);
        market.listNFT(id, 999_999 ether);
        vm.prank(bob);
        vm.expectRevert("Marketplace: insufficient balance");
        market.buyNFT(id);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint256 j; j < n.length; j++) {
                if (h[i+j] != n[j]) { found = false; break; }
            }
            if (found) return true;
        }
        return false;
    }
}
