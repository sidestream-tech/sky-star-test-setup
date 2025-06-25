// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {IDaiJoinMock} from "./interfaces/IDaiJoinMock.sol";
import {IUsdsJoinMock} from "./interfaces/IUsdsJoinMock.sol";
import {IGemMock} from "./interfaces/IGemMock.sol";
import {IVatMock} from "./interfaces/IVatMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 */
contract DaiUsdsMock {
    IDaiJoinMock   public immutable daiJoin;
    IUsdsJoinMock  public immutable usdsJoin;
    IGemMock       public immutable dai;
    IGemMock       public immutable usds;

    constructor(address daiJoin_, address usdsJoin_) {
        daiJoin = IDaiJoinMock(daiJoin_);
        usdsJoin = IUsdsJoinMock(usdsJoin_);
        dai = IGemMock(daiJoin.dai());
        usds = IGemMock(usdsJoin.usds());

        IVatMock vat = IVatMock(daiJoin.vat());
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
