// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {VatMock} from "script/mocks/VatMock.sol";
import {GemMock} from "script/mocks/GemMock.sol";
import {UsdsJoinMock} from "script/mocks/UsdsJoinMock.sol";

struct MockContracts {
    VatMock vat;
    UsdsJoinMock usdsJoin;
    GemMock usds;
}

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        bytes32 ilk = ScriptTools.stringToBytes32(vm.envString("ILK_NAME"));
        VmSafe.Wallet memory deployer = vm.createWallet(vm.envUint("PRIVATE_KEY"));
        MockContracts memory mocks;

        vm.startBroadcast(deployer.privateKey);

        // 1. Deploy mock contracts
        mocks.vat = new VatMock();
        mocks.usds = new GemMock(0);
        mocks.usdsJoin = new UsdsJoinMock(mocks.vat, mocks.usds);

        // 2. Deploy AllocatorSystem
        AllocatorSharedInstance memory sharedInstance = AllocatorDeploy.deployShared(deployer.addr, deployer.addr);
        AllocatorDeploy.deployIlk(deployer.addr, deployer.addr, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        vm.stopBroadcast();
    }
}
