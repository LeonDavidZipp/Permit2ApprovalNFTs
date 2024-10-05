//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";

contract ApprovalNFT is ERC721, IERC721Receiver, Ownable, Nonces, ReentrancyGuard {
    mapping(uint256 => IAllowanceTransfer.PermitBatch) internal permits;

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
     * @param permit The permissions for a batch of tokens of the NFT holder
     * @param to The address of the NFT holder
     */
    function mintAllowanceNFT(
        IAllowanceTransfer.PermitBatch memory permit,
        address to
    ) external { }

    /**
     * @dev PermitSingle will have to be converted to PermitBatch in the frontend
     * @notice Mint an NFT and set the permit for the NFT
     * @param permit The permissions for a batch of tokens of the NFT holder
     * @param to The address of the NFT holder
     */
    function safeMintAllowanceNFT(
        IAllowanceTransfer.PermitBatch memory permit,
        address to
    ) external { }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
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
