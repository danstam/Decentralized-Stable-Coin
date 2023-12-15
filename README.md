# Decentralized Stable Coin (DSC) System

In the dynamic landscape of cryptocurrencies, the need for stability amidst volatility has given rise to stablecoins. These are digital currencies pegged to stable assets, typically the US dollar, providing a safe harbor during market turbulence. However, most existing stablecoins are backed by centralized entities holding physical dollars, which, while providing a measure of safety, contradicts the decentralization ethos of blockchain technology and could potentially lead to future complications.

The Decentralized Stable Coin (DSC) system offers an innovative solution to this paradox. It leverages the power of blockchain technology to create a digital token, the DSC, which is pegged to the US dollar but operates independently of any central authority. Unlike traditional stablecoins, the DSC is backed not by physical dollars but by collateral within the system, ensuring its stability.

The DSC system employs a health factor algorithm to maintain the protocol's solvency. This algorithm calculates the risk associated with each user's position and triggers a liquidation if the health factor falls below a certain threshold. This mechanism ensures the system remains overcollateralized, providing an additional layer of security.



## Architecture

The DSC system is built on the Ethereum blockchain and consists of two primary components: the DSC token and the DSCEngine contract.

### DSC Token

The DSC token is a digital currency that represents the stablecoin in our system. It's designed to maintain a 1:1 ratio with the US dollar. The token contract includes functions for creating (minting) and destroying (burning) tokens, which are only accessible by the owner, typically set to be the DSCEngine contract.

### DSCEngine Contract

The DSCEngine contract is the core of the DSC system. It manages the operations related to minting and redeeming DSC, as well as handling the deposit and withdrawal of collateral. The collateral is overcollateralized, meaning the value of collateral is always more than the value of minted DSC. This overcollateralization provides an additional layer of security, ensuring the stability of the DSC token.

## Algorithm

The DSCEngine contract uses an algorithm to calculate a health factor for each user's position. This health factor is a measure of the risk associated with a user's position. If the health factor falls below a certain threshold, the contract triggers a liquidation of the user's position to ensure the system remains overcollateralized.

## Integration with Chainlink

The system integrates with Chainlink price feeds to get real-time price information of the collateral tokens. This ensures accurate calculation of the health factor and the collateralization ratio, contributing to the overall stability of the DSC.

