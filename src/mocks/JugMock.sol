// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {VatMock} from "src/mocks/VatMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 * This contract was copied from
 * https://github.com/sky-ecosystem/dss-allocator/blob/226584d3b179d98025497815adb4ea585ea0102d/test/mocks/JugMock.sol
 */
contract JugMock {
    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address usr) external auth {
        wards[usr] = 1;
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "Jug/not-authorized");
        _;
    }

    struct Ilk {
        uint256 duty;
        uint256 rho;
    }

    VatMock vat;
    mapping(bytes32 => Ilk) public ilks;

    constructor(VatMock vat_) {
        wards[msg.sender] = 1;
        vat = vat_;
    }

    uint256 constant ONE = 10 ** 27;

    function init(bytes32 ilk) external auth {
        Ilk storage i = ilks[ilk];
        require(i.duty == 0, "Jug/ilk-already-init");
        i.duty = ONE;
        i.rho = block.timestamp;
    }

    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        require(block.timestamp == ilks[ilk].rho, "Jug/rho-not-updated");
        if (what == "duty") ilks[ilk].duty = data;
        else revert("Jug/file-unrecognized-param");
    }

    function drip(bytes32 ilk) external returns (uint256 rate) {
        uint256 add = (ilks[ilk].duty - 10 ** 27) * (block.timestamp - ilks[ilk].rho);
        (, uint256 prev,,,) = vat.ilks(ilk);
        rate = prev + add;
        vat.fold(ilk, int256(rate) - int256(prev));
        ilks[ilk].rho = block.timestamp;
    }
}
