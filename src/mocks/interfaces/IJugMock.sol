// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IJugMock {
    function rely(address usr) external;
    function deny(address usr) external;
    function wards(address usr) external view returns (uint256);
    function init(bytes32 ilk) external;
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function drip(bytes32 ilk) external returns (uint256);
    function ilks(bytes32 ilk) external view returns (uint256 duty, uint256 rho);
}