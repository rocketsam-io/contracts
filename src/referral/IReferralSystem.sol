// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

/**
* @author RocketSam
* @title IReferralSystem
*/
interface IReferralSystem {

    /**
     * @notice Default referrer bips changed
     */
    event CommonRefBipsChanged(uint16 indexed oldRefBips, uint16 indexed newRefBips);

    /**
     * @notice Earning share bips changed for `referrer`
     */
    event ReferrerBipsChanged(address indexed referrer, uint16 oldRefBips, uint16 newRefBips);

    /**
     * @notice Earning share bips changed for `referrers`
     */
    event ReferrersBatchBipsChanged(address[] indexed referrers, uint16 newRefBips);

    /**
     * @notice Referrer claimed earnings
     */
    event ReferralEarningsClaimed(address indexed referrer, uint256 amount);

    /**
    * @notice Basic error, thrown every time something goes wrong according to the contract logic.
    * @dev The error code indicates more details.
    */
    error ReferralSystem_CoreError(uint8 errorCode);

    /**
    * @notice Change referral earning bips
    * @param _commonRefBips   new referral earning bips
    */
    function setCommonRefBips(uint16 _commonRefBips) external;

    /**
    * @notice Change referral earning bips for specific referrer
    * @param _referrer   referrer address
    * @param _refBips    new referral earning bips
    */
    function setRefBips(address _referrer, uint16 _refBips) external;

    /**
    * @notice Change referral earning bips for specific referrers batch
    * @param _referrers   referrers addresses
    * @param _refBips     new referral earning bips
    */
    function setRefBipsBatch(address[] calldata _referrers, uint16 _refBips) external;

    /**
    * @notice Claim earnings from referral system
    */
    function claimReferrerEarnings() external;
}
