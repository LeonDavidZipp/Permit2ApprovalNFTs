// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/ApprovalNFT.sol";
import { IAllowanceTransfer } from
    "permit2/src/interfaces/IAllowanceTransfer.sol";
import { DeployPermit2 } from "permit2/test/utils/DeployPermit2.sol";
import { PermitSignature } from "permit2/test/utils/PermitSignature.sol";
import { TokenProvider } from "permit2/test/utils/TokenProvider.sol";
import { AddressBuilder } from "permit2/test/utils/AddressBuilder.sol";
import { StructBuilder } from "permit2/test/utils/StructBuilder.sol";

contract ApprovalNFTTest is
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
    uint256 acc3 = 0x12345;
    address pubKey3 = vm.addr(acc3);
    uint160 public immutable defaultAmount = 10 ** 18;
    uint48 public defaultNonce;
    uint48 public immutable defaultExpiration =
        uint48(block.timestamp + 5000000);
    address public immutable permit2 = deployPermit2();
    bytes32 public immutable DOMAIN_SEPARATOR =
        IAllowanceTransfer(permit2).DOMAIN_SEPARATOR();
    ApprovalNFT public nft;

    /* ------------------------------------------------------------------ */
    /* Helper Functions                                                   */
    /* ------------------------------------------------------------------ */
    function _defaultERC20PermitBatchAllowance(
        address[] memory tokens,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        address spender
    ) internal view returns (IAllowanceTransfer.PermitBatch memory) {
        IAllowanceTransfer.PermitDetails[] memory details =
            new IAllowanceTransfer.PermitDetails[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: amount,
                expiration: expiration,
                nonce: nonce
            });
        }

        return IAllowanceTransfer.PermitBatch({
            details: details,
            spender: spender,
            sigDeadline: block.timestamp + 100
        });
    }

    function _defaultAllowanceTransferDetails(
        address from,
        address to
    )
        internal
        view
        returns (IAllowanceTransfer.AllowanceTransferDetails[] memory details)
    {
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            new IAllowanceTransfer.AllowanceTransferDetails[](2);
        details[0] = IAllowanceTransfer.AllowanceTransferDetails({
            from: from,
            to: to,
            amount: defaultAmount,
            token: address(token0)
        });
        details[1] = IAllowanceTransfer.AllowanceTransferDetails({
            from: from,
            to: to,
            amount: defaultAmount,
            token: address(token1)
        });
    }

    /// @notice Update the permissions for the signer
    function _updatePermissions(uint256 signer, uint160 amount) public {
        address[] memory tokens =
            AddressBuilder.fill(1, address(token0)).push(address(token1));
        IAllowanceTransfer.PermitBatch memory permitBatch =
        _defaultERC20PermitBatchAllowance(
            tokens, amount, defaultExpiration, defaultNonce, address(nft)
        );
        bytes memory sig1 =
            getPermitBatchSignature(permitBatch, signer, DOMAIN_SEPARATOR);

        vm.Prank(vm.addr(signer));
        nft.updatePermissions(permitBatch, sig1);

        // check allowances for nft contract
        (uint160 amount2, uint48 expiration, uint48 nonce) = IAllowanceTransfer(
            permit2
        ).allowance(sender, address(token0), address(nft));
        assertEq(amount2, amount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, defaultNonce + 1);

        (amount2, expiration, nonce) = IAllowanceTransfer(permit2).allowance(
            sender, address(token1), address(nft)
        );
        assertEq(amount2, defaultAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, defaultNonce + 1);
    }

    function setUp() public {
        initializeERC20Tokens();
        setERC20TestTokens(pubKey1);
        setERC20TestTokenApprovals(vm, pubKey1, permit2);
        setERC20TestTokenApprovals(vm, pubKey2, permit2);
        defaultNonce = 0;
        nft = new ApprovalNFT(owner, "TestNFT", "TNFT");
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */
    function test_constructor() public view {
        assertEq(nft.owner(), owner);
        assertEq(nft.name(), "TestNFT");
        assertEq(nft.symbol(), "TNFT");
    }

    /* ------------------------------------------------------------------ */
    /* Mint Functions                                                     */
    /* ------------------------------------------------------------------ */
    function test_mintAllowanceNFT() public {
        // prepare permit
        _updatePermissions(acc1, type(uint160).max);
        IAllowanceTransfer.AllowanceTransferDetails[] memory permitDetails =
            _defaultAllowanceTransferDetails(pubKey1, pubKey2);

        // mint nft with permit to receiver
        vm.prank(vm.addr(signer));
        nft.mintAllowanceNFT(receiver, permitDetails);

        uint256 nftId = nft.totalSupply() - 1;

        // check balance of account that received nft
        assertEq(nft.balanceOf(receiver), 1);
        assertEq(nft.ownerOf(nftId), receiver);

        // check nft details are correct
        IAllowanceTransfer.AllowanceTransferDetails[] memory details = nft.nftAllowance(nftId);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        uint256 len = details.length;
        assertEq(len, 2);
        for (uint256 i = 0; i < len; ++i) {
            assertEq(details[i].from, pubKey1);
            assertEq(details[i].to, pubKey2);
            assertEq(details[i].amount, defaultAmount);
            assertEq(details[i].token, tokens[i]);
        }
    }

    function test_safeMintAllowanceNFT() public {
        // prepare permit
        _updatePermissions(acc1, type(uint160).max);
        IAllowanceTransfer.AllowanceTransferDetails[] memory permitDetails =
            _defaultAllowanceTransferDetails(pubKey1, pubKey2);

        // mint nft with permit to receiver
        vm.prank(vm.addr(signer));
        nft.safeMintAllowanceNFT(receiver, permitDetails);

        uint256 nftId = nft.totalSupply() - 1;

        // check balance of account that received nft
        assertEq(nft.balanceOf(receiver), 1);
        assertEq(nft.ownerOf(nftId), receiver);

        // check nft details are correct
        IAllowanceTransfer.AllowanceTransferDetails[] memory details = nft.nftAllowance(nftId);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        uint256 len = details.length;
        assertEq(len, 2);
        for (uint256 i = 0; i < len; ++i) {
            assertEq(details[i].from, pubKey1);
            assertEq(details[i].to, pubKey2);
            assertEq(details[i].amount, defaultAmount);
            assertEq(details[i].token, tokens[i]);
        }
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Functions                                                 */
    /* ------------------------------------------------------------------ */
    function test_transferFunds() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey2);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey2), 0);
        assertEq(token0.balanceOf(pubKey2), defaultAmount);
        assertEq(token1.balanceOf(pubKey2), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);
    }

    function test_transferFunds_afterNFTChangedOwner() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);
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

    function test_transferFunds_multipleNFT_differentDebtors_inParallel()
        public
    {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);
        _mintAllowanceNFT(acc2, pubKey2, pubKey3);

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey2);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey2), 0);
        assertEq(token0.balanceOf(pubKey2), defaultAmount);
        assertEq(token1.balanceOf(pubKey2), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);

        uint256 balance2_token0 = token0.balanceOf(pubKey2);
        uint256 balance2_token1 = token1.balanceOf(pubKey2);

        vm.prank(pubKey3);
        nft.transferFunds(1);

        assertEq(nft.balanceOf(pubKey3), 0);
        assertEq(token0.balanceOf(pubKey3), defaultAmount);
        assertEq(token1.balanceOf(pubKey3), defaultAmount);
        assertEq(token0.balanceOf(pubKey2), balance2_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey2), balance2_token1 - defaultAmount);
    }

    function test_transferFunds_multipleNFT_differentDebtors_inSuccession()
        public
    {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey2);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey2), 0);
        assertEq(token0.balanceOf(pubKey2), defaultAmount);
        assertEq(token1.balanceOf(pubKey2), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);

        _mintAllowanceNFT(acc2, pubKey2, pubKey3);

        uint256 balance2_token0 = token0.balanceOf(pubKey2);
        uint256 balance2_token1 = token1.balanceOf(pubKey2);

        vm.prank(pubKey3);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey3), 0);
        assertEq(token0.balanceOf(pubKey3), defaultAmount);
        assertEq(token1.balanceOf(pubKey3), defaultAmount);
        assertEq(token0.balanceOf(pubKey2), balance2_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey2), balance2_token1 - defaultAmount);
    }

    function test_transferFunds_multipleNFT_sameDebtor_inParallel() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);
        _mintAllowanceNFT(acc1, pubKey1, pubKey3);

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey2);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey2), 0);
        assertEq(token0.balanceOf(pubKey2), defaultAmount);
        assertEq(token1.balanceOf(pubKey2), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);

        uint256 balance2_token0 = token0.balanceOf(pubKey2);
        uint256 balance2_token1 = token1.balanceOf(pubKey2);

        vm.prank(pubKey3);
        nft.transferFunds(1);

        assertEq(nft.balanceOf(pubKey3), 0);
        assertEq(token0.balanceOf(pubKey3), defaultAmount);
        assertEq(token1.balanceOf(pubKey3), defaultAmount);
        assertEq(token0.balanceOf(pubKey2), balance2_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey2), balance2_token1 - defaultAmount);
    }

    function test_transferFunds_multipleNFT_sameDebtor_inSuccession() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);

        uint256 balance1_token0 = token0.balanceOf(pubKey1);
        uint256 balance1_token1 = token1.balanceOf(pubKey1);

        vm.prank(pubKey2);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey2), 0);
        assertEq(token0.balanceOf(pubKey2), defaultAmount);
        assertEq(token1.balanceOf(pubKey2), defaultAmount);
        assertEq(token0.balanceOf(pubKey1), balance1_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey1), balance1_token1 - defaultAmount);

        _mintAllowanceNFT(acc1, pubKey1, pubKey3);

        uint256 balance2_token0 = token0.balanceOf(pubKey2);
        uint256 balance2_token1 = token1.balanceOf(pubKey2);

        vm.prank(pubKey3);
        nft.transferFunds(0);

        assertEq(nft.balanceOf(pubKey3), 0);
        assertEq(token0.balanceOf(pubKey3), defaultAmount);
        assertEq(token1.balanceOf(pubKey3), defaultAmount);
        assertEq(token0.balanceOf(pubKey2), balance2_token0 - defaultAmount);
        assertEq(token1.balanceOf(pubKey2), balance2_token1 - defaultAmount);
    }

    function testFail_transferFunds_notOwner() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);
        vm.prank(pubKey3);
        nft.transferFunds(0);
    }

    function testFail_transferFunds_retry() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);
        vm.startPrank(pubKey3);
        nft.transferFunds(0);
        nft.transferFunds(0);
        vm.stopPrank();
    }

    function testFail_transferFunds_nonExistingNFT() public {
        _mintAllowanceNFT(acc1, pubKey1, pubKey2);
        vm.prank(pubKey2);
        nft.transferFunds(1);
    }
}
