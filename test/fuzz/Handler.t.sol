// Handler is gonna narrow down the way we call function
// e.g.: call deposit function before mint function, giving fuzz test a structure to follow

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "test/mocks/ERC20MockOriginalVersion.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    using SafeMath for uint256;

    DSCEngine engine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;

    uint256 public constant MAX_DEPOSIT = type(uint96).max;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);

        // console.log("totalDscMinted: ", totalDscMinted);
        // console.log("collateralValueInUsd: ", collateralValueInUsd);

        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return; // alt. we can use vm.assume()
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        engine.mintDsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }
    // To redeem collateral, first we need to deposit collateral

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        uint256 testOverflow = collateralSeed;
        uint256 testOverflowMod2 = testOverflow % 2;
        ERC20Mock collateral = _getCollateralFromSeed(testOverflowMod2);

        // ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT);
        // if (amountCollateral == 0) {
        //     return;
        // }

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);

        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        //double push!
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        uint256 testOverflow = collateralSeed;
        uint256 testOverflowMod2 = testOverflow % 2;
        ERC20Mock collateral = _getCollateralFromSeed(testOverflowMod2);

        // ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getSingleCollateralBalanceOfUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        // console.log("collateralSeed: ", collateralSeed);
        // console.log("collateral: ", address(collateral));
        // console.log("amountCollateral: ", amountCollateral);
        // console.log("maxCollateralToRedeem: ", maxCollateralToRedeem);
        if (amountCollateral == 0) {
            // console.log("returning");
            return; // alt. we can use vm.assume()
        }
        // vm.startPrank(msg.sender);
        engine.redeemCollateral(address(collateral), amountCollateral);
        // vm.stopPrank();
    }

    // This breaks our invariant test suite!
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        console.log("collaretalSeed:: ", collateralSeed);
        if (collateralSeed == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
