

# FUZE.ac Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

This repository contains the official Solidity smart contracts for the **FUZE.ac** ecosystem. FUZE.ac is a platform designed to bridge the gap between innovative Web3 projects and strategic investors, powered by the FUZE token. The contracts manage the token, core platform services like staking and OTC deals, and future ecosystem expansions.

All contracts are built using [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) for security and adherence to community standards.

---

## Contracts in this Repository

The smart contract system is modular, with each contract handling a specific piece of the platform's logic.

### 1. Token & Tokenomics
* **`FUZEToken.sol`**: The core ERP-20 token contract for FUZE. It features a fixed supply, pausable transfers for security, and is ownable for administrative control.
* **`VestingContract.sol`**: Manages time-locked token releases for team members, advisors, and private sale investors with customizable cliff and linear vesting schedules. *(Work in Progress)*

### 2. Core Platform Services
* **`StakingAndYield.sol`**: Manages the staking of FUZE tokens and the quarterly distribution of real-yield rewards in stablecoins. *(Planned)*
* **`OTC_Escrow.sol`**: Facilitates secure Over-the-Counter (OTC) deals between the project and investors, acting as a trusted escrow. *(Planned)*

### 3. Future Ecosystem Expansion
* **`PerformanceBonding.sol`**: Allows projects to lock FUZE tokens as a public commitment to meeting performance goals (KPIs). *(Planned)*
* **`FusePlayHub.sol`**: The utility contract for the Play2Earn mini-game ecosystem, managing entry fees, prize distribution, and in-game assets. *(Planned)*
* **`DAOLite.sol`**: The governance contract to facilitate community voting on key platform decisions. *(Planned)*

---

## Getting Started

### Prerequisites

* [Node.js](https://nodejs.org/en/) (v18 or later)
* [Yarn](https://yarnpkg.com/) or [npm](https://www.npmjs.com/)
* [Git](https://git-scm.com/)

### Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/fuse-contracts.git](https://github.com/your-username/fuse-contracts.git)
    cd fuse-contracts
    ```

2.  **Install dependencies:**
    This project uses [Hardhat](https://hardhat.org/) as its development environment.
    ```bash
    npm install
    # or
    yarn install
    ```

3.  **Set up environment variables:**
    Create a `.env` file in the project root by copying the example file:
    ```bash
    cp .env.example .env
    ```
    Populate the `.env` file with the necessary values:
    * `BSC_MAINNET_RPC_URL`: RPC endpoint for Binance Smart Chain Mainnet.
    * `BSC_TESTNET_RPC_URL`: RPC endpoint for Binance Smart Chain Testnet.
    * `PRIVATE_KEY`: The private key of the wallet you'll use for deployment.
    * `BSCSCAN_API_KEY`: Your BscScan API key for contract verification.

    **Note:** Never commit your `.env` file to a public repository.

---

## Development Workflow

### Compile Contracts

To compile all the contracts in the `contracts/` directory, run:
```bash
npx hardhat compile
````

This will generate ABI and bytecode artifacts in the `artifacts/` directory.

### Run Tests

To run the suite of unit tests, ensuring the contracts behave as expected:

```bash
npx hardhat test
```

### Deploy Contracts

Deployment scripts are located in the `scripts/` directory.

To deploy the `FUZEToken` contract to the BSC Testnet, for example:

```bash
npx hardhat run scripts/deploy-fuzetoken.js --network bsc_testnet
```

To deploy to the BSC Mainnet:

```bash
npx hardhat run scripts/deploy-fuzetoken.js --network bsc_mainnet
```

### Verify Contracts on BscScan

After deployment, you can verify your contract on BscScan to make the source code public and transparent.

If your contract has no imports (is already flattened), you can use the built-in Hardhat Etherscan plugin. For a contract like `FUZEToken` that imports from other files, you first need to flatten it.

1.  **Flatten the contract:**
    ```bash
    npx hardhat flatten contracts/FUZEToken.sol > flattened/FUZEToken_flat.sol
    ```
2.  **Verify on BscScan:**
    You can either use the Hardhat plugin with the flattened file or copy-paste the contents of `FUZEToken_flat.sol` directly into the BscScan "Verify & Publish" page, selecting "Solidity (Single file)" as the contract type.

-----

## Security

Security is a top priority. These contracts leverage OpenZeppelin's battle-tested libraries. The `FUZEToken` includes a `Pausable` module, which allows the contract owner to halt all token transfers in case of a critical vulnerability or security incident, protecting token holders.

Formal audits will be conducted before mainnet deployment of core platform contracts.

## Contributing

Contributions are welcome\! If you'd like to contribute, please fork the repository and open a pull request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.

```

Does this look good, or would you like any changes?

When you're ready, we can proceed to the next contract: the **Vesting Contract**.
```
