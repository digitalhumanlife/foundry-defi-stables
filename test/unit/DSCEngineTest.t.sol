//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20MockOriginalVersion.sol";
import {MockERC20FailedMint} from "test/mocks/MockERC20FailedMint.sol";

contract DSCEngineTest is Test {
    DeployDSC deployDSC;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployDSC = new DeployDSC();
        (dsc, engine, config) = deployDSC.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////
    // Price Tests  //
    //////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        console.log("usdAmount: ", usdAmount);
        // if 1 eth = 2000usd -> 100usd = 0.05eth
        uint256 expectedEthAmount = 0.05 ether;
        uint256 actualEthAmount = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedEthAmount, actualEthAmount);
    }

    /////////////////////////////
    // DepositCollateral Tests //
    /////////////////////////////
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock("RAN", "RAN", address(USER), AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // modifier for desiting collateral
    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL); //amount is 10 ether
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    ///////////////////////////
    // Mint tests            //
    ///////////////////////////
    function testRevertsWhenMintDscHealthFactorIsBroken() public depositCollateral {
        vm.startPrank(USER);
        (, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 amountDscToMint = collateralValueInUsd * 2;
        uint256 exHealthFactor = engine.calculateHealthFactor(USER, amountDscToMint);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, exHealthFactor));
        engine.mintDsc(amountDscToMint);
        vm.stopPrank();
    }

    function testRevertsMintFailed() public {
        MockERC20FailedMint mockDsc = new MockERC20FailedMint();
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];

        // address owner = msg.sender;
        // vm.prank(owner);
        DSCEngine engineWithMockDsc = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(engineWithMockDsc));
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engineWithMockDsc), AMOUNT_COLLATERAL);
        uint256 amountDscToMint = 5 ether;
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        engineWithMockDsc.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountDscToMint);
        vm.stopPrank();
    }
    ///////////////////////////
    // redeem and burn test  //
    ///////////////////////////

    function testCanRedeemCollateral() public depositCollateral {
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);

        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(AMOUNT_COLLATERAL, userBalance);
        vm.stopPrank();
    }

    function testCanBurnDsc() public {
        uint256 amountDscToMint = 500 ether;
        uint256 amountDscToBurn = 200 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        dsc.approve(address(engine), amountDscToMint);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountDscToMint);
        engine.burnDsc(amountDscToBurn);
        assertEq(300 ether, dsc.balanceOf(USER));
        vm.stopPrank();

        //         totalDscMinted:     500. 000 00000 00000 00000
        //   collateralValueInUsd:  20,000. 000 00000 00000 00000
    }
}
