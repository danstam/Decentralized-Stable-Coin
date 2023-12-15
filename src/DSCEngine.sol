// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3interface.sol";

/**
 * @title Decentralized Stable Coin Engine
 * @author Daniel Stamler
 *
 * This system is engineered to be streamlined and efficient, ensuring that tokens consistently maintain a 1 token to $1 ratio. The stablecoin possesses the following characteristics:
 *
 * - Exogenously Collateralized (backed by WETH and WBTC)
 * - Anchored to the Dollar
 * - Stability Maintained Algorithmically
 *
 * The system can be compared to DAI, but with the distinctions of having no governance, no fees, and being backed solely by WETH and WBTC.
 *
 * The DSC system is designed to maintain an` "overcollateralized" state at all times. Under no circumstances should the total value of the collateral fall below the dollar-backed value of all DSC.
 *
 * @notice This contract serves as the nucleus of the Decentralized Stablecoin system. It manages all operations related to minting and redeeming DSC, in addition to handling the deposit and withdrawal of collateral.
 * @notice The foundation of this contract is based on the MakerDAO DSS system.
 */

//   /$$$$$$$   /$$$$$$   /$$$$$$        /$$$$$$$$                     /$$
//  | $$__  $$ /$$__  $$ /$$__  $$      | $$_____/                    |__/
//  | $$  \ $$| $$  \__/| $$  \__/      | $$       /$$$$$$$   /$$$$$$  /$$ /$$$$$$$   /$$$$$$
//  | $$  | $$|  $$$$$$ | $$            | $$$$$   | $$__  $$ /$$__  $$| $$| $$__  $$ /$$__  $$
//  | $$  | $$ \____  $$| $$            | $$__/   | $$  \ $$| $$  \ $$| $$| $$  \ $$| $$$$$$$$
//  | $$  | $$ /$$  \ $$| $$    $$      | $$      | $$  | $$| $$  | $$| $$| $$  | $$| $$_____/
//  | $$$$$$$/|  $$$$$$/|  $$$$$$/      | $$$$$$$$| $$  | $$|  $$$$$$$| $$| $$  | $$|  $$$$$$$
//  |_______/  \______/  \______/       |________/|__/  |__/ \____  $$|__/|__/  |__/ \_______/
//                                                         /$$  \ $$
//                                                        |  $$$$$$/
//                                                         \_____/

