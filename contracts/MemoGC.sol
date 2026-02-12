// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@coti-io/coti-contracts/contracts/utils/mpc/MpcCore.sol";

/**
 * MemoGC: Private memo + optional native COTI transfer with configurable fee.
 * - Memo: private (itString); validated and stored encrypted for recipient (only they can decrypt).
 * - Recipient: public (required by COTI; no private address type).
 * - Optional native COTI: send with msg.value; fee goes to feeRecipient, remainder to recipient.
 * - Ownership, fee recipient and fee amount are public and changeable by owner.
 */
contract MemoGC {
    address public owner;
    address public feeRecipient;
    uint256 public feeAmount;

    /// Last memo (encrypted for recipient) per recipient; recipient can fetch and decrypt off-chain.
    mapping(address => utString) public lastMemoForRecipient;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeRecipientSet(address indexed feeRecipient);
    event FeeAmountSet(uint256 feeAmount);
    event Submitted(address indexed recipient, uint256 valueSent, uint256 feeTaken);
    /// Emitted for every submit; recipient can query logs for full history or get receipt by tx hash and decrypt.
    event MemoSubmitted(address indexed recipient, address indexed from, utString memoForRecipient);

    error OnlyOwner();
    error InvalidRecipient();
    error InvalidFeeRecipient();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(address initialOwner_, address initialFeeRecipient_, uint256 initialFeeAmount_) {
        owner = initialOwner_;
        feeRecipient = initialFeeRecipient_;
        feeAmount = initialFeeAmount_;
        emit OwnershipTransferred(address(0), initialOwner_);
        emit FeeRecipientSet(initialFeeRecipient_);
        emit FeeAmountSet(initialFeeAmount_);
    }

    /// Transfer ownership to a new address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidRecipient();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    /// Set the address that receives the fee (native COTI).
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert InvalidFeeRecipient();
        feeRecipient = newFeeRecipient;
        emit FeeRecipientSet(newFeeRecipient);
    }

    /// Set the fee amount (in wei, native COTI). Public and changeable.
    function setFeeAmount(uint256 newFeeAmount) external onlyOwner {
        feeAmount = newFeeAmount;
        emit FeeAmountSet(newFeeAmount);
    }

    /**
     * Submit a private memo and optionally send native COTI to the recipient.
     * @param recipient Recipient (visible on-chain).
     * @param memo Private memo (itString); client must encrypt with COTI SDK before calling.
     * If msg.value > 0: fee = min(feeAmount, msg.value) is sent to feeRecipient, rest to recipient.
     */
    function submit(address recipient, itString calldata memo) external payable {
        if (recipient == address(0)) revert InvalidRecipient();
        gtString memory gtMemo = MpcCore.validateCiphertext(memo);
        utString memory ut = MpcCore.offBoardCombined(gtMemo, recipient);
        lastMemoForRecipient[recipient] = ut;
        emit MemoSubmitted(recipient, msg.sender, ut);

        uint256 value = msg.value;
        if (value > 0) {
            uint256 fee = feeAmount < value ? feeAmount : value;
            uint256 toRecipient = value - fee;
            if (fee > 0 && feeRecipient != address(0)) {
                (bool ok, ) = payable(feeRecipient).call{value: fee}("");
                if (!ok) revert TransferFailed();
            }
            if (toRecipient > 0) {
                (bool ok, ) = payable(recipient).call{value: toRecipient}("");
                if (!ok) revert TransferFailed();
            }
            emit Submitted(recipient, value, fee);
        }
    }

    /// Recipient can call this to get their last memo (utString); decrypt off-chain with COTI SDK.
    function getLastMemo(address account) external view returns (utString memory) {
        return lastMemoForRecipient[account];
    }
}
