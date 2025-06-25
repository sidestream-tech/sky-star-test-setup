// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {VatMock} from "script/mocks/VatMock.sol";
import {GemMock} from "script/mocks/GemMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 * This contract was copied from
 * https://github.com/sky-ecosystem/dss-allocator/blob/226584d3b179d98025497815adb4ea585ea0102d/test/mocks/UsdsJoinMock.sol
 */
contract DaiJoinMock {
    VatMock public vat;
    GemMock public dai;

    constructor(VatMock vat_, GemMock usds_) {
        vat = vat_;
        dai = usds_;
    }

    function join(address usr, uint256 wad) external {
        vat.move(address(this), usr, wad * 10 ** 27);
        dai.burn(msg.sender, wad);
    }

    function exit(address usr, uint256 wad) external {
        vat.move(msg.sender, address(this), wad * 10 ** 27);
        dai.mint(usr, wad);
    }
}
