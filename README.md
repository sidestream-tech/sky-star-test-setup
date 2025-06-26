# Sky Star Test Setup

Easily deploy the Sky allocation system and Spark ALM controller to any EVM-compatible chain, including all required mock contracts. This repository is designed to help Sky Stars test and validate contracts quickly. 

## Included Deployments

- [`dss-allocator`](https://github.com/sky-ecosystem/dss-allocator)
- [`spark-alm-controller`](https://github.com/sparkdotfi/spark-alm-controller)
- Mock contracts: `vat`, `usdsJoin`, `usds`, `sUsds`, `jug`, `usdsDai`, `dai`, `psmLite`

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) must be installed.


## Quick Start

### 1. Prepare Environment

- Copy the example environment file:
    ```sh
    cp .env.dev .env
    ```
- Edit `.env` and update the variables as described below.


### 2. Simulate Transaction

- Run a dry run:
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url fuji -vv
    ```

### 3. Execute transaction on Network

- Broadcast the deployment and setup:
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url fuji -vv --broadcast --verify --slow 
    ```

### 4. Document Results

- Commit the generated output folder to record deployed contract addresses.


## Environment Variables

| Variable              | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `PRIVATE_KEY`         | Deployer's private key (used as admin for all contracts)                    |
| `FOUNDRY_ROOT_CHAINID`| Chain ID for deployment                                                     |
| `FUJI_RPC_URL`        | RPC URL for Avalanche Fuji                                                  |



## Deploying to Other Chains

1. Update `FOUNDRY_ROOT_CHAINID` in `.env`.
2. Add the new RPC URL in `.env`.
3. Create `script/input/{CHAIN_ID}/input.json` file
4. Add the new verification endpoint in [`foundry.toml`](./foundry.toml), e.g:
     ```toml
     mainnet = { key = "${ETHERSCAN_API_KEY}", chain = 1 }
     ```
5. Add the new `rpc_endpoints` in [`foundry.toml`](./foundry.toml), e.g.:
     ```toml
     mainnet = "${MAINNET_RPC_URL}"
     ```
6. Specify the chain when running the script, e.g.:
     ```sh
     forge script script/SetUpAll.s.sol:SetUpAll --fork-url ${CHAIN} -vv --broadcast --verify --slow 
     ```


### Running Tests

- Run all tests:
    ```sh
    forge test
    ```

- Run a specific test by name:
    ```sh
    forge test --match-test ${YourTestName} -vvv
    ```
