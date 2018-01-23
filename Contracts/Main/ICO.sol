pragma solidity ^0.4.15;

import './SafeMath.sol';

contract CoinvestToken {
    function transfer(address _to, uint256 _amount);
    function balanceOf(address _owner) constant returns (uint balance);
}

contract ICO {
    
    event Buy(address indexed _owner, uint256 indexed _amount);
    
    address public owner = msg.sender; // << Replace with proper address
    address public token_address; // << Replace with token contract address
    CoinvestToken token = CoinvestToken(token_address);
    
    uint256 public max_contribution = 50e18; // Whale protection: 50 ETH max deposit
    
    uint256 public constant price = 2058; // Amount of tokens to be sent per each WEI(ETH) contributed.
    /**
     * NOTE: The `price` should be calculated as follows:
     * Targeted parameters 1100 COIN for $700 USD
     * 
     * Assume ETH price = $1310 USD
     * 1310 / 700 * 1100 = 2058 
     */
    
    uint256 public start_block = block.number;
    uint256 public end_block = block.number + 172800;
    
    function() payable {
        assert(msg.value <= max_contribution);
        assert((block.number < end_block) && (block.number > start_block));
        uint256 _tokens_bought = msg.value * price;
        if(token.balanceOf(address(this)) < _tokens_bought)
        {
            msg.sender.transfer( msg.value - (token.balanceOf(address(this)) / price ) );
            _tokens_bought = token.balanceOf(address(this));
        }
        token.transfer(msg.sender, _tokens_bought);
        Buy(msg.sender, msg.value);
    }
    
    function tokenFallback(address, uint, bytes)
    {
        assert(msg.sender == token_address);
    }
    
    function set_timeframes(uint256 _start_block, uint256 _end_block) only_owner
    {
        start_block = _start_block;
        end_block = _end_block;
    }
    
    function withdraw() only_owner
    {
        owner.transfer(this.balance);
    }
    
    function withdraw_token() only_owner
    {
        token.transfer(msg.sender, token.balanceOf(this));
    }
    
    function set_token_address(address _token) only_owner
    {
        token_address = _token;
        token = CoinvestToken(token_address);
    }
    
    
    modifier only_owner
    {
        if(msg.sender != owner)
        {
            revert();
        }
        _;
    }
}
