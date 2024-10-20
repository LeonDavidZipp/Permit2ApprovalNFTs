//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";
import "@sollib/src/Permit2Extensions/Permit2Registerer.sol";
import "@sollib/src/Paying/Donatable.sol";

import "forge-std/Test.sol";

/// @title DirectDebitNFT
/// @notice A protocol for creating NFTs that have a set of permissions for transferring tokens,
///         essentially making permissions independent from addresses and instead depending on
///         who holds the NFT
/// @dev Requires debtor's token approval on the Permit2 contract; including the Permit2Registerer
///      contract because of this as a helper for debtors
/// @notice You can donate to this contract by simply sending ETH or ERC20 tokens to it and help
///         fund the development of this project
contract DirectDebitNFT is ERC721Enumerable, Permit2Registerer, Donatable {
    struct NFTPermit {
        IAllowanceTransfer.AllowanceTransferDetails[] details;
        uint48 start;
        uint48 expiration;
    }

    /* ------------------------------------------------------------------ */
    /* State Variables                                                    */
    /* ------------------------------------------------------------------ */
    /// @notice The Permit2 contract
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    /// @notice maps the token id to the permissions for the token
    mapping(uint256 nftId => NFTPermit) private _nftPermits;

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */
    event PermissionsUpdated(address indexed debtor);
    event NFTMinted(address indexed to, uint256 nftId);
    event FundsTransferred(address indexed to);

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */
    error ApprovalNotFromSender(address account);
    error NotOwner(address account, uint256 nftId);
    error Permit2PermissionError(uint256 nftId);
    error NotStarted(uint256 nftId);
    error Expired(uint256 nftId);

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */
    /// @notice Ensure the permissions are from the sender
    /// @param details The details of the transfer
    modifier fromSender(
        IAllowanceTransfer.AllowanceTransferDetails[] calldata details
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
    /// @notice Construct a new DirectDebitNFT contract
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
    /// @dev correct permit2 nonce NEEDS to be grabbed in the frontend
    function updateDebtorPermissions(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external {
        // TODO ?invalid nonce?
        address sender = _msgSender();
        _PERMIT_2.permit(sender, permitBatch, signature);

        emit PermissionsUpdated(sender);
    }

    /* ------------------------------------------------------------------ */
    /* Allowance Functions                                                */
    /* ------------------------------------------------------------------ */
    /// @notice returns the approved amount for a token for a debtor
    function debtorTokenAllowance(
        address debtor,
        address token
    ) external view returns (uint160 amount) {
        (amount,,) = _PERMIT_2.allowance(debtor, token, address(this));
    }

    /// @notice returns all approved tokens and respective amounts for a debtor
    function debtorTokenAllowance(address debtor)
        external
        view
        returns (address[] memory tokens, uint160[] memory amounts)
    {
        unchecked {
            tokens = registeredTokens[debtor];
            uint256 len = tokens.length;
            amounts = new uint160[](len);
            for (uint256 i = 0; i < len; ++i) {
                (amounts[i],,) =
                    _PERMIT_2.allowance(debtor, tokens[i], address(this));
            }
        }
    }

    /// @notice returns all approved tokens and respective amounts for a debtor
    function nftAllowance(uint256 nftId)
        external
        view
        returns (
            address[] memory tokens,
            uint160[] memory amounts,
            uint48 start,
            uint48 expiration
        )
    {
        NFTPermit storage permit = _nftPermits[nftId];
        unchecked {
            uint256 len = permit.details.length;
            tokens = new address[](len);
            amounts = new uint160[](len);
            for (uint256 i = 0; i < len; ++i) {
                tokens[i] = permit.details[i].token;
                amounts[i] = permit.details[i].amount;
            }
            start = permit.start;
            expiration = permit.expiration;
        }
    }

    /* ------------------------------------------------------------------ */
    /* Mint Functions                                                     */
    /* ------------------------------------------------------------------ */
    /// Question: who should be allowed to create NFTs with certain details? Only the debtor or other authorized parties too?

    /// @dev PermitSingle will have to be converted to PermitBatch in the frontend
    /// @notice Mint an NFT and set the permit for the NFT
    /// @param to The address of the NFT holder
    /// @param details The permissions for the NFT holder
    /// @param start The start time of the permit
    /// @param expiration The expiration time of the permit
    function create(
        address to,
        IAllowanceTransfer.AllowanceTransferDetails[] calldata details,
        uint48 start,
        uint48 expiration
    ) external fromSender(details) {
        uint256 supply = totalSupply();
        uint256 nftId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _mint(to, nftId);

        NFTPermit storage permit = _nftPermits[nftId];
        unchecked {
            uint256 len = details.length;
            for (uint256 i = 0; i < len; ++i) {
                permit.details.push(details[i]);
            }
            permit.start = start;
            permit.expiration = expiration;
        }

        emit NFTMinted(to, nftId);
    }

    /// @dev PermitSingle will have to be converted to PermitBatch in the frontend
    /// @notice Mint an NFT and set the permit for the NFT
    /// @param to The address of the NFT holder
    /// @param details The permissions for the NFT holder
    /// @param start The start time of the permit
    /// @param expiration The expiration time of the permit
    function safeCreate(
        address to,
        IAllowanceTransfer.AllowanceTransferDetails[] calldata details,
        uint48 start,
        uint48 expiration
    ) external fromSender(details) {
        uint256 supply = totalSupply();
        uint256 nftId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _safeMint(to, nftId);

        NFTPermit storage permit = _nftPermits[nftId];
        unchecked {
            uint256 len = details.length;
            for (uint256 i = 0; i < len; ++i) {
                permit.details.push(details[i]);
            }
            permit.start = start;
            permit.expiration = expiration;
        }

        emit NFTMinted(to, nftId);
    }

    /* ------------------------------------------------------------------ */
    /* Claim Functions                                                    */
    /* ------------------------------------------------------------------ */
    /// @notice Transfers all permitted funds from the debtor to the NFT holder
    /// @param nftId The ID of the NFT
    function claim(uint256 nftId) external {
        address sender = _msgSender();
        if (sender != _ownerOf(nftId)) {
            revert NotOwner(sender, nftId);
        }
        NFTPermit memory permit = _nftPermits[nftId];
        if (block.timestamp < permit.start) {
            revert NotStarted(nftId);
        }
        if (block.timestamp > permit.expiration) {
            revert Expired(nftId);
        }
        // grab & adjust associated permit
        unchecked {
            uint256 len = permit.details.length;
            for (uint256 i = 0; i < len; ++i) {
                permit.details[i].to = sender;
            }
        }
        // burn NFT
        _burn(nftId);

        // delete permit
        delete _nftPermits[nftId];

        // transfer funds
        try _PERMIT_2.transferFrom(permit.details) {
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
            // TODO figure out if both debtor & owner should be able to invalidate
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
