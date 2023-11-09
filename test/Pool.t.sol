// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Pool} from "../src/Pool.sol";

contract PoolTest is Test {
    uint16 public constant ZERO_PERCENT = 0; // 10%
    uint16 public constant TEN_PERCENT = 1000; // 10%
    address public constant FEE_COLLECTOR = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
    address public constant REFERRER = 0x00000000219ab540356cBB839Cbe05303d7705Fa;

    uint8 public constant ERROR_INVALID_COLLECTOR = 1;
    uint8 public constant ERROR_INVALID_FEE = 2;
    uint8 public constant ERROR_INVALID_BALANCE = 3;
    uint8 public constant ERROR_NOT_FEE_COLLECTOR = 4;
    uint8 public constant ERROR_INVALID_REFERRER = 5;
    uint8 public constant ERROR_INVALID_DEPOSIT = 6;
    error Pool_CoreError(uint256 errorCode);

    event FeeChanged(uint256 indexed oldFee, uint256 indexed newFee);
    event FeeCollectorChanged(address indexed oldFeeCollector, address indexed newFeeCollector);
    event Deposit(
        address indexed depositer,
        uint256 fee,
        uint256 amount,
        uint256 balance,
        address indexed referrer,
        uint256 referrerShare
    );
    event Withdraw(address indexed depositer, uint256 amount);
    event FeeEarningsClaimed(address indexed feeCollector, uint256 amount);


    Pool public pool;

    function setUp() public {
        uint256 poolId = 0;
        uint256 fee = 0;
        address feeCollector = FEE_COLLECTOR;
        uint16 refBips = ZERO_PERCENT;
        pool = new Pool(
            poolId,
            fee,
            feeCollector,
            refBips
        );
    }

    function test_setFee() public {
        uint256 newFee = 0.1 ether;

        vm.expectEmit();
        emit FeeChanged(0, newFee);

        pool.setFee(newFee);

        assertEq(pool.fee(), newFee, "Fee should change");
    }

    function test_setFee_revert() public {
        uint256 newFee = 0.1 ether;

        vm.startPrank(FEE_COLLECTOR);

        vm.expectRevert();

        pool.setFee(newFee);
        vm.stopPrank();
    }

    function test_setFeeCollector() public {
        address newFeeCollector = address(this);

        vm.expectEmit();
        emit FeeCollectorChanged(FEE_COLLECTOR, newFeeCollector);

        pool.setFeeCollector(newFeeCollector);

        assertEq(pool.feeCollector(), newFeeCollector, "FeeCollector should change");
    }

    function test_setFeeCollector_revert() public {
        address newFeeCollector = address(this);

        vm.startPrank(FEE_COLLECTOR);

        vm.expectRevert();

        pool.setFeeCollector(newFeeCollector);

        vm.stopPrank();
    }

    function test_pause() public {
        pool.pause();

        assert(pool.paused());
    }

    function test_pause_revert() public {
        vm.startPrank(FEE_COLLECTOR);

        vm.expectRevert();

        pool.pause();

        vm.stopPrank();
    }

    function test_unpause() public {
        pool.pause();

        pool.unpause();

        assert(!pool.paused());
    }

    function test_unpause_revert() public {
        vm.startPrank(FEE_COLLECTOR);

        vm.expectRevert();

        pool.unpause();

        vm.stopPrank();
    }

    function test_deposit() public {
        address sender = address(this);
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;

        pool.setFee(fee);

        vm.expectEmit();
        emit Deposit(
            sender,
            fee,
            amountToDeposit,
            amountToDeposit,
            address(0),
            0
        );

        pool.deposit{value: fee + amountToDeposit}();

        uint256 after_protocolBalance = address(pool).balance;
        uint256 after_feeEarned = pool.feeEarned();
        uint256 after_balance = pool.balances(sender);
        uint256 after_depositsCount = pool.depositsCount();
        uint256 after_depositsVolume = pool.depositsVolume();
        (uint256 after_senderDepositsCount, uint256 after_senderDepositsVolume) = pool.addressStatistic(sender);

        assertEq(after_protocolBalance, amountToDeposit + fee);
        assertEq(after_feeEarned, fee);
        assertEq(after_balance, amountToDeposit);
        assertEq(after_depositsCount, 1);
        assertEq(after_depositsVolume, amountToDeposit);
        assertEq(after_senderDepositsCount, 1);
        assertEq(after_senderDepositsVolume, amountToDeposit);
    }

    function test_depositWithReferrer() public {
        address sender = address(this);
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address referrer = REFERRER;

        pool.setFee(fee);
        pool.setCommonRefBips(TEN_PERCENT);
        uint256 referrerShare = pool.estimateReferrerShare(referrer, fee);
        uint256 protocolShare = fee - referrerShare;

        vm.expectEmit();
        emit Deposit(
            sender,
            protocolShare,
            amountToDeposit,
            amountToDeposit,
            referrer,
            referrerShare
        );

        pool.depositWithReferrer{value: fee + amountToDeposit}(referrer);

        (uint256 after_referrerTxCount, uint256 after_referrerEarned,) = pool.referrers(referrer);
        uint256 after_feeEarned = pool.feeEarned();
        uint256 after_balance = pool.balances(sender);
        uint256 after_depositsCount = pool.depositsCount();
        uint256 after_depositsVolume = pool.depositsVolume();
        (uint256 after_senderDepositsCount, uint256 after_senderDepositsVolume) = pool.addressStatistic(sender);

        assertEq(after_referrerTxCount, 1);
        assertEq(after_referrerEarned, referrerShare);
        assertEq(address(pool).balance, amountToDeposit + fee);
        assertEq(after_feeEarned, protocolShare);
        assertEq(after_balance, amountToDeposit);
        assertEq(after_depositsCount, 1);
        assertEq(after_depositsVolume, amountToDeposit);
        assertEq(after_senderDepositsCount, 1);
        assertEq(after_senderDepositsVolume, amountToDeposit);
    }

    function test_deposit_revert_paused() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;

        pool.setFee(fee);
        pool.pause();

        vm.expectRevert();

        pool.deposit{value: fee + amountToDeposit}();
    }

    function test_depositWithReferrer_revert_paused() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address referrer = REFERRER;

        pool.setFee(fee);
        pool.pause();

        vm.expectRevert();

        pool.depositWithReferrer{value: fee + amountToDeposit}(referrer);
    }

    function test_deposit_revert_invalidDeposit() public {
        uint256 fee = 0.1 ether;

        pool.setFee(fee);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_DEPOSIT));

        pool.deposit{value: 0}();
    }

    function test_deposit_revert_invalidFee() public {
        uint256 fee = 0.1 ether;

        pool.setFee(fee);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_FEE));

        pool.deposit{value: fee}();
    }

    function test_depositWithReferrer_revert_invalidReferrer() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address referrer = address(this);

        pool.setFee(fee);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_REFERRER));

        pool.depositWithReferrer{value: fee + amountToDeposit}(referrer);
    }

    function test_withdraw() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address sender = FEE_COLLECTOR;

        pool.setFee(fee);
        vm.deal(sender, fee + amountToDeposit);
        vm.startPrank(sender);
        pool.deposit{value: fee + amountToDeposit}();

        vm.expectEmit();
        emit Withdraw(sender, amountToDeposit);

        pool.withdraw();

        vm.stopPrank();

        assertEq(address(pool).balance, fee);
        assertEq(sender.balance, amountToDeposit);
        assertEq(pool.balances(sender), 0);
    }

    function test_withdraw_revert_invalidBalance() public {
        address sender = FEE_COLLECTOR;

        vm.startPrank(sender);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_BALANCE));

        pool.withdraw();
    }

    function test_claimFeeEarnings() public {
        address collector = FEE_COLLECTOR;
        address sender = REFERRER;
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;

        pool.setFee(fee);
        vm.deal(sender, amountToDeposit + fee);
        vm.startPrank(sender);
        pool.deposit{value: amountToDeposit + fee}();
        vm.startPrank(collector);

        vm.expectEmit();
        emit FeeEarningsClaimed(collector, fee);

        pool.claimFeeEarnings();

        assertEq(address(pool).balance, amountToDeposit);
        assertEq(collector.balance, fee);
        assertEq(pool.feeEarned(), 0);
        assertEq(pool.feeClaimed(), fee);
    }

    function test_claimFeeEarnings_revert_notFeeCollector() public {
        address sender = REFERRER;
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;

        pool.setFee(fee);
        vm.deal(sender, amountToDeposit + fee);
        vm.startPrank(sender);
        pool.deposit{value: amountToDeposit + fee}();

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_NOT_FEE_COLLECTOR));

        pool.claimFeeEarnings();
    }

    function test_claimFeeEarnings_revert_invalidBalance() public {
        address collector = FEE_COLLECTOR;

        vm.startPrank(collector);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_BALANCE));

        pool.claimFeeEarnings();
    }
}
