// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/// @title A debt redemption mechanism for coupon holders
/// @notice Allows users to redeem individual debt coupons or batch redeem coupons
/// @dev Implements IERC1155Receiver so that it can deal with redemptions
interface IDebtCouponManager is IERC1155Receiver {
    function redeemCoupons(
        address from,
        uint256 id,
        uint256 amount
    ) external;

    function exchangeDollarsForCoupons(uint256 amount) external;
}