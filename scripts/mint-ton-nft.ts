import * as fs from 'fs';
import * as path from 'path';
import { Address, Cell, beginCell, toNano } from '@ton/core';
import { mnemonicToPrivateKey } from '@ton/crypto';
import { TonClient, WalletContractV5R1 } from '@ton/ton';
import { NftCollection } from '../wrappers/NftCollection';

const REPO_ROOT = path.resolve(__dirname, '..');
const BUILD_DIR = path.join(REPO_ROOT, 'build');

const ENDPOINT = process.env.ENDPOINT || 'https://testnet.toncenter.com/api/v2/jsonRPC';
const MY_WALLET = process.env.MY_WALLET || '';
const COLLECTION_METADATA_URL = process.env.COLLECTION_METADATA_URL || '';
const COMMON_CONTENT_URL = process.env.COMMON_CONTENT_URL || '';
const ITEM_FILE = process.env.ITEM_FILE || '0.json';
const MODE = process.env.MODE || 'deploy';
const COLLECTION_ADDRESS = process.env.COLLECTION_ADDRESS || '';
const MNEMONIC = process.env.MNEMONIC || '';
const TONCENTER_API_KEY = process.env.TONCENTER_API_KEY;

function requireEnv(name: string, value: string) {
    if (!value.trim()) {
        throw new Error(`Set ${name} env var`);
    }
    return value;
}

function loadCompiledCell(filePath: string): Cell {
    const json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return Cell.fromBoc(Buffer.from(json.hex, 'hex'))[0];
}

function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForSeqno(wallet: { getSeqno(): Promise<number> }, currentSeqno: number) {
    for (let i = 0; i < 24; i++) {
        await sleep(5000);
        const seqno = await wallet.getSeqno();
        if (seqno > currentSeqno) {
            return;
        }
    }
    throw new Error('Timed out waiting for wallet seqno to increase');
}

async function main() {
    const mnemonic = requireEnv('MNEMONIC', MNEMONIC);
    const walletAddress = Address.parse(requireEnv('MY_WALLET', MY_WALLET));

    const keyPair = await mnemonicToPrivateKey(mnemonic.trim().split(/\s+/));

    const client = new TonClient({
        endpoint: ENDPOINT,
        apiKey: TONCENTER_API_KEY,
    });

    const wallet = WalletContractV5R1.create({
        workchain: 0,
        publicKey: keyPair.publicKey,
        walletId: {
            networkGlobalId: -3,
        },
    });

    console.log('Derived sender address:', wallet.address.toString());
    console.log('Expected wallet address:', walletAddress.toString());

    if (wallet.address.toString() !== walletAddress.toString()) {
        throw new Error('Derived wallet address does not match MY_WALLET. Check wallet version/network or mnemonic.');
    }

    const openedWallet = client.open(wallet);
    const sender = openedWallet.sender(keyPair.secretKey);

    if (MODE === 'deploy') {
        const collectionMetadataUrl = requireEnv('COLLECTION_METADATA_URL', COLLECTION_METADATA_URL);
        const commonContentUrl = requireEnv('COMMON_CONTENT_URL', COMMON_CONTENT_URL);

        if (!commonContentUrl.endsWith('/')) {
            throw new Error('COMMON_CONTENT_URL must end with a trailing slash');
        }

        const collectionCode = loadCompiledCell(path.join(BUILD_DIR, 'NftCollection.compiled.json'));
        const itemCode = loadCompiledCell(path.join(BUILD_DIR, 'NftItem.compiled.json'));

        const collection = NftCollection.createFromConfig(
            {
                admin: walletAddress,
                content: {
                    type: 'offchain',
                    uri: collectionMetadataUrl,
                },
                common_content: commonContentUrl,
                item_code: itemCode,
                royalty: {
                    address: walletAddress,
                    royalty_factor: 0,
                    royalty_base: 1000,
                },
            },
            collectionCode
        );

        const openedCollection = client.open(collection);

        console.log('Collection address will be:', collection.address.toString());

        const seqno = await openedWallet.getSeqno();
        await openedCollection.sendDeploy(sender, toNano('0.05'));

        console.log('Deploy tx sent. Waiting for confirmation...');
        await waitForSeqno(openedWallet, seqno);

        console.log('Collection deployed at:', collection.address.toString());
        console.log(`Now run again with: MODE=mint COLLECTION_ADDRESS=${collection.address.toString()}`);
        return;
    }

    if (MODE === 'mint') {
        const collectionAddress = Address.parse(requireEnv('COLLECTION_ADDRESS', COLLECTION_ADDRESS));
        const collection = client.open(NftCollection.createFromAddress(collectionAddress));

        const data = await collection.getCollectionData();
        console.log('nextItemIndex =', data.nextItemIndex);

        if (data.nextItemIndex !== 0) {
            console.log('Warning: this collection is not empty. Minting current nextItemIndex instead of assuming 0.');
        }

        const mintIndex = BigInt(data.nextItemIndex);
        const seqno = await openedWallet.getSeqno();

        await collection.sendDeployItem(
            sender,
            {
                owner: walletAddress,
                content: beginCell().storeStringTail(ITEM_FILE).endCell(),
            },
            mintIndex,
            toNano('0.06'),
            toNano('0.08')
        );

        console.log('Mint tx sent. Waiting for confirmation...');
        await waitForSeqno(openedWallet, seqno);

        const itemAddress = await collection.getNftAddressByIndex(mintIndex);
        console.log('Minted item index:', mintIndex.toString());
        console.log('NFT item address:', itemAddress.toString());
        return;
    }

    throw new Error(`Unknown MODE: ${MODE}`);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
