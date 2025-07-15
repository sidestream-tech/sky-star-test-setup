// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {ERC4626Mock} from "src/mocks/ERC4626Mock.sol";
import {GemMock} from "./GemMock.sol";

/**
 * @dev Contract overwrite to deploy contract instances with specific naming.
 */
contract SusdsMock is ERC4626Mock {
    constructor(GemMock _asset) ERC4626Mock(_asset) {}
}
