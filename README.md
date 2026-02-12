# MemoGC — Private memo + optional native COTI (COTI GC)

Smart contract on COTI V2 that accepts a **private memo** (encrypted with COTI privacy SDK) and an optional **native COTI** transfer. Fee is configurable and routed to a changeable fee recipient; ownership is transferable.

## Features

- **Private memo**: `itString` memo; validated on-chain and stored encrypted for the recipient (only they can decrypt via COTI SDK).
- **Optional native COTI**: Call `submit(recipient, memo)` with `msg.value > 0`; fee (up to `feeAmount`) goes to `feeRecipient`, remainder to `recipient`. Amount is public (`msg.value`).
- **Ownership**: Changeable via `transferOwnership(newOwner)` (owner-only).
- **Fee recipient**: Public and changeable via `setFeeRecipient(addr)` (owner-only).
- **Fee amount**: Public and changeable via `setFeeAmount(amount)` (owner-only).
- **Recipient**: Must be public (COTI has no private address type).

## Build

```bash
cd memo-gc-contract
npm install
npm run compile
```

## Deploy

Set (optional):

- `DEPLOYER_PRIVATE_KEY` — used for `coti-mainnet` / `coti-testnet`.
- `COTI_RPC_URL` — default `https://mainnet.coti.io/rpc`.
- `MEMO_GC_OWNER` — initial owner (default: deployer).
- `MEMO_GC_FEE_RECIPIENT` — initial fee recipient (default: owner).
- `MEMO_GC_FEE_AMOUNT` — initial fee in wei (default: 0).

Then:

```bash
# Mainnet
npm run deploy:mainnet

# Testnet
npm run deploy:testnet

# Or with default hardhat network (local)
npm run deploy
```

## Client usage (private memo)

1. Use `@coti-io/coti-ethers` (or COTI SDK) to build a wallet and encrypt the memo as `itString`.
2. Call `submit(recipient, memo)` (and optionally send native COTI as `msg.value`).
3. Recipient can:
   - **Latest:** `getLastMemo(recipient)` then decrypt the returned `utString` with their COTI key.
   - **Full history:** Query `MemoSubmitted(recipient, from, memoForRecipient)` event logs for that recipient; decode each log’s data to `utString` and decrypt.
   - **By tx hash:** Get `getTransactionReceipt(txHash)`, find the `MemoSubmitted` log in the receipt, decode its data to `utString`, and decrypt.

Each submit updates `lastMemoForRecipient[recipient]` and emits `MemoSubmitted` so both “latest” and full history (or single-tx lookup) are supported.

## Contract summary

| Item           | Visibility   | Changeable              |
|----------------|-------------|-------------------------|
| Owner          | Public      | Yes (`transferOwnership`) |
| Fee recipient  | Public      | Yes (`setFeeRecipient`)   |
| Fee amount     | Public      | Yes (`setFeeAmount`)      |
| Memo           | Private     | N/A (per-call input)      |
| Native amount  | Public      | N/A (`msg.value`)         |

Network: COTI V2 (chainId 2632500). Explorer: https://mainnet.cotiscan.io

## Verify on Blockscout / CotiScan

1. **Generate flattened source** (single file, UTF-8):

   ```bash
   npm run flatten
   ```

   This writes `MemoGC_flat.sol` in the project root.

2. **In the explorer** (e.g. https://mainnet.cotiscan.io):
   - Open your contract’s address.
   - Go to **Contract** → **Verify & Publish** (or **Code** → **Verify contract**).
   - Choose **Solidity (Single file)**.
   - **Contract address**: your deployed MemoGC address.
   - **Compiler**: `v0.8.19`.
   - **Optimization**: Yes, 200 runs.
   - Paste the full contents of `MemoGC_flat.sol` into the source field.
   - Submit. If the bytecode matches, the contract will be verified.
