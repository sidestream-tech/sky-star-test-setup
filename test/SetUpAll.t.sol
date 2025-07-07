// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {AllocatorDeploy} from "dss-allocator/deploy/AllocatorDeploy.sol";
import {AllocatorSharedInstance, AllocatorIlkInstance} from "dss-allocator/deploy/AllocatorInstances.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SetUpAllLib, MockContracts, ControllerInstance} from "src/libraries/SetUpAllLib.sol";
import {IGemMock} from "src/mocks/interfaces/IGemMock.sol";
import {IVatMock} from "src/mocks/interfaces/IVatMock.sol";
import {ERC4626Mock} from "src/mocks/ERC4626Mock.sol";
import {GodMode} from "dss-test/DssTest.sol";
import {console} from "forge-std/console.sol";

interface MainnetControllerLike {
    function mintUSDS(uint256 usdsAmount) external;
    function burnUSDS(uint256 usdsAmount) external;
    function depositERC4626(address token, uint256 amount) external returns (uint256 shares);
    function withdrawERC4626(address token, uint256 amount) external returns (uint256 shares);
    function redeemERC4626(address token, uint256 shares) external returns (uint256 assets);
    function swapUSDSToUSDC(uint256 usdcAmount) external;
    function swapUSDCToUSDS(uint256 usdcAmount) external;
}

contract SetUpAllTest is Test {
    using stdJson for string;

    address relayer;
    address usdc;
    address pocket;
    MockContracts mocks;
    AllocatorSharedInstance sharedInstance;
    AllocatorIlkInstance ilkInstance;
    ControllerInstance controllerInstance;
    bytes32 ilk;

    uint256 constant WAD = 10 ** 18;

    function setUp() public {
        // 0. Set up Avalanche Fuji testnet
        // 0-a. Set up the environment for the Fuji testnet
        vm.setEnv("FOUNDRY_ROOT_CHAINID", "43113");
        // 0-b. Create a fork of the Fuji testnet
        uint256 fujiFork = vm.createFork("https://api.avax-test.network/ext/bc/C/rpc");
        vm.selectFork(fujiFork);

        (address deployer,) = makeAddrAndKey("deployer");
        address admin = pocket = deployer;

        string memory config = ScriptTools.loadConfig("input");
        ilk = ScriptTools.stringToBytes32(config.readString(".ilk"));
        relayer = config.readAddress(".relayer");
        usdc = config.readAddress(".usdc");

        // Fill up usdc to pocket
        GodMode.setBalance(usdc, pocket, 1000 * 10 ** 6);

        vm.startPrank(deployer);

        // 1. Deploy mock contracts
        mocks = SetUpAllLib.deployMockContracts(usdc, admin);

        // 2. Deploy AllocatorSystem
        sharedInstance = AllocatorDeploy.deployShared(deployer, admin);
        ilkInstance = AllocatorDeploy.deployIlk(deployer, admin, sharedInstance.roles, ilk, address(mocks.usdsJoin));

        // 3. Set up AllocatorSystem and Deploy and set up ALM controller
        address[] memory relayers = new address[](1);
        relayers[0] = relayer;

        SetUpAllLib.AllocatorSetupParams memory params = SetUpAllLib.AllocatorSetupParams({
            ilk: ilk,
            ilkInstance: ilkInstance,
            sharedInstance: sharedInstance,
            mocks: mocks,
            admin: admin,
            cctp: config.readAddress(".cctpTokenMessenger"),
            relayers: relayers
        });
        controllerInstance = SetUpAllLib.setUpAllocatorAndALMController(params);

        // 4. Set up rate limits for the controller
        SetUpAllLib.setMainnetControllerRateLimits({
            controllerInstance: controllerInstance,
            usdcUnitSize: config.readUint(".usdcUnitSize"),
            susds: address(mocks.susds)
        });

        vm.stopPrank();
    }

    function testMintAndBurnUsds() public {
        IGemMock usds = IGemMock(mocks.usds);
        IVatMock vat = IVatMock(mocks.vat);

        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.assertEq(usds.balanceOf(almProxy), 0, "Initial USDS balance should be zero");
        vm.prank(relayer);
        MainnetControllerLike(controllerInstance.controller).mintUSDS(10 * WAD); // Mint 10 USDS
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after minting should be 10 WAD");
        (uint256 art,,,,) = vat.ilks(ilk);
        vm.assertEq(art, 10 * WAD, "art should be 10 WAD after minting");

        // Burn USDS
        vm.prank(relayer);
        controller.burnUSDS(5 * WAD); // Burn 5 USDS
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance after burning should be 5 WAD");
        (art,,,,) = vat.ilks(ilk);
        vm.assertEq(art, 5 * WAD, "art should be 5 WAD after burning");
    }

    function testDepositAndWithdrawAndRedeemERC4626() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.prank(relayer);
        controller.mintUSDS(10 * WAD); // Mint 10 USDS

        // Deposit into ERC4626
        vm.assertEq(ERC4626Mock(mocks.susds).shareBalance(almProxy), 0, "Share balance before deposit should be 0");

        vm.prank(relayer);
        controller.depositERC4626(mocks.susds, 5 * WAD); // Deposit 5 USDS
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance after deposit should be 5 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 5 * WAD, "Share balance after deposit should be 5 WAD"
        );

        // Withdraw from ERC4626
        vm.prank(relayer);
        uint256 shares = controller.withdrawERC4626(mocks.susds, 3 * WAD); // Withdraw 3 USDS
        vm.assertEq(shares, 3 * WAD, "Withdrawn shares should be 3 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 2 * WAD, "Share balance after withdrawal should be 2 WAD"
        );
        vm.assertEq(usds.balanceOf(almProxy), 8 * WAD, "USDS balance after withdrawal should be 8 WAD");

        // Redeem from ERC4626
        vm.prank(relayer);
        shares = controller.redeemERC4626(mocks.susds, 2 * WAD); // Redeem 2 USDS
        vm.assertEq(shares, 2 * WAD, "Redeemed shares should be 2 WAD");
        vm.assertEq(
            ERC4626Mock(mocks.susds).shareBalance(almProxy), 0, "Share balance after redemption should be 0 WAD"
        );
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after redemption should be 10 WAD");
    }

    function testSwapUSDSToUSDCAndBack() public {
        IGemMock usds = IGemMock(mocks.usds);
        address almProxy = controllerInstance.almProxy;
        MainnetControllerLike controller = MainnetControllerLike(controllerInstance.controller);

        // Mint USDS
        vm.prank(relayer);
        controller.mintUSDS(10 * WAD); // Mint 10 USDS

        // Swap USDS to USDC
        vm.prank(relayer);
        controller.swapUSDSToUSDC(5 * 10 ** 6); // Swap to 5 USDC
        vm.assertEq(usds.balanceOf(almProxy), 5 * WAD, "USDS balance after swap should be 5 WAD");
        vm.assertEq(IGemMock(usdc).balanceOf(almProxy), 5 * 10 ** 6, "USDC balance after swap should be 5 USDC");

        // Swap USDC back to USDS
        vm.prank(relayer);
        controller.swapUSDCToUSDS(5 * 10 ** 6); // Swap to 5 USDC back to USDS
        vm.assertEq(usds.balanceOf(almProxy), 10 * WAD, "USDS balance after swap back should be 10 WAD");
        vm.assertEq(IGemMock(usdc).balanceOf(almProxy), 0, "USDC balance after swap back should be 0 USDC");
    }
}
