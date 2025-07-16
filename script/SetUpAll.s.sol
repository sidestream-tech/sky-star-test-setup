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
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        VmSafe.Wallet memory deployer = vm.createWallet(vm.envUint("PRIVATE_KEY"));

        address admin = deployer.addr;

        string memory config = ScriptTools.loadConfig("input");
        bytes32 ilk = ScriptTools.stringToBytes32(config.readString(".ilk"));
        address usdc = config.readAddress(".usdc");
        uint32 cctpDestinationDomain = uint32(config.readUint(".cctpDestinationDomain"));
        uint32 layerZeroDestinationEndpointId = uint32(config.readUint(".layerZeroDestinationEndpointId"));

        vm.startBroadcast(deployer.privateKey);

        // 1. Deploy mock contracts
        MockContracts memory mocks =
            SetUpAllLib.deployMockContracts(usdc, admin, config.readAddress(".layerZeroEndpoint"));

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
            relayers: relayers,
            cctpDestinationDomain: cctpDestinationDomain,
            cctpRecipient: config.readBytes32(".cctpRecipient"),
            destinationEndpointId: layerZeroDestinationEndpointId,
            layerZeroRecipient: config.readBytes32(".layerZeroRecipient")
        });
        ControllerInstance memory controllerInstance = SetUpAllLib.setUpAllocatorAndALMController(params);

        // 4. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits(
            SetUpAllLib.RateLimitParams({
                controllerInstance: controllerInstance,
                usdcUnitSize: config.readUint(".usdcUnitSize"),
                usds: address(mocks.usds),
                susds: address(mocks.susds),
                cctpDestinationDomain: cctpDestinationDomain,
                destinationEndpointId: layerZeroDestinationEndpointId
            })
        );

        vm.stopBroadcast();

        // 5. Log contract addresses
        bool isBroadCast = vm.isContext(VmSafe.ForgeContext.ScriptBroadcast);
        string memory outputSlug = isBroadCast ? "output" : "dry-run/output";
        ScriptTools.exportContract(outputSlug, "almProxy", controllerInstance.almProxy);
        ScriptTools.exportContract(outputSlug, "controller", controllerInstance.controller);
        ScriptTools.exportContract(outputSlug, "rateLimits", controllerInstance.rateLimits);
        ScriptTools.exportContract(outputSlug, "dai", mocks.dai);
        ScriptTools.exportContract(outputSlug, "daiJoin", mocks.daiJoin);
        ScriptTools.exportContract(outputSlug, "daiUsds", mocks.daiUsds);
        ScriptTools.exportContract(outputSlug, "usds", mocks.usds);
        ScriptTools.exportContract(outputSlug, "usdsJoin", mocks.usdsJoin);
        ScriptTools.exportContract(outputSlug, "susds", mocks.susds);
        ScriptTools.exportContract(outputSlug, "vat", mocks.vat);
        ScriptTools.exportContract(outputSlug, "jug", mocks.jug);
        ScriptTools.exportContract(outputSlug, "psm", mocks.psm);
    }
}
