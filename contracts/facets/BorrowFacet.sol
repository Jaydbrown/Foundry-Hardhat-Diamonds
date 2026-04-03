// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, BorrowListing} from "../storage/AppStorage.sol";

contract BorrowFacet {

    AppStorage internal s;

    event Listed(uint256 indexed tokenId, address indexed lender, uint256 dailyFee, uint256 collateral);
    event Borrowed(uint256 indexed tokenId, address indexed borrower);
    event Returned(uint256 indexed tokenId);
    event CollateralSlashed(uint256 indexed tokenId, address indexed lender);

    function listForBorrow(
        uint256 tokenId,
        uint256 dailyFee,
        uint256 collateralRequired,
        uint256 maxDuration
    ) external {
        require(s.erc721Owners[tokenId] == msg.sender, "Borrow: not owner");
        require(!s.borrowListings[tokenId].active,     "Borrow: already listed");
        s.erc721Owners[tokenId] = address(this);
        s.erc721Balances[msg.sender]--;
        s.erc721Balances[address(this)]++;
        delete s.erc721TokenApprovals[tokenId];
        s.borrowListings[tokenId] = BorrowListing({
            lender:      msg.sender,
            borrower:    address(0),
            collateral:  collateralRequired,
            dailyFee:    dailyFee,
            maxDuration: maxDuration,
            borrowedAt:  0,
            active:      true
        });
        emit Listed(tokenId, msg.sender, dailyFee, collateralRequired);
    }

    function borrow(uint256 tokenId) external {
        BorrowListing storage listing = s.borrowListings[tokenId];
        require(listing.active,                 "Borrow: not listed");
        require(listing.borrower == address(0), "Borrow: already borrowed");
        uint256 collateral = listing.collateral;
        require(s.erc20Balances[msg.sender] >= collateral, "Borrow: insufficient collateral");
        s.erc20Balances[msg.sender]    -= collateral;
        s.erc20Balances[address(this)] += collateral;
        s.erc721Owners[tokenId] = msg.sender;
        s.erc721Balances[address(this)]--;
        s.erc721Balances[msg.sender]++;
        listing.borrower   = msg.sender;
        listing.borrowedAt = block.timestamp;
        s.activeBorrows[msg.sender].push(tokenId);
        emit Borrowed(tokenId, msg.sender);
    }

    function returnNFT(uint256 tokenId) external {
        BorrowListing storage listing = s.borrowListings[tokenId];
        require(listing.borrower == msg.sender, "Borrow: not borrower");
        uint256 duration    = block.timestamp - listing.borrowedAt;
        uint256 daysElapsed = (duration + 86399) / 86400;
        uint256 fee         = daysElapsed * listing.dailyFee;
        uint256 collateral  = listing.collateral;
        s.erc721Owners[tokenId] = listing.lender;
        s.erc721Balances[msg.sender]--;
        s.erc721Balances[listing.lender]++;
        uint256 refund    = collateral > fee ? collateral - fee : 0;
        uint256 lenderPay = collateral - refund;
        s.erc20Balances[address(this)]  -= collateral;
        s.erc20Balances[listing.lender] += lenderPay;
        if (refund > 0) s.erc20Balances[msg.sender] += refund;
        _clearActiveBorrow(msg.sender, tokenId);
        delete s.borrowListings[tokenId];
        emit Returned(tokenId);
    }

    function slashOverdue(uint256 tokenId) external {
        BorrowListing storage listing = s.borrowListings[tokenId];
        require(listing.lender == msg.sender,   "Borrow: not lender");
        require(listing.borrower != address(0), "Borrow: not borrowed");
        require(
            block.timestamp > listing.borrowedAt + listing.maxDuration,
            "Borrow: not overdue"
        );
        s.erc20Balances[address(this)]  -= listing.collateral;
        s.erc20Balances[listing.lender] += listing.collateral;
        _clearActiveBorrow(listing.borrower, tokenId);
        delete s.borrowListings[tokenId];
        emit CollateralSlashed(tokenId, msg.sender);
    }

    function cancelListing(uint256 tokenId) external {
        BorrowListing storage listing = s.borrowListings[tokenId];
        require(listing.lender == msg.sender,    "Borrow: not lender");
        require(listing.borrower == address(0),  "Borrow: already borrowed");
        s.erc721Owners[tokenId] = msg.sender;
        s.erc721Balances[address(this)]--;
        s.erc721Balances[msg.sender]++;
        delete s.borrowListings[tokenId];
    }

    function getBorrowListing(uint256 tokenId) external view returns (BorrowListing memory) {
        return s.borrowListings[tokenId];
    }

    function getActiveBorrows(address user) external view returns (uint256[] memory) {
        return s.activeBorrows[user];
    }

    function _clearActiveBorrow(address user, uint256 tokenId) internal {
        uint256[] storage borrows = s.activeBorrows[user];
        for (uint256 i; i < borrows.length; i++) {
            if (borrows[i] == tokenId) {
                borrows[i] = borrows[borrows.length - 1];
                borrows.pop();
                break;
            }
        }
    }
}