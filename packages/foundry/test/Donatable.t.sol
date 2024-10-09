//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../contracts/Donatable.sol";
import "forge-std/Test.sol";

contract Token1 is ERC20 {
    constructor() ERC20("Token1", "TKN1") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract Token2 is ERC20 {
    constructor() ERC20("Token2", "TKN2") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract DonatableTest is Test {
    uint256 public constant amountEth = 1 ether;
    uint256 public constant amountToken = 1000;
    uint256 public constant transactionFee = 21_000;
    Donatable public donatable;
    Token1 public token1;
    Token2 public token2;

    receive() external payable { }

    fallback() external payable { }

    function setUp() public {
        donatable = new Donatable(address(this));
        token1 = new Token1();
        token2 = new Token2();
    }

    function test_withdraw_eth() public {
        uint256 oldBalance = address(this).balance;
        (bool success,) =
            payable(address(donatable)).call{ value: amountEth }("some data");

        assertTrue(success);

        donatable.withdraw();
        assertEq(address(donatable).balance, 0);
        assertApproxEqAbs(address(this).balance, oldBalance, transactionFee * 2);
    }

    function testFail_withdraw_eth_notOwner() public {
        (bool success,) =
            payable(address(donatable)).call{ value: amountEth }("some data");

        assertTrue(success);

        vm.prank(address(0x1234));
        donatable.withdraw();
    }

    function test_withdraw_oneToken() public {
        token1.transfer(address(donatable), amountToken);

        assertEq(token1.balanceOf(address(donatable)), amountToken);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        uint256 oldBalance = token1.balanceOf(address(this));

        donatable.withdraw(tokens);

        assertEq(token1.balanceOf(address(donatable)), 0);
        assertEq(token1.balanceOf(address(this)), oldBalance + amountToken);
    }

    function test_withdraw_multipleToken() public {
        token1.transfer(address(donatable), amountToken);
        token2.transfer(address(donatable), amountToken);

        assertEq(token1.balanceOf(address(donatable)), amountToken);
        assertEq(token2.balanceOf(address(donatable)), amountToken);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);

        uint256 oldBalance1 = token1.balanceOf(address(this));
        uint256 oldBalance2 = token2.balanceOf(address(this));

        donatable.withdraw(tokens);

        assertEq(token1.balanceOf(address(donatable)), 0);
        assertEq(token1.balanceOf(address(this)), oldBalance1 + amountToken);
        assertEq(token2.balanceOf(address(donatable)), 0);
        assertEq(token2.balanceOf(address(this)), oldBalance2 + amountToken);
    }

    function testFail_withdraw_token_notOwner() public {
        token1.transfer(address(donatable), amountToken);

        assertEq(token1.balanceOf(address(donatable)), amountToken);

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        vm.prank(address(0x1234));
        donatable.withdraw(tokens);
    }
}
