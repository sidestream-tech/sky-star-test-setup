// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, stdJson} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {SetUpAllLib, MockContracts, ControllerInstance} from "src/libraries/SetUpAllLib.sol";

interface MainnetControllerLike {
    function LIMIT_USDS_MINT() external returns (bytes32);
}

contract SetUpAll is Script {
    using stdJson for string;

    uint256 internal constant WAD = 10 ** 18;

    function setUp() public {}

    function run() public {
        VmSafe.Wallet memory deployer = vm.createWallet(vm.envUint("PRIVATE_KEY"));
        address admin = deployer.addr;

        string memory config = ScriptTools.loadConfig("input");
        bytes32 ilk = ScriptTools.stringToBytes32(config.readString(".ilk"));
        address usdc = config.readAddress(".usdc");

        vm.startBroadcast(deployer.privateKey);

        // 1. Deploy mock contracts
        MockContracts memory mocks = SetUpAllLib.deployMockContracts(usdc, admin);

        // 2. Deploy AllocatorSystem
        AllocatorSharedInstance memory sharedInstance = AllocatorDeploy.deployShared(deployer.addr, admin);
        AllocatorIlkInstance memory ilkInstance =
            AllocatorDeploy.deployIlk(deployer.addr, admin, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        // 3. Set up AllocatorSystem and Deploy and set up ALM controller
        address[] memory relayers = new address[](1);
        relayers[0] = config.readAddress(".relayer");

        SetUpAllLib.AllocatorSetupParams memory params = SetUpAllLib.AllocatorSetupParams({
            ilk: ilk,
            ilkInstance: ilkInstance,
            sharedInstance: sharedInstance,
            admin: admin,
            mocks: mocks,
            cctp: config.readAddress(".cctpTokenMessenger"),
            relayers: relayers
        });
        ControllerInstance memory controllerInstance = SetUpAllLib.setUpAllocatorAndALMController(params);

        // 4. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits(
            SetUpAllLib.RateLimitParams({
                controllerInstance: controllerInstance,
                usdcUnitSize: config.readUint(".usdcUnitSize"),
                susds: address(mocks.susds),
                cctpDestinationDomain: uint32(config.readUint(".cctpDestinationDomain")),
                cctpRecipient: ScriptTools.stringToBytes32(config.readString(".cctpRecipient"))
            })
        );

        vm.stopBroadcast();
    }
}
