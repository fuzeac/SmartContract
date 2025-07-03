// SPDX-License-Identifier: MIT
/**
 * @title FUZE Token Smart Contract
 * @author Gemini
 * @notice This contract implements a standard ERC20 token with additional features
 * such as ownership control, pausable transfers, and a fixed total supply.
 */

// Specifies the version of the Solidity compiler to be used.
pragma solidity ^0.8.20;

/**
 * @title Context
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. This is a helper contract to abstract
 * away getting `msg.sender` and `msg.data`, primarily for metatransactions.
 */
abstract contract Context {
    /**
     * @notice Returns the address of the transaction sender.
     * @return The address of the sender.
     */
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    /**
     * @notice Returns the calldata of the transaction.
     * @return The transaction calldata.
     */
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @title IERC20Errors
 * @dev Defines custom error types for the ERC20 standard. Using custom errors
 * is more gas-efficient than using `require` with string messages.
 */
interface IERC20Errors {
    /**
     * @dev Thrown when a transfer fails due to an insufficient balance.
     * @param sender The address of the account with insufficient funds.
     * @param balance The current balance of the sender.
     * @param needed The amount of tokens required for the transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Thrown when a transfer originates from an invalid address (e.g., the zero address).
     * @param sender The invalid sender address.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Thrown when a transfer is attempted to an invalid recipient (e.g., the zero address).
     * @param receiver The invalid receiver address.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Thrown when `transferFrom` is called with an insufficient allowance.
     * @param spender The address of the account trying to spend the tokens.
     * @param allowance The current allowance granted to the spender.
     * @param needed The amount of tokens the spender is trying to transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Thrown when an approval is attempted from an invalid approver (e.g., the zero address).
     * @param approver The invalid approver address.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Thrown when an approval is attempted for an invalid spender (e.g., the zero address).
     * @param spender The invalid spender address.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @title IERC20
 * @dev Interface of the ERC20 standard as defined in EIP-20.
 * It defines the functions and events that every ERC20 token must implement.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice Returns the total supply of tokens in existence.
     * @return The total number of tokens.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the number of tokens owned by a specific `account`.
     * @param account The address to query the balance of.
     * @return The token balance of the specified account.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Moves `value` tokens from the caller's account to a `to` address.
     * @param to The recipient's address.
     * @param value The amount of tokens to transfer.
     * @return A boolean indicating whether the operation succeeded.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @notice Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner`.
     * @param owner The address of the token owner.
     * @param spender The address of the approved spender.
     * @return The amount of remaining allowance.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @notice Sets `value` as the allowance of `spender` over the caller's tokens.
     * @param spender The address to be approved.
     * @param value The amount of tokens to approve.
     * @return A boolean indicating whether the operation succeeded.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @notice Moves `value` tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's allowance.
     * @param from The address of the token owner.
     * @param to The recipient's address.
     * @param value The amount of tokens to transfer.
     * @return A boolean indicating whether the operation succeeded.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/**
 * @title IERC20Metadata
 * @dev Optional extension to the ERC20 standard that adds `name`, `symbol`,
 * and `decimals` functions.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @notice Returns the name of the token.
     * @return The token's name.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token.
     * @return The token's symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the number of decimals used to represent token amounts.
     * @return The number of decimal places.
     */
    function decimals() external view returns (uint8);
}

/**
 * @title ERC20
 * @dev A core implementation of the ERC20 token standard.
 * This contract provides the basic functionality of an ERC20 token.
 */
contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    // Mapping from an address to its token balance.
    mapping(address => uint256) private _balances;

    // Mapping from an owner's address to a spender's address to their allowance.
    mapping(address => mapping(address => uint256)) private _allowances;

    // The total supply of tokens.
    uint256 private _totalSupply;

    // The name of the token.
    string private _name;

    // The symbol of the token.
    string private _symbol;

    /**
     * @dev Sets the `name` and `symbol` of the token.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @notice Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the number of decimals for the token.
     * By default, this is 18, a common value in ERC20 tokens.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the total supply of the token.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the balance of a given account.
     * @param account The address to check.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice Transfers tokens from the message sender to a recipient.
     * @param to The recipient's address.
     * @param value The amount to transfer.
     * @return True if the transfer succeeds.
     */
    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @notice Returns the allowance a spender has from an owner.
     * @param owner The token owner's address.
     * @param spender The spender's address.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Approves a spender to transfer a certain amount of tokens on behalf of the message sender.
     * @param spender The address to approve.
     * @param value The amount of allowance.
     * @return True if the approval succeeds.
     */
    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @notice Transfers tokens from one address to another, using the allowance mechanism.
     * @param from The owner of the tokens.
     * @param to The recipient of the tokens.
     * @param value The amount to transfer.
     * @return True if the transfer succeeds.
     */
    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Internal function to handle the actual token transfer logic.
     * @param from The sender's address.
     * @param to The recipient's address.
     * @param value The amount to transfer.
     */
    function _transfer(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);

        uint256 fromBalance = _balances[from];
        if (fromBalance < value) revert ERC20InsufficientBalance(from, fromBalance, value);
        
        // `unchecked` is used for gas optimization as the balance check above prevents underflow.
        unchecked {
            _balances[from] = fromBalance - value;
        }
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function to create new tokens and assign them to an account.
     * Increases the total supply.
     * @param account The address to receive the new tokens.
     * @param value The amount of tokens to mint.
     */
    function _mint(address account, uint256 value) internal virtual {
        if (account == address(0)) revert ERC20InvalidReceiver(account);
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value); // Standard practice to emit Transfer from zero address for minting.
    }

    /**
     * @dev Internal function to destroy tokens from an account.
     * Decreases the total supply.
     * @param account The address to burn tokens from.
     * @param value The amount of tokens to burn.
     */
    function _burn(address account, uint256 value) internal virtual {
        if (account == address(0)) revert ERC20InvalidSender(account);
        uint256 accountBalance = _balances[account];
        if (accountBalance < value) revert ERC20InsufficientBalance(account, accountBalance, value);
        
        unchecked {
            _balances[account] = accountBalance - value;
        }
        _totalSupply -= value;
        emit Transfer(account, address(0), value); // Standard practice to emit Transfer to zero address for burning.
    }

    /**
     * @dev Internal function to set the allowance for a spender.
     * @param owner The owner's address.
     * @param spender The spender's address.
     * @param value The allowance amount.
     */
    function _approve(address owner, address spender, uint256 value) internal virtual {
        if (owner == address(0)) revert ERC20InvalidApprover(owner);
        if (spender == address(0)) revert ERC20InvalidSpender(spender);
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Internal function to update an allowance after a `transferFrom`.
     * If the allowance is not infinite, it is reduced by the `value` spent.
     * @param owner The owner of the tokens.
     * @param spender The spender of the tokens.
     * @param value The amount spent.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) { // A check for infinite allowance.
            if (currentAllowance < value) revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }
}

