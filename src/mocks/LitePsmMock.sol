// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {VatMock} from "src/mocks/VatMock.sol";
import {DaiJoinMock} from "src/mocks/DaiJoinMock.sol";
import {GemMock} from "src/mocks/GemMock.sol";
import {console} from "forge-std/console.sol";

/**
 * @dev This contract is not intended for production use and should only be used for testing purpose.
 */
contract LitePsmMock {
    bytes32 public immutable ilk;
    VatMock public immutable vat;
    DaiJoinMock public immutable daiJoin;
    GemMock public immutable dai;
    GemMock public immutable gem;
    uint256 public immutable to18ConversionFactor;
    address public immutable pocket;

    uint256 internal constant RAY = 10 ** 27;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event SellGem(address indexed usr, uint256 gemAmt, uint256 fee);
    event BuyGem(address indexed usr, uint256 gemAmt, uint256 fee);

    mapping(address => uint256) public wards;

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth() {
        require(wards[msg.sender] > 0, "LitePsmMock/not-authorized");
        _;
    }

    constructor(bytes32 ilk_, address gem_, address daiJoin_, address pocket_) {
        ilk = ilk_;
        gem = GemMock(gem_);
        daiJoin = DaiJoinMock(daiJoin_);
        vat = VatMock(daiJoin.vat());
        dai = GemMock(daiJoin.dai());
        pocket = pocket_;

        to18ConversionFactor = 10 ** (18 - gem.decimals());

        dai.approve(daiJoin_, type(uint256).max);
        vat.hope(daiJoin_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function sellGemNoFee(address usr, uint256 gemAmt) external returns (uint256 daiOutWad) {
        daiOutWad = gemAmt * to18ConversionFactor;

        gem.transferFrom(msg.sender, pocket, gemAmt);
        // This can consume the whole balance including system fees not withdrawn.
        dai.transfer(usr, daiOutWad);

        emit SellGem(usr, gemAmt, 0);
    }

    function buyGemNoFee(address usr, uint256 gemAmt) external returns (uint256 daiInWad) {
        daiInWad = gemAmt * to18ConversionFactor;

        dai.transferFrom(msg.sender, address(this), daiInWad);
        gem.transferFrom(pocket, usr, gemAmt);

        emit BuyGem(usr, gemAmt, 0);
    }

    function rush() public view returns (uint256 wad) {
        (uint256 Art, uint256 rate,, uint256 line,) = vat.ilks(ilk);
        require(rate == RAY, "LitePsmMock/rate-not-RAY");
        uint256 tArt = gem.balanceOf(pocket) * to18ConversionFactor;

        wad = _min(
            // To avoid two extra SLOADs it assumes urn.art == ilk.Art.
            _subcap(tArt, Art),
            _subcap(line / RAY, Art)
        );
    }

    function fill() external auth returns (uint256 wad) {
        wad = rush();
        require(wad > 0, "LitePsmMock/nothing-to-fill");

        // The `urn` for this contract in the `Vat` is expected to have "unlimited" `ink`.
        vat.frob(ilk, address(this), address(0), address(this), 0, int256(wad));
        daiJoin.exit(address(this), wad);
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x < y ? x : y;
    }

    function _subcap(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x > y ? x - y : 0;
        }
    }
}
