// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerDeploy} from "spark-alm-controller/deploy/ControllerDeploy.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SetUpAllLib, MockContracts, ControllerInstance} from "script/libraries/SetUpAllLib.sol";
import {IGemMock} from "script/mocks/interfaces/IGemMock.sol";
import {IVatMock} from "script/mocks/interfaces/IVatMock.sol";
import {ERC4626Mock} from "script/mocks/ERC4626Mock.sol";
import {console} from "forge-std/console.sol";

interface MainnetControllerLike {
    function mintUSDS(uint256 usdsAmount) external;
    function burnUSDS(uint256 usdsAmount) external;
    function depositERC4626(address token, uint256 amount) external returns (uint256 shares);
    function withdrawERC4626(address token, uint256 amount) external returns (uint256 shares);
    function redeemERC4626(address token, uint256 shares) external returns (uint256 assets);
}

contract SetUpAllTest is Test {
    address deployer;
    MockContracts mocks;
    AllocatorSharedInstance sharedInstance;
    AllocatorIlkInstance ilkInstance;
    ControllerInstance controllerInstance;
    bytes32 ilk;

    uint256 constant WAD = 10 ** 18;

    function setUp() public {
        (deployer,) = makeAddrAndKey("deployer");
        ilk = ScriptTools.stringToBytes32("ALLOCATOR-TEST-A");

        vm.startPrank(deployer);
        // 1. Deploy mock contracts
        mocks = SetUpAllLib.deployMockContracts();

        // 2. Deploy AllocatorSystem
        sharedInstance = AllocatorDeploy.deployShared(deployer, deployer);
        ilkInstance = AllocatorDeploy.deployIlk(deployer, deployer, sharedInstance.roles, ilk, mocks.usdsJoin);

        // 2. Set up AllocatorSystem and set up
        SetUpAllLib.setUpAllocatorSystem({
            ilk: ilk,
            ilkInstance: ilkInstance,
            sharedInstance: sharedInstance,
            mocks: mocks,
            admin: deployer
        });

        // 3. Deploy MainnetController
        controllerInstance = SetUpAllLib.deployAlmController({
            admin: deployer,
            vault: ilkInstance.vault,
            psm: mocks.psm,
            daiUsds: mocks.daiUsds,
            cctp: address(0),
            usds: mocks.usds
        });

        // 4. Set up ALM controller
        address[] memory relayers = new address[](1);
        relayers[0] = deployer;
        SetUpAllLib.setUpAlmController({
            controllerInstance: controllerInstance,
            ilkInstance: ilkInstance,
            mocks: mocks,
            admin: deployer,
            relayers: relayers,
            cctpTokenMessenger: address(0)
        });

        // 5. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits({
            controllerInstance: controllerInstance,
            usdcUnitSize: 10,
            susds: mocks.susds
        });

        vm.stopPrank();
    }

    function testMintUsds() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;

        // Mint USDS
        vm.assertEq(usds.balanceOf(almProxy), 0, "Initial USDS balance should be zero");
        vm.prank(deployer);
        MainnetControllerLike(controllerInstance.controller).mintUSDS(10 * WAD); // Mint 10 USDS
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after minting should be 10 WAD");
    }

    function testBurnUsds() public {
        IGemMock usds = IGemMock(mocks.usds);
        IVatMock vat = IVatMock(mocks.vat);
        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.assertEq(usds.balanceOf(almProxy), 0, "Initial USDS balance should be zero");
        vm.prank(deployer);
        controller.mintUSDS(10 * WAD); // Mint 10 USDS
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after minting should be 10 WAD");
        (uint256 art,,,,) = vat.ilks(ilk);
        vm.assertEq(art, 10 * WAD, "art should be 10 WAD after minting");

        // Burn USDS
        vm.prank(deployer);
        controller.burnUSDS(5 * WAD); // Burn 5 USDS
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance after burning should be 5 WAD");
        (art,,,,) = vat.ilks(ilk);
        vm.assertEq(art, 5 * WAD, "art should be 5 WAD after burning");
    }

    function testDepositERC4626() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.prank(deployer);
        controller.mintUSDS(10 * WAD); // Mint 10 USDS

        // Deposit into ERC4626
        vm.assertEq(ERC4626Mock(mocks.susds).shareBalance(almProxy), 0, "Share balance before deposit should be 0");

        vm.prank(deployer);
        controller.depositERC4626(mocks.susds, 5 * WAD); // Deposit 5 USDS
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance after deposit should be 5 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 5 * WAD, "Share balance after deposit should be 5 WAD"
        );
    }

    function testWithdrawERC4626() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.prank(deployer);
        controller.mintUSDS(10 * WAD); // Mint 10 USDS

        // Deposit into ERC4626
        vm.assertEq(ERC4626Mock(mocks.susds).shareBalance(almProxy), 0, "Share balance before deposit should be 0");
        vm.prank(deployer);
        controller.depositERC4626(mocks.susds, 5 * WAD); // Deposit 5 USDS

        // Withdraw from ERC4626
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance before withdrawal should be 5 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 5 * WAD, "Share balance before withdrawal should be 5 WAD"
        );

        vm.prank(deployer);
        uint256 shares = controller.withdrawERC4626(mocks.susds, 3 * WAD); // Withdraw 3 USDS
        vm.assertEq(shares, 3 * WAD, "Withdrawn shares should be 3 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 2 * WAD, "Share balance after withdrawal should be 2 WAD"
        );
        vm.assertEq(usds.balanceOf(almProxy), 8 * WAD, "USDS balance after withdrawal should be 8 WAD");
    }

    function testRedeemERC4626() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.prank(deployer);
        controller.mintUSDS(10 * WAD); // Mint 10 USDS

        // Deposit into ERC4626
        vm.assertEq(ERC4626Mock(mocks.susds).shareBalance(almProxy), 0, "Share balance before deposit should be 0");
        vm.prank(deployer);
        controller.depositERC4626(mocks.susds, 5 * WAD); // Deposit 5 USDS

        // Withdraw from ERC4626
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance before redemption should be 5 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 5 * WAD, "Share balance before redemption should be 5 WAD"
        );

        vm.prank(deployer);
        uint256 shares = controller.redeemERC4626(mocks.susds, 3 * WAD); // Redeem 3 USDS
        vm.assertEq(shares, 3 * WAD, "Redeemed shares should be 3 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 2 * WAD, "Share balance after redemption should be 2 WAD"
        );
        vm.assertEq(usds.balanceOf(almProxy), 8 * WAD, "USDS balance after redemption should be 8 WAD");
    }
}
