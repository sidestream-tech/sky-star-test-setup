# Sky Star Test Setup

Easily deploy the Sky allocation system and Spark ALM controller to any EVM-compatible chain, including all required mock contracts. This repository is designed to help Sky Stars test and validate contracts quickly. 

## Included Deployments

- [`dss-allocator`](https://github.com/sky-ecosystem/dss-allocator)
- [`spark-alm-controller`](https://github.com/sparkdotfi/spark-alm-controller)
- Mock contracts: `vat`, `usdsJoin`, `usds (layerZero oft)`, `sUsds`, `jug`, `usdsDai`, `dai`, `daiJoin`, `psmLite`

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) must be installed.


## Quick Start

To deploy and configure contracts to the Avalanche Fuji public testnet:

1. Set environment variables
    - Copy the example environment via `cp .env.dev .env`
    - Edit `.env` to update the variables as described in the "Environment Variables" section below
    
2. Set correct variables inside `script/input/{CHAIN_ID}/input.json` based on the "Configuration Variables" section below

3. Create correct output folders in `script` (`script/output/{CHAIN_ID}/dry-run/`) to log created contracts address correctly
    ```sh
    mkdir -p script/output/{CHAIN_ID}/dry-run/
    ```

4. Dry-run a transaction to determine the amount of required gas
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url sepolia -vv
    ```

5. Get enough gas tokens using a faucet

6. (optional) Required for CCTP testing: Get enough testnet USDC from [Circle USDC faucet](https://faucet.circle.com/). This is required by the LitePSM mock contract which expects USDC to be present on the deployer wallet.

7. Deploy, configure and verify contracts
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url sepolia -vv --broadcast --verify --slow
    ```

8. (optional) Commit generated `broadcast/SetUpAll.s.sol/11155111/run-latest.json` and `script/output/11155111/output-latest.json` to record deployed contract addresses 

9. Deploy and wire `oft` on `destinationToken` following [the instruction](#test-mainnetcontrollertransfertokenlayerzero)

## Environment Variables

| Variable              | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `PRIVATE_KEY`         | Deployer's private key (used as admin for all contracts)                    |
| `FOUNDRY_ROOT_CHAINID`| Chain ID for deployment                                                     |
| `SEPOLIA_RPC_URL`        | RPC URL for Ethereum Sepolia                                                  |
| `ETHERSCAN_API_KEY`        | Etherscan api key to verify deployed contracts                                                  |

## Test `MainnetController.transferTokenLayerZero`
To use `MainnetController.transferTokenLayerZero`, [`oft`](https://docs.layerzero.network/v2/developers/evm/oft/quickstart) should be deployed on the destination domain and then [wired](https://docs.layerzero.network/v2/developers/evm/oft/quickstart#deployment-and-wiring) to usds that was deployed from this script. 

It can be done in the following order
1. Deploy `oft` on the destination domain
2. (For Solana) Create token account of layerZero transfer recipient  
3. Add recipient address to `layerZeroRecipient` in  `script/input/{chainId}/input.json`  
4. Execute test setup script following [`Quick Start`](#quick-start)
5. Wire deployed `usds` to `oft` on destination domain

### How to deploy `oft` on Solana
- Deploy program: https://docs.layerzero.network/v2/developers/solana/oft/program
- Create OFT: https://docs.layerzero.network/v2/developers/solana/oft/account
- Example repo: https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana

## Deploying to Other Chains

1. Update `FOUNDRY_ROOT_CHAINID` in `.env` to use [chain id of the network](https://chainlist.org/) you're trying to deploy to. For example, to deploy to Sepolia that would be `11155111`
2. Add new `*_RPC_URL` to the `.env` pointing to the PRC endpoint for the chain specified above, e.g:
    ```toml
    SEPOLIA_RPC_URL = "https://..."
    ```
3. Create `script/input/{CHAIN_ID}/input.json` file with relevant content and create `script/output/dry-run` folder
    ```sh
    mkdir -p script/output/{CHAIN_ID}/dry-run/
    ```
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
| `cctpDestinationDomain` | CCTP destination domain ID for cross-chain messaging ([see supported domains](https://developers.circle.com/cctp/solana-programs#devnet-program-addresses))|
| `cctpTokenMessenger`    | Address of the CCTP Token Messenger contract on the target chain ([see EVM contracts](https://developers.circle.com/cctp/evm-smart-contracts#tokenmessenger-testnet))         |
| `cctpRecipient`         | USDC token account of the CCTP transfer recipient in HEX, decode can be done using tools like [this](https://appdevtools.com/base58-encoder-decoder). _It should correspond to the destination domain_ |
| `usdc`                  | Address of the USDC token contract on the target chain ([see contract addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses)) |
| `layerZeroEndpoint` | Address of the LayerZero endpoint on the target chain ([see supported domains](https://docs.layerzero.network/v2/deployments/deployed-contracts?chains=sepolia))|
| `layerZeroDestinationEndpointId`    | LayerZero transaction Destination endpoint ([see EVM contracts](https://docs.layerzero.network/v2/deployments/deployed-contracts?chains=solana-testnet))         |
| `layerZeroRecipient`         | Solana oft token account of the LayerZero transfer recipient in HEX, decode can be done using tools like [this](https://appdevtools.com/base58-encoder-decoder). _It should correspond to the destination endpoint_ |
| `relayer`               | Address of the relayer to be used by the ALM controller                                                                           |


### Running Tests

- Run all tests:
    ```sh
    forge test
    ```

- Run a specific test by name:
    ```sh
    forge test --match-test ${YourTestName} -vvv
    ```
