//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";
import "./Permit2Registerer.sol";

import "forge-std/Test.sol";

/// @title ApprovalNFT
/// @notice A protocol for creating NFTs that have a set of permissions for transferring tokens,
///         essentially making permissions independent from addresses and instead depending on
///         who holds the NFT
/// @dev Requires user's token approval on the Permit2 contract; including the Permit2Registerer
///      contract because of this as a helper for users
/// @notice You can donate to this contract by simply sending ETH or ERC20 tokens to it and help
///         fund the development of this project
contract ApprovalNFT is ERC721Enumerable, Ownable, Permit2Registerer {
    /* ------------------------------------------------------------------ */
    /* State Variables                                                    */
    /* ------------------------------------------------------------------ */
    /// @notice The Permit2 contract
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    /// @notice maps the debtors to the tokens to the amounts they have approved for this contract
    mapping(address user => mapping(address token => uint160)) private _debtors;
    /// @notice maps the token id to the permissions for the token
    mapping(uint256 tokenId => IAllowanceTransfer.AllowanceTransferDetails[])
        private _permits;

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */
    event PermissionsUpdated(address indexed user);
    event NFTMinted(address indexed to, uint256 tokenId);
    event FundsTransferred(address indexed to);

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */
    error NotOwner(address account, uint256 tokenId);
    error ApprovalNotFromSender(address account);

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Ensure the permissions are from the sender
     * @param details The details of the transfer
     */
    modifier fromSender(
        IAllowanceTransfer.AllowanceTransferDetails[] memory details
    ) {
        unchecked {
            address sender = _msgSender();
            uint256 len = details.length;
            for (uint256 i; i < len; ++i) {
                if (details[i].from != sender) {
                    revert ApprovalNotFromSender(sender);
                }
            }
        }
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Fallback Functions                                                 */
    /* ------------------------------------------------------------------ */
    receive() external payable { }

    fallback() external payable { }

    /* ------------------------------------------------------------------ */
    /* Donation Functions                                                 */
    /* ------------------------------------------------------------------ */
    /// @notice withdraw all eth
    function withdraw() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }

    /// @notice withdraw all of token
    function withdraw(address token) external onlyOwner {
        ERC20(token).transfer(
            _msgSender(), ERC20(token).balanceOf(address(this))
        );
    }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */
    /// @notice Construct a new ApprovalNFT contract
    /// @param owner_ The owner of the contract
    /// @param name_ The name of the NFT
    /// @param symbol_ The symbol of the NFT
    constructor(
        address owner_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(owner_) { }

    /* ------------------------------------------------------------------ */
    /* Permission Functions                                               */
    /* ------------------------------------------------------------------ */
    /// @notice Update or add permissions for a debtor using permit2
    /// @param permitBatch The permissions for a batch of tokens of the debtor
    /// @param signature The signature of the permit
    function updatePermissions(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external {
        address sender = _msgSender();
        _PERMIT_2.permit(sender, permitBatch, signature);
        unchecked {
            uint256 len = permitBatch.details.length;
            for (uint256 i; i < len; ++i) {
                _debtors[sender][permitBatch.details[i].token] =
                    permitBatch.details[i].amount;
            }
        }

        emit PermissionsUpdated(sender);
    }

    /// @notice returns the approved amount for a token for a user
    function permissionedAmount(address user, address token)
        external
        view
        returns (uint160 amount)
    {
        amount = _debtors[user][token];
    }

    /* ------------------------------------------------------------------ */
    /* Mint Functions                                                     */
    /* ------------------------------------------------------------------ */
    /// @dev PermitSingle will have to be converted to PermitBatch in the frontend
    /// @notice Mint an NFT and set the permit for the NFT
    /// @param to The address of the NFT holder
    /// @param details The permissions for the NFT holder
    ///
    function mintAllowanceNFT(
        address to,
        IAllowanceTransfer.AllowanceTransferDetails[] memory details
    ) external fromSender(details) {
        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _mint(to, tokenId);

        _permits[tokenId] = details;

        emit NFTMinted(to, tokenId);
    }

    /// @dev PermitSingle will have to be converted to PermitBatch in the frontend
    /// @notice Mint an NFT and set the permit for the NFT
    /// @param to The address of the NFT holder
    /// @param details The permissions for the NFT holder
    ///
    function safeMintAllowanceNFT(
        address to,
        IAllowanceTransfer.AllowanceTransferDetails[] memory details
    ) external fromSender(details) {
        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _safeMint(to, tokenId);

        _permits[tokenId] = details;

        emit NFTMinted(to, tokenId);
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
    /// @notice Transfer funds from the debtor to the NFT holder
    /// @param tokenId The ID of the NFT
    function transferFunds(uint256 tokenId) external {
        address sender = _msgSender();
        if (sender != _ownerOf(tokenId)) {
            revert NotOwner(sender, tokenId);
        }
        // grab & adjust associated permit
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _permits[tokenId];
        unchecked {
            uint256 len = details.length;
            for (uint256 i; i < len; ++i) {
                details[i].to = sender;
            }
        }
        // burn NFT
        _burn(tokenId);

        // delete permit
        delete _permits[tokenId];

        // transfer funds
        _PERMIT_2.transferFrom(details);

        emit FundsTransferred(sender);
    }

    /* ------------------------------------------------------------------ */
    /* Invalidate NFT Functions                                           */
    /* ------------------------------------------------------------------ */
    /// @notice Invalidate an NFT (either by the owner or the debtor)
    /// @param tokenId The ID of the NFT
    function invalidateNFT(uint256 tokenId) external {
        address sender = _msgSender();
        if (
            sender != _ownerOf(tokenId) && _permits[tokenId].length > 0
                && sender != _permits[tokenId][0].from
        ) {
            revert NotOwner(sender, tokenId);
        }

        _burn(tokenId);

        // delete permit
        delete _permits[tokenId];
    }
}
