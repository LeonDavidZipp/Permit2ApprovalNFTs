//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";

contract ApprovalNFT is ERC721Enumerable, IERC721Receiver, Ownable, Nonces, ReentrancyGuard {
    IAllowanceTransfer private constant _PERMIT_2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    mapping(uint256 tokenId => IAllowanceTransfer.PermitDetails[]) private _permits;

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
        _permits[nextId] = permit.details;
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
        _permits[nextId] = permit.details;
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
    /**
     
     */
    function transferFunds() external {
        // check if sender has one or more NFTs, revert if not
        // transfer NFT back to this contract
        // grab associated permit
        // transfer funds
        // destroy NFT & delete permit
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
