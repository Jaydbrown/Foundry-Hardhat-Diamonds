// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct AppStorage {
    // ── Diamond owner is stored in LibDiamond, not here ──────────────────────
    // Do NOT add contractOwner here — use LibDiamond.contractOwner() instead

    // ── ERC20 ─────────────────────────────────────────────────────────────────
    string  erc20Name;
    string  erc20Symbol;
    uint8   erc20Decimals;
    uint256 erc20TotalSupply;
    mapping(address => uint256)                     erc20Balances;
    mapping(address => mapping(address => uint256)) erc20Allowances;

    // ── ERC721 ────────────────────────────────────────────────────────────────
    string  erc721Name;
    string  erc721Symbol;
    mapping(uint256 => address)                     erc721Owners;
    mapping(address => uint256)                     erc721Balances;
    mapping(uint256 => address)                     erc721TokenApprovals;
    mapping(address => mapping(address => bool))    erc721OperatorApprovals;
    mapping(uint256 => string)                      erc721TokenURIs;
    mapping(uint256 => NFTAttributes)               nftAttributes;
    uint256 nextTokenId;
    bool    erc721Paused;
    mapping(address => bool) minters;

    // ── SVG ───────────────────────────────────────────────────────────────────
    mapping(uint256 => SVGLayer[]) svgLayers;

    // ── Staking ───────────────────────────────────────────────────────────────
    mapping(address => StakeInfo[]) stakes;
    uint256 rewardRatePerSecond;
    uint256 totalStaked;

    // ── Multisig ──────────────────────────────────────────────────────────────
    address[]                                    multisigOwners;
    mapping(address => bool)                     isMultisigOwner;
    uint256                                      multisigThreshold;
    uint256                                      multisigTxCount;
    mapping(uint256 => MultiSigTx)               multisigTxs;
    mapping(uint256 => mapping(address => bool)) multisigConfirmations;

    // ── Borrowing ─────────────────────────────────────────────────────────────
    mapping(uint256 => BorrowListing)  borrowListings;
    mapping(address => uint256[])      activeBorrows;

    // ── Marketplace ───────────────────────────────────────────────────────────
    mapping(uint256 => Listing) listings;
    uint256                     marketplaceFee;
    address                     feeRecipient;
}
// ── Structs ───────────────────────────────────────────────────────────────────

struct NFTAttributes {
    string  name;
    uint8   level;
    uint8   rarity;   // 0=common 1=rare 2=epic 3=legendary
    uint256 power;
}

struct SVGLayer {
    string  layerName;
    string  svgContent;
}

struct StakeInfo {
    uint256 tokenId;
    uint256 stakedAt;
    uint256 lastClaimed;
}

struct MultiSigTx {
    address   proposer;
    address   to;
    bytes     data;           // encoded diamondCut call
    bool      executed;
    uint256   confirmCount;
    uint256   createdAt;
}

struct BorrowListing {
    address  lender;
    address  borrower;
    uint256  collateral;      // ERC20 amount locked
    uint256  dailyFee;        // ERC20 per day
    uint256  maxDuration;     // seconds
    uint256  borrowedAt;
    bool     active;
}

struct Listing {
    address  seller;
    uint256  price;           // ERC20 amount
    bool     active;
}