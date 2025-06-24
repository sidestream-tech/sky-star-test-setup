// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {VatMock} from "script/mocks/VatMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 * This contract was copied from
 * https://github.com/sky-ecosystem/dss-allocator/blob/226584d3b179d98025497815adb4ea585ea0102d/test/mocks/JugMock.sol
 */
contract JugMock {
    VatMock vat;

    uint256 public duty = 1001 * 10 ** 27 / 1000;
    uint256 public rho = block.timestamp;

    constructor(VatMock vat_) {
        vat = vat_;
    }

    function drip(bytes32) external returns (uint256 rate) {
        uint256 add = (duty - 10 ** 27) * (block.timestamp - rho);
        rate = vat.rate() + add;
        vat.fold(add);
        rho = block.timestamp;
    }
}