contract DSCEngine is ReentrancyGuard {
    // ┏━━━━━━━━━━━┓
    // ┃  Errors   ┃
    // ┗━━━━━━━━━━━┛
    error DSCEngine__AmountMustBeGreaterThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorNotBelowMinimum();
    error DSCEngine__InsufficientCollateralDeposited();
    error DSCEngine__HealthFactorNotImproved();
    // ┏━━━━━━━━━━━━━━━━━━━━━┓
    // ┃  State Variables    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━┛
    // Constants

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 200; // Threshold for overcollateralization, set at 200%
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus

    DecentralizedStableCoin private immutable i_dsc; // Instance of the Decentralized Stable Coin

    // Mapping to keep track of the amount of collateral deposited by each user for each token
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    // Mapping to keep track of the price feed for each token
    mapping(address token => address priceFeed) private s_priceFeeds;

    // Mapping to keep track of the amount of DSC minted by each user
    mapping(address user => uint256 amountDscMinted) private s_DscMinted;

    // Array to store the addresses of all collateral tokens
    address[] private s_collateralTokens;

    // ┏━━━━━━━━━━━┓
    // ┃  Events   ┃
    // ┗━━━━━━━━━━━┛
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    // ┏━━━━━━━━━━━┓
    // ┃ Modifiers ┃
    // ┗━━━━━━━━━━━┛
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__AmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    // ┏━━━━━━━━━━━┓
    // ┃ Functions ┃
    // ┗━━━━━━━━━━━┛

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddreses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddreses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddreses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━┓
    // ┃ External Functions  ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━┛
    /**
     * @notice This function allows a user to deposit collateral and mint DSC in a single transaction.
     * @dev This function first calls the `depositCollateral` function to deposit the collateral, then calls the `mintDsc` function to mint the DSC.
     * @param tokenCollateralAddress The contract address of the token being used as collateral. This must be an ERC20 token that is allowed by the contract.
     * @param amountCollateral The quantity of the token to deposit as collateral. This must be greater than 0.
     * @param amountDscToMint The amount of DSC the user wants to mint. This must be greater than 0 and the resulting minting must not break the health factor of the user.
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @param tokenCollateralAddress The contract address of the token being used as collateral.
     * @param amountCollateral The quantity of the token to deposit as collateral.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @notice This function allows a user to redeem their collateral and burn DSC in a single transaction
     * making it more efficient and convenient for the user.
     * @param tokenCollateralAddress The contract address of the token that was used as collateral.
     * @param amountCollateral The quantity of the token to be redeemed as collateral.
     * @param amountDscToBurn The amount of DSC the user wants to burn.
     */

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        public
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeem collateral already checks health factor
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);

        _revertIfHealthFactorIsBroken(msg.sender); //i dont think this line will ever hit...
    }
    /**
     * @notice This function is designed to liquidate a user's position when their health factor falls below the threshold.
     * @dev The health factor is a measure of the risk associated with a user's position. It is calculated as the ratio of the total value of the user's collateral (in USD) to the total amount of DSC minted by the user. If the health factor falls below the MIN_HEALTH_FACTOR, the user's position is considered undercollateralized and is eligible for liquidation.
     * In the event of liquidation, the contract incentivizes liquidators to cover the user's debt. The liquidator is compensated with a portion of the user's collateral, ensuring that the system remains overcollateralized at all times. This creates a win-win situation where the liquidator is rewarded for their service, and the system maintains its stability.
     * @param collateral The ERC20 contract address of the token being used as collateral for the liquidation.
     * @param user The address of the user whose position is being liquidated.
     * @param debtToCover The amount of debt (DSC) to be covered by the liquidation.
     * @notice Partial liquidation of a user's position is possible.
     * @notice A liquidation bonus is provided to incentivize the liquidators.
     * @notice The function assumes that the protocol will be approximately 200% overcollateralized for it to operate effectively. If the protocol were 100% or less collateralized, it would not be able to incentivize the liquidators, leading to potential issues.
     */

    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // Calculate the user's health factor at the start of the operation
        uint256 startingHealthFactor = _calculateAndReturnHealthFactor(user);

        if (startingHealthFactor < MIN_HEALTH_FACTOR) {
            uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
            uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / 100;
            uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
            _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
            _burnDsc(debtToCover, user, msg.sender);
            uint256 endingUserHealthFactor = _calculateAndReturnHealthFactor(user);
            if (endingUserHealthFactor <= startingHealthFactor) {
                revert DSCEngine__HealthFactorNotImproved();
            }
        } else {
            revert DSCEngine__HealthFactorNotBelowMinimum();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Private & Internal View Functions  ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /**
     * @dev This is a low-level internal function. It should only be called by other functions that have already verified the health factors to prevent any potential risk of liquidation.
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DscMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = _calculateAccountCollateralValue(user);
    }

    /**
     * @dev This function calculates the health factor for a user.
     * The health factor is a risk metric that indicates the likelihood of a user's position being liquidated.
     * It is calculated as the ratio of the total value of the user's collateral (in USD) to the total amount of DSC minted by the user.
     * The value of the collateral is adjusted by the LIQUIDATION_THRESHOLD, which is a percentage value representing the required overcollateralization.
     * If the health factor falls below the LIQUIDATION_THRESHOLD (i.e., the collateral is not sufficiently overcollateralized), liquidation is triggered.
     * If the user has not minted any DSC, the health factor is defined to be the maximum possible uint256 value.
     * @param user The address of the user.
     * @return The health factor of the user.
     */
    function _calculateAndReturnHealthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _calculateAndReturnHealthFactor(user);
        // Revert the transaction if the health factor is below the LIQUIDATION_THRESHOLD
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor();
        }
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃   Public & External View Functions   ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    function _calculateAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        totalCollateralValueInUsd = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256 priceInUsd) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // The scaling factor is used to convert the raw price from Chainlink to a more manageable number. Chainlink uses a scaling factor of 1e18.
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getHealthFactor() external view returns (uint256) {
        return _calculateAndReturnHealthFactor(address(msg.sender));
    }

    function getCollateralDeposited(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collVallueInUsd)
    {
        (totalDscMinted, collVallueInUsd) = _getAccountInformation(user);
    }
}
