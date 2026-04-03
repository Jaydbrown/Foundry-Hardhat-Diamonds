// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, NFTAttributes, SVGLayer} from "../storage/AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {Base64} from "../libraries/Base64.sol";

contract SVGFacet {

    AppStorage internal s;

    function generateSVG(uint256 tokenId) public view returns (string memory) {
        require(s.erc721Owners[tokenId] != address(0), "SVG: nonexistent token");
        NFTAttributes memory attrs = s.nftAttributes[tokenId];

        return string(abi.encodePacked(
            _buildSVGHeader(attrs.rarity),
            _buildSVGLayers(tokenId),
            _buildSVGBody(tokenId, attrs),
            '</svg>'
        ));
    }

    function tokenMetadata(uint256 tokenId) external view returns (string memory) {
        require(s.erc721Owners[tokenId] != address(0), "SVG: nonexistent token");
        NFTAttributes memory attrs = s.nftAttributes[tokenId];

        string memory imageURI = string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(bytes(generateSVG(tokenId)))
        ));

        string memory json = string(abi.encodePacked(
            _buildMetadataHead(tokenId, attrs.name, imageURI),
            _buildMetadataAttrs(attrs)
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    // ── Layer management ──────────────────────────────────────────────────────

    function addSVGLayer(
        uint256 tokenId,
        string calldata layerName,
        string calldata svgContent
    ) external {
        require(
            msg.sender == s.erc721Owners[tokenId] ||
            msg.sender == LibDiamond.contractOwner(),  // fixed: was s.contractOwner
            "SVG: not authorized"
        );
        s.svgLayers[tokenId].push(SVGLayer(layerName, svgContent));
    }

    function getSVGLayers(uint256 tokenId) external view returns (SVGLayer[] memory) {
        return s.svgLayers[tokenId];
    }

    // ── Private builders ──────────────────────────────────────────────────────

    function _buildSVGHeader(uint8 rarity) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300">',
            '<defs>',
            '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:#1a1a2e"/>',
            '<stop offset="100%" style="stop-color:#16213e"/>',
            '</linearGradient></defs>',
            '<rect width="300" height="300" fill="url(#bg)" rx="15"/>',
            '<rect x="10" y="10" width="280" height="280" fill="none" stroke="',
            _rarityColor(rarity),
            '" stroke-width="3" rx="12"/>'
        ));
    }

    function _buildSVGLayers(uint256 tokenId) private view returns (string memory result) {
        SVGLayer[] storage layers = s.svgLayers[tokenId];
        for (uint256 i = 0; i < layers.length; i++) {
            result = string(abi.encodePacked(result, layers[i].svgContent));
        }
    }

    function _buildSVGBody(
        uint256 tokenId,
        NFTAttributes memory attrs
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            _buildSVGText(attrs),
            _buildSVGPower(attrs.rarity, attrs.power),
            _buildSVGFooter(tokenId, attrs.rarity)
        ));
    }

    function _buildSVGText(NFTAttributes memory attrs) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<text x="150" y="60" font-family="monospace" font-size="18" fill="white" text-anchor="middle" font-weight="bold">',
            attrs.name,
            '</text>',
            _levelBar(attrs.level),
            '<text x="150" y="160" font-family="monospace" font-size="48" fill="',
            _rarityColor(attrs.rarity),
            '" text-anchor="middle">',
            _rarityEmoji(attrs.rarity),
            '</text>'
        ));
    }

    function _buildSVGPower(uint8 rarity, uint256 power) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<text x="150" y="220" font-family="monospace" font-size="14" fill="#aaaaaa" text-anchor="middle">POWER: ',
            _uint2str(power),
            '</text>',
            '<text x="150" y="250" font-family="monospace" font-size="11" fill="',
            _rarityColor(rarity),
            '" text-anchor="middle">',
            _rarityLabel(rarity),
            '</text>'
        ));
    }

    function _buildSVGFooter(uint256 tokenId, uint8 rarity) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<text x="150" y="280" font-family="monospace" font-size="10" fill="',
            _rarityColor(rarity),
            '" text-anchor="middle">#',
            _uint2str(tokenId),
            '</text>'
        ));
    }

    function _buildMetadataHead(
        uint256 tokenId,
        string memory nftName,
        string memory imageURI
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            '{"name":"', nftName, ' #', _uint2str(tokenId), '",',
            '"description":"Onchain Diamond NFT",',
            '"image":"', imageURI, '",',
            '"attributes":['
        ));
    }

    function _buildMetadataAttrs(NFTAttributes memory attrs) private pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"Level","value":', _uint2str(attrs.level), '},',
            '{"trait_type":"Rarity","value":"', _rarityLabel(attrs.rarity), '"},',
            '{"trait_type":"Power","value":', _uint2str(attrs.power), '}',
            ']}'
        ));
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    function _rarityColor(uint8 rarity) internal pure returns (string memory) {
        if (rarity == 3) return "#FFD700";
        if (rarity == 2) return "#9B59B6";
        if (rarity == 1) return "#3498DB";
        return "#95A5A6";
    }

    function _rarityEmoji(uint8 rarity) internal pure returns (string memory) {
        if (rarity == 3) return "&#x1F451;";
        if (rarity == 2) return "&#x1F48E;";
        if (rarity == 1) return "&#x2B50;";
        return "&#x26AA;";
    }

    function _rarityLabel(uint8 rarity) internal pure returns (string memory) {
        if (rarity == 3) return "LEGENDARY";
        if (rarity == 2) return "EPIC";
        if (rarity == 1) return "RARE";
        return "COMMON";
    }

    function _levelBar(uint8 level) internal pure returns (string memory) {
        uint256 width = (uint256(level) * 260) / 100;
        return string(abi.encodePacked(
            '<rect x="20" y="75" width="260" height="8" fill="#333" rx="4"/>',
            '<rect x="20" y="75" width="', _uint2str(width), '" height="8" fill="#00ff88" rx="4"/>',
            '<text x="150" y="100" font-family="monospace" font-size="11" fill="#aaaaaa" text-anchor="middle">LVL ',
            _uint2str(level),
            '</text>'
        ));
    }

    function _uint2str(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 tmp = v;
        uint256 len;
        while (tmp != 0) { len++; tmp /= 10; }
        bytes memory b = new bytes(len);
        while (v != 0) { b[--len] = bytes1(uint8(48 + v % 10)); v /= 10; }
        return string(b);
    }
}
