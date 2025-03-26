// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;
import "../libraries/AppStorage.sol";

contract ERC20 {

    AppStorage internal s;
    // string public name;
    // string public symbol;
    // uint8 public decimals;
    // uint256 public totalSupply;
    // address owner;
    
    // mapping (address => uint256) public balances;
    // mapping (address => mapping(address => uint256)) approves;
    // mapping (address => mapping(address => uint256)) allowances;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value); 

    
    constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        s.owner = msg.sender;    
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
        s.totalSupply = _totalSupply;
    }
        
    function balanceOf(address _owner) public view returns (uint256 balance) {
        require(_owner != address(0), "INVALID ADDRESS");
        balance = s.balances[_owner];
    }
    
    
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(msg.sender != address(0) && _to != address(0), "INVALID ADDRESS");
        require(s.balances[msg.sender] >= _value, "INSUFFICIENT BALANCE");
        s.balances[msg.sender] -= _value;
        s.balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        success = true;
    
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0) && _to != address(0), "INVALID ADDRESS");
        require(s.balances[_from] >= _value, "INSUFFICIENT BALANCE");
        require(s.approves[msg.sender][_from] > 0, "UNAUTHORIZED");
        s.balances[_from] -= _value;
        s.balances[_to] += _value;
        s.allowances[msg.sender][_from] -= _value;
        emit Transfer(_from, _to, _value);
        success = true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0) && msg.sender != address(0), "INVALID ADDRESS");
        require(s.balances[msg.sender] >= _value, "INSUFFICIENT BALANCE");

        s.approves[_spender][msg.sender] = _value;
        s.allowances[_spender][msg.sender] = _value;
        success = true;
        emit Approval(msg.sender, _spender, _value);

    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        require(_spender != address(0) && _owner != address(0), "INVALID ADDRESS");

        remaining = s.allowances[_spender][_owner];

    }

}

// function name() public view returns (string)
    // function symbol() public view returns (string)
    // function decimals() public view returns (uint8)
    // function totalSupply() public view returns (uint2