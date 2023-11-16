// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Pool} from "../src/Pool.sol";

contract PoolScript is Script {

    uint256 public constant START_POOL = 0;
    uint256 public constant POOLS_COUNT = 1;

    function run() public {
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

        uint256 fee = 0.0005 ether;
        address feeCollector = 0xBaF6B7ea2b1F4b42AC52095E95DACAa982f9FFcb;
        uint16 refBips = 0;

        vm.broadcast();
        for (uint256 i = START_POOL; i < POOLS_COUNT; i++) {
            Pool pool = new Pool(
                i, // _poolId
                fee,
                feeCollector,
                refBips
            );
            console2.logAddress(address(pool));
            pool.setFee(values, fees, maxFee);
        }
    }
}
