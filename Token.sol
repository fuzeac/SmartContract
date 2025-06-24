// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title FUSE.ac (FUZE) Token
 * @author FUSE.ac Team
 * @notice This is the official BEP-20 token contract for the FUSE.ac ecosystem.
 * It is a standard ERC20 token with a fixed supply, pausable functionality for security,
 * and ownership control for administrative purposes. This contract is intended for audit by CertiK.
 * @dev This contract uses OpenZeppelin's secure, community-vetted implementations of ERC20, Ownable, and Pausable.
 */
contract FUZE is ERC20, Ownable, Pausable {
    /**
     * @notice Constructor to create the FUZE token.
     * @dev On deployment, this mints the entire fixed supply of 500,000,000 tokens to the initial owner's address.
     * The `initialOwner` will have administrative rights over the contract (e.g., pausing/unpausing).
     * @param initialOwner The address that will initially own the contract and receive the total supply.
     */
    constructor(address initialOwner)
        ERC20("FUSE.ac", "FUZE")
        Ownable(initialOwner)
    {
        // Mint the total fixed supply of 500,000,000 tokens.
        // The total supply is calculated as 500,000,000 * 10**18, where 18 is the standard number of decimals.
        _mint(initialOwner, 500_000_000 * (10 ** decimals()));
    }

    /**
     * @notice Pauses all token transfers.
     * @dev This is a critical security feature that can only be called by the contract owner.
     * It should be used in response to a detected threat, vulnerability, or other emergency
     * to prevent unauthorized movement of tokens.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Resumes token transfers after they have been paused.
     * @dev Can only be called by the contract owner once a security situation has been resolved.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Overrides the internal ERC20 _update function to add the 'whenNotPaused' modifier.
     * This is the most effective way to ensure all token movements (transfers, approvals, etc.)
     * are subject to the pausable functionality. No value-transferring operations can occur
     * while the contract is paused.
     */
    function _update(address from, address to, uint256 value)
        internal
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }
}
