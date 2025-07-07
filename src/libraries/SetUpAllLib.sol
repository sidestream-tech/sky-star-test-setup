// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {RolesLike, VaultLike, BufferLike} from "dss-allocator/deploy/AllocatorInit.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {MainnetControllerInit} from "sky-star-alm-controller/deploy/MainnetControllerInit.sol";
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
import {IJugMock} from "src/mocks/interfaces/IJugMock.sol";
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
    uint256 internal constant RAD = 10 ** 45;

    struct AllocatorSetupParams {
        bytes32 ilk;
        AllocatorIlkInstance ilkInstance;
        AllocatorSharedInstance sharedInstance;
        address admin;
        MockContracts mocks;
        address cctp;
        address[] relayers;
    }

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

    function setUpAllocatorAndALMController(
        AllocatorSetupParams memory params
    ) internal returns (ControllerInstance memory controllerInstance) {
        IVatMock vat = IVatMock(params.mocks.vat);
        IJugMock jug = IJugMock(params.mocks.jug);

        // 1. Onboard the ilk
        vat.init(params.ilk);
        jug.init(params.ilk);

        // 1.1 Set ilk parameters
        vat.file(params.ilk, "line", 10_000_000  * RAD); // 1 million line
        jug.file(params.ilk, "duty", 1000000000000000000000000000); // 0% duty

        // 2. Add buffer to registry
        RegistryLike(params.sharedInstance.registry).file(params.ilk, "buffer", params.ilkInstance.buffer);

        // 3. Initiate the allocator vault
        vat.slip(params.ilk, params.ilkInstance.vault, int256(10 ** 12 * WAD));
        vat.grab(params.ilk, params.ilkInstance.vault, params.ilkInstance.vault, address(0), int256(10 ** 12 * WAD), 0);

        // 4. Set up Jug on AllocatorVault (to draw/wipe)
        VaultLike(params.ilkInstance.vault).file("jug", params.mocks.jug);

        // 5. Allow vault to pull funds from the buffer
        BufferLike(params.ilkInstance.buffer).approve(
            VaultLike(params.ilkInstance.vault).usds(), params.ilkInstance.vault, type(uint256).max
        );

        // 6. Register
        RolesLike(params.sharedInstance.roles).setIlkAdmin(params.ilk, params.admin);

        // 7. Deploy ALM controller
        controllerInstance.almProxy = address(new ALMProxy(params.admin));
        controllerInstance.rateLimits = address(new RateLimits(params.admin));

        controllerInstance.controller = address(
            new MainnetController({
                admin_: params.admin,
                proxy_: controllerInstance.almProxy,
                rateLimits_: controllerInstance.rateLimits,
                vault_: params.ilkInstance.vault,
                psm_: params.mocks.psm,
                daiUsds_: params.mocks.daiUsds,
                cctp_: params.cctp,
                addresses: MainnetController.Addresses({
                    USDS: params.mocks.usds,
                    USDE: address(0),
                    SUSDE: address(0),
                    USTB: address(0),
                    ETHENA_MINTER: address(0),
                    SUPERSTATE_REDEMPTION: address(0)
                })
            })
        );

        // 8. Set up ALM controller
        MainnetControllerInit.MintRecipient[] memory mintRecipients = new MainnetControllerInit.MintRecipient[](0);

        MainnetControllerInit.initAlmSystem(
            params.ilkInstance.vault,
            params.mocks.usds,
            controllerInstance,
            MainnetControllerInit.ConfigAddressParams({
                freezer: address(0),
                relayers: params.relayers,
                oldController: address(0)
            }),
            MainnetControllerInit.CheckAddressParams({
                admin: params.admin,
                proxy: controllerInstance.almProxy,
                rateLimits: controllerInstance.rateLimits,
                vault: params.ilkInstance.vault,
                psm: params.mocks.psm,
                daiUsds: params.mocks.daiUsds,
                cctp: params.cctp
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
