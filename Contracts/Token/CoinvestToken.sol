pragma solidity ^0.4.18;
/**
 * @title Coinvest Token
 * @dev Just a very straightforward ERC20 contract.
**/

contract CoinvestToken {
    string public constant symbol = "COIN";
    string public constant name = "Coinvest";
    
    // Storing small numbers is cheaper.
    uint256 public constant decimals = 18;
    uint256 _totalSupply = 1000000 * (10 ** 18);

    // Balances for each account
    mapping(address => uint256) balances;

    // Owner of account approves the transfer of an amount to another account
    mapping(address => mapping (address => uint256)) allowed;

    event Transfer(address indexed _from, address indexed _to, uint indexed _amount);
    event Approval(address indexed _from, address indexed _spender, uint indexed _amount);

    /**
     * @dev Set owner and beginning balance.
    **/
    function CoinvestToken()
      public
    {
        balances[msg.sender] = _totalSupply;
    }

    /**
     * @dev Return total supply of token
    **/
    function totalSupply() 
      external
      constant 
     returns (uint256) 
    {
        return _totalSupply;
    }

    /**
     * @dev Return balance of a certain address.
     * @param _owner The address whose balance we want to check.
    **/
    function balanceOf(address _owner)
      external
      constant 
    returns (uint256) 
    {
        return balances[_owner];
    }

    /**
     * @dev Transfers coins from one address to another.
     * @param _to The recipient of the transfer amount.
     * @param _amount The amount of tokens to transfer.
    **/
    function transfer(address _to, uint256 _amount) 
      external
    returns (bool success)
    {
        // Throw if insufficient balance
        require(balances[msg.sender] >= _amount);
        
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        Transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @dev An allowed address can transfer tokens from another's address.
     * @param _from The owner of the tokens to be transferred.
     * @param _to The address to which the tokens will be transferred.
     * @param _amount The amount of tokens to be transferred.
    **/
    function transferFrom(address _from, address _to, uint _amount)
      external
    returns (bool success)
    {
        require(balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount);

        allowed[_from][msg.sender] -= _amount;
        balances[_from] -= _amount;
        balances[_to] += _amount;
        
        Transfer(_from, _to, _amount);
        return true;
    }

    /**
     * @dev Approves a wallet to transfer tokens on one's behalf.
     * @param _spender The wallet approved to spend tokens.
     * @param _amount The amount of tokens approved to spend.
    **/
    function approve(address _spender, uint256 _amount) 
      external
    {
        require(_amount == 0 || allowed[msg.sender][_spender] == 0);
        require(balances[msg.sender] >= _amount);
        
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
    }

    /**
     * @dev Allowed amount for a user to spend of another's tokens.
     * @param _owner The owner of the tokens approved to spend.
     * @param _spender The address of the user allowed to spend the tokens.
    **/
    function allowance(address _owner, address _spender) 
      external
      constant 
    returns (uint256) 
    {
        return allowed[_owner][_spender];
    }
}
