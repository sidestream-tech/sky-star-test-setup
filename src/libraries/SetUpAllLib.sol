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
import {DaiMock} from "src/mocks/DaiMock.sol";
import {UsdsMock} from "src/mocks/UsdsMock.sol";
import {UsdsJoinMock} from "src/mocks/UsdsJoinMock.sol";
import {DaiJoinMock} from "src/mocks/DaiJoinMock.sol";
import {DaiUsdsMock} from "src/mocks/DaiUsdsMock.sol";
import {LitePsmMock} from "src/mocks/LitePsmMock.sol";
import {JugMock} from "src/mocks/JugMock.sol";
import {IVatMock} from "src/mocks/interfaces/IVatMock.sol";
import {IJugMock} from "src/mocks/interfaces/IJugMock.sol";
import {IGemMock} from "src/mocks/interfaces/IGemMock.sol";
import {SusdsMock} from "src/mocks/SusdsMock.sol";
import {PSMMock} from "src/mocks/PSMMock.sol";

interface MainnetControllerLike {
    function LIMIT_USDS_MINT() external returns (bytes32);
    function LIMIT_4626_DEPOSIT() external returns (bytes32);
    function LIMIT_4626_WITHDRAW() external returns (bytes32);
    function LIMIT_USDS_TO_USDC() external returns (bytes32);
    function LIMIT_USDC_TO_DOMAIN() external returns (bytes32);
    function LIMIT_USDC_TO_CCTP() external returns (bytes32);

    function setMintRecipient(uint32 destinationDomain, bytes32 mintRecipient) external;
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

    struct RateLimitParams {
        ControllerInstance controllerInstance;
        uint256 usdcUnitSize;
        address susds;
        uint32 cctpDestinationDomain;
        bytes32 cctpRecipient;
    }

    function deployMockContracts(address usdc, address pocket) internal returns (MockContracts memory mocks) {
        bytes32 psmIlk = "MCD_LITE_PSM_USDC";

        // 1. Deploy mock contracts
        VatMock vat = new VatMock();
        mocks.vat = address(vat);
        mocks.usds = address(new UsdsMock());
        mocks.usdsJoin = address(new UsdsJoinMock(VatMock(mocks.vat), GemMock(mocks.usds)));
        mocks.dai = address(new DaiMock());
        mocks.daiJoin = address(new DaiJoinMock(VatMock(mocks.vat), GemMock(mocks.dai)));
        mocks.daiUsds = address(new DaiUsdsMock(mocks.daiJoin, mocks.usdsJoin));
        JugMock jug = new JugMock(VatMock(mocks.vat));
        mocks.jug = address(jug);
        mocks.susds = address(new SusdsMock(GemMock(mocks.usds)));
        mocks.psm = address(new LitePsmMock(psmIlk, usdc, mocks.daiJoin, pocket));

        // 2. Rely Usds on UsdsJoin
        IGemMock(mocks.usds).rely(mocks.usdsJoin);
        // 4. Rely Dai on DaiJoin
        IGemMock(mocks.dai).rely(mocks.daiJoin);
        // 5. Rely Vat on Jug
        vat.rely(mocks.jug);
        // 6. Set PSM
        vat.init(psmIlk);
        jug.init(psmIlk);
        vat.file(psmIlk, "line", 10_000_000 * RAD); // 1 million line
        // 7. Approve psm to transfer usdc from pocket (msg.sender)
        IGemMock(usdc).approve(mocks.psm, type(uint256).max);

        return mocks;
    }

    function setUpAllocatorAndALMController(AllocatorSetupParams memory params)
        internal
        returns (ControllerInstance memory controllerInstance)
    {
        IVatMock vat = IVatMock(params.mocks.vat);
        IJugMock jug = IJugMock(params.mocks.jug);

        // 1. Onboard the ilk
        vat.init(params.ilk);
        jug.init(params.ilk);

        // 1.1 Set ilk parameters
        vat.file(params.ilk, "line", 10_000_000 * RAD); // 1 million line

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
    function setMainnetControllerRateLimits(RateLimitParams memory params) internal {
        IRateLimits rateLimits = IRateLimits(params.controllerInstance.rateLimits);
        MainnetControllerLike controller = MainnetControllerLike(params.controllerInstance.controller);
        uint256 USDC_UNIT_SIZE = params.usdcUnitSize * 1e6;
        uint256 maxAmount18 = USDC_UNIT_SIZE * 1e12 * 5;
        uint256 slope18 = USDC_UNIT_SIZE * 1e12 / 4 hours;
        uint256 maxAmount6 = USDC_UNIT_SIZE * 5;
        uint256 slope6 = USDC_UNIT_SIZE / 4 hours;

        // USDS mint/burn rate limits
        rateLimits.setRateLimitData(controller.LIMIT_USDS_MINT(), maxAmount18, slope18);

        // susds deposit/withdraw rate limits
        bytes32 depositKey = controller.LIMIT_4626_DEPOSIT();
        bytes32 withdrawKey = controller.LIMIT_4626_WITHDRAW();

        rateLimits.setRateLimitData(RateLimitHelpers.makeAssetKey(depositKey, params.susds), maxAmount18, slope18);
        rateLimits.setRateLimitData(RateLimitHelpers.makeAssetKey(withdrawKey, params.susds), type(uint256).max, 0);

        // USDS to USDC conversion rate limits
        rateLimits.setRateLimitData(controller.LIMIT_USDS_TO_USDC(), maxAmount6, slope6);

        // transferUSDCToCCTP rate limits
        controller.setMintRecipient(params.cctpDestinationDomain, params.cctpRecipient);
        bytes32 domainKey =
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), params.cctpDestinationDomain);
        rateLimits.setRateLimitData(domainKey, maxAmount6, slope6);
        rateLimits.setUnlimitedRateLimitData(controller.LIMIT_USDC_TO_CCTP());
    }
}
