//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";

contract ApprovalNFT is
    ERC721Enumerable,
    IERC721Receiver,
    Ownable,
    Nonces,
    ReentrancyGuard
{
    struct PermissionDetails {
        IAllowanceTransfer.PermitDetails[] details;
        address from;
    }

    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    mapping(uint256 tokenId => PermissionDetails) private _permits;

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
     * @param permit The permissions for a batch of tokens of the NFT holder
     * @param signature The signature of the permit
     */
    function mintAllowanceNFT(
        address to,
        IAllowanceTransfer.PermitBatch calldata permit, // assumes all relevant tokens will be found out before
        bytes calldata signature
    ) external {
        address sender = _msgSender();
        // permit this contract using permit 2
        // TODO: ensure in frontend spender is this contract
        _PERMIT_2.permit(sender, permit, signature);

        uint256 nextId = totalSupply();
        _mint(to, nextId);

        PermissionDetails memory details;
        details.details = permit.details;
        details.from = sender;
        _permits[nextId] = details;
    }

    /**
     * @dev PermitSingle will have to be converted to PermitBatch in the frontend
     * @notice Mint an NFT and set the permit for the NFT
     * @param permit The permissions for a batch of tokens of the NFT holder
     * @param to The address of the NFT holder
     */
    function safeMintAllowanceNFT(
        address to,
        IAllowanceTransfer.PermitBatch calldata permit, // assumes all relevant tokens will be found out before
        bytes calldata signature
    ) external {
        address sender = _msgSender();
        // permit this contract using permit 2
        // TODO: ensure in frontend spender is this contract
        _PERMIT_2.permit(sender, permit, signature);

        uint256 nextId = totalSupply();
        _safeMint(to, nextId);

        PermissionDetails memory details;
        details.details = permit.details;
        details.from = sender;
        _permits[nextId] = details;
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
        PermissionDetails storage permit = _permits[tokenId];
        unchecked {
            uint256 len = permit.details.length;
            IAllowanceTransfer.AllowanceTransferDetails[] memory details =
                new IAllowanceTransfer.AllowanceTransferDetails[](len);
            IAllowanceTransfer.AllowanceTransferDetails memory detail;
            for (uint256 i; i < len; ++i) {
                detail.from = permit.from;
                detail.to = sender;
                detail.amount = permit.details[i].amount;
                detail.token = permit.details[i].token;

                details[i] = detail;
            }
            // transfer funds
            _PERMIT_2.transferFrom(details);
        }
        // destroy NFT & delete permit
        _burn(tokenId);

        delete _permits[tokenId];
    }

    /**
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
