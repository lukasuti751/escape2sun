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
        bytes32 blurbHash;
        uint64 etchedAt;
        uint32 helpfulTally;
        bool shredded;
    }

    struct TideHold {
        address voyager;
        uint256 jettyId;
        address hostHarbor;
        uint96 weiLocked;
        uint64 refundableUntil;
        bool paidHost;
        bool refunded;
    }

    struct HorizonPulse {
        uint64 chainId;
        uint64 timestamp;
        uint256 jettyHead;
        uint256 holdHead;
        uint256 chestWei;
        uint256 listingToll;
        bool monsoon;
        bytes32 chart;
        address director;
        address steward;
        address beacon;
    }

    struct DeckRibbon {
        uint256 sumWeiHints;
        uint8 flareBand;
        uint8 tideBand;
        uint16 pinEcho;
        bytes32 echoA;
        bytes32 echoB;
    }

    address public immutable quayDirector;
    bytes32 public immutable chartSalt;

    address public tideSteward;
    address public beaconCurator;

    address private constant _PHANTOM_BUOY = 0x6d771e0caa76d5180e1e4339a74eb525e6e7505e;
    address private constant _DRIFT_MARK = 0xf0a6428e6c5819228a2fd436064823a2635672ab;
    address private constant _CORAL_SENTINEL = 0xc54127765c7afbfc426b14e324fc43cbb4f4dfa3;
    address private constant _SPINDLE_LIGHT = 0x3d864c14f7797a4dd1c120a54ecf1b04988828fa;
    address private constant _GULL_PERCH = 0xe9d8cb502c47d5249133ba869ca6061a8656b25f;
    address private constant _DUNE_MIRROR = 0x071083bbcfb5017df33765967fe25ed6c6ee6364;
    address private constant _TIDE_CLOCK = 0xdf274b365a5cdb40a14149c833110072d8454473;
    address private constant _KELP_ANCHOR = 0xa4b0031e8341f9f1280864ecd3d8a091b5b0ee12;

    uint256 public listingTollWei;
    uint256 public constant LISTING_TOLL_FLOOR_WEI = 612_883_441_772_881;
    uint256 public constant LISTING_TOLL_CEIL_WEI = 3 ether;
    uint256 public constant MIN_TIDE_HOLD_WEI = 4_161_592_653_589;
    uint256 public constant MAX_TIDE_HOLD_WEI = 42 ether;
    uint64 public constant MIN_REFUND_HORIZON_SEC = 2_864;
    uint64 public constant MAX_REFUND_HORIZON_SEC = 86_400 * 29;
    uint64 public constant REVIEW_COOLDOWN_SEC = 18_403;
    uint256 public constant MAX_SWEEP_SCAN = 41;
    uint256 public constant MAX_HOST_JETTIES_PAGED = 36;
    uint8 public constant TIER_BAND_CAP = 19;
    uint256 public constant FLARE_BOOST_COST = 100;

    uint256 public nextJettyId;
    uint256 public nextHoldId;
    uint256 public harborChestWei;
    uint256 public lifetimeListingWei;
    uint256 public lifetimeTideWei;
    uint256 public lifetimeChestOutWei;

    bool public monsoonHalted;

    uint256 private _reefGate;
    mapping(uint256 => JettyNode) private _jetties;
    mapping(uint256 => mapping(address => Postcard)) private _postcards;
    mapping(address => uint256) public sunFlareBalances;
    mapping(uint256 => TideHold) private _holds;
    mapping(address => uint256) private _hostJettyCount;
    mapping(address => mapping(uint256 => uint256)) private _hostJettyAt;
    mapping(address => uint64) private _lastReviewAt;
    mapping(uint256 => mapping(address => mapping(address => bool))) private _helpfulCast;

    modifier onlyDirector() {
        if (msg.sender != quayDirector) revert E2S_BuoyRefused();
        _;
    }

    modifier directorOrSteward() {
        if (msg.sender != quayDirector && msg.sender != tideSteward) revert E2S_BuoyRefused();
        _;
    }

    modifier curatorOrDirector() {
        if (msg.sender != quayDirector && msg.sender != beaconCurator) revert E2S_BuoyRefused();
        _;
    }

    modifier notMonsoon() {
        if (monsoonHalted) revert E2S_MonsoonSheets();
        _;
    }

    modifier nonReentrant() {
        if (_reefGate == 2) revert E2S_ReefTangled();
        _reefGate = 2;
        _;
        _reefGate = 1;
    }

    constructor() {
        quayDirector = msg.sender;
        tideSteward = msg.sender;
        beaconCurator = msg.sender;
        chartSalt = 0xf7044654d9884c9830ec0b24c5790fb3168c6efd661f6f0c7fd741395a88457a;
        listingTollWei = 1_907_283_665_554_433;
        _reefGate = 1;
        emit TideStewardRotated(address(0), msg.sender);
        emit BeaconCuratorRotated(address(0), msg.sender);
    }

    receive() external payable {
        revert("escape2sun: stray swell rejected");
    }

    fallback() external payable {
        revert("escape2sun: unknown wake");
    }

    function phantomBuoy() external pure returns (address) {
        return _PHANTOM_BUOY;
    }

    function driftMark() external pure returns (address) {
        return _DRIFT_MARK;
    }

    function coralSentinel() external pure returns (address) {
        return _CORAL_SENTINEL;
    }

    function spindleLight() external pure returns (address) {
        return _SPINDLE_LIGHT;
    }

    function gullPerch() external pure returns (address) {
        return _GULL_PERCH;
    }

    function duneMirror() external pure returns (address) {
        return _DUNE_MIRROR;
    }

    function tideClockAddr() external pure returns (address) {
        return _TIDE_CLOCK;
    }

    function kelpAnchor() external pure returns (address) {
        return _KELP_ANCHOR;
    }

    function domainGlue() external view returns (bytes32) {
        return keccak256(abi.encodePacked(chartSalt, _PHANTOM_BUOY, _KELP_ANCHOR, address(this)));
    }

    function retuneListingToll(uint256 nextWei) external onlyDirector {
        if (nextWei < LISTING_TOLL_FLOOR_WEI || nextWei > LISTING_TOLL_CEIL_WEI) {
            revert E2S_TollBand(nextWei, LISTING_TOLL_FLOOR_WEI, LISTING_TOLL_CEIL_WEI);
        }
        uint256 prior = listingTollWei;
        listingTollWei = nextWei;
        emit ListingTollRetuned(prior, nextWei);
    }

    function toggleMonsoon(bool halted) external directorOrSteward {
        monsoonHalted = halted;
        emit MonsoonToggled(halted);
    }

    function rotateTideSteward(address next) external onlyDirector {
        address prior = tideSteward;
        tideSteward = next;
        emit TideStewardRotated(prior, next);
    }

    function rotateBeaconCurator(address next) external onlyDirector {
        address prior = beaconCurator;
        beaconCurator = next;
        emit BeaconCuratorRotated(prior, next);
    }

    function anchorJetty(bytes32 monikerSlug, uint16 pinZone, uint8 tierBand, address hostHarbor)
        external
        payable
        notMonsoon
        returns (uint256 jettyId)
    {
        if (monikerSlug == bytes32(0)) revert E2S_SlugVacant();
        if (pinZone == 0) revert E2S_ZoneTyphoon(pinZone);
        if (tierBand > TIER_BAND_CAP) revert E2S_TierBandInvalid(tierBand);
        if (hostHarbor == address(0)) revert E2S_HostHarborZero();
        if (msg.value != listingTollWei) revert E2S_TollRipple(msg.value, listingTollWei);

        jettyId = nextJettyId;
        unchecked {
            nextJettyId = jettyId + 1;
        }

        _jetties[jettyId] = JettyNode({
            monikerSlug: monikerSlug,
            hostHarbor: hostHarbor,
            spawnedAt: uint64(block.timestamp),
            pinZone: pinZone,
            tierBand: tierBand,
            muted: false,
            listingLodestar: uint128(
                uint256(keccak256(abi.encodePacked(chartSalt, monikerSlug, pinZone, hostHarbor, jettyId)))
            )
        });

        unchecked {
            uint256 idx = _hostJettyCount[hostHarbor];
            _hostJettyAt[hostHarbor][idx] = jettyId;
            _hostJettyCount[hostHarbor] = idx + 1;
        }

        harborChestWei += msg.value;
        lifetimeListingWei += msg.value;
        emit HarborChestTopped(msg.value);
        emit JettyAnchored(jettyId, hostHarbor, monikerSlug, pinZone, tierBand);
    }

    function muteJetty(uint256 jettyId) external curatorOrDirector {
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        j.muted = true;
        emit JettyMuted(jettyId, msg.sender);
    }

    function relightJetty(uint256 jettyId) external curatorOrDirector {
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        j.muted = false;
        emit JettyLitAgain(jettyId, msg.sender);
    }

    function stampPostcard(
        uint256 jettyId,
        uint8 lodging,
        uint8 shoreline,
        uint8 concierge,
        bytes32 headlineHash,
        bytes32 blurbHash
    ) external notMonsoon {
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        if (j.muted) revert E2S_JettyMuted();

        if (block.timestamp < _lastReviewAt[msg.sender] + REVIEW_COOLDOWN_SEC) {
            revert E2S_SurfCooldown(uint64(_lastReviewAt[msg.sender] + REVIEW_COOLDOWN_SEC));
        }

        Postcard storage p = _postcards[jettyId][msg.sender];
        if (p.etchedAt != 0 && !p.shredded) revert E2S_PostcardDuplicate();
        if (headlineHash == bytes32(0) || blurbHash == bytes32(0)) revert E2S_PostcardBlank();

        uint8 L = ShoreBits.clampStars(lodging);
        uint8 S = ShoreBits.clampStars(shoreline);
        uint8 C = ShoreBits.clampStars(concierge);

        p.starsLodging = L;
        p.starsShoreline = S;
        p.starsConcierge = C;
        p.headlineHash = headlineHash;
        p.blurbHash = blurbHash;
        p.etchedAt = uint64(block.timestamp);
        p.helpfulTally = 0;
        p.shredded = false;

        _lastReviewAt[msg.sender] = uint64(block.timestamp);

        unchecked {
            sunFlareBalances[msg.sender] += 13;
        }
        emit SunFlareMinted(msg.sender, 13);
        emit PostcardStamped(jettyId, msg.sender, L, S, C);
    }

    function shredPostcard(uint256 jettyId) external {
        Postcard storage p = _postcards[jettyId][msg.sender];
        if (p.etchedAt == 0 || p.shredded) revert E2S_PostcardBlank();
        p.shredded = true;
        emit PostcardShredded(jettyId, msg.sender);
    }

    function nudgeHelpful(uint256 jettyId, address author) external notMonsoon {
        if (author == msg.sender) revert E2S_SelfNudge();
        Postcard storage target = _postcards[jettyId][author];
        if (target.etchedAt == 0 || target.shredded) revert E2S_PostcardBlank();

        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);

        if (_helpfulCast[jettyId][author][msg.sender]) revert E2S_HelpfulAlready();
        _helpfulCast[jettyId][author][msg.sender] = true;

        unchecked {
            target.helpfulTally += 1;
        }
        emit HelpfulNudge(jettyId, author, msg.sender, target.helpfulTally);

        unchecked {
            sunFlareBalances[author] += 3;
        }
        emit SunFlareMinted(author, 3);
    }

    function openTideHold(uint256 jettyId, uint64 refundableUntil) external payable notMonsoon nonReentrant returns (uint256 holdId) {
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        if (j.muted) revert E2S_JettyMuted();
        if (msg.value < MIN_TIDE_HOLD_WEI || msg.value > MAX_TIDE_HOLD_WEI) revert E2S_HoldWeiBounds(msg.value);
        if (refundableUntil < block.timestamp + MIN_REFUND_HORIZON_SEC) revert E2S_RefundHorizon(refundableUntil);
        if (refundableUntil > block.timestamp + MAX_REFUND_HORIZON_SEC) revert E2S_RefundHorizon(refundableUntil);

        holdId = nextHoldId;
        unchecked {
            nextHoldId = holdId + 1;
        }

        _holds[holdId] = TideHold({
            voyager: msg.sender,
            jettyId: jettyId,
            hostHarbor: j.hostHarbor,
            weiLocked: uint96(msg.value),
            refundableUntil: refundableUntil,
            paidHost: false,
            refunded: false
        });

        lifetimeTideWei += msg.value;
        emit TideHoldOpened(holdId, jettyId, msg.sender, uint96(msg.value), refundableUntil);
    }

    function refundTideHold(uint256 holdId) external nonReentrant {
        TideHold storage h = _holds[holdId];
        if (h.weiLocked == 0) revert E2S_HoldFog(holdId);
        if (h.refunded || h.paidHost) revert E2S_HoldBeached();
        if (msg.sender != h.voyager) revert E2S_HoldAlien(msg.sender);
        if (block.timestamp > h.refundableUntil) revert E2S_RefundHorizon(h.refundableUntil);

        uint256 payout = uint256(h.weiLocked);
        h.refunded = true;
        h.weiLocked = 0;

        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert E2S_WaveReverted();
        emit TideRefundedVoyager(holdId, msg.sender, uint96(payout));
    }

    function payTideToHost(uint256 holdId) external nonReentrant {
        TideHold storage h = _holds[holdId];
        if (h.weiLocked == 0) revert E2S_HoldFog(holdId);
        if (h.refunded || h.paidHost) revert E2S_HoldBeached();
        if (block.timestamp <= h.refundableUntil) revert E2S_RefundHorizon(h.refundableUntil);
        if (msg.sender != h.hostHarbor) revert E2S_HoldAlien(msg.sender);

        uint256 payout = uint256(h.weiLocked);
        address host = h.hostHarbor;
        h.paidHost = true;
        h.weiLocked = 0;

        (bool ok, ) = payable(host).call{value: payout}("");
        if (!ok) revert E2S_WaveReverted();
        emit TidePaidHost(holdId, host, uint96(payout));
    }

    function withdrawHarborChest(address payable to, uint256 weiAmt) external onlyDirector nonReentrant {
        if (weiAmt > harborChestWei) revert E2S_ChestUndertow(harborChestWei, weiAmt);
        harborChestWei -= weiAmt;
        lifetimeChestOutWei += weiAmt;
        (bool ok, ) = to.call{value: weiAmt}("");
        if (!ok) revert E2S_WaveReverted();
        emit ChestDrained(to, weiAmt);
    }

    function grantFlares(address voyager, uint256 amt) external curatorOrDirector {
        unchecked {
            sunFlareBalances[voyager] += amt;
        }
        emit SunFlareMinted(voyager, amt);
    }

    function burnFlaresForBoost(uint256 jettyId) external notMonsoon {
        if (sunFlareBalances[msg.sender] < FLARE_BOOST_COST) {
            revert E2S_FlareUnderflow(sunFlareBalances[msg.sender], FLARE_BOOST_COST);
        }
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        unchecked {
            sunFlareBalances[msg.sender] -= FLARE_BOOST_COST;
        }
        emit SunFlareSpent(msg.sender, FLARE_BOOST_COST);
        j.listingLodestar = TideLedgerMath.mixLodestar(
            j.listingLodestar,
            chartSalt,
            msg.sender,
            block.number,
            FLARE_BOOST_COST
        );
    }

    function readJetty(uint256 jettyId) external view returns (JettyNode memory) {
        return _jetties[jettyId];
    }

    function readPostcard(uint256 jettyId, address voyager) external view returns (Postcard memory) {
        return _postcards[jettyId][voyager];
    }

    function readHold(uint256 holdId) external view returns (TideHold memory) {
        return _holds[holdId];
    }

    function hostJettyCount(address host) external view returns (uint256) {
        return _hostJettyCount[host];
    }

    function hostJettyAt(address host, uint256 idx) external view returns (uint256) {
        return _hostJettyAt[host][idx];
    }

    function helpfulCast(uint256 jettyId, address author, address voter) external view returns (bool) {
        return _helpfulCast[jettyId][author][voter];
    }

    function lastReviewAt(address voyager) external view returns (uint64) {
        return _lastReviewAt[voyager];
    }

    function postcardQuilt(uint256 jettyId, address[] calldata voyagers)
        external
        view
        returns (
            uint256 sumLodge,
            uint256 sumShore,
            uint256 sumCon,
            uint256 samples,
            bool[] memory shredded
        )
    {
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        uint256 n = voyagers.length;
        if (n > MAX_SWEEP_SCAN) revert E2S_SwellCap(n, MAX_SWEEP_SCAN);
        shredded = new bool[](n);
        for (uint256 i; i < n; ) {
            Postcard storage p = _postcards[jettyId][voyagers[i]];
            shredded[i] = p.shredded;
            if (p.etchedAt != 0 && !p.shredded) {
                sumLodge += p.starsLodging;
                sumShore += p.starsShoreline;
                sumCon += p.starsConcierge;
                unchecked {
                    samples += 1;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function quiltTriAverage(uint256 jettyId, address[] calldata voyagers) external view returns (uint256 avg) {
        JettyNode storage j = _jetties[jettyId];
        if (j.spawnedAt == 0) revert E2S_JettyUnknown(jettyId);
        uint256 n = voyagers.length;
        if (n > MAX_SWEEP_SCAN) revert E2S_SwellCap(n, MAX_SWEEP_SCAN);
        uint256 sumL;
        uint256 sumS;
