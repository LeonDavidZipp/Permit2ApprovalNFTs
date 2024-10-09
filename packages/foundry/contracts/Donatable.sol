//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Payable.sol";

contract Donatable is Ownable, Payable {
    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */
    constructor(address owner_) Ownable(owner_) { }

    /* ------------------------------------------------------------------ */
    /* Donation Functions                                                 */
    /* ------------------------------------------------------------------ */
    /// @notice withdraw all eth
    function withdraw() external onlyOwner {
        (bool success,) =
            payable(_msgSender()).call{ value: address(this).balance }("");
        if (!success) {
            revert();
        }
    }

    /// @notice withdraw all of token
    function withdraw(address[] calldata tokens) external onlyOwner {
        unchecked {
            uint256 len = tokens.length;
            for (uint256 i = 0; i < len; ++i) {
                ERC20(tokens[i]).transfer(
                    _msgSender(), ERC20(tokens[i]).balanceOf(address(this))
                );
            }
        }
    }
}
