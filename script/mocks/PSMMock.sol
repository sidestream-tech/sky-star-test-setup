// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 * This contract was copied from
 * https://github.com/sparkdotfi/spark-alm-controller/blob/7f0a473951e4c5528d52ee442461662976c4a947/test/unit/mocks/MockPSM3.sol
 */
contract PSMMock {
    address public gem;

    uint256 public to18ConversionFactor = 1e12;

    constructor(address _gem) {
        gem = _gem;
    }
}
