//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";
// import "./Permit2Registerer.sol";
import "@sollib/permit2ext/Permit2Registerer.sol";
// import "./Donatable.sol";
import "@sollib/paying/Donatable.sol";

/// @title ApprovalNFT
/// @notice A protocol for creating NFTs that have a set of permissions for transferring tokens,
///         essentially making permissions independent from addresses and instead depending on
///         who holds the NFT
/// @dev Requires user's token approval on the Permit2 contract; including the Permit2Registerer
///      contract because of this as a helper for users
/// @notice You can donate to this contract by simply sending ETH or ERC20 tokens to it and help
///         fund the development of this project
contract ApprovalNFT is ERC721Enumerable, Permit2Registerer, Donatable {
    /* ------------------------------------------------------------------ */
    /* State Variables                                                    */
    /* ------------------------------------------------------------------ */
    /// @notice The Permit2 contract
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    /// @notice maps the token id to the permissions for the token
    mapping(uint256 nftId => IAllowanceTransfer.AllowanceTransferDetails[])
        private _nftPermits;

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */
    event PermissionsUpdated(address indexed user);
    event NFTMinted(address indexed to, uint256 nftId);
    event FundsTransferred(address indexed to);

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */
    error ApprovalNotFromSender(address account);
    error NotOwner(address account, uint256 nftId);
    error Permit2PermissionError(uint256 nftId);

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
            for (uint256 i = 0; i < len; ++i) {
                if (details[i].from != sender) {
                    revert ApprovalNotFromSender(sender);
                }
            }
        }
        _;
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
    ) ERC721(name_, symbol_) Donatable(owner_) { }

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

        emit PermissionsUpdated(sender);
    }

    /* ------------------------------------------------------------------ */
    /* Allowance Functions                                                */
    /* ------------------------------------------------------------------ */
    /// @notice returns the approved amount for a token for a user
    function userTokenAllowance(
        address user,
        address token
    ) external view returns (uint160 amount) {
        (amount,,) = _PERMIT_2.allowance(user, token, address(this));
    }

    /// @notice returns all approved tokens and respective amounts for a user
    function userTokenAllowance(address user)
        external
        view
        returns (address[] memory tokens, uint160[] memory amounts)
    {
        unchecked {
            tokens = registeredTokens[user];
            uint256 len = tokens.length;
            amounts = new uint160[](len);
            for (uint256 i = 0; i < len; ++i) {
                (amounts[i],,) =
                    _PERMIT_2.allowance(user, tokens[i], address(this));
            }
        }
    }

    /// @notice returns all approved tokens and respective amounts for a user
    function nftAllowance(uint256 nftId)
        external
        view
        returns (address[] memory tokens, uint160[] memory amounts)
    {
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _nftPermits[nftId];
        unchecked {
            uint256 len = details.length;
            tokens = new address[](len);
            amounts = new uint160[](len);
            for (uint256 i = 0; i < len; ++i) {
                tokens[i] = details[i].token;
                amounts[i] = details[i].amount;
            }
        }
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
        uint256 nftId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _mint(to, nftId);

        IAllowanceTransfer.AllowanceTransferDetails[] storage storageDetails =
            _nftPermits[nftId];
        for (uint256 i = 0; i < details.length; i++) {
            storageDetails.push(details[i]);
        }

        emit NFTMinted(to, nftId);
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
        uint256 nftId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _safeMint(to, nftId);

        IAllowanceTransfer.AllowanceTransferDetails[] storage storageDetails =
            _nftPermits[nftId];
        for (uint256 i = 0; i < details.length; i++) {
            storageDetails.push(details[i]);
        }

        emit NFTMinted(to, nftId);
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
    /// @notice Transfer funds from the debtor to the NFT holder
    /// @param nftId The ID of the NFT
    function transferFunds(uint256 nftId) external {
        address sender = _msgSender();
        if (sender != _ownerOf(nftId)) {
            revert NotOwner(sender, nftId);
        }
        // grab & adjust associated permit
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _nftPermits[nftId];
        unchecked {
            uint256 len = details.length;
            for (uint256 i = 0; i < len; ++i) {
                details[i].to = sender;
            }
        }
        // burn NFT
        _burn(nftId);

        // delete permit
        delete _nftPermits[nftId];

        // transfer funds
        try _PERMIT_2.transferFrom(details) {
            emit FundsTransferred(sender);
        } catch {
            revert Permit2PermissionError(nftId);
        }
    }

    /* ------------------------------------------------------------------ */
    /* Invalidate NFT Functions                                           */
    /* ------------------------------------------------------------------ */
    /// @notice Invalidate an NFT (either by the owner or the debtor)
    /// @param nftId The ID of the NFT
    function invalidateNFT(uint256 nftId) external {
        address sender = _msgSender();
        if (sender != _ownerOf(nftId)) {
            // && _nftPermits[nftId].length > 0
            // && sender != _nftPermits[nftId][0].from

            revert NotOwner(sender, nftId);
        }

        // burn nft
        _burn(nftId);

        // delete permit
        delete _nftPermits[nftId];
    }
}
