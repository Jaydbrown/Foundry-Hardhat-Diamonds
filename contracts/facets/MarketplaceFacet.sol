// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, Listing} from "../storage/AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract MarketplaceFacet {

    AppStorage internal s;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTDelisted(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event FeeUpdated(uint256 newFee);

    function initMarketplace(uint256 feeBps, address feeRecipient) external {
        LibAppStorage.enforceIsContractOwner();
        require(feeBps <= 1000, "Marketplace: fee too high");
        s.marketplaceFee = feeBps;
        s.feeRecipient   = feeRecipient;
    }

    function listNFT(uint256 tokenId, uint256 price) external {
        require(s.erc721Owners[tokenId] == msg.sender, "Marketplace: not owner");
        require(price > 0,                             "Marketplace: zero price");
        require(!s.listings[tokenId].active,           "Marketplace: already listed");
        require(!s.borrowListings[tokenId].active,     "Marketplace: NFT listed for borrow");
        s.erc721Owners[tokenId] = address(this);
        s.erc721Balances[msg.sender]--;
        s.erc721Balances[address(this)]++;
        delete s.erc721TokenApprovals[tokenId];
        s.listings[tokenId] = Listing({ seller: msg.sender, price: price, active: true });
        emit NFTListed(tokenId, msg.sender, price);
    }

    function delistNFT(uint256 tokenId) external {
        Listing storage listing = s.listings[tokenId];
        require(listing.active,               "Marketplace: not listed");
        require(listing.seller == msg.sender, "Marketplace: not seller");
        s.erc721Owners[tokenId] = msg.sender;
        s.erc721Balances[address(this)]--;
        s.erc721Balances[msg.sender]++;
        delete s.listings[tokenId];
        emit NFTDelisted(tokenId);
    }

    function buyNFT(uint256 tokenId) external {
        Listing storage listing = s.listings[tokenId];
        require(listing.active,               "Marketplace: not listed");
        require(listing.seller != msg.sender, "Marketplace: cannot buy own listing");
        uint256 price     = listing.price;
        uint256 fee       = (price * s.marketplaceFee) / 10000;
        uint256 sellerAmt = price - fee;
        require(s.erc20Balances[msg.sender] >= price, "Marketplace: insufficient balance");
        s.erc20Balances[msg.sender]     -= price;
        s.erc20Balances[listing.seller] += sellerAmt;
        if (fee > 0) s.erc20Balances[s.feeRecipient] += fee;
        s.erc721Owners[tokenId] = msg.sender;
        s.erc721Balances[address(this)]--;
        s.erc721Balances[msg.sender]++;
        address seller = listing.seller;
        delete s.listings[tokenId];
        emit NFTSold(tokenId, seller, msg.sender, price);
    }

    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        Listing storage listing = s.listings[tokenId];
        require(listing.active,               "Marketplace: not listed");
        require(listing.seller == msg.sender, "Marketplace: not seller");
        require(newPrice > 0,                 "Marketplace: zero price");
        listing.price = newPrice;
        emit NFTListed(tokenId, msg.sender, newPrice);
    }

    function getListing(uint256 tokenId) external view returns (Listing memory) {
        return s.listings[tokenId];
    }

    function setMarketplaceFee(uint256 feeBps) external {
        LibAppStorage.enforceIsContractOwner();
        require(feeBps <= 1000, "Marketplace: fee too high");
        s.marketplaceFee = feeBps;
        emit FeeUpdated(feeBps);
    }
}