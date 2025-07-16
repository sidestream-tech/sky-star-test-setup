// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {OFTMock} from "src/mocks/OFTMock.sol";

/**
 * @dev Contract overwrite to deploy contract instances with specific naming.
 */
contract UsdsMock is OFTMock {
    constructor(address layerZeroEndpoint) OFTMock("Usds", "Usds", layerZeroEndpoint, msg.sender) {}
}
