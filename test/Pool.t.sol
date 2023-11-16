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
    uint8 public constant ERROR_INVALID_BALANCE = 2;
    uint8 public constant ERROR_NOT_FEE_COLLECTOR = 3;
    uint8 public constant ERROR_INVALID_REFERRER = 4;
    uint8 public constant ERROR_INVALID_DEPOSIT = 5;
    uint8 public constant ERROR_INCORRECT_FEE_VALUES = 6;
    error Pool_CoreError(uint256 errorCode);

    event MaxFeeChanged(uint256 indexed oldMaxFee, uint256 indexed newMaxFee);
    event FeeChanged(uint256 valuesCount, uint256 indexed maxFee);
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
        uint256[] memory values = new uint256[](4);
        values[0] = 0.01 ether;
        values[1] = 0.1 ether;
        values[2] = 1 ether;
        values[3] = 10 ether;
        uint256[] memory fees = new uint256[](4);
        fees[0] = 0.00015 ether;
        fees[1] = 0.0002 ether;
        fees[2] = 0.0003 ether;
        fees[3] = 0.0004 ether;
        uint256 maxFee = 0.0005 ether;

        vm.expectEmit();
        emit FeeChanged(values.length, maxFee);

        pool.setFee(values, fees, maxFee);

        assertEq(pool.maxFee(), maxFee, "Max fee should change");
        for (uint256 i; i < values.length; i++) {
            assertEq(pool.values(i), values[i], "Value should change");
            assertEq(pool.fee(values[i]), fees[i], "Fee should change");
        }
    }

    function test_setFee_twice() public {
        uint256[] memory values = new uint256[](4);
        values[0] = 0.01 ether;
        values[1] = 0.1 ether;
        values[2] = 1 ether;
        values[3] = 10 ether;
        uint256[] memory fees = new uint256[](4);
        fees[0] = 0.00015 ether;
        fees[1] = 0.0002 ether;
        fees[2] = 0.0003 ether;
        fees[3] = 0.0004 ether;
        uint256 maxFee = 0.0005 ether;

        vm.expectEmit();
        emit FeeChanged(values.length, maxFee);

        pool.setFee(values, fees, maxFee);

        assertEq(pool.maxFee(), maxFee, "Max fee should change");
        for (uint256 i; i < values.length; i++) {
            assertEq(pool.values(i), values[i], "Value should change");
            assertEq(pool.fee(values[i]), fees[i], "Fee should change");
        }

        uint256[] memory values1 = new uint256[](4);
        values1[0] = 0.02 ether;
        values1[1] = 0.2 ether;
        values1[2] = 2 ether;
        values1[3] = 20 ether;
        uint256[] memory fees1 = new uint256[](4);
        fees1[0] = 0.00015 ether;
        fees1[1] = 0.0002 ether;
        fees1[2] = 0.0003 ether;
        fees1[3] = 0.0004 ether;
        uint256 maxFee1 = 0.0005 ether;

        vm.expectEmit();
        emit FeeChanged(values1.length, maxFee1);

        pool.setFee(values1, fees1, maxFee1);

        assertEq(pool.maxFee(), maxFee1, "Max fee should change");
        for (uint256 i; i < values1.length; i++) {
            assertEq(pool.values(i), values1[i], "Value should change");
            assertEq(pool.fee(values1[i]), fees1[i], "Fee should change");
        }
        for (uint256 i; i < values.length; i++) {
            assertEq(pool.fee(values[i]), 0);
        }
    }

    function test_setFee_revert_incorrectFeeValues() public {
        uint256[] memory values = new uint256[](4);
        values[0] = 0.01 ether;
        values[1] = 0.1 ether;
        values[2] = 1 ether;
        values[3] = 10 ether;
        uint256[] memory fees = new uint256[](3);
        fees[0] = 0.00015 ether;
        fees[1] = 0.0002 ether;
        fees[2] = 0.0003 ether;
        uint256 maxFee = 0.0005 ether;

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INCORRECT_FEE_VALUES));

        pool.setFee(values, fees, maxFee);
    }

    function test_setFee_revert_onlyOwner() public {
        uint256[] memory values = new uint256[](4);
        values[0] = 0.01 ether;
        values[1] = 0.1 ether;
        values[2] = 1 ether;
        values[3] = 10 ether;
        uint256[] memory fees = new uint256[](4);
        fees[0] = 0.00015 ether;
        fees[1] = 0.0002 ether;
        fees[2] = 0.0003 ether;
        fees[3] = 0.0004 ether;
        uint256 maxFee = 0.0005 ether;

        vm.expectRevert();

        vm.startPrank(FEE_COLLECTOR);
        pool.setFee(values, fees, maxFee);
    }

    function test_estimate() public {
        test_setFee();

        uint256 fee = pool.estimateProtocolFee(0.001 ether);
        assertEq(fee, 0.00015 ether, "Incorrect fee");
        fee = pool.estimateProtocolFee(0.05 ether);
        assertEq(fee, 0.0002 ether, "Incorrect fee");
        fee = pool.estimateProtocolFee(1 ether);
        assertEq(fee, 0.0003 ether, "Incorrect fee");
        fee = pool.estimateProtocolFee(1.4 ether);
        assertEq(fee, 0.0004 ether, "Incorrect fee");
        fee = pool.estimateProtocolFee(102 ether);
        assertEq(fee, 0.0005 ether, "Incorrect fee");
    }

    function test_setMaxFee() public {
        uint256 newFee = 0.1 ether;

        vm.expectEmit();
        emit MaxFeeChanged(0, newFee);

        pool.setMaxFee(newFee);

        assertEq(pool.maxFee(), newFee, "Fee should change");
    }

    function test_setMaxFee_revert() public {
        uint256 newFee = 0.1 ether;

        vm.startPrank(FEE_COLLECTOR);

        vm.expectRevert();

        pool.setMaxFee(newFee);
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
        test_setFee();
        address sender = address(this);
        uint256 amountToDeposit = 0.1 ether;
        uint256 fee = 0.0002 ether;

        pool.setMaxFee(fee);

        vm.expectEmit();
        emit Deposit(
            sender,
            fee,
            amountToDeposit,
            amountToDeposit,
            address(0),
            0
        );

        pool.deposit{value: fee + amountToDeposit}(amountToDeposit);

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
        test_setFee();
        address sender = address(this);
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.0003 ether;
        address referrer = REFERRER;

        pool.setMaxFee(fee);
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

        pool.depositWithReferrer{value: fee + amountToDeposit}(referrer, amountToDeposit);

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

        pool.setMaxFee(fee);
        pool.pause();

        vm.expectRevert();

        pool.deposit{value: fee + amountToDeposit}(amountToDeposit);
    }

    function test_depositWithReferrer_revert_paused() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address referrer = REFERRER;

        pool.setMaxFee(fee);
        pool.pause();

        vm.expectRevert();

        pool.depositWithReferrer{value: fee + amountToDeposit}(referrer, amountToDeposit);
    }

    function test_deposit_revert_invalidDeposit() public {
        uint256 fee = 0.1 ether;

        pool.setMaxFee(fee);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_DEPOSIT));

        pool.deposit{value: 0}(fee + fee);
    }

    function test_depositWithReferrer_revert_invalidReferrer() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address referrer = address(this);

        pool.setMaxFee(fee);

        vm.expectRevert(abi.encodeWithSelector(Pool_CoreError.selector, ERROR_INVALID_REFERRER));

        pool.depositWithReferrer{value: fee + amountToDeposit}(referrer, amountToDeposit);
    }

    function test_withdraw() public {
        uint256 amountToDeposit = 1 ether;
        uint256 fee = 0.1 ether;
        address sender = FEE_COLLECTOR;

        pool.setMaxFee(fee);
        vm.deal(sender, fee + amountToDeposit);
        vm.startPrank(sender);
        pool.deposit{value: fee + amountToDeposit}(amountToDeposit);

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

        pool.setMaxFee(fee);
        vm.deal(sender, amountToDeposit + fee);
        vm.startPrank(sender);
        pool.deposit{value: amountToDeposit + fee}(amountToDeposit);
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

        pool.setMaxFee(fee);
        vm.deal(sender, amountToDeposit + fee);
        vm.startPrank(sender);
        pool.deposit{value: amountToDeposit + fee}(amountToDeposit);

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
