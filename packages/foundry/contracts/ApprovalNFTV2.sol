//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";

import "forge-std/Test.sol";

contract ApprovalNFT is
    ERC721Enumerable,
    IERC721Receiver,
    Ownable,
    Nonces,
    ReentrancyGuard
{
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    mapping(uint256 tokenId => IAllowanceTransfer.AllowanceTransferDetails[])
        private _permits;

    error OutOfBoundsID(uint256 tokenId);
    error NotOwner(address account, uint256 tokenId);

    constructor(
        address owner_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(owner_) { }

    /* ------------------------------------------------------------------ */
    /* Mint Functions                                                     */
    /* ------------------------------------------------------------------ */
    /**
     * @dev PermitSingle will have to be converted to PermitBatch in the frontend
     * @notice Mint an NFT and set the permit for the NFT
     * @param to The address of the NFT holder
     * @param permitBatch The permissions for a batch of tokens of the NFT holder
     * @param signature The signature of the permit
     */
    function mintAllowanceNFT(
        address to,
        IAllowanceTransfer.PermitBatch calldata permitBatch, // assumes all relevant tokens will be found out before
        bytes calldata signature
    ) external nonReentrant {
        address sender = _msgSender();
        // permit this contract using permit 2
        // TODO: ensure in frontend spender is this contract
        _PERMIT_2.permit(sender, permitBatch, signature);

        uint256 nextId = totalSupply();
        _mint(to, nextId);

        unchecked {
            uint256 len = permitBatch.details.length;
            for (uint256 i; i < len; ++i) {
                _permits[nextId].push(
                    IAllowanceTransfer.AllowanceTransferDetails({
                        from: sender,
                        to: address(this),
                        amount: permitBatch.details[i].amount,
                        token: permitBatch.details[i].token
                    })
                );
            }
        }
    }

    /**
     * @dev PermitSingle will have to be converted to PermitBatch in the frontend
     * @notice Mint an NFT and set the permit for the NFT
     * @param permitBatch The permissions for a batch of tokens of the NFT holder
     * @param to The address of the NFT holder
     */
    function safeMintAllowanceNFT(
        address to,
        IAllowanceTransfer.PermitBatch calldata permitBatch, // assumes all relevant tokens will be found out before
        bytes calldata signature
    ) external nonReentrant {
        address sender = _msgSender();
        // permit this contract using permit 2
        // TODO: ensure in frontend spender is this contract
        _PERMIT_2.permit(sender, permitBatch, signature);

        uint256 nextId = totalSupply();
        _safeMint(to, nextId);

        unchecked {
            uint256 len = permitBatch.details.length;
            for (uint256 i; i < len; ++i) {
                _permits[nextId].push(
                    IAllowanceTransfer.AllowanceTransferDetails({
                        from: sender,
                        to: address(this),
                        amount: permitBatch.details[i].amount,
                        token: permitBatch.details[i].token
                    })
                );
            }
        }
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Transfer funds from the debtor to the NFT holder
     * @param tokenId The ID of the NFT
     */
    function transferFunds(uint256 tokenId) external nonReentrant {
        // check if sender has one or more NFTs, revert if not
        if (tokenId >= totalSupply()) {
            revert OutOfBoundsID(tokenId);
        }
        address sender = _msgSender();
        if (sender != _ownerOf(tokenId)) {
            revert NotOwner(sender, tokenId);
        }
        // grab associated permit
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _permits[tokenId];
        unchecked {
            uint256 len = details.length;
            for (uint256 i; i < len; ++i) {
                details[i].to = sender;
            }
        }
        // burn NFT & transfer funds
        _burn(tokenId);
        _PERMIT_2.transferFrom(details);

        // delete permit
        delete _permits[tokenId];
    }

    /* ------------------------------------------------------------------ */
    /* ERC721Receiver Functions                                           */
    /* ------------------------------------------------------------------ */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
