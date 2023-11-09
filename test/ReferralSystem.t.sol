// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ReferralSystem} from "../src/referral/ReferralSystem.sol";
import {ReferralSystemMock} from "./mocks/ReferralSystemMock.sol";

contract ReferralSystemTest is Test {
    uint16 public constant ZERO_PERCENT = 0; // 10%
    uint16 public constant TEN_PERCENT = 1000; // 10%
    uint16 public constant HUNDRED_PERCENT = 10000; // 10%
    address public constant TEST_REFERRER = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    event CommonRefBipsChanged(uint16 indexed oldRefBips, uint16 indexed newRefBips);
    event ReferrerBipsChanged(address indexed referrer, uint16 oldRefBips, uint16 newRefBips);
    event ReferrersBatchBipsChanged(address[] indexed referrers, uint16 newRefBips);
    event ReferralEarningsClaimed(address indexed referrer, uint256 amount);

    uint8 public constant ERROR_INVALID_REF_BIPS = 1;
    uint8 public constant ERROR_INVALID_REF_EARNINGS = 2;
    error ReferralSystem_CoreError(uint8 errorCode);

    ReferralSystemMock public referralSystem;

    function setUp() public {
        uint16 initialRefBips = ZERO_PERCENT;
        referralSystem = new ReferralSystemMock(initialRefBips);
    }

    function test_setCommonRefBips() public {
        uint16 newRefBips = TEN_PERCENT;

        vm.expectEmit();
        emit CommonRefBipsChanged(ZERO_PERCENT, TEN_PERCENT);

        referralSystem.setCommonRefBips(newRefBips);

        assertEq(referralSystem.commonRefBips(), newRefBips, "CommonRefBips must change");
    }

    function test_setCommonRefBips_revert() public {
        uint16 newRefBips = HUNDRED_PERCENT + TEN_PERCENT;

        vm.expectRevert(abi.encodeWithSelector(ReferralSystem_CoreError.selector, ERROR_INVALID_REF_BIPS));
        referralSystem.setCommonRefBips(newRefBips);
    }

    function test_setRefBips() public {
        uint16 newRefBips = TEN_PERCENT;
        address referrer = TEST_REFERRER;

        vm.expectEmit();
        emit ReferrerBipsChanged(referrer, ZERO_PERCENT, TEN_PERCENT);

        referralSystem.setRefBips(referrer, newRefBips);

        assertEq(referralSystem.referrerBips(referrer), newRefBips, "ReferrerBips must change for referrer");
    }

    function test_setRefBips_revert() public {
        uint16 newRefBips = HUNDRED_PERCENT + TEN_PERCENT;
        address referrer = TEST_REFERRER;

        vm.expectRevert(abi.encodeWithSelector(ReferralSystem_CoreError.selector, ERROR_INVALID_REF_BIPS));
        referralSystem.setRefBips(referrer, newRefBips);
    }

    function test_setRefBipsBatch() public {
        uint16 newRefBips = TEN_PERCENT;
        address[] memory referrers = new address[](1);
        referrers[0] = TEST_REFERRER;

        vm.expectEmit();
        emit ReferrersBatchBipsChanged(referrers, TEN_PERCENT);

        referralSystem.setRefBipsBatch(referrers, newRefBips);

        for (uint256 i; i < referrers.length; i++) {
            assertEq(referralSystem.referrerBips(referrers[i]), newRefBips, "ReferrerBips must change for referrer");
        }
    }

    function test_setRefBipsBatch_revert() public {
        uint16 newRefBips = HUNDRED_PERCENT + TEN_PERCENT;
        address[] memory referrers = new address[](1);
        referrers[0] = TEST_REFERRER;

        vm.expectRevert(abi.encodeWithSelector(ReferralSystem_CoreError.selector, ERROR_INVALID_REF_BIPS));
        referralSystem.setRefBipsBatch(referrers, newRefBips);
    }

    function test_claimReferrerEarnings() public {
        uint256 amountToClaim = 100;
        address referrer = TEST_REFERRER;

        referralSystem.setEarnedForReferrer(referrer, amountToClaim);
        vm.deal(address(referralSystem), 1 ether);

        uint256 before_protocolBalance = address(referralSystem).balance;
        uint256 before_referrerBalance = referrer.balance;

        vm.expectEmit();
        emit ReferralEarningsClaimed(referrer, amountToClaim);

        vm.startPrank(referrer);
        referralSystem.claimReferrerEarnings();
        vm.stopPrank();

        (, uint256 after_refEarned, uint256 after_refClaimed) = referralSystem.referrers(referrer);
        uint256 after_protocolBalance = address(referralSystem).balance;
        uint256 after_referrerBalance = referrer.balance;

        assertEq(after_refEarned, 0);
        assertEq(after_refClaimed, amountToClaim);
        assertEq(after_protocolBalance, before_protocolBalance - amountToClaim);
        assertEq(after_referrerBalance, before_referrerBalance + amountToClaim);
    }

    function test_claimReferrerEarnings_revert_zeroEarnings() public {
        address referrer = TEST_REFERRER;
        vm.deal(address(referralSystem), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(ReferralSystem_CoreError.selector, ERROR_INVALID_REF_EARNINGS));

        vm.startPrank(referrer);
        referralSystem.claimReferrerEarnings();
    }

    function test_claimReferrerEarnings_revert_failedSend() public {
        uint256 amountToClaim = 100;
        address referrer = TEST_REFERRER;

        referralSystem.setEarnedForReferrer(referrer, amountToClaim);

        vm.expectRevert("Failed to send Ether");

        vm.startPrank(referrer);
        referralSystem.claimReferrerEarnings();
    }

    function test_estimateReferrerShare_withCommonBips() public {
        address referrer = TEST_REFERRER;
        uint16 referralBips = TEN_PERCENT;
        uint256 amount = 100;
        uint256 tenPercentAmount = 10;

        referralSystem.setCommonRefBips(referralBips);

        uint256 referrerShare = referralSystem.estimateReferrerShare(referrer, amount);

        assertEq(referrerShare, tenPercentAmount);
    }

    function test_estimateReferrerShare_withSpecialBips() public {
        address referrer = TEST_REFERRER;
        uint16 referralBips = TEN_PERCENT;
        uint256 amount = 100;
        uint256 tenPercentAmount = 10;

        referralSystem.setRefBips(referrer, referralBips);

        uint256 referrerShare = referralSystem.estimateReferrerShare(referrer, amount);

        assertEq(referrerShare, tenPercentAmount);
    }
}