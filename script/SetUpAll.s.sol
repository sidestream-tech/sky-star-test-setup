// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, stdJson} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {RolesLike, VaultLike, BufferLike, RegistryLike} from "dss-allocator/deploy/AllocatorInit.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerInit} from "spark-alm-controller/deploy/MainnetControllerInit.sol";
import {MainnetControllerDeploy} from "spark-alm-controller/deploy/ControllerDeploy.sol";
import {ControllerInstance} from "spark-alm-controller/deploy/ControllerInstance.sol";
import {IRateLimits} from "spark-alm-controller/src/interfaces/IRateLimits.sol";
import {VatMock} from "script/mocks/VatMock.sol";
import {GemMock} from "script/mocks/GemMock.sol";
import {UsdsJoinMock} from "script/mocks/UsdsJoinMock.sol";
import {DaiUsdsMock} from "script/mocks/DaiUsdsMock.sol";
import {PSMMock} from "script/mocks/PSMMock.sol";
import {JugMock} from "script/mocks/JugMock.sol";
import {IVatMock} from "script/mocks/interfaces/IVatMock.sol";

interface MainnetControllerLike {
    function LIMIT_USDS_MINT() external returns (bytes32);
}

struct MockContracts {
    VatMock vat;
    UsdsJoinMock usdsJoin;
    GemMock usds;
    GemMock dai;
    DaiUsdsMock daiUsds;
    PSMMock psm;
    JugMock jug;
}

contract SetUpAll is Script {
    using stdJson for string;

    uint256 internal constant WAD = 10 ** 18;

    string config;
    MockContracts mocks;
    VmSafe.Wallet deployer;
    bytes32 ilk;
    address admin;
    address cctpTokenMessenger;
    AllocatorSharedInstance sharedInstance;
    AllocatorIlkInstance ilkInstance;
    ControllerInstance controllerInstance;

    function setUp() public {
        config = ScriptTools.loadConfig("input");
        deployer = vm.createWallet(vm.envUint("PRIVATE_KEY"));
        ilk = ScriptTools.stringToBytes32(config.readString(".ilk"));
        admin = config.readAddress(".admin");
        cctpTokenMessenger = config.readAddress(".cctpTokenMessenger");
    }

    function run() public {
        vm.startBroadcast(deployer.privateKey);

        // 1. Deploy mock contracts
        _deployMockContracts();

        // 2. Deploy AllocatorSystem and set up
        _deployAndSetUpAllocatorSystem();

        // 3. Deploy and set up ALM controller
        _deployAndSetUpAlmController();

        // 4. Set up rate limits for the controller
        _setMainnetControllerRateLimits();

        vm.stopBroadcast();
    }

    function _deployMockContracts() internal {
        // 1. Deploy mock contracts
        mocks.vat = new VatMock();
        mocks.usds = new GemMock();
        mocks.usdsJoin = new UsdsJoinMock(mocks.vat, mocks.usds);
        mocks.dai = new GemMock();
        mocks.daiUsds = new DaiUsdsMock(address(mocks.dai));
        mocks.psm = new PSMMock(address(mocks.usds));
        mocks.jug = new JugMock(mocks.vat);

        // 2. Rely Usds on UsdsJoin
        mocks.usds.rely(address(mocks.usdsJoin));
    }

    function _deployAndSetUpAllocatorSystem() internal {
        // 1. Deploy AllocatorSystem
        sharedInstance = AllocatorDeploy.deployShared(deployer.addr, admin);
        ilkInstance =
            AllocatorDeploy.deployIlk(deployer.addr, admin, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        // 2. Add buffer to registry
        RegistryLike(sharedInstance.registry).file(ilk, "buffer", ilkInstance.buffer);

        // 3. Initiate the allocator vault
        mocks.vat.slip(ilk, ilkInstance.vault, int256(10 ** 12 * WAD));
        mocks.vat.grab(ilk, ilkInstance.vault, ilkInstance.vault, address(0), int256(10 ** 12 * WAD), 0);

        // 4. Set up Jug on AllocatorVault (to draw/wipe)
        VaultLike(ilkInstance.vault).file("jug", address(mocks.jug));

        // 5. Allow vault to pull funds from the buffer
        BufferLike(ilkInstance.buffer).approve(
            VaultLike(ilkInstance.vault).usds(), ilkInstance.vault, type(uint256).max
        );

        // 6. Register
        RolesLike(sharedInstance.roles).setIlkAdmin(ilk, admin);
    }

    function _deployAndSetUpAlmController() internal {
        // 1. Deploy MainnetController
        controllerInstance = MainnetControllerDeploy.deployFull({
            admin: admin,
            vault: ilkInstance.vault,
            psm: address(mocks.psm),
            daiUsds: address(mocks.daiUsds),
            cctp: cctpTokenMessenger
        });

        // 2. Set up ALM controller
        address[] memory relayers = new address[](0);
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);

        MainnetControllerInit.initAlmSystem(
            ilkInstance.vault,
            address(mocks.usds),
            controllerInstance,
            MainnetControllerInit.ConfigAddressParams({
                freezer: address(0),
                relayers: relayers,
                oldController: address(0)
            }),
            MainnetControllerInit.CheckAddressParams({
                admin: admin,
                proxy: controllerInstance.almProxy,
                rateLimits: controllerInstance.rateLimits,
                vault: ilkInstance.vault,
                psm: address(mocks.psm),
                daiUsds: address(mocks.daiUsds),
                cctp: cctpTokenMessenger
            }),
            mintRecipients
        );
    }

    // Rate limits value copied from https://github.com/sparkdotfi/spark-alm-controller/blob/7f0a473951e4c5528d52ee442461662976c4a947/script/staging/FullStagingDeploy.s.sol#L381
    function _setMainnetControllerRateLimits() internal {
        IRateLimits rateLimits = IRateLimits(controllerInstance.rateLimits);
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);
        uint256 USDC_UNIT_SIZE = config.readUint(".usdcUnitSize") * 1e6;
        uint256 maxAmount18 = USDC_UNIT_SIZE * 1e12 * 5;
        uint256 slope18 = USDC_UNIT_SIZE * 1e12 / 4 hours;

        // USDS mint/burn rate limits
        rateLimits.setRateLimitData(controller.LIMIT_USDS_MINT(), maxAmount18, slope18);
    }
}
