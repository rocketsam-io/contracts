// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;


import "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReferralSystem} from "../../src/referral/ReferralSystem.sol";

contract ReferralSystemMock is ReferralSystem {
    constructor(uint16 _refBips) Ownable(_msgSender()) ReferralSystem(_refBips) {}

    function setEarnedForReferrer(address referrer, uint256 earnedAmount) public {
        referrers[referrer].earnedAmount = earnedAmount;
    }
}
