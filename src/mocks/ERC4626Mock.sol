// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {OFTMock} from "./OFTMock.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 */
contract ERC4626Mock is OFT {
    OFTMock public immutable asset;

    constructor(OFTMock _asset, string memory _name, string memory _symbol, address _lzEndpoint, address _owner)
        OFT(_name, _symbol, _lzEndpoint, _owner)
        Ownable(_owner)
    {
        asset = _asset;
    }

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function _withdraw(address from, address to, address owner, uint256 assets, uint256 shares) internal virtual {
        if (msg.sender != owner && allowance(owner, msg.sender) < shares) revert("ERC4626/not authorized");
        require(balanceOf(owner) >= shares, "ERC4626/insufficient shares");

        _burn(owner, shares);
        asset.transfer(to, assets);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0, "ERC4626/no assets");
        asset.transferFrom(msg.sender, address(this), assets);

        shares = assets; // 1:1 ratio for simplicity
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        require(assets > 0, "ERC4626/no assets");

        shares = assets; // 1:1
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 asts) {
        require(shares > 0, "ERC4626/no shares");

        asts = shares; // 1:1
        _withdraw(_msgSender(), receiver, owner, asts, shares);

        emit Withdraw(msg.sender, receiver, owner, asts, shares);
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
        return balanceOf(owner);
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }
}
