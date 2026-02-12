import { ethers } from "hardhat";

async function main() {
  const initialOwner =
    process.env.MEMO_GC_OWNER ?? process.env.DEPLOYER_ADDRESS ?? (await ethers.provider.getSigner(0).then((s) => s.address));
  const initialFeeRecipient = process.env.MEMO_GC_FEE_RECIPIENT ?? initialOwner;
  const initialFeeAmount = process.env.MEMO_GC_FEE_AMOUNT ?? "0";

  const MemoGC = await ethers.getContractFactory("MemoGC");
  // COTI RPC may not support "pending" block; pass gasLimit to skip estimateGas and avoid "pending block is not available"
  const memoGC = await MemoGC.deploy(initialOwner, initialFeeRecipient, BigInt(initialFeeAmount), {
    gasLimit: 8_000_000n,
  });

  await memoGC.waitForDeployment();
  const address = await memoGC.getAddress();

  console.log("MemoGC deployed to:", address);
  console.log("  owner:", initialOwner);
  console.log("  feeRecipient:", initialFeeRecipient);
  console.log("  feeAmount:", initialFeeAmount);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
