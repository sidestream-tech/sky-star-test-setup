// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {VatMock} from "script/mocks/VatMock.sol";
import {GemMock} from "script/mocks/GemMock.sol";


interface IDaiJoinMock {
    function vat() external view returns (address);
    function dai() external view returns (address);
    function join(address usr, uint256 wad) external; 
    function exit(address usr, uint256 wad) external;
}
