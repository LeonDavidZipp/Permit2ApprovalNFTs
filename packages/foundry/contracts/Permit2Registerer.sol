//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract Permit2Registerer is Context {
    address private constant _Permit_2_ADDRESS =
        address(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    /// @notice maps the user to the tokens they have registered
    mapping(address user => address[]) public registeredTokens;
    /* ------------------------------------------------------------------ */
    /* Permit2 Functions                                                  */
    /* ------------------------------------------------------------------ */
    /// @notice Helper function for users to approve permit2
    /// @dev assumes only new tokens!
    /// @param tokens The tokens to approve

    function registerForPermit2(address[] memory tokens) external {
        unchecked {
            uint256 len = tokens.length;
            address[] storage _registeredTokens = registeredTokens[_msgSender()];
            for (uint256 i; i < len; ++i) {
                _registeredTokens.push(tokens[i]);
                ERC20(tokens[i]).approve(_Permit_2_ADDRESS, type(uint160).max);
            }
        }
    }

    /// @notice Helper function for users to revoke a set of permissions of permit2 given through this contract
    /// @param tokens The tokens to revoke
    function unregisterFromPermit2(address[] calldata tokens) external {
        unchecked {
            address[] storage _registeredTokens = registeredTokens[_msgSender()];

            uint256 len = tokens.length;
            for (uint256 i; i < len; ++i) {
                for (uint256 j = 0; j < _registeredTokens.length; ++j) {
                    if (_registeredTokens[j] == tokens[i]) {
                        ERC20(tokens[i]).approve(_Permit_2_ADDRESS, 0);
                        _registeredTokens[j] =
                            _registeredTokens[_registeredTokens.length - 1];
                        _registeredTokens.pop();
                        break; // Exit the inner loop once the token is found and removed
                    }
                }
            }
        }
    }

    /// @notice Helper function for users to revoke all permissions of permit2 given through this contract
    function unregisterFromPermit2() external {
        unchecked {
            address sender = _msgSender();
            address[] storage _registeredTokens = registeredTokens[sender];

            uint256 len = _registeredTokens.length;
            for (uint256 i; i < len; ++i) {
                ERC20(_registeredTokens[i]).approve(_Permit_2_ADDRESS, 0);
            }

            delete registeredTokens[sender];
        }
    }
}
