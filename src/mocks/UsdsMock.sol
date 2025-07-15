// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {GemMock} from "src/mocks/GemMock.sol";

/**
 * @dev Contract overwrite to deploy contract instances with specific naming.
 */
contract UsdsMock is GemMock {
    constructor() GemMock() {}
}
