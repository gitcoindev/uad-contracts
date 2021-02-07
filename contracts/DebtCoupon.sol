// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "solidity-linked-list/contracts/StructuredLinkedList.sol";
import "./UbiquityAlgorithmicDollarManager.sol";

/// @title A coupon redeemable for dollars with an expiry block number
/// @notice An ERC1155 where the token ID is the expiry block number
/// @dev Implements ERC1155 so receiving contracts must implement IERC1155Receiver
contract DebtCoupon is ERC1155 {
    using SafeMath for uint256;
    using StructuredLinkedList for StructuredLinkedList.List;

    UbiquityAlgorithmicDollarManager public manager;

    address public redemptionContractAddress = address(0);
    bool private _redemptionContractSet = false;

    //not public as if called externally can give inaccurate value. see method
    uint256 private _totalOutstandingDebt;

    //represents tokenSupply of each expiry (since 1155 doesnt have this)
    mapping(uint256 => uint256) private _tokenSupplies;

    //ordered list of coupon expiries
    StructuredLinkedList.List private _sortedBlockNumbers;

    modifier onlyCouponManager() {
        require(
            manager.hasRole(manager.COUPON_MANAGER_ROLE(), msg.sender),
            "Caller is not a coupon manager"
        );
        _;
    }

    //@dev URI param is if we want to add an off-chain meta data uri associated with this contract
    constructor(address _manager) ERC1155("URI") {
        manager = UbiquityAlgorithmicDollarManager(_manager);
        _totalOutstandingDebt = 0;
    }

    /// @notice Mint an amount of coupons expiring at a certain block for a certain recipient
    /// @param amount amount of tokens to mint
    /// @param expiryBlockNumber the expiration block number of the coupons to mint
    function mintCoupons(
        address recipient,
        uint256 amount,
        uint256 expiryBlockNumber
    ) public onlyCouponManager {
        _mint(recipient, expiryBlockNumber, amount, "");
        emit MintedCoupons(recipient, expiryBlockNumber, amount);

        //insert new relevant block number if it doesnt exist in our list
        // (linkedlist implementation wont insert if dupe)
        _sortedBlockNumbers.pushBack(expiryBlockNumber);

        //update the total supply for that expiry and total outstanding debt
        _tokenSupplies[expiryBlockNumber] = _tokenSupplies[expiryBlockNumber]
            .add(amount);
        _totalOutstandingDebt = _totalOutstandingDebt.add(amount);
    }

    /// @notice Burn an amount of coupons expiring at a certain block from
    /// a certain holder's balance
    /// @param couponOwner the owner of those coupons
    /// @param amount amount of tokens to burn
    /// @param expiryBlockNumber the expiration block number of the coupons to burn
    function burnCoupons(
        address couponOwner,
        uint256 amount,
        uint256 expiryBlockNumber
    ) public onlyCouponManager {
        require(
            balanceOf(couponOwner, expiryBlockNumber) >= amount,
            "Coupon owner doesn't have enough coupons"
        );
        _burn(couponOwner, expiryBlockNumber, amount);
        emit BurnedCoupons(couponOwner, expiryBlockNumber, amount);

        //update the total supply for that expiry and total outstanding debt
        _tokenSupplies[expiryBlockNumber] = _tokenSupplies[expiryBlockNumber]
            .sub(amount);
        _totalOutstandingDebt = _totalOutstandingDebt.sub(amount);
    }

    /// @notice Should be called prior to any state changing functions.
    // Updates debt according to current block number
    function updateTotalDebt() public {
        bool reachedEndOfExpiredKeys = false;
        uint256 currentBlockNumber = _sortedBlockNumbers.popFront();

        //if list is empty, currentBlockNumber will be 0
        while (!reachedEndOfExpiredKeys && currentBlockNumber != 0) {
            if (currentBlockNumber > block.number) {
                //put the key back in since we popped, and end loop
                _sortedBlockNumbers.pushFront(currentBlockNumber);
                reachedEndOfExpiredKeys = true;
            } else {
                //update tally and remove key from blocks and map
                _totalOutstandingDebt = _totalOutstandingDebt.sub(
                    _tokenSupplies[currentBlockNumber]
                );
                delete _tokenSupplies[currentBlockNumber];
                _sortedBlockNumbers.remove(currentBlockNumber);
            }
            currentBlockNumber = _sortedBlockNumbers.popFront();
        }
    }

    /// @notice Returns outstanding debt by fetching current tally and removing any expired debt
    function getTotalOutstandingDebt() public view returns (uint256) {
        uint256 outstandingDebt = _totalOutstandingDebt;
        bool reachedEndOfExpiredKeys = false;
        (, uint256 currentBlockNumber) = _sortedBlockNumbers.getNextNode(0);

        while (!reachedEndOfExpiredKeys && currentBlockNumber != 0) {
            if (currentBlockNumber > block.number) {
                reachedEndOfExpiredKeys = true;
            } else {
                outstandingDebt = outstandingDebt.sub(
                    _tokenSupplies[currentBlockNumber]
                );
            }
            (, currentBlockNumber) = _sortedBlockNumbers.getNextNode(
                currentBlockNumber
            );
        }

        return outstandingDebt;
    }

    /// @notice This can only be done once, and should be done post-deployment!
    function setRedemptionContractAddress(address newAddress)
        external
        onlyCouponManager
    {
        require(
            !_redemptionContractSet,
            "Redemption contract has already been set"
        );
        _redemptionContractSet = true;
        redemptionContractAddress = newAddress;
    }

    event MintedCoupons(address recipient, uint256 expiryBlock, uint256 amount);

    event BurnedCoupons(
        address couponHolder,
        uint256 expiryBlock,
        uint256 amount
    );
}
