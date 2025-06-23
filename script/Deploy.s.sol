// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerDeploy} from "spark-alm-controller/deploy/ControllerDeploy.sol";
import {VatMock} from "script/mocks/VatMock.sol";
import {GemMock} from "script/mocks/GemMock.sol";
import {UsdsJoinMock} from "script/mocks/UsdsJoinMock.sol";
import {DaiUsdsMock} from "script/mocks/DaiUsdsMock.sol";
import {PSMMock} from "script/mocks/PSMMock.sol";
import "forge-std/Script.sol";

struct MockContracts {
    VatMock vat;
    UsdsJoinMock usdsJoin;
    GemMock usds;
    GemMock dai;
    DaiUsdsMock daiUsds;
    PSMMock psm;
}

contract Deploy is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        string memory config = ScriptTools.loadConfig("input");

        VmSafe.Wallet memory deployer = vm.createWallet(vm.envUint("PRIVATE_KEY"));
        bytes32 ilk = ScriptTools.stringToBytes32(config.readString(".ilk"));
        address admin = config.readAddress(".admin");
        MockContracts memory mocks;

        vm.startBroadcast(deployer.privateKey);

        // 1. Deploy mock contracts
        mocks.vat = new VatMock();
        mocks.usds = new GemMock(0);
        mocks.usdsJoin = new UsdsJoinMock(mocks.vat, mocks.usds);
        mocks.dai = new GemMock(0);
        mocks.daiUsds = new DaiUsdsMock(address(mocks.dai));
        mocks.psm = new PSMMock(address(mocks.usds));

        // 2. Deploy AllocatorSystem
        AllocatorSharedInstance memory sharedInstance = AllocatorDeploy.deployShared(deployer.addr, admin);
        AllocatorIlkInstance memory ilkInstance =
            AllocatorDeploy.deployIlk(deployer.addr, admin, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        // 3. Deploy MainnetController
        MainnetControllerDeploy.deployFull({
            admin: admin,
            vault: ilkInstance.vault,
            psm: address(mocks.psm),
            daiUsds: address(mocks.daiUsds),
            cctp: config.readAddress(".cctpTokenMessenger")
        });

        vm.stopBroadcast();
    }
}
