// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GemMock} from "./GemMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 */
contract ERC4626Mock is GemMock {
    GemMock public immutable asset;

    // Tracks shares per address
    mapping(address => uint256) public shareBalance;

    constructor(GemMock _asset) {
        asset = _asset;
        wards[msg.sender] = 1;
    }

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "ERC4626/no assets");
        asset.transferFrom(msg.sender, address(this), assets);

        shares = assets; // 1:1 ratio for simplicity
        shareBalance[receiver] += shares;
        totalSupply += shares;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        require(assets > 0, "ERC4626/no assets");

        shares = assets; // 1:1
        require(shareBalance[owner] >= shares, "ERC4626/insufficient shares");
        if (msg.sender != owner) revert("ERC4626/not authorized");

        shareBalance[owner] -= shares;
        totalSupply -= shares;

        asset.transfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(shares > 0, "ERC4626/no shares");

        assets = shares; // 1:1
        require(shareBalance[owner] >= shares, "ERC4626/insufficient shares");
        if (msg.sender != owner) revert("ERC4626/not authorized");

        shareBalance[owner] -= shares;
        totalSupply -= shares;

        asset.transfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // --- ERC4626 accounting view functions ---

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return shareBalance[owner];
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return shareBalance[owner];
    }
}
