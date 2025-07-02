// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* Context.sol */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/* IERC20Errors.sol */
interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

/* IERC20.sol */
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/* IERC20Metadata.sol */
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/* ERC20.sol */
contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }
    function _transfer(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);

        uint256 fromBalance = _balances[from];
        if (fromBalance < value) revert ERC20InsufficientBalance(from, fromBalance, value);
        unchecked {
            _balances[from] = fromBalance - value;
        }
        _balances[to] += value;
        emit Transfer(from, to, value);
    }
    function _mint(address account, uint256 value) internal virtual {
        if (account == address(0)) revert ERC20InvalidReceiver(account);
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value);
    }
    function _burn(address account, uint256 value) internal virtual {
        if (account == address(0)) revert ERC20InvalidSender(account);
        uint256 accountBalance = _balances[account];
        if (accountBalance < value) revert ERC20InsufficientBalance(account, accountBalance, value);
        unchecked {
            _balances[account] = accountBalance - value;
        }
        _totalSupply -= value;
        emit Transfer(account, address(0), value);
    }
    function _approve(address owner, address spender, uint256 value) internal virtual {
        if (owner == address(0)) revert ERC20InvalidApprover(owner);
        if (spender == address(0)) revert ERC20InvalidSpender(spender);
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }
}

/* Ownable.sol */
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/* Pausable.sol */
abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);
    bool private _paused;
    constructor() {
        _paused = false;
    }
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/* FUZE Token Contract */
contract FUZE is ERC20, Ownable, Pausable {
    constructor(address initialOwner)
        ERC20("FUZE.ac", "FUZE")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 500_000_000 * (10 ** decimals()));
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._transfer(from, to, amount);
    }
}
