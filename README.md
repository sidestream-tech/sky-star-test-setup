# Sky Star Test Setup

Easily deploy the Sky allocation system and Spark ALM controller to any EVM-compatible chain, including all required mock contracts. This repository is designed to help Sky Stars test and validate contracts quickly. 

## Included Deployments

- [`dss-allocator`](https://github.com/sky-ecosystem/dss-allocator)
- [`spark-alm-controller`](https://github.com/sparkdotfi/spark-alm-controller)
- Mock contracts: `vat`, `usdsJoin`, `usds`, `sUsds`, `jug`, `usdsDai`, `dai`, `daiJoin`, `psmLite`

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) must be installed.


## Quick Start

To deploy and configure contracts to the Avalanche Fuji public testnet:

1. Set environment variables
    - Copy the example environment via `cp .env.dev .env`
    - Edit `.env` to update the variables as described in the "Environment Variables" section below
    
2. Set the desired ALM `relayer` address inside `script/input/{CHAIN_ID}/input.json`

3. Set the desired CCTP `recipient` address inside `script/input/{CHAIN_ID}/input.json`

4. Dry-run a transaction to determine the amount of required gas
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url fuji -vv
    ```

5. Get enough gas tokens using a faucet

6. (optional) Required for CCTP testing: Get enough testnet USDC from [Circle USDC faucet](https://faucet.circle.com/). This is required by the LitePSM mock contract which expects USDC to be present on the deployer wallet.

7. Deploy, configure and verify contracts
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url fuji -vv --broadcast --verify --slow
    ```

8. (optional) Commit generated output folder to record deployed contract addresses 


## Environment Variables

| Variable              | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `PRIVATE_KEY`         | Deployer's private key (used as admin for all contracts)                    |
| `FOUNDRY_ROOT_CHAINID`| Chain ID for deployment                                                     |
| `FUJI_RPC_URL`        | RPC URL for Avalanche Fuji                                                  |



## Deploying to Other Chains

1. Update `FOUNDRY_ROOT_CHAINID` in `.env` to use [chain id of the network](https://chainlist.org/) you're trying to deploy to. For example, to deploy to Sepolia that would be `11155111`
2. Add new `*_RPC_URL` to the `.env` pointing to the PRC endpoint for the chain specified above, e.g:
    ```toml
    SEPOLIA_RPC_URL = "https://..."
    ```
3. Create `script/input/{CHAIN_ID}/input.json` file with relevant content
4. Add the new verification endpoint to the [`foundry.toml`](./foundry.toml), e.g:
     ```toml
     sepolia = { key = "${ETHERSCAN_API_KEY}", chain = 11155111 }
     ```
5. Add the new `rpc_endpoints` in [`foundry.toml`](./foundry.toml), e.g.:
     ```toml
     sepolia = "${SEPOLIA_RPC_URL}"
     ```
6. Follow the "Quick start" section, while specifying the chain name under `--fork-url` (e.g. `sepolia`) when running the script, e.g.:
     ```sh
     forge script script/SetUpAll.s.sol:SetUpAll --fork-url ${CHAIN} -vv
     `````

### `input.json` Configuration Variables

| Variable                | Description                                                                                                                        |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| `ilk`                   | Collateral type identifier (e.g., `"ALLOCATOR_STAR_A"`)                                                                           |
| `usdcUnitSize`          | Amount of USDC (in smallest units, e.g., wei) to use for testing (default: 10)                                                    |
| `cctpDestinationDomain` | CCTP destination domain ID for cross-chain messaging ([see supported domains](https://developers.circle.com/cctp/supported-domains))|
| `usdc`                  | Address of the USDC token contract on the target chain ([see contract addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses)) |
| `cctpTokenMessenger`    | Address of the CCTP Token Messenger contract on the target chain ([see EVM contracts](https://developers.circle.com/cctp/evm-smart-contracts))         |
| `relayer`               | Address of the relayer to be used by the ALM controller                                                                           |
| `cctpRecipient`         | Address of the CCTP transfer recipient (should correspond to the destination domain)                                               |




### Running Tests

- Run all tests:
    ```sh
    forge test
    ```

- Run a specific test by name:
    ```sh
    forge test --match-test ${YourTestName} -vvv
    ```
