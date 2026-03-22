# TON NFT Contract

Reference implementation of NFT (non-fungible token) smart contract for TON.

`nft-collection.fc` - basic implementation of immutable NFT collection with royalty.

`nft-collection-editable.fc` - basic implementation of the NFT collection with royalty in which the author can change the content and royalty params.

It is preferable to use an editable collection in case if you decide to change content hosting in the future (for example, to TON Storage).

`nft-item.fc` - basic implementation of immutable NFT item.

Also repo contains an example of a simple marketplace smart contract `nft-marketplace` and a smart contract for selling NFT for a fixed price for Toncoins `nft-sale`.

In a real product, marketplace and sale smart contracts are likely to be more sophisticated.

# Compile

Compiled contracts are in `build/` folders. Compiled by [func-0.3.0](https://github.com/ton-blockchain/ton/releases/tag/func-0.3.0).

# Simple testnet NFT minting template

This repo can be used to deploy a basic NFT collection and mint simple off-chain NFTs on TON testnet using metadata and images that you host yourself.

The included `scripts/mint-ton-nft.ts` template is intended to:

1. Deploy a new NFT collection.
2. Mint NFT items into that collection.
3. Point each NFT item to a metadata file like `0.json`, `1.json`, `2.json` under a shared metadata base URL.

## Metadata layout expected by this repo

This collection format stores:

- a full collection metadata URL such as `https://example.com/nft/collection.json`
- a shared `COMMON_CONTENT_URL` such as `https://example.com/nft/`
- an item file name such as `0.json`

That means the final NFT item metadata URL becomes:

- `https://example.com/nft/0.json`
- `https://example.com/nft/1.json`
- `https://example.com/nft/2.json`

### Important

`COMMON_CONTENT_URL` **must** end with a trailing slash.

Each item metadata file should contain an image URL, for example:

```json
{
  "name": "Duck #00",
  "description": "A simple TON NFT",
  "image": "https://example.com/images/0.jpg",
  "attributes": [
    {
      "trait_type": "Edition",
      "value": "0"
    }
  ]
}
```

A minimal `collection.json` can look like:

```json
{
  "name": "My TON NFT Collection",
  "description": "A simple TON NFT collection on testnet.",
  "image": "https://example.com/images/logo.jpg"
}
```

## Why the mint script uses raw item file names

The collection metadata URL is stored as a normal off-chain URI.

The per-item NFT content is stored as a raw file suffix like `0.json`, not a full off-chain URI, because the collection contract itself combines `COMMON_CONTENT_URL` with the item content when resolving the final NFT metadata URL.

## Prerequisites

- Node.js installed
- testnet TON in your wallet
- a mnemonic for a testnet wallet that matches the wallet address you plan to use
- hosted metadata and images (HTTPS, IPFS gateway, or another wallet-compatible public URL)
- optional TON Center API key for higher testnet rate limits

## Environment variables used by `scripts/mint-ton-nft.ts`

- `MNEMONIC` - your wallet seed phrase
- `MY_WALLET` - your wallet address
- `TONCENTER_API_KEY` - optional API key for TON Center
- `COLLECTION_METADATA_URL` - full URL to `collection.json`
- `COMMON_CONTENT_URL` - base URL that contains `0.json`, `1.json`, etc. Must end with `/`
- `ITEM_FILE` - item metadata file name such as `0.json`
- `COLLECTION_ADDRESS` - required for mint mode after the collection is deployed
- `MODE` - `deploy` or `mint`
- `ENDPOINT` - optional override for the JSON-RPC endpoint; defaults to TON Center testnet

## Deploy a collection

Example:

```bash
MNEMONIC="word1 word2 ... word24" \
MY_WALLET="YOUR_TESTNET_WALLET_ADDRESS" \
TONCENTER_API_KEY="YOUR_TONCENTER_API_KEY" \
COLLECTION_METADATA_URL="https://example.com/nft/collection.json" \
COMMON_CONTENT_URL="https://example.com/nft/" \
MODE=deploy \
npx ts-node scripts/mint-ton-nft.ts
```

The script prints the deterministic collection address before sending the deploy transaction. After the deploy confirms, it prints the on-chain collection address to reuse for minting.

## Mint item `0`

```bash
MNEMONIC="word1 word2 ... word24" \
MY_WALLET="YOUR_TESTNET_WALLET_ADDRESS" \
TONCENTER_API_KEY="YOUR_TONCENTER_API_KEY" \
COLLECTION_ADDRESS="YOUR_COLLECTION_ADDRESS" \
ITEM_FILE="0.json" \
MODE=mint \
npx ts-node scripts/mint-ton-nft.ts
```

## Mint additional items in the same collection

```bash
MNEMONIC="word1 word2 ... word24" \
MY_WALLET="YOUR_TESTNET_WALLET_ADDRESS" \
TONCENTER_API_KEY="YOUR_TONCENTER_API_KEY" \
COLLECTION_ADDRESS="YOUR_COLLECTION_ADDRESS" \
ITEM_FILE="1.json" \
MODE=mint \
npx ts-node scripts/mint-ton-nft.ts
```

Then repeat with `ITEM_FILE="2.json"`, `ITEM_FILE="3.json"`, and so on.

The script reads `nextItemIndex` from the collection and mints the next available index automatically.

## Recommended verification

After each mint:

1. Check the item address printed by the script.
2. Open the collection and item in a testnet explorer such as Tonviewer.
3. If metadata does not render as expected, inspect what TON Center sees:

```bash
curl --request GET \
  --url "https://testnet.toncenter.com/api/v2/getTokenData?address=NFT_ITEM_ADDRESS" \
  -H "X-API-Key: YOUR_TONCENTER_API_KEY"
```

This helps confirm the resolved item metadata URL and whether the item content was stored correctly.
