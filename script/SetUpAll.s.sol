// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, stdJson} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerDeploy} from "sky-star-alm-controller/deploy/ControllerDeploy.sol";
import {SetUpAllLib, MockContracts, ControllerInstance} from "src/libraries/SetUpAllLib.sol";

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
        address admin = deployer.addr;
        address cctpTokenMessenger = config.readAddress(".cctpTokenMessenger");

        vm.startBroadcast(deployer.privateKey);
        // 1. Deploy mock contracts
        MockContracts memory mocks = SetUpAllLib.deployMockContracts();

        // 2. Deploy AllocatorSystem
        AllocatorSharedInstance memory sharedInstance = AllocatorDeploy.deployShared(deployer.addr, admin);
        AllocatorIlkInstance memory ilkInstance =
            AllocatorDeploy.deployIlk(deployer.addr, admin, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        // 2. Set up AllocatorSystem and set up
        SetUpAllLib.setUpAllocatorSystem({
            ilk: ilk,
            ilkInstance: ilkInstance,
            sharedInstance: sharedInstance,
            mocks: mocks,
            admin: admin
        });

        // 3. Deploy MainnetController
        ControllerInstance memory controllerInstance = SetUpAllLib.deployAlmController({
            admin: admin,
            vault: ilkInstance.vault,
            psm: mocks.psm,
            daiUsds: mocks.daiUsds,
            cctp: cctpTokenMessenger,
            usds: mocks.usds
        });

        // 4. Set up ALM controller
        address[] memory relayers = new address[](1);
        relayers[0] = deployer.addr;
        SetUpAllLib.setUpAlmController({
            controllerInstance: controllerInstance,
            ilkInstance: ilkInstance,
            mocks: mocks,
            admin: admin,
            relayers: relayers,
            cctpTokenMessenger: cctpTokenMessenger
        });

        // 5. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits({
            controllerInstance: controllerInstance,
            usdcUnitSize: config.readUint(".usdcUnitSize"),
            susds: address(mocks.susds)
        });

        vm.stopBroadcast();
    }
}