/**
 * @title Ownable
 * @dev Provides a basic access control mechanism where there is an account (an owner)
 * that can be granted exclusive access to specific functions.
 */
abstract contract Ownable is Context {
    address private _owner; // Stores the address of the contract owner.
    
    /**
     * @dev Emitted when ownership is transferred.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract by setting the `initialOwner` as the owner.
     * @param initialOwner The address to be set as the initial owner.
     */
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    /**
     * @dev A modifier that restricts function execution to the contract owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    /**
     * @notice Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    /**
     * @notice Allows the current owner to renounce their ownership of the contract.
     * The contract will have no owner after this is called.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    /**
     * @notice Allows the current owner to transfer ownership to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    
    /**
     * @dev Internal function to handle the ownership transfer.
     * @param newOwner The address of the new owner.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title Pausable
 * @dev Provides a mechanism to pause and unpause contract functionality.
 * This is useful as an emergency stop mechanism.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the contract is paused.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the contract is unpaused.
     */
    event Unpaused(address account);

    bool private _paused; // State variable to track if the contract is paused.

    /**
     * @dev Initializes the contract in a non-paused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @notice Returns true if the contract is paused, false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to ensure a function is only callable when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to ensure a function is only callable when the contract is paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Internal function to pause the contract. Can only be called when not already paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Internal function to unpause the contract. Can only be called when already paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @title FUZE Token Contract
 * @dev This is the main contract for the FUZE token. It inherits from ERC20, Ownable, and Pausable
 * to create a fully-featured token.
 */
contract FUZE is ERC20, Ownable, Pausable {
    /**
     * @dev The constructor for the FUZE token.
     * @param initialOwner The address that will own the contract and receive the initial supply.
     */
    constructor(address initialOwner)
        ERC20("FUZE.ac", "FUZE") // Sets the token name and symbol.
        Ownable(initialOwner)   // Sets the initial owner of the contract.
    {
        // Mints the initial total supply of 500 million tokens to the initialOwner.
        // `10 ** decimals()` is used to account for the 18 decimal places.
        _mint(initialOwner, 500_000_000 * (10 ** decimals()));
    }

    /**
     * @notice Pauses all token transfers. Can only be called by the owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses token transfers. Can only be called by the owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Public view function to check if the contract is currently paused.
     * @return True if paused, false otherwise.
     */
    function isPaused() external view returns (bool) {
        return paused();
    }

    /**
     * @notice Overrides the default decimals function to return a constant value of 18.
     * `pure` is used as the function does not read from or modify the state.
     * @return The number of decimals (18).
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @dev Overrides the internal `_transfer` function to add the `whenNotPaused` modifier.
     * This ensures that transfers can only happen when the contract is not paused.
     */
    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._transfer(from, to, amount);
    }
}
