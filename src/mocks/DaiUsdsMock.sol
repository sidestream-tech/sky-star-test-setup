// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {DaiJoinMock} from "./DaiJoinMock.sol";
import {UsdsJoinMock} from "./UsdsJoinMock.sol";
import {GemMock} from "./GemMock.sol";
import {VatMock} from "./VatMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 */
contract DaiUsdsMock {
    DaiJoinMock   public immutable daiJoin;
    UsdsJoinMock  public immutable usdsJoin;
    GemMock       public immutable dai;
    GemMock       public immutable usds;

    constructor(address daiJoin_, address usdsJoin_) {
        daiJoin = DaiJoinMock(daiJoin_);
        usdsJoin = UsdsJoinMock(usdsJoin_);
        dai = GemMock(address(daiJoin.dai()));
        usds = GemMock(address(usdsJoin.usds()));

        VatMock vat = VatMock(address(daiJoin.vat()));
        vat.hope(address(daiJoin));
        vat.hope(address(usdsJoin));
    }

    function daiToUsds(address usr, uint256 wad) external {
        dai.transferFrom(msg.sender, address(this), wad);
        daiJoin.join(address(this), wad);
        usdsJoin.exit(usr, wad);
    }

    function usdsToDai(address usr, uint256 wad) external {
        usds.transferFrom(msg.sender, address(this), wad);
        usdsJoin.join(address(this), wad);
        daiJoin.exit(usr, wad);
    } 
}
