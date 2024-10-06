// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/ApprovalNFTV2.sol";
import { IAllowanceTransfer } from
    "permit2/src/interfaces/IAllowanceTransfer.sol";
import { DeployPermit2 } from "permit2/test/utils/DeployPermit2.sol";
import { PermitSignature } from "permit2/test/utils/PermitSignature.sol";
import { TokenProvider } from "permit2/test/utils/TokenProvider.sol";
import { AddressBuilder } from "permit2/test/utils/AddressBuilder.sol";
import { StructBuilder } from "permit2/test/utils/StructBuilder.sol";

contract ApprovalNFTV2Test is
    Test,
    DeployPermit2,
    PermitSignature,
    TokenProvider
{
    using AddressBuilder for address[];

    uint256 ownerPrivKey = 0x0123456789;
    address owner = vm.addr(ownerPrivKey);
    uint256 acc1 = 0x01234;
    address pubKey1 = vm.addr(acc1);
    uint256 acc2 = 0x56789;
    address pubKey2 = vm.addr(acc2);
    uint256 acc3 = 0xabcde;
    address pubKey3 = vm.addr(acc3);
    uint160 public immutable defaultAmount = 10 ** 18;
    uint48 public defaultNonce = 0;
    uint48 public immutable defaultExpiration =
        uint48(block.timestamp + 5000000);
    address public immutable permit2 = deployPermit2();
    bytes32 public immutable DOMAIN_SEPARATOR =
        IAllowanceTransfer(permit2).DOMAIN_SEPARATOR();
    ApprovalNFT public nft;

    function _defaultERC20PermitBatchAllowance(
        address[] memory tokens,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        address spender
    ) internal view returns (IAllowanceTransfer.PermitBatch memory) {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: amount,
                expiration: expiration,
                nonce: nonce
            });
        }

        return IAllowanceTransfer.PermitBatch({details: details, spender: spender, sigDeadline: block.timestamp + 100});
    }

    function _mintAllowanceNFT() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permitBatch = _defaultERC20PermitBatchAllowance(
            tokens, defaultAmount, defaultExpiration, defaultNonce, address(nft)
        );
        bytes memory sig1 = getPermitBatchSignature(permitBatch, acc1, DOMAIN_SEPARATOR);

        // mint nft with permit to pubKey2
        vm.prank(pubKey1);
        nft.mintAllowanceNFT(pubKey2, permitBatch, sig1);

        // check allowances for nft contract
        (uint160 amount, uint48 expiration, uint48 nonce) =
            IAllowanceTransfer(permit2).allowance(pubKey1, address(token0), address(nft));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, defaultNonce + 1);

        (amount, expiration, nonce) =
            IAllowanceTransfer(permit2).allowance(pubKey1, address(token1), address(nft));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, defaultNonce + 1);

        // check balance of account that received nft
        assertEq(nft.balanceOf(pubKey2), 1);
        assertEq(nft.ownerOf(0), pubKey2);
    }

    function _safeMintAllowanceNFT() public {
        address[] memory tokens = AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permitBatch = _defaultERC20PermitBatchAllowance(
            tokens, defaultAmount, defaultExpiration, defaultNonce, address(nft)
        );
        bytes memory sig1 = getPermitBatchSignature(permitBatch, acc1, DOMAIN_SEPARATOR);

        // mint nft with permit to pubKey2
        vm.prank(pubKey1);
        nft.safeMintAllowanceNFT(pubKey2, permitBatch, sig1);

        // check allowances for nft contract
        (uint160 amount, uint48 expiration, uint48 nonce) =
            IAllowanceTransfer(permit2).allowance(pubKey1, address(token0), address(nft));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, defaultNonce + 1);

        (amount, expiration, nonce) =
            IAllowanceTransfer(permit2).allowance(pubKey1, address(token1), address(nft));
        assertEq(amount, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, defaultNonce + 1);

        // check balance of account that received nft
        assertEq(nft.balanceOf(pubKey2), 1);
        assertEq(nft.ownerOf(0), pubKey2);
    }

    function setUp() public {
        initializeERC20Tokens();
        setERC20TestTokens(pubKey1);
        setERC20TestTokenApprovals(vm, pubKey1, permit2);
        nft = new ApprovalNFT(owner, "TestNFT", "TNFT");
    }

    function test_constructor() public view {
        assertEq(nft.owner(), owner);
        assertEq(nft.name(), "TestNFT");
        assertEq(nft.symbol(), "TNFT");
    }

    function test_mintAllowanceNFT() public {
        _mintAllowanceNFT();
    }

    function test_safeMintAllowanceNFT() public {
        _safeMintAllowanceNFT();
    }

    function test_transferFunds() public {
        _mintAllowanceNFT();

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey2);
        nft.transferFunds(0);

        assertEq(token0.balanceOf(pubKey2), defaultAmount);
        assertEq(token1.balanceOf(pubKey2), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);
    }

    function test_transferFunds_afterNFTChangedOwner() public {
        _mintAllowanceNFT();
        vm.prank(pubKey2);
        nft.safeTransferFrom(pubKey2, pubKey3, 0);

        assertEq(nft.ownerOf(0), pubKey3);

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey3);
        nft.transferFunds(0);

        assertEq(token0.balanceOf(pubKey3), defaultAmount);
        assertEq(token1.balanceOf(pubKey3), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);
    }
}
