// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, stdJson} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerDeploy} from "spark-alm-controller/deploy/ControllerDeploy.sol";
import {ControllerInstance} from "spark-alm-controller/deploy/ControllerInstance.sol";
import {
    SetUpAllLib,
    MockContracts,
    AllocatorSetUpInstance,
    ALMSetUpInstance,
    RateLimitsInstance
} from "script/libraries/SetUpAllLib.sol";

interface MainnetControllerLike {
    function LIMIT_USDS_MINT() external returns (bytes32);
}

contract SetUpAll is Script {
    using stdJson for string;

    uint256 internal constant WAD = 10 ** 18;

    function setUp() public {}

    function run() public {
        string memory config = ScriptTools.loadConfig("input");
        VmSafe.Wallet memory deployer = vm.createWallet(vm.envUint("PRIVATE_KEY"));
        bytes32 ilk = ScriptTools.stringToBytes32(config.readString(".ilk"));
        address admin = config.readAddress(".admin");
        address cctpTokenMessenger = config.readAddress(".cctpTokenMessenger");

        vm.startBroadcast(deployer.privateKey);
        // 1. Deploy mock contracts
        MockContracts memory mocks = SetUpAllLib.deployMockContracts();

        // 2. Deploy AllocatorSystem
        AllocatorSharedInstance memory sharedInstance = AllocatorDeploy.deployShared(deployer.addr, admin);
        AllocatorIlkInstance memory ilkInstance =
            AllocatorDeploy.deployIlk(deployer.addr, admin, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        // 2. Set up AllocatorSystem and set up
        SetUpAllLib.setUpAllocatorSystem(
            AllocatorSetUpInstance({
                ilk: ilk,
                ilkInstance: ilkInstance,
                sharedInstance: sharedInstance,
                mocks: mocks,
                admin: admin
            })
        );

        // 3. Deploy MainnetController
        ControllerInstance memory controllerInstance = MainnetControllerDeploy.deployFull({
            admin: admin,
            vault: ilkInstance.vault,
            psm: address(mocks.psm),
            daiUsds: address(mocks.daiUsds),
            cctp: cctpTokenMessenger
        });

        // 4. Set up ALM controller
        address[] memory relayers = new address[](1);
        relayers[0] = deployer.addr;
        SetUpAllLib.setUpAlmController(
            ALMSetUpInstance({
                controllerInstance: controllerInstance,
                ilkInstance: ilkInstance,
                mocks: mocks,
                admin: admin,
                relayers: relayers,
                cctpTokenMessenger: cctpTokenMessenger
            })
        );

        // 5. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits(
            RateLimitsInstance({
                controllerInstance: controllerInstance,
                usdcUnitSize: config.readUint(".usdcUnitSize"),
                sUsds: address(mocks.sUsds)
            })
        );

        vm.stopBroadcast();
    }
}
