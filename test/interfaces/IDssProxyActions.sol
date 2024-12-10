/**
 * @title CommonLike
 * @dev Interface for the Common contract
 */
interface CommonLike {
    function daiJoin_join(address apt, address urn, uint wad) external;
}

/**
 * @title DssProxyActionsDsrLike
 * @dev Interface for the DssProxyActionsDsr contract, inheriting CommonLike
 */
interface DssProxyActionsDsrLike is CommonLike {
    // Joining to DSR
    function join(address daiJoin, address pot, uint wad) external;

    // Exiting from DSR
    function exit(address daiJoin, address pot, uint wad) external;
    function exitAll(address daiJoin, address pot) external;
}

/**
 * @title DssProxyActionsLike
 * @dev Interface for the DssProxyActions contract, inheriting CommonLike
 */
interface DssProxyActionsLike is CommonLike {
    // Transfer Functions
    function transfer(address gem, address dst, uint amt) external;

    // Join Functions
    function ethJoin_join(address apt, address urn) external payable;
    function gemJoin_join(address apt, address urn, uint amt, bool transferFrom) external;

    // Permission Functions
    function hope(address obj, address usr) external;
    function nope(address obj, address usr) external;

    // CDP Management Functions
    function open(address manager, bytes32 ilk, address usr) external returns (uint cdp);
    function give(address manager, uint cdp, address usr) external;
    function giveToProxy(address proxyRegistry, address manager, uint cdp, address dst) external;
    function cdpAllow(address manager, uint cdp, address usr, uint ok) external;
    function urnAllow(address manager, address usr, uint ok) external;

    // CDP Operations
    function flux(address manager, uint cdp, address dst, uint wad) external;
    function move(address manager, uint cdp, address dst, uint rad) external;
    function frob(address manager, uint cdp, int dink, int dart) external;
    function quit(address manager, uint cdp, address dst) external;
    function enter(address manager, address src, uint cdp) external;
    function shift(address manager, uint cdpSrc, uint cdpOrg) external;

    // Bag Management
    function makeGemBag(address gemJoin) external returns (address bag);

    // Locking Collateral
    function lockETH(address manager, address ethJoin, uint cdp) external payable;
    function safeLockETH(address manager, address ethJoin, uint cdp, address owner) external payable;
    function lockGem(address manager, address gemJoin, uint cdp, uint amt, bool transferFrom) external;
    function safeLockGem(
        address manager,
        address gemJoin,
        uint cdp,
        uint amt,
        bool transferFrom,
        address owner
    ) external;

    // Freeing Collateral
    function freeETH(address manager, address ethJoin, uint cdp, uint wad) external;
    function freeGem(address manager, address gemJoin, uint cdp, uint amt) external;

    // Exiting Collateral
    function exitETH(address manager, address ethJoin, uint cdp, uint wad) external;
    function exitGem(address manager, address gemJoin, uint cdp, uint amt) external;

    // Debt Management
    function draw(address manager, address jug, address daiJoin, uint cdp, uint wad) external;
    function wipe(address manager, address daiJoin, uint cdp, uint wad) external;
    function safeWipe(address manager, address daiJoin, uint cdp, uint wad, address owner) external;
    function wipeAll(address manager, address daiJoin, uint cdp) external;
    function safeWipeAll(address manager, address daiJoin, uint cdp, address owner) external;

    // Combined Operations
    function lockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address daiJoin,
        uint cdp,
        uint wadD
    ) external payable;

    function openLockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint wadD
    ) external payable returns (uint cdp);

    function lockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address daiJoin,
        uint cdp,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) external;

    function openLockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) external returns (uint cdp);

    function openLockGNTAndDraw(
        address manager,
        address jug,
        address gntJoin,
        address daiJoin,
        bytes32 ilk,
        uint amtC,
        uint wadD
    ) external returns (address bag, uint cdp);

    // Wipe and Free Operations
    function wipeAndFreeETH(address manager, address ethJoin, address daiJoin, uint cdp, uint wadC, uint wadD) external;

    function wipeAllAndFreeETH(address manager, address ethJoin, address daiJoin, uint cdp, uint wadC) external;

    function wipeAndFreeGem(address manager, address gemJoin, address daiJoin, uint cdp, uint amtC, uint wadD) external;

    function wipeAllAndFreeGem(address manager, address gemJoin, address daiJoin, uint cdp, uint amtC) external;
}

/**
 * @title DssProxyActionsEndLike
 * @dev Interface for the DssProxyActionsEnd contract, inheriting CommonLike
 */
interface DssProxyActionsEndLike is CommonLike {
    // Freeing Collateral via End
    function freeETH(address manager, address ethJoin, address end, uint cdp) external;
    function freeGem(address manager, address gemJoin, address end, uint cdp) external;

    // Packing DAI
    function pack(address daiJoin, address end, uint wad) external;

    // Cashing Out Collateral
    function cashETH(address ethJoin, address end, bytes32 ilk, uint wad) external;
    function cashGem(address gemJoin, address end, bytes32 ilk, uint wad) external;
}