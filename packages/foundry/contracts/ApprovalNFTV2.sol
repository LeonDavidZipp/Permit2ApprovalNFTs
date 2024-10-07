//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";

import "forge-std/Test.sol";

contract ApprovalNFT is
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard
{
    address private constant _Permit_2_ADDRESS =
        address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(_Permit_2_ADDRESS);
    mapping(uint256 tokenId => IAllowanceTransfer.AllowanceTransferDetails[])
        private _permits;
    mapping(address user => bool) private _debtors;

    /* ------------------------------------------------------------------ */
    /* Errors                                                             */
    /* ------------------------------------------------------------------ */
    error NotOwner(address account, uint256 tokenId);

    constructor(
        address owner_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(owner_) { }

    /* ------------------------------------------------------------------ */
    /* Modifiers                                                          */
    /* ------------------------------------------------------------------ */
    modifier onlyDebtor() {
        if (!_debtors[_msgSender()]) {
            revert("ApprovalNFT: caller is not a debtor");
        }
        _;
    }

    /* ------------------------------------------------------------------ */
    /* Fallback Functions                                                 */
    /* ------------------------------------------------------------------ */
    receive() external payable { }

    fallback() external payable { }

    /* ------------------------------------------------------------------ */
    /* Permit2 Functions                                                  */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Helper function for users to approve permit2
     * @param tokens The tokens to approve
     */
    function registerForPermit2(address[] calldata tokens) external {
        unchecked {
            uint256 len = tokens.length;
            for (uint256 i; i < len; ++i) {
                ERC20(tokens[i]).approve(_Permit_2_ADDRESS, type(uint256).max);
            }
        }
    }

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
    }

    /**
     * @notice Update the permits for the debtor
     * @param permitBatch The permissions for a batch of tokens of the debtor
        * @param signature The signature of the permit
     */
    function updatePermits(
        AllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external onlyDebtor {
        _PERMIT_2.permit(_msgSender(), permitBatch, signature);
    }

    /**
     * @notice Unregister an address as a debtor, disallowing the address to send nft
     * @param permitBatch The permissions for a batch of tokens of the debtor
     */
    function unregisterAsDebtor(
        IAllowanceTransfer.PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external {
        address sender = _msgSender();
        _PERMIT_2.permit(sender, permitBatch, signature);
        // _debtors[sender] = false;
        delete _debtors[sender];
    }

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
        IAllowanceTransfer.AllowanceTransferDetails[] memory details,
        bytes calldata signature
    ) external onlyDebtor {
        address sender = _msgSender();

        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _mint(to, tokenId);

        _permits[tokenId] = details;
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
    ) external onlyDebtor {
        address sender = _msgSender();

        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;

        _safeMint(to, tokenId);

        _permits[tokenId] = details;
    }

    /* ------------------------------------------------------------------ */
    /* Transfer Funds Functions                                           */
    /* ------------------------------------------------------------------ */
    /**
     * @notice Transfer funds from the debtor to the NFT holder
     * @param tokenId The ID of the NFT
     */
    function transferFunds(uint256 tokenId) external nonReentrant {
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
    }
}
