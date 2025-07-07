// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IVatMock {
    function rely(address usr) external;
    function deny(address usr) external;
    function ilks(bytes32)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
    function can(address src, address usr) external view returns (uint256);
    function urns(bytes32 ilk, address usr) external view returns (uint256 ink, uint256 art);
    function gem(bytes32 ilk, address usr) external view returns (uint256);
    function dai(address usr) external view returns (uint256);
    function init(bytes32 ilk) external;
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function hope(address usr) external;
    function slip(bytes32 ilk, address usr, int256 wad) external;
    function move(address src, address dst, uint256 rad) external;
    function frob(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external;
    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external;
    function fold(bytes32 i, int rate) external;
}
