//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Donatable is Ownable {
    /* ------------------------------------------------------------------ */
    /* Fallback Functions                                                 */
    /* ------------------------------------------------------------------ */
    receive() external payable { }

    fallback() external payable { }

    /* ------------------------------------------------------------------ */
    /* Constructor                                                        */
    /* ------------------------------------------------------------------ */
    constructor(address owner_) Ownable(owner_) { }

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
}
