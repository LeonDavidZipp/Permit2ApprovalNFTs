//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../contracts/Payable.sol";
import "forge-std/Test.sol";

contract PayableTest is Test {
    uint256 public constant amountEth = 1 ether;
    uint256 public constant transactionFee = 21_000;
    Payable public pay;

    receive() external payable { }

    fallback() external payable { }

    function setUp() public {
        pay = new Payable();
    }

    function test_receive() public {
        uint256 oldBalance = address(this).balance;
        (bool success,) =
            payable(address(pay)).call{ value: amountEth }("");

        assertTrue(success);
        assertApproxEqAbs(
            address(this).balance, oldBalance - amountEth, transactionFee
        );
        assertEq(address(pay).balance, amountEth);
    }

    function test_fallback() public {
        uint256 oldBalance = address(this).balance;
        (bool success,) =
            payable(address(pay)).call{ value: amountEth }("some data");

        assertTrue(success);
        assertApproxEqAbs(
            address(this).balance, oldBalance - amountEth, transactionFee
        );
        assertEq(address(pay).balance, amountEth);
    }
}