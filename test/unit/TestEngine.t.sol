// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";

contract TestDSCEngine is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    MockV3Aggregator mockPriceFeed;

    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        // Impersonate USER account and approve dsce to spend USER's tokens

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
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses, address(dsc));
    }

    function testSetUpIsSuccessful() public view {
        assert(address(deployer) != address(0));
    }

    //////////////////
    // Price Tests //
    ////////////////

    function testGetUsdValue() public {
        uint256 amount = 1 ether;
        // Set the price in the price feed to a known value. The details will depend on your testing environment.
        uint256 expectedUsdValue = 2000e8 * 1e10; // Convert to wei
        uint256 actualUsdValue = dsce.getUsdValue(weth, amount);
        assertEq(expectedUsdValue, actualUsdValue);
    }

    function testGetTokenAmountFromUsd() public {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether; // This is in wei
        uint256 usdAmount = 100 ether; // This is in USD, in wei

        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualWeth, expectedWeth);
    }

    ///////////////////////////////
    // Deposit Collateral Tests //
    /////////////////////////////
    // This modifier is used to impersonate a user and approve the DSCEngine contract to spend the user's tokens.
    modifier approveAndDepositColateral() {
        uint256 amountDscToMint = 1 ether; // Declare the variable and set a value
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.mintDsc(amountDscToMint);

        _;
    }

    function testRevertIfCollateralZero() public approveAndDepositColateral {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dsce.depositCollateral(weth, 0);
    }

    function testRevertWithUnapprovedCollateral() public approveAndDepositColateral {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositCollateral(address(0), AMOUNT_COLLATERAL);
    }

    function testCanDepositCollateralAndGetAccountInfo() public approveAndDepositColateral {
        // Deposit collateral
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Get account information
        (uint256 totalDscMinted, uint256 collValueInUsd) = dsce.getAccountInformation(USER);

        // Assert that the total DSC minted is greater than zero
        assertTrue(totalDscMinted > 0);

        // Assert that the collateral value in USD is equal to the amount of collateral deposited
        assertEq(collValueInUsd, AMOUNT_COLLATERAL);
    }
}
