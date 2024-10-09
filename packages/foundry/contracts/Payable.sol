//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract Payable {
    /* ------------------------------------------------------------------ */
    /* Fallback Functions                                                 */
    /* ------------------------------------------------------------------ */
    receive() external payable { }

    fallback() external payable { }
}
