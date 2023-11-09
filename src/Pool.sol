// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./referral/ReferralSystem.sol";

/**
* @author RocketSam
* @title Pool
*/
contract Pool is Pausable, ReferralSystem {

    /************
    *   ERRORS  *
    ************/

    /**
    * @notice Contract error codes, used to specify the error
    * CODE LIST:
    * E1    "Invalid fee collector address"
    * E2    "Invalid depositing fee"
    * E3    "Balance is zero"
    * E4    "Access denied, address is not fee collector"
    * E5    "Invalid referrer address"
    * E6    "Invalid deposit amount"
    */
    uint8 public constant ERROR_INVALID_COLLECTOR = 1;
    uint8 public constant ERROR_INVALID_FEE = 2;
    uint8 public constant ERROR_INVALID_BALANCE = 3;
    uint8 public constant ERROR_NOT_FEE_COLLECTOR = 4;
    uint8 public constant ERROR_INVALID_REFERRER = 5;
    uint8 public constant ERROR_INVALID_DEPOSIT = 6;

    /**
    * @notice Basic error, thrown every time something goes wrong according to the contract logic.
    * @dev The error code indicates more details.
    */
    error Pool_CoreError(uint256 errorCode);

    /************
    *   EVENTS  *
    ************/

    /**
    * State change
    */
    event FeeChanged(uint256 indexed oldFee, uint256 indexed newFee);
    event FeeCollectorChanged(address indexed oldFeeCollector, address indexed newFeeCollector);

    /**
    * Logic
    */
    event Deposit(
        address indexed depositer,
        uint256 feeEarned,
        uint256 amount,
        uint256 balance,
        address indexed referrer,
        uint256 referrerShare
    );
    event Withdraw(address indexed depositer, uint256 amount);
    event FeeEarningsClaimed(address indexed feeCollector, uint256 amount);

    /***********************
    *   VARIABLES & STATES *
    ***********************/

    uint256 public poolId;

    uint256 public fee;
    address public feeCollector;

    uint256 public feeEarned;
    uint256 public feeClaimed;

    mapping (address => uint256) public balances;

    uint256 public depositsCount;
    uint256 public depositsVolume;

    struct AddressData {
        uint256 depositsCount;
        uint256 depositsVolume;
    }
    mapping (address => AddressData) public addressStatistic;
    mapping (address => uint256) public addressDepositsCount;
    mapping (address => uint256) public addressDepositsVolume;

    /***************
    *   MODIFIERS  *
    ***************/

    /**
    * @dev Protects functions available only to the fee collector, e.g. fee claiming
    */
    modifier onlyFeeCollector() {
        _isFeeCollector(_msgSender());
        _;
    }

    /*****************
    *   CONSTRUCTOR  *
    *****************/

    /**
    * @param _poolId        unique id of the pool
    * @param _fee           depositing fee
    * @param _feeCollector  the address to which the fee claiming is authorized
    * @param _refBips       earning bips for referral system. See {ReferralSystem}
    */
    constructor(
        uint256 _poolId,
        uint256 _fee,
        address _feeCollector,
        uint16 _refBips
    ) Ownable(_msgSender()) ReferralSystem(_refBips) {
        require(_feeCollector != address(0), "Invalid fee collector address");

        poolId = _poolId;
        fee = _fee;
        feeCollector = _feeCollector;
    }

    /*************
    *   SETTERS  *
    *************/

    /**
    * ADMIN
    * @notice Change fee
    * @param _fee   new fee
    *
    * @dev emits {Pool-FeeChanged}
    */
    function setFee(uint256 _fee) external onlyOwner {
        uint256 oldFee = fee;
        fee = _fee;
        emit FeeChanged(oldFee, _fee);
    }

    /**
    * ADMIN
    * @notice Change fee collector address
    * @param _feeCollector   new fee collector address, should not be zero address
    *
    * @dev emits {Pool-FeeCollectorChanged}
    */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        _validate(_feeCollector != address(0), ERROR_INVALID_COLLECTOR);
        address oldFeeCollector = feeCollector;
        feeCollector = _feeCollector;
        emit FeeCollectorChanged(oldFeeCollector, _feeCollector);
    }

    /**
    * ADMIN
    * @notice Pause deposits
    */
    function pause() public onlyOwner {
        _pause();
    }

    /**
    * ADMIN
    * @notice Unpause deposits
    */
    function unpause() public onlyOwner {
        _unpause();
    }

    /*************
    *   LOGIC    *
    *************/

    /**
    * @notice Deposit to pool
    */
    function deposit() external payable nonReentrant whenNotPaused {
        _deposit(address(0), msg.value);
    }

    /**
    * @notice Deposit to pool with referrer address
    * @param _referrer  referral address
    */
    function depositWithReferrer(address _referrer) external payable nonReentrant whenNotPaused {
        _deposit(_referrer, msg.value);
    }

    /**
    * @notice Withdraw from pool
    */
    function withdraw() external nonReentrant {
        uint256 depositBalance = balances[_msgSender()];
        _validate(depositBalance > 0, ERROR_INVALID_BALANCE);

        balances[_msgSender()] = 0;
        _sendEther(_msgSender(), depositBalance);

        emit Withdraw(_msgSender(), depositBalance);
    }

    /**
    * FEE_COLLECTOR
    * @notice Claim earned fees
    */
    function claimFeeEarnings() external nonReentrant onlyFeeCollector {
        uint256 earnedAmount = feeEarned;
        _validate(earnedAmount > 0, ERROR_INVALID_BALANCE);
        
        feeEarned = 0;
        feeClaimed += earnedAmount;
        _sendEther(feeCollector, earnedAmount);
        
        emit FeeEarningsClaimed(feeCollector, earnedAmount);
    }

    /****************
    *   INTERNAL    *
    ****************/

    /**
    * @notice Deposit to pool
    * @param _referrer  referral address
    * @param _amount    amount to deposit
    */
    function _deposit(address _referrer, uint256 _amount) internal {
        _validate(_amount > 0, ERROR_INVALID_DEPOSIT);
        _validate(_amount > fee, ERROR_INVALID_FEE);
        _validate(_msgSender() != _referrer, ERROR_INVALID_REFERRER);
        uint256 referrerEarnings;
        uint256 protocolEarnings;
        if (_referrer != address(0)) {
            referrerEarnings = estimateReferrerShare(_referrer, fee);
            protocolEarnings = fee - referrerEarnings;
            feeEarned += protocolEarnings;

            ReferrerData memory referrerData = referrers[_referrer];
            referrerData.earnedAmount += referrerEarnings;
            ++referrerData.txCount;
            referrers[_referrer] = referrerData;
        } else {
            protocolEarnings = fee;
            feeEarned += fee;
        }

        uint256 depositAmount = _amount - fee;
        balances[_msgSender()] += depositAmount;
        ++depositsCount;
        depositsVolume += depositAmount;
        addressStatistic[_msgSender()].depositsCount++;
        addressStatistic[_msgSender()].depositsVolume += depositAmount;

        emit Deposit(
            _msgSender(),
            protocolEarnings,
            depositAmount,
            balances[_msgSender()],
            _referrer,
            referrerEarnings
        );
    }

    /**
    * @notice Send funds to address
    * @param to         recipient address
    * @param amount     amount to send
    */
    function _sendEther(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    /**
    * @notice Checks if address is current fee collector
    */
    function _isFeeCollector(address caller) internal view {
        _validate(caller == feeCollector, ERROR_NOT_FEE_COLLECTOR);
    }

    /**
    * @notice Checks if the condition is met and reverts with {Pool-Pool_CoreError} error if not
    * @param _clause condition to be checked
    * @param _errorCode code that will be passed in the {Pool-Pool_CoreError} error
    */
    function _validate(bool _clause, uint8 _errorCode) internal pure {
        if (!_clause) revert Pool_CoreError(_errorCode);
    }
}
