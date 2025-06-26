// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {RolesLike, VaultLike, BufferLike} from "dss-allocator/deploy/AllocatorInit.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerInit} from "sky-star-alm-controller/deploy/MainnetControllerInit.sol";
import {MainnetControllerDeploy} from "sky-star-alm-controller/deploy/ControllerDeploy.sol";
import {ControllerInstance} from "sky-star-alm-controller/deploy/ControllerInstance.sol";
import {IRateLimits} from "sky-star-alm-controller/src/interfaces/IRateLimits.sol";
import {RateLimitHelpers} from "sky-star-alm-controller/src/RateLimitHelpers.sol";
import {ALMProxy} from "sky-star-alm-controller/src/ALMProxy.sol";
import {RateLimits} from "sky-star-alm-controller/src/RateLimits.sol";
import {MainnetController} from "sky-star-alm-controller/src/MainnetController.sol";
import {VatMock} from "src/mocks/VatMock.sol";
import {GemMock} from "src/mocks/GemMock.sol";
import {UsdsJoinMock} from "src/mocks/UsdsJoinMock.sol";
import {DaiJoinMock} from "src/mocks/DaiJoinMock.sol";
import {DaiUsdsMock} from "src/mocks/DaiUsdsMock.sol";
import {PSMMock} from "src/mocks/PSMMock.sol";
import {JugMock} from "src/mocks/JugMock.sol";
import {IVatMock} from "src/mocks/interfaces/IVatMock.sol";
import {IGemMock} from "src/mocks/interfaces/IGemMock.sol";
import {ERC4626Mock} from "src/mocks/ERC4626Mock.sol";

interface MainnetControllerLike {
    function LIMIT_USDS_MINT() external returns (bytes32);
    function LIMIT_4626_DEPOSIT() external returns (bytes32);
    function LIMIT_4626_WITHDRAW() external returns (bytes32);
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
    address daiJoin;
    address daiUsds;
    address psm;
    address jug;
    address susds;
}

library SetUpAllLib {
    uint256 internal constant WAD = 10 ** 18;

    function deployMockContracts() internal returns (MockContracts memory mocks) {
        // 1. Deploy mock contracts
        mocks.vat = address(new VatMock());
        mocks.usds = address(new GemMock());
        mocks.usdsJoin = address(new UsdsJoinMock(VatMock(mocks.vat), GemMock(mocks.usds)));
        mocks.dai = address(new GemMock());
        mocks.daiJoin = address(new DaiJoinMock(VatMock(mocks.vat), GemMock(mocks.dai)));
        mocks.daiUsds = address(new DaiUsdsMock(mocks.daiJoin, mocks.usdsJoin));
        mocks.psm = address(new PSMMock(mocks.usds));
        mocks.jug = address(new JugMock(VatMock(mocks.vat)));
        mocks.susds = address(new ERC4626Mock(GemMock(mocks.usds)));

        // 2. Rely Usds on UsdsJoin
        IGemMock(mocks.usds).rely(mocks.usdsJoin);
        // 3. Rely Dai on DaiJoin
        IGemMock(mocks.dai).rely(mocks.daiJoin);
        // 4. Rely Vat on Jug
        IVatMock(mocks.vat).rely(mocks.jug);

        return mocks;
    }

    function setUpAllocatorSystem(
        bytes32 ilk,
        AllocatorIlkInstance memory ilkInstance,
        AllocatorSharedInstance memory sharedInstance,
        address admin,
        MockContracts memory mocks
    ) internal {
        IVatMock vat = IVatMock(mocks.vat);

        // 1. Add buffer to registry
        RegistryLike(sharedInstance.registry).file(ilk, "buffer", ilkInstance.buffer);

        // 2. Initiate the allocator vault
        vat.slip(ilk, ilkInstance.vault, int256(10 ** 12 * WAD));
        vat.grab(ilk, ilkInstance.vault, ilkInstance.vault, address(0), int256(10 ** 12 * WAD), 0);

        // 3. Set up Jug on AllocatorVault (to draw/wipe)
        VaultLike(ilkInstance.vault).file("jug", mocks.jug);

        // 4. Allow vault to pull funds from the buffer
        BufferLike(ilkInstance.buffer).approve(
            VaultLike(ilkInstance.vault).usds(), ilkInstance.vault, type(uint256).max
        );

        // 5. Register
        RolesLike(sharedInstance.roles).setIlkAdmin(ilk, admin);
    }

    function deployAlmController(address admin, address vault, address psm, address daiUsds, address cctp, address usds)
        internal
        returns (ControllerInstance memory controllerInstance)
    {
        controllerInstance.almProxy = address(new ALMProxy(admin));
        controllerInstance.rateLimits = address(new RateLimits(admin));

        controllerInstance.controller = address(
            new MainnetController({
                admin_: admin,
                proxy_: controllerInstance.almProxy,
                rateLimits_: controllerInstance.rateLimits,
                vault_: vault,
                psm_: psm,
                daiUsds_: daiUsds,
                cctp_: cctp,
                addresses: MainnetController.Addresses({
                    USDS: usds,
                    USDE: address(0),
                    SUSDE: address(0),
                    USTB: address(0),
                    ETHENA_MINTER: address(0),
                    SUPERSTATE_REDEMPTION: address(0)
                })
            })
        );
    }

    function setUpAlmController(
        ControllerInstance memory controllerInstance,
        AllocatorIlkInstance memory ilkInstance,
        MockContracts memory mocks,
        address admin,
        address cctpTokenMessenger,
        address[] memory relayers
    ) internal {
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);

        MainnetControllerInit.initAlmSystem(
            ilkInstance.vault,
            mocks.usds,
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
                psm: mocks.psm,
                daiUsds: mocks.daiUsds,
                cctp: cctpTokenMessenger
            }),
            mintRecipients
        );
    }

    // Rate limits value copied from https://github.com/sparkdotfi/spark-alm-controller/blob/7f0a473951e4c5528d52ee442461662976c4a947/script/staging/FullStagingDeploy.s.sol#L381
    function setMainnetControllerRateLimits(
        ControllerInstance memory controllerInstance,
        uint256 usdcUnitSize,
        address susds
    ) internal {
        IRateLimits rateLimits = IRateLimits(controllerInstance.rateLimits);
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);
        uint256 USDC_UNIT_SIZE = usdcUnitSize * 1e6;
        uint256 maxAmount18 = USDC_UNIT_SIZE * 1e12 * 5;
        uint256 slope18 = USDC_UNIT_SIZE * 1e12 / 4 hours;

        // USDS mint/burn rate limits
        rateLimits.setRateLimitData(controller.LIMIT_USDS_MINT(), maxAmount18, slope18);

        // susds deposit/withdraw rate limits
        bytes32 depositKey = controller.LIMIT_4626_DEPOSIT();
        bytes32 withdrawKey = controller.LIMIT_4626_WITHDRAW();

        rateLimits.setRateLimitData(RateLimitHelpers.makeAssetKey(depositKey, susds), maxAmount18, slope18);
        rateLimits.setRateLimitData(RateLimitHelpers.makeAssetKey(withdrawKey, susds), type(uint256).max, 0);
    }
}
