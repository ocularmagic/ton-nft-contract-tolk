import * as fs from 'fs';
import * as path from 'path';
import { NetworkProvider } from '@ton/blueprint';
import { Address, Cell, beginCell, toNano } from '@ton/core';
import { NftCollection } from '../wrappers/NftCollection';

const REPO_ROOT = path.resolve(__dirname, '..');
const BUILD_DIR = path.join(REPO_ROOT, 'build');

const COLLECTION_METADATA_URL = process.env.COLLECTION_METADATA_URL || '';
const COMMON_CONTENT_URL = process.env.COMMON_CONTENT_URL || '';
const ITEM_FILE = process.env.ITEM_FILE || '0.json';
const MODE = process.env.MODE || 'deploy';
const COLLECTION_ADDRESS = process.env.COLLECTION_ADDRESS || '';
const MY_WALLET = process.env.MY_WALLET || '';

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

function requireSenderAddress(provider: NetworkProvider): Address {
    const senderAddress = provider.sender().address;

    if (!senderAddress) {
        throw new Error('Connected wallet address is unavailable. Re-run the script and reconnect your wallet.');
    }

    return senderAddress;
}

export async function run(provider: NetworkProvider) {
    const connectedWalletAddress = requireSenderAddress(provider);

    console.log('Connected wallet address:', connectedWalletAddress.toString());

    if (MY_WALLET) {
        const expectedWalletAddress = Address.parse(MY_WALLET);
        console.log('Expected wallet address:', expectedWalletAddress.toString());

        if (!connectedWalletAddress.equals(expectedWalletAddress)) {
            throw new Error('Connected wallet does not match MY_WALLET. Please reconnect the correct wallet or update MY_WALLET.');
        }
    }

    if (MODE === 'deploy') {
        const collectionMetadataUrl = requireEnv('COLLECTION_METADATA_URL', COLLECTION_METADATA_URL);
        const commonContentUrl = requireEnv('COMMON_CONTENT_URL', COMMON_CONTENT_URL);

        if (!commonContentUrl.endsWith('/')) {
            throw new Error('COMMON_CONTENT_URL must end with a trailing slash');
        }

        const collectionCode = loadCompiledCell(path.join(BUILD_DIR, 'NftCollection.compiled.json'));
        const itemCode = loadCompiledCell(path.join(BUILD_DIR, 'NftItem.compiled.json'));

        const collection = provider.open(
            NftCollection.createFromConfig(
                {
                    admin: connectedWalletAddress,
                    content: {
                        type: 'offchain',
                        uri: collectionMetadataUrl,
                    },
                    common_content: commonContentUrl,
                    item_code: itemCode,
                    royalty: {
                        address: connectedWalletAddress,
                        royalty_factor: 0,
                        royalty_base: 1000,
                    },
                },
                collectionCode
            )
        );

        console.log('Collection address will be:', collection.address.toString());

        await collection.sendDeploy(provider.sender(), toNano('0.05'));

        console.log('Deploy request sent. Approve it in your wallet if prompted...');
        await provider.waitForDeploy(collection.address);

        console.log('Collection deployed at:', collection.address.toString());
        console.log(`Now run again with: MODE=mint COLLECTION_ADDRESS=${collection.address.toString()}`);
        return;
    }

    if (MODE === 'mint') {
        const collectionAddress = Address.parse(requireEnv('COLLECTION_ADDRESS', COLLECTION_ADDRESS));
        const collection = provider.open(NftCollection.createFromAddress(collectionAddress));

        const data = await collection.getCollectionData();
        console.log('nextItemIndex =', data.nextItemIndex);

        if (data.nextItemIndex !== 0) {
            console.log('Warning: this collection is not empty. Minting current nextItemIndex instead of assuming 0.');
        }

        const mintIndex = BigInt(data.nextItemIndex);

        await collection.sendDeployItem(
            provider.sender(),
            {
                owner: connectedWalletAddress,
                content: beginCell().storeStringTail(ITEM_FILE).endCell(),
            },
            mintIndex,
            toNano('0.06'),
            toNano('0.08')
        );

        console.log('Mint request sent. Approve it in your wallet if prompted...');
        await provider.waitForLastTransaction();

        const itemAddress = await collection.getNftAddressByIndex(mintIndex);
        console.log('Minted item index:', mintIndex.toString());
        console.log('NFT item address:', itemAddress.toString());
        return;
    }

    throw new Error(`Unknown MODE: ${MODE}`);
}
