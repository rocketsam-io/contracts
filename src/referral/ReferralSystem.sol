// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IReferralSystem.sol";

/**
* @author RocketSam
* @title ReferralSystem
*/
abstract contract ReferralSystem is IReferralSystem, ReentrancyGuard, Ownable2Step {

    /***************
    *   CONSTANTS  *
    ***************/

    uint16 public constant ONE_HUNDRED_PERCENT = 10000; // 100%

    /*************
    *   ERRORS   *
    *************/

    /**
    * @notice Contract error codes, used to specify the error
    * CODE LIST:
    * E1    "Invalid referral bips"
    * E2    "Nothing to claim, referral earnings is zero"
    */
    uint8 public constant ERROR_INVALID_REF_BIPS = 1;
    uint8 public constant ERROR_INVALID_REF_EARNINGS = 2;

    /***********************
    *   VARIABLES & STATES *
    ***********************/

    struct ReferrerData {
        uint256 txCount;
        uint256 earnedAmount;
        uint256 claimedAmount;
    }

    uint16 public commonRefBips;
    mapping (address => uint16) public referrerBips;
    mapping (address => ReferrerData) public referrers;

    /*****************
    *   CONSTRUCTOR  *
    *****************/

    /**
    * @param _refBips   default earning bips for referrers
    */
    constructor(uint16 _refBips) {
        commonRefBips = _refBips;
    }

    /**
    * ADMIN
    * @notice Change referral earning bips
    * @param _commonRefBips   new referral earning bips, should not be more or equal than 100%
    *
    * @dev emits {IReferralSystem-CommonRefBipsChanged}
    */
    function setCommonRefBips(uint16 _commonRefBips) external virtual onlyOwner {
        if (_commonRefBips >= ONE_HUNDRED_PERCENT) {
            revert ReferralSystem_CoreError(ERROR_INVALID_REF_BIPS);
        }
        uint16 oldCommonRefBips = commonRefBips;
        commonRefBips = _commonRefBips;
        emit CommonRefBipsChanged(oldCommonRefBips, _commonRefBips);
    }

    /**
    * ADMIN
    * @notice Change referral earning bips for specific referrer
    * @param _referrer   referrer address
    * @param _refBips    new referral earning bips, should not be more than 100%
    *
    * @dev emits {IReferralSystem-ReferrerBipsChanged}
    */
    function setRefBips(address _referrer, uint16 _refBips) external virtual onlyOwner {
        if (_refBips > ONE_HUNDRED_PERCENT) {
            revert ReferralSystem_CoreError(ERROR_INVALID_REF_BIPS);
        }
        uint16 oldRefBips = referrerBips[_referrer];
        referrerBips[_referrer] = _refBips;
        emit ReferrerBipsChanged(_referrer, oldRefBips, _refBips);
    }

    /**
    * ADMIN
    * @notice Change referral earning bips for specific referrer
    * @param _referrers   referrers addresses
    * @param _refBips     new referral earning bips, should not be more than 100%
    *
    * @dev emits {IReferralSystem-ReferrersBatchBipsChanged}
    */
    function setRefBipsBatch(address[] calldata _referrers, uint16 _refBips) external virtual onlyOwner {
        if (_refBips > ONE_HUNDRED_PERCENT) {
            revert ReferralSystem_CoreError(ERROR_INVALID_REF_BIPS);
        }
        for (uint256 i; i < _referrers.length; i++) {
            referrerBips[_referrers[i]] = _refBips;
        }
        emit ReferrersBatchBipsChanged(_referrers, _refBips);
    }

    /**
    * @notice Claim earnings from referral system
    */
    function claimReferrerEarnings() external virtual nonReentrant {
        ReferrerData memory referrer = referrers[_msgSender()];
        if (referrer.earnedAmount == 0) {
            revert ReferralSystem_CoreError(ERROR_INVALID_REF_EARNINGS);
        }

        uint256 refAmount = referrer.earnedAmount;
        referrer.earnedAmount = 0;
        referrer.claimedAmount += refAmount;
        referrers[_msgSender()] = referrer;

        (bool success, ) = payable(_msgSender()).call{value: refAmount}("");
        require(success, "Failed to send Ether");

        emit ReferralEarningsClaimed(_msgSender(), refAmount);
    }

    /**
    * @notice Get referrer share for specified amount
    * @param _referrer   referrer address
    * @param _amount     amount to calculate share from
    */
    function estimateReferrerShare(
        address _referrer,
        uint256 _amount
    ) public virtual view returns (uint256 referrerEarnings) {
        uint256 specialRefBips = referrerBips[_referrer];
        uint256 bips = specialRefBips == 0
            ? commonRefBips
            : specialRefBips;
        referrerEarnings = (_amount * bips) / ONE_HUNDRED_PERCENT;
    }
}
