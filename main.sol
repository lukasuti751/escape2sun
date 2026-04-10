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
    error E2S_BuoyRefused();
    error E2S_HoldFog(uint256 hid);
    error E2S_HoldBeached();
    error E2S_HoldAlien(address who);
    error E2S_WaveReverted();
    error E2S_SwellCap(uint256 n, uint256 cap);
    error E2S_SurfCooldown(uint64 readyAt);
    error E2S_ChestUndertow(uint256 have, uint256 ask);
    error E2S_HostHarborZero();
    error E2S_TierBandInvalid(uint8 b);
    error E2S_HoldWeiBounds(uint256 w);
    error E2S_RefundHorizon(uint64 until);
    error E2S_SelfNudge();
    error E2S_HelpfulAlready();
    error E2S_FlareUnderflow(uint256 have, uint256 spend);
    error E2S_RosterSkew(uint256 a, uint256 b);
    error E2S_SliceOverhang(uint256 end, uint256 len);

    event JettyAnchored(
        uint256 indexed jettyId,
        address indexed hostHarbor,
        bytes32 monikerSlug,
        uint16 pinZone,
        uint8 tierBand
    );
    event JettyMuted(uint256 indexed jettyId, address indexed byCurator);
    event JettyLitAgain(uint256 indexed jettyId, address indexed byCurator);
    event PostcardStamped(
        uint256 indexed jettyId,
        address indexed voyager,
        uint8 lodging,
        uint8 shoreline,
        uint8 concierge
    );
    event PostcardShredded(uint256 indexed jettyId, address indexed voyager);
    event TideHoldOpened(
        uint256 indexed holdId,
        uint256 indexed jettyId,
        address indexed voyager,
        uint96 weiLocked,
        uint64 refundableUntil
    );
    event TidePaidHost(uint256 indexed holdId, address indexed hostHarbor, uint96 weiOut);
    event TideRefundedVoyager(uint256 indexed holdId, address indexed voyager, uint96 weiOut);
    event SunFlareMinted(address indexed voyager, uint256 amount);
    event SunFlareSpent(address indexed voyager, uint256 amount);
    event HarborChestTopped(uint256 weiAmt);
    event ChestDrained(address indexed to, uint256 weiAmt);
    event TideStewardRotated(address indexed prior, address indexed next);
    event BeaconCuratorRotated(address indexed prior, address indexed next);
    event ListingTollRetuned(uint256 priorWei, uint256 nextWei);
    event MonsoonToggled(bool halted);
    event HelpfulNudge(uint256 indexed jettyId, address indexed author, address indexed voter, uint32 newTally);

    struct JettyNode {
        bytes32 monikerSlug;
        address hostHarbor;
        uint64 spawnedAt;
        uint16 pinZone;
        uint8 tierBand;
        bool muted;
        uint128 listingLodestar;
    }

    struct Postcard {
        uint8 starsLodging;
        uint8 starsShoreline;
        uint8 starsConcierge;
        bytes32 headlineHash;
