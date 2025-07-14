// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IVatMock {
    function rely(address usr) external;
    function deny(address usr) external;
    function ilks(bytes32)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
    function hope(address usr) external;
    function slip(bytes32 ilk, address usr, int256 wad) external;
    function grab(bytes32 i, address u, address v, address, int256 dink, int256 dart) external;
    function fold(uint256 rate_) external;
}
