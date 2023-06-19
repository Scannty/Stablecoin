//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Stablecoin} from "./Stablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract StablecoinEngine {
    error StablecoinEngine__TokensDontMatchPriceFeeds();
    error Stablecoin__MustBeMoreThanZero();
    error Stablecoin__TokenNotAllowed();
    error Stablecoin__TransferFailed();
    error Stablecoin__HealthFactorToLow(uint256 healthFactor);
    error Stablecoin__MintFailed();

    event CollateralDeposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amountDeposited
    );

    address[] public collateralTokens;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenAddress => uint256 collateralDeposited))
        private collateralLedger;
    mapping(address user => uint256 mintedStablecoin) private stablecoinLedger;
    Stablecoin private immutable i_stablecoin;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert Stablecoin__MustBeMoreThanZero();
        }
        _;
    }

    modifier isTokenAllowed(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert Stablecoin__TokenNotAllowed();
        }
        _;
    }

    modifier healthFactorCheck() {
        uint256 healthFactor = _getHealthFactor(msg.sender);
        if (healthFactor <= MIN_HEALTH_FACTOR) {
            revert Stablecoin__HealthFactorToLow(healthFactor);
        }
        _;
    }

    constructor(
        address[] memory collateralTokenAddresses,
        address[] memory priceFeedAddresses,
        address stablecoinAddress
    ) {
        if (collateralTokenAddresses.length != priceFeedAddresses.length) {
            revert StablecoinEngine__TokensDontMatchPriceFeeds();
        }

        for (uint i = 0; i < collateralTokenAddresses.length; i++) {
            s_priceFeeds[collateralTokenAddresses[i]] = priceFeedAddresses[i];
            collateralTokens.push(collateralTokenAddresses[i]);
        }

        i_stablecoin = Stablecoin(stablecoinAddress);
    }

    function depositCollateral(
        address tokenAddress,
        uint256 amount
    ) internal moreThanZero(amount) isTokenAllowed(tokenAddress) {
        collateralLedger[msg.sender][tokenAddress] = amount;
        emit CollateralDeposited(msg.sender, tokenAddress, amount);
        bool success = IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) {
            revert Stablecoin__TransferFailed();
        }
    }

    function mintStablecoin(
        uint256 amount
    ) internal moreThanZero(amount) healthFactorCheck {
        stablecoinLedger[msg.sender] += amount;
        bool minted = i_stablecoin.mint(msg.sender, amount);
        if (!minted) {
            revert Stablecoin__MintFailed();
        }
    }

    function _getHealthFactor(address user) private view returns (uint256) {
        uint256 totalMintedStablecoin = stablecoinLedger[user];
        uint256 totalCollateralValueInUsd = _getCollateralValueInUsd(user);
        // 200% overcollaterized => health factor = 1
        // health factor = totalCollateralValueInUsd / 2 * totalMintedStablecoin
        // But since there is no decimal precision in solidity, we must use 18 decimal system
        return (totalCollateralValueInUsd * 10e18) / totalMintedStablecoin;
    }

    function _getCollateralValueInUsd(
        address user
    ) private view returns (uint256) {
        uint256 totalCollateralValueInUsd;
        for (uint i = 0; i < collateralTokens.length; i++) {
            address tokenAddress = collateralTokens[i];
            uint256 tokenAmount = collateralLedger[user][tokenAddress];
            totalCollateralValueInUsd += _getUsdValue(
                tokenAddress,
                tokenAmount
            );
        }
        return totalCollateralValueInUsd;
    }

    function _getUsdValue(
        address token,
        uint256 amount
    ) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        uint8 decimals = priceFeed.decimals();
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (amount * uint256(price)) / decimals;
    }
}
