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

0. (optional) Deploy and wire `oft` on `destinationToken` following [the instruction](#test-mainnetcontrollertransfertokenlayerzero)

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
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url fuji -vv
    ```

5. Get enough gas tokens using a faucet

6. (optional) Required for CCTP testing: Get enough testnet USDC from [Circle USDC faucet](https://faucet.circle.com/). This is required by the LitePSM mock contract which expects USDC to be present on the deployer wallet.

7. Deploy, configure and verify contracts
    ```sh
    forge script script/SetUpAll.s.sol:SetUpAll --fork-url fuji -vv --broadcast --verify --slow
    ```

8. (optional) Commit generated `broadcast/SetUpAll.s.sol/11155111/run-latest.json` and `script/output/11155111/output-latest.json` to record deployed contract addresses 


## Environment Variables

| Variable              | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `PRIVATE_KEY`         | Deployer's private key (used as admin for all contracts)                    |
| `FOUNDRY_ROOT_CHAINID`| Chain ID for deployment                                                     |
| `SEPOLIA_RPC_URL`     | RPC URL for Ethereum Sepolia                                                |
| `FUJI_RPC_URL`        | RPC URL for Avalanche Fuji                                                  |
| `ETHERSCAN_API_KEY`   | Etherscan api key to verify deployed contracts                              |


## Test `MainnetController.transferTokenLayerZero`

To test LayerZero-related functionality, follow these steps in order:
**Note:** These instructions are specific to `Solana`.

1. Convert the Solana recipient address from base58 to hex using [this decoder](https://appdevtools.com/base58-encoder-decoder):
    1. Select the `Decode` tab.
    2. Set `Treat Output As` to `HEX`.
2. In the `sky-star-test-setup` project, add the converted recipient address under `layerZeroRecipient` in `script/input/{chainId}/input.json`.
3. In the `sky-star-test-setup` project, deploy OTFs (`UsdsMock`, `sUsdsMock`) on the EVM chain by following the remaining steps in the [`Quick Start`](#quick-start) section.
4. Clone the `lz-oapp` example locally:
    - https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana#scaffold-this-example
5. Complete the [`Setup`](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana#setup) and [`Build`](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana#build) steps in the README from [this repo](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana).
6. In the `lz-oapp` project, add a `.chainId` file to `deployments/sepolia-testnet/`:
    ```sh
    mkdir -p deployments/sepolia-testnet && echo "11155111" > deployments/sepolia-testnet/.chainId
    ```
7. In the `lz-oapp` project, add EVM `PRIVATE_KEY` to `.env`.
8. Follow the instructions to [`Deploy the Solana OFT Program`](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana#deploy-the-solana-oft-program).
    - You can use an already deployed OFT program: `ENP58syDWoSp6SS1CvndMgSB3daB9UpNYWmob7rzUh97`. (Note: The `Upgrade Authority` belongs to the program deployer.)
9. Follow the steps to [`Create the Solana OFT`](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana#create-the-solana-oft).
10. Update the `sepolia OFT peer` information:
    1. In the `lz-oapp` project, copy `out/UsdsMock.sol/UsdsMock.json` from the `sky-star-test-setup` project to `deployments/sepolia-testnet/UsdsMock.json` in the `lz-oapp` project, and add the address in the JSON as shown below:
        ```json
        {
            "address": "DEPLOYED_USDS_MOCK_ADDRESS"
            /** Other deployment info like abi ...*/
        }
        ```
    2. In the `lz-oapp` project, update `sepoliaContract.contractName` in `layerzero.config.ts`:
        ```ts
        const sepoliaContract: OmniPointHardhat = {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            contractName: 'UsdsMock',
        }
        ```
11. In the `lz-oapp` project, wire the deployed OTF (`UsdsMock`) on EVM to the `oft` on Solana (deployed in Step 9) by following the [`Enable Messaging`](https://github.com/LayerZero-Labs/devtools/tree/main/examples/oft-solana#enable-messaging) instructions.
12. Test `MainnetController.transferTokenLayerZero`:
    1. Call `MainnetController.mintUsds` (e.g., `MainnetController.mintUsds(1000000000000000000)` to mint 1 USDS).
    2. Call `MainnetController.transferTokenLayerZero` (e.g., `MainnetController.transferTokenLayerZero{value: 0.0005}(evmUsdsAddress, 1000000000000000000, 40168)` to transfer 1 USDS).
        - **Note:** Native tokens must be sent to cover the LayerZero fee. The values above are examples with a safe buffer.
13. The transaction can be found at: `https://testnet.layerzeroscan.com/address/{usdsTokenAddress}`.
    - The token should be transferred to the recipient wallet on Solana once the transaction status is updated to `delivered`.
14. Set up `sUsdsMock` in the same way (repeat steps 9–13).


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
| `layerZeroRecipient`         | Solana LayerZero transfer recipient in HEX, decode can be done using tools like [this](https://appdevtools.com/base58-encoder-decoder). _It should correspond to the destination endpoint_ |
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
