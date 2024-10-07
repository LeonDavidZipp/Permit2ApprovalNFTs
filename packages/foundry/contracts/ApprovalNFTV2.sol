//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";
import "./Permit2Registerer.sol";

import "forge-std/Test.sol";

contract ApprovalNFT is ERC721Enumerable, Ownable, Permit2Registerer {
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    mapping(uint256 tokenId => IAllowanceTransfer.AllowanceTransferDetails[])
        private _permits;
    mapping(address user => bool) private _debtors;

    /* ------------------------------------------------------------------ */
    /* Events                                                             */
    /* ------------------------------------------------------------------ */
    event DebtorRegistered(address indexed debtor);
    event PermitsUpdated(address indexed debtor);
    event DebtorUnregistered(address indexed debtor);
    event NFTMinted(address indexed to, uint256 tokenId);
    event FundsTransferred(address indexed to, uint256 tokenId);

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */
    error NotOwner(address account, uint256 tokenId);
    error NotDebtor(address account);

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Ensure the caller is a debtor
     */
    modifier onlyDebtor() {
        address sender = _msgSender();
        if (!_debtors[sender]) {
            revert NotDebtor(sender);
        }
        _;
    }

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
                    revert("ApprovalNFT: invalid sender");
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
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Construct a new ApprovalNFT contract
     * @param owner_ The owner of the contract
     * @param name_ The name of the NFT
     * @param symbol_ The symbol of the NFT
     */
    constructor(
        address owner_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(owner_) { }

    /* ------------------------------------------------------------------ */
    /* Debtor Functions                                                   */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Register the caller as a debtor, allowing them to send nfts to creditors
     * @param permitBatch The permissions for a batch of tokens of the debtor
     * @param signature The signature of the permit
     */
    function registerAsDebtor(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external {
        address sender = _msgSender();
        _PERMIT_2.permit(sender, permitBatch, signature);
        _debtors[sender] = true;

        emit DebtorRegistered(sender);
    }

    /**
     * @notice Update the permits for the debtor
     * @param permitBatch The permissions for a batch of tokens of the debtor
     * @param signature The signature of the permit
     */
    function updatePermits(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external onlyDebtor {
        address sender = _msgSender();
        _PERMIT_2.permit(sender, permitBatch, signature);

        emit PermitsUpdated(sender);
    }

    /**
     * @notice Unregister an address as a debtor, disallowing the address to send nft
     * @param permitBatch The permissions for a batch of tokens of the debtor
     */
    function unregisterAsDebtor(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external onlyDebtor {
        address sender = _msgSender();
        _PERMIT_2.permit(sender, permitBatch, signature);
        delete _debtors[sender];

        emit DebtorUnregistered(sender);
    }

    /* ------------------------------------------------------------------ */
    /* Mint Functions                                                     */
    /* ------------------------------------------------------------------ */
    /**
     * @dev PermitSingle will have to be converted to PermitBatch in the frontend
     * @notice Mint an NFT and set the permit for the NFT
     * @param to The address of the NFT holder
     * @param details The permissions for the NFT holder
     */
    function mintAllowanceNFT(
        address to,
        IAllowanceTransfer.AllowanceTransferDetails[] memory details
    ) external onlyDebtor fromSender(details) {
        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _mint(to, tokenId);

        _permits[tokenId] = details;

        emit NFTMinted(to, tokenId);
    }

    /**
     * @dev PermitSingle will have to be converted to PermitBatch in the frontend
     * @notice Mint an NFT and set the permit for the NFT
     * @param to The address of the NFT holder
     * @param details The permissions for the NFT holder
     */
    function safeMintAllowanceNFT(
        address to,
        IAllowanceTransfer.AllowanceTransferDetails[] memory details
    ) external onlyDebtor fromSender(details) {
        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _safeMint(to, tokenId);

        _permits[tokenId] = details;

        emit NFTMinted(to, tokenId);
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Transfer funds from the debtor to the NFT holder
     * @param tokenId The ID of the NFT
     */
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

        emit FundsTransferred(sender, tokenId);
    }
}
