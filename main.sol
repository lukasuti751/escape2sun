// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Kelp-ember folio r7 — shoreline mirror keeps CDN digests aligned with on-chain jetty anchors.
 * Monsoon drills pause swaps only; steward logs rotate without redeploying chart salt.
 * Pin-zone collisions resolve off-chain; this ledger stores slugs, scores, and tide holds only.
 */

library ShoreBits {
    function clampStars(uint8 s) internal pure returns (uint8) {
        if (s < 1) return 1;
        if (s > 5) return 5;
        return s;
    }

    function packZoneMeta(uint16 pinZone, uint8 tierBand) internal pure returns (uint24 packed) {
        packed = uint24(uint256(pinZone)) | (uint24(uint256(tierBand)) << 16);
    }

    function unpackZone(uint24 packed) internal pure returns (uint16 pinZone, uint8 tierBand) {
        pinZone = uint16(uint256(packed) & 0xFFFF);
        tierBand = uint8((uint256(packed) >> 16) & 0xFF);
    }
}

library TideLedgerMath {
    function mixLodestar(uint128 prior, bytes32 salt, address who, uint256 blk, uint256 costWei)
        internal
        pure
        returns (uint128)
    {
        return uint128(uint256(keccak256(abi.encodePacked(prior, salt, who, blk, costWei))));
    }

    function triScoreAverage(uint256 sumL, uint256 sumS, uint256 sumC, uint256 n) internal pure returns (uint256 avg) {
        if (n == 0) return 0;
        uint256 t = sumL + sumS + sumC;
        avg = t / (n * 3);
    }

    function tideRiskBand(uint64 refundableUntil, uint64 nowTs) internal pure returns (uint8 band) {
        if (nowTs >= refundableUntil) return 2;
        uint256 rem = uint256(refundableUntil - nowTs);
        if (rem < 3_600) return 1;
        return 0;
    }

    function flareTier(uint256 bal) internal pure returns (uint8 tier) {
        if (bal >= 10_000) return 9;
        if (bal >= 5_000) return 7;
        if (bal >= 1_000) return 5;
        if (bal >= 250) return 3;
        if (bal >= 50) return 1;
        return 0;
    }
}

contract escape2sun {
    error E2S_MonsoonSheets();
    error E2S_JettyUnknown(uint256 id);
    error E2S_JettyMuted();
    error E2S_SlugVacant();
    error E2S_ZoneTyphoon(uint16 z);
    error E2S_PostcardDuplicate();
    error E2S_PostcardBlank();
    error E2S_TollRipple(uint256 sent, uint256 need);
    error E2S_TollBand(uint256 next, uint256 lo, uint256 hi);
    error E2S_ReefTangled();
