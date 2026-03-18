// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract QuantumERC20Token {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    address public owner;
    bool public mintable;
    bool public burnable;
    bool public pausable;
    bool public paused;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddress, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "TOKEN_PAUSED");
        _;
    }

    constructor(
        string memory tokenName_,
        string memory tokenSymbol_,
        uint8 tokenDecimals_,
        uint256 initialSupplyWhole_,
        address tokenOwner_,
        bool tokenMintable_,
        bool tokenBurnable_,
        bool tokenPausable_
    ) {
        require(tokenOwner_ != address(0), "OWNER_ZERO");
        name = tokenName_;
        symbol = tokenSymbol_;
        decimals = tokenDecimals_;
        owner = tokenOwner_;
        mintable = tokenMintable_;
        burnable = tokenBurnable_;
        pausable = tokenPausable_;
        uint256 rawSupply = initialSupplyWhole_ * (10 ** uint256(tokenDecimals_));
        _mint(tokenOwner_, rawSupply);
        emit OwnershipTransferred(address(0), tokenOwner_);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address ownerAddress, address spender) external view returns (uint256) {
        return _allowances[ownerAddress][spender];
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external whenNotPaused returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ALLOWANCE_TOO_LOW");
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "NEW_OWNER_ZERO");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function pause() external onlyOwner {
        require(pausable, "PAUSE_DISABLED");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        require(pausable, "PAUSE_DISABLED");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function mint(address to, uint256 wholeUnits) external onlyOwner returns (bool) {
        require(mintable, "MINT_DISABLED");
        uint256 amount = wholeUnits * (10 ** uint256(decimals));
        _mint(to, amount);
        emit Mint(to, amount);
        return true;
    }

    function burn(uint256 wholeUnits) external returns (bool) {
        require(burnable, "BURN_DISABLED");
        uint256 amount = wholeUnits * (10 ** uint256(decimals));
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
        return true;
    }

    function burnFrom(address from, uint256 wholeUnits) external returns (bool) {
        require(burnable, "BURN_DISABLED");
        uint256 amount = wholeUnits * (10 ** uint256(decimals));
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ALLOWANCE_TOO_LOW");
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _burn(from, amount);
        emit Burn(from, amount);
        return true;
    }

    function batchTransfer(address[] calldata recipients, uint256[] calldata amountsWhole) external onlyOwner whenNotPaused returns (bool) {
        require(recipients.length == amountsWhole.length, "LENGTH_MISMATCH");
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 amount = amountsWhole[i] * (10 ** uint256(decimals));
            _transfer(msg.sender, recipients[i], amount);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "FROM_ZERO");
        require(to != address(0), "TO_ZERO");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "BALANCE_TOO_LOW");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address ownerAddress, address spender, uint256 amount) internal {
        require(ownerAddress != address(0), "OWNER_ZERO");
        require(spender != address(0), "SPENDER_ZERO");
        _allowances[ownerAddress][spender] = amount;
        emit Approval(ownerAddress, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "TO_ZERO");
        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "FROM_ZERO");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "BALANCE_TOO_LOW");
        unchecked {
            _balances[from] = fromBalance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
