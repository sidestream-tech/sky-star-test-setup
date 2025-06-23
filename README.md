# Sky Star Test Deployment

Easily deploy the Sky allocation system and Spark ALM controller to any EVM-compatible chain, including all required mock contracts. This repository is designed to help Sky Stars test and validate contracts quickly. 

## Included Deployments

- [`dss-allocator`](https://github.com/sky-ecosystem/dss-allocator)
- [`spark-alm-controller`](https://github.com/sparkdotfi/spark-alm-controller)
- Mock contracts: `vat`, `usdsJoin`, `usds`

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) must be installed.


## Quick Start

### 1. Prepare Environment

- Copy the example environment file:
    ```sh
    cp .env.dev .env
    ```
- Edit `.env` and update the variables as described below.

### 2. Simulate Deployment

- Run a dry run (default: Avalanche Fuji):
    ```sh
    make deploy-dry-run
    ```

### 3. Deploy to Network

- Broadcast the deployment (default: Avalanche Fuji):
    ```sh
    make deploy-run
    ```

### 4. Document Results

- Commit the generated output folder to record deployed contract addresses.


## Environment Variables

| Variable              | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `PRIVATE_KEY`         | Deployer's private key (used as admin for all contracts)                    |
| `FOUNDRY_ROOT_CHAINID`| Chain ID for deployment                                                     |
| `FUJI_RPC_URL`        | RPC URL for Avalanche Fuji                                                  |
| `ILK_NAME`            | ILK name to use                                                             |


## Deploying to Other Chains

1. Update `FOUNDRY_ROOT_CHAINID` in `.env`.
2. Add the new RPC URL in `.env`.
3. Add the new `rpc_endpoints` in [`foundry.toml`](./foundry.toml), e.g.:
     ```toml
     mainnet = "${MAINNET_RPC_URL}"
     ```
4. Specify the chain when running the script, e.g.:
     ```sh
     make deploy-dry-run chain='mainnet'
     ```
