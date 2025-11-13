## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
# CAPSTONE-NFT

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Deployment & frontend notes for Cohort3NFT

This repo includes `src/Cohort3NFT.sol` and a Forge script at `script/Cohort3NFT.s.sol` (contract `DeployCohort3NFT`) to deploy the contract.

Quick steps to deploy with Foundry:

```bash
# build
forge build

# Run the deploy script and broadcast (set PRIVATE_KEY and RPC URL in env)
export PRIVATE_KEY=0xYOUR_PRIVATE_KEY
forge script script/Cohort3NFT.s.sol:DeployCohort3NFT --rpc-url https://rpc.your-network.example --broadcast
```

Notes:
- The deploy script logs the deployed address and contract parameters.
- Use a testnet RPC (Goerli/Sepolia or other testnets supported by your provider) and a funded account for deployment.

### Metadata hosting and reveal

This contract stores SVG metadata on-chain as data URIs (base64 encoded). That means:

- No external image hosting is required; the `tokenURI` returns a data:application/json;base64,... payload containing the SVG in the `image` field.
- Owner can set `hiddenSVG` and `revealedSVG` with `setHiddenSVG` / `setRevealedSVG` and toggle the public `reveal()`.

Pros:
- Self-contained metadata and images (no reliance on IPFS or third-party hosting).
- Simple to test and verify in the frontend.

Cons and considerations:
- On-chain metadata increases deployment cost and may be expensive for large images.
- If you prefer off-chain hosting (IPFS/Arweave), change `tokenURI` to return an HTTP/IPFS URL for each token and host JSON metadata there.

### Minimal frontend (web/)

A minimal web frontend is included at `web/index.html` and `web/app.js`. It lets users:

- Connect with MetaMask
- Read `mintPrice`, `maxPerWallet`, `totalMinted`, and `revealed` from the contract
- Mint by specifying a quantity and sending ETH
- List tokens owned by the connected wallet and view their `tokenURI` payloads

Usage:

1. Serve the `web/` folder (for example using a simple static server):

```bash
# from project root
python3 -m http.server --directory web 8000
# or: npx serve web
```

2. Open http://localhost:8000 in your browser, connect MetaMask, and enter the deployed contract address when prompted (or set it in `web/app.js`).

3. Use the UI to mint and view metadata. If `revealed` is false you'll see the hidden SVG image in the returned metadata; after `reveal()` the `image` field will point to the revealed SVG.

### Next steps

- Add IPFS-based metadata hosting and update `tokenURI` to return token-specific JSON URL if you need scalable off-chain hosting.
- Build a nicer UI with previews (render the embedded SVG data URI) and handle errors/gas estimations.

## Project overview & repository contents

- `src/Cohort3NFT.sol` - ERC-721 contract with public minting, on-chain SVG metadata, enumeration helpers, and reveal mechanism.
- `script/Cohort3NFT.s.sol` - Forge script to deploy the contract.
- `test/` - Foundry test suites covering minting, limits, metadata, withdraw, and owner-only functions.
- `web/` - Minimal frontend to mint and preview on-chain SVG metadata.

## Team

- Team member 1: (Oyinlayefa Yinkore)
- Team member 2: (Uwakwe Ugochukwu)
- Team member 3: (Ekpe Favour)

## Testnet deployment addresses

Add your deployed contract address(es) here after deployment (Sepolia / Anvil):

- Sepolia: (paste address)
- Local Anvil: (paste address)

## Verify on block explorers

After deploying to a public testnet (Sepolia or similar), verify the contract using Etherscan's contract verification UI or `forge verify-contract` to improve transparency.

Example (foundry):

```bash
forge verify-contract --chain sepolia <DEPLOYED_ADDRESS> script/Cohort3NFT.s.sol:DeployCohort3NFT $ETHERSCAN_API_KEY
```

Replace `$ETHERSCAN_API_KEY` with your API key.

## Demo / Delivery

Provide any of the following to demonstrate the app:

- A short video recording (screen capture) showing deployment, connecting the frontend, minting, and viewing metadata & preview images.
- Screenshots of the running frontend and successful transactions.
- A small PDF explaining architecture, security considerations, and where the deployed addresses are.

## Security & best practices

- Follow checks-effects-interactions: in `mint` we update state before external transfers (refunds are executed after state updates) and `withdraw` uses a single call to owner.
- Validate inputs and guard conditions (e.g., non-zero maxSupply checked in constructor).
- Consider using OpenZeppelin's Enumerable extension for large collections if you need gas-efficient enumeration.
- For production/mainnet: consider off-chain metadata (IPFS) for large images and audits for security-critical code.

