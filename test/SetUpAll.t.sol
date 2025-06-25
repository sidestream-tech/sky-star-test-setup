// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerDeploy} from "spark-alm-controller/deploy/ControllerDeploy.sol";
import {ControllerInstance} from "spark-alm-controller/deploy/ControllerInstance.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {
    SetUpAllLib,
    MockContracts,
    AllocatorSetUpInstance,
    ALMSetUpInstance,
    RateLimitsInstance
} from "script/libraries/SetUpAllLib.sol";
import {IGemMock} from "script/mocks/interfaces/IGemMock.sol";
import {IVatMock} from "script/mocks/interfaces/IVatMock.sol";
import {console} from "forge-std/console.sol";

interface MainnetControllerLike {
    function mintUSDS(uint256 usdsAmount) external;
    function burnUSDS(uint256 usdsAmount) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
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
        SetUpAllLib.setUpAllocatorSystem(
            AllocatorSetUpInstance({
                ilk: ilk,
                ilkInstance: ilkInstance,
                sharedInstance: sharedInstance,
                mocks: mocks,
                admin: deployer
            })
        );

        // 3. Deploy MainnetController
        controllerInstance = MainnetControllerDeploy.deployFull({
            admin: deployer,
            vault: ilkInstance.vault,
            psm: mocks.psm,
            daiUsds: mocks.daiUsds,
            cctp: address(0)
        });

        // 4. Set up ALM controller
        address[] memory relayers = new address[](1);
        relayers[0] = deployer; 
        SetUpAllLib.setUpAlmController(
            ALMSetUpInstance({
                controllerInstance: controllerInstance,
                ilkInstance: ilkInstance,
                mocks: mocks,
                admin: deployer,
                relayers: relayers,
                cctpTokenMessenger: address(0)
            })
        );

        // 5. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits(
            RateLimitsInstance({controllerInstance: controllerInstance, usdcUnitSize: 10})
        );

        vm.stopPrank();
    }

    function testMintUsds() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;

        // Mint USDS to the deployer address
        vm.assertEq(usds.balanceOf(almProxy), 0, "Initial USDS balance should be zero");
        vm.prank(deployer);
        MainnetControllerLike(controllerInstance.controller).mintUSDS(10 * WAD); // Mint 10 USDS
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after minting should be 10 WAD");
    }

    function testBurnUsds() public {
        IGemMock usds = IGemMock(mocks.usds);
        IVatMock vat = IVatMock(mocks.vat);
        address almProxy = controllerInstance.almProxy;

        // Mint USDS to the deployer address
        vm.assertEq(usds.balanceOf(almProxy), 0, "Initial USDS balance should be zero");
        vm.prank(deployer);
        MainnetControllerLike(controllerInstance.controller).mintUSDS(10 * WAD); // Mint 10 USDS
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after minting should be 10 WAD");
        (uint256 art,,,,) = vat.ilks(ilk);
        vm.assertEq(art, 10 * WAD, "art should be 10 WAD after minting");

        // Burn USDS
        vm.prank(deployer);
        MainnetControllerLike(controllerInstance.controller).burnUSDS(5 * WAD); // Burn 5 USDS
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance after burning should be 5 WAD");
        (art,,,,) = vat.ilks(ilk);
        vm.assertEq(art, 5 * WAD, "art should be 5 WAD after burning");
    }
}
