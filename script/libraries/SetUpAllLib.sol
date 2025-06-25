// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {RolesLike, VaultLike, BufferLike} from "dss-allocator/deploy/AllocatorInit.sol";
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
import {IGemMock} from "script/mocks/interfaces/IGemMock.sol";

interface MainnetControllerLike {
    function LIMIT_USDS_MINT() external returns (bytes32);
}

interface RegistryLike {
    function wards(address) external view returns (uint256);
    function file(bytes32, bytes32, address) external;
}

struct MockContracts {
    address vat;
    address usds;
    address dai;
    address usdsJoin;
    address daiUsds;
    address psm;
    address jug;
}

struct AllocatorSetUpInstance {
    bytes32 ilk;
    AllocatorIlkInstance ilkInstance;
    AllocatorSharedInstance sharedInstance;
    address admin;
    MockContracts mocks;
}

struct ALMSetUpInstance {
    ControllerInstance controllerInstance;
    AllocatorIlkInstance ilkInstance;
    MockContracts mocks;
    address admin;
    address cctpTokenMessenger;
    address[] relayers;
}

struct RateLimitsInstance {
    ControllerInstance controllerInstance;
    uint256 usdcUnitSize;
}

library SetUpAllLib {
    uint256 internal constant WAD = 10 ** 18;

    function deployMockContracts() internal returns (MockContracts memory mocks) {
        // 1. Deploy mock contracts
        mocks.vat = address(new VatMock());
        mocks.usds = address(new GemMock());
        mocks.usdsJoin = address(new UsdsJoinMock(VatMock(mocks.vat), GemMock(mocks.usds)));
        mocks.dai = address(new GemMock());
        mocks.daiUsds = address(new DaiUsdsMock(address(mocks.dai)));
        mocks.psm = address(new PSMMock(address(mocks.usds)));
        mocks.jug = address(new JugMock(VatMock(mocks.vat)));

        // 2. Rely Usds on UsdsJoin
        IGemMock(mocks.usds).rely(mocks.usdsJoin);
        // 3. Rely Vat on Jug
        IVatMock(mocks.vat).rely(mocks.jug);

        return mocks;
    }

    function setUpAllocatorSystem(AllocatorSetUpInstance memory setupInstance) internal {
        AllocatorSharedInstance memory shared = setupInstance.sharedInstance;
        AllocatorIlkInstance memory ilkInstance = setupInstance.ilkInstance;
        MockContracts memory mocks = setupInstance.mocks;
        IVatMock vat = IVatMock(mocks.vat);

        // 1. Add buffer to registry
        RegistryLike(shared.registry).file(setupInstance.ilk, "buffer", ilkInstance.buffer);

        // 2. Initiate the allocator vault
        vat.slip(setupInstance.ilk, ilkInstance.vault, int256(10 ** 12 * WAD));
        vat.grab(setupInstance.ilk, ilkInstance.vault, ilkInstance.vault, address(0), int256(10 ** 12 * WAD), 0);

        // 3. Set up Jug on AllocatorVault (to draw/wipe)
        VaultLike(ilkInstance.vault).file("jug", mocks.jug);

        // 4. Allow vault to pull funds from the buffer
        BufferLike(ilkInstance.buffer).approve(
            VaultLike(ilkInstance.vault).usds(), ilkInstance.vault, type(uint256).max
        );

        // 5. Register
        RolesLike(shared.roles).setIlkAdmin(setupInstance.ilk, setupInstance.admin);
    }

    function setUpAlmController(ALMSetUpInstance memory setupInstance) internal {
        ControllerInstance memory controllerInstance = setupInstance.controllerInstance;
        AllocatorIlkInstance memory ilkInstance = setupInstance.ilkInstance;
        MockContracts memory mocks = setupInstance.mocks;
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);

        MainnetControllerInit.initAlmSystem(
            ilkInstance.vault,
            mocks.usds,
            controllerInstance,
            MainnetControllerInit.ConfigAddressParams({
                freezer: address(0),
                relayers: setupInstance.relayers,
                oldController: address(0)
            }),
            MainnetControllerInit.CheckAddressParams({
                admin: setupInstance.admin,
                proxy: controllerInstance.almProxy,
                rateLimits: controllerInstance.rateLimits,
                vault: ilkInstance.vault,
                psm: mocks.psm,
                daiUsds: mocks.daiUsds,
                cctp: setupInstance.cctpTokenMessenger
            }),
            mintRecipients
        );
    }

    // Rate limits value copied from https://github.com/sparkdotfi/spark-alm-controller/blob/7f0a473951e4c5528d52ee442461662976c4a947/script/staging/FullStagingDeploy.s.sol#L381
    function setMainnetControllerRateLimits(RateLimitsInstance memory rateLimitsInstance) internal {
        ControllerInstance memory controllerInstance = rateLimitsInstance.controllerInstance;

        IRateLimits rateLimits = IRateLimits(controllerInstance.rateLimits);
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);
        uint256 USDC_UNIT_SIZE = rateLimitsInstance.usdcUnitSize * 1e6;
        uint256 maxAmount18 = USDC_UNIT_SIZE * 1e12 * 5;
        uint256 slope18 = USDC_UNIT_SIZE * 1e12 / 4 hours;

        // USDS mint/burn rate limits
        rateLimits.setRateLimitData(controller.LIMIT_USDS_MINT(), maxAmount18, slope18);
    }
}
