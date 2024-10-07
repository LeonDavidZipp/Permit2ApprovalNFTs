//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";

import "forge-std/Test.sol";

contract ApprovalNFT is
    ERC721Enumerable,
    IERC721Receiver,
    Ownable,
    ReentrancyGuard
{
    address private constant _Permit_2_ADDRESS =
        address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IAllowanceTransfer private constant _PERMIT_2 =
        IAllowanceTransfer(_Permit_2_ADDRESS);
    mapping(uint256 tokenId => IAllowanceTransfer.AllowanceTransferDetails[])
        private _permits;

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
    ) external {
        address sender = _msgSender();
        // permit this contract using permit 2
        // TODO: ensure in frontend spender is this contract
        console.log("sender:", sender);
        _PERMIT_2.permit(sender, permitBatch, signature);
        console.log("permit passed");

        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;
        console.log("token id:", tokenId);
        _mint(to, tokenId);

        unchecked {
            uint256 len = permitBatch.details.length;
            for (uint256 i; i < len; ++i) {
                _permits[tokenId].push(
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

        uint256 supply = totalSupply();
        uint256 tokenId = supply == 0 ? 0 : tokenByIndex(supply - 1) + 1;
        _safeMint(to, tokenId);

        unchecked {
            uint256 len = permitBatch.details.length;
            for (uint256 i; i < len; ++i) {
                _permits[tokenId].push(
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
        console.log("-----------------");
        console.log("tokenId:", tokenId);
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
                // log all values
                console.log(i);
                console.log("from:", details[i].from);
                console.log("to:", details[i].to);
                console.log("det:", details[i].amount);
                console.log("token:", details[i].token);
                console.log("----");
            }
        }
        // burn NFT & transfer funds
        _burn(tokenId);
        console.log("burned");
        _PERMIT_2.transferFrom(details);
        console.log("transferred");

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
