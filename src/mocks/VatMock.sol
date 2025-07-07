// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 * This contract was edited from
 * https://github.com/sky-ecosystem/dss-allocator/blob/226584d3b179d98025497815adb4ea585ea0102d/test/mocks/VatMock.sol
 */
contract VatMock {
    // --- auth ---
    mapping(address => uint256) public wards;

    function rely(address usr) external auth {
        wards[usr] = 1;
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "Vat/not-authorized");
        _;
    }

    uint256 public Art;

    struct Urn {
        uint256 ink;
        uint256 art;
    }

    struct Ilk {
        uint256 Art; // Total Normalised Debt     [wad]
        uint256 rate; // Accumulated Rates         [ray]
        uint256 spot; // Price with Safety Margin  [ray]
        uint256 line; // Debt Ceiling              [rad]
        uint256 dust; // Urn Debt Floor            [rad]
    }

    mapping(bytes32 => Ilk) public ilks;
    mapping(address => mapping(address => uint256)) public can;
    mapping(bytes32 => mapping(address => Urn)) public urns;
    mapping(bytes32 => mapping(address => uint256)) public gem;
    mapping(address => uint256) public dai;

    constructor() {
        wards[msg.sender] = 1;
    }

    function init(bytes32 ilk) external auth {
        require(ilks[ilk].rate == 0, "Vat/ilk-already-init");
        ilks[ilk].rate = 10 ** 27;
        ilks[ilk].line = 20_000_000 * 10 ** 45;
    }

    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        if (what == "line") ilks[ilk].line = data;
        else revert("Vat/file-unrecognized-param");
    }

    function hope(address usr) external {
        can[msg.sender][usr] = 1;
    }

    function slip(bytes32 ilk, address usr, int256 wad) external auth {
        gem[ilk][usr] = _add(gem[ilk][usr], wad);
    }

    function move(address src, address dst, uint256 rad) external {
        require(src == msg.sender || can[src][msg.sender] == 1);
        dai[src] = dai[src] - rad;
        dai[dst] = dai[dst] + rad;
    }

    function frob(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external {
        require(u == msg.sender || can[u][msg.sender] == 1);
        Ilk memory ilk = ilks[i];
        require(ilk.rate != 0, "VatMock/ilk-not-init");
        Urn memory urn = urns[i][u];

        urn.ink = _add(urn.ink, dink);
        urn.art = _add(urn.art, dart);
        ilk.Art = _add(ilk.Art, dart);
        int256 dtab = int256(ilk.rate) * dart;

        require(dart <= 0 || ilk.Art * ilk.rate <= ilk.line, "Vat/ceiling-exceeded");

        gem[i][v] = dink >= 0 ? gem[i][v] - uint256(dink) : gem[i][v] + uint256(-dink);
        require(dart == 0 || ilk.rate <= uint256(type(int256).max));
        dai[w] = dtab >= 0 ? dai[w] + uint256(dtab) : dai[w] - uint256(-dtab);

        urns[i][u] = urn;
        ilks[i] = ilk;
    }

    function grab(bytes32 i, address u, address v, address, int256 dink, int256 dart) external auth {
        Urn storage urn = urns[i][u];
        Ilk storage ilk = ilks[i];

        urn.ink = _add(urn.ink, dink);
        urn.art = _add(urn.art, dart);
        ilk.Art = _add(ilk.Art, dart);
        gem[i][v] = _sub(gem[i][v], dink);
    }

    function fold(bytes32 i, int256 rate) external auth {
        Ilk storage ilk = ilks[i];
        ilk.rate = _add(ilk.rate, rate);
    }

    /**
     * Math
     */
    function _add(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y >= 0 ? x + uint256(y) : x - uint256(-y);
    }

    function _sub(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y >= 0 ? x - uint256(y) : x + uint256(-y);
    }

    function _mul(uint256 x, int256 y) internal pure returns (int256 z) {
        z = int256(x) * y;
        require(y == 0 || z / y == int256(x), "VatMock/mul-overflow");
    }
}
