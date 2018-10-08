pragma solidity ^0.4.24; 
import './ERC20Interface.sol'; 
import './Ownable.sol';

contract TokenSwap is Ownable {
    
    ERC20Interface public tokenV1;
    ERC20Interface public tokenV2;
    ERC20Interface public tokenV3;
    
    /**
     * @param _tokenV1 The original ERC223 version of the Coinvest token.
     * @param _tokenV2 The second iteration of the token using ERC865.
     * @param _tokenV3 The new iteration of the Coinvest token.
    **/
    constructor(address _tokenV1, address _tokenV2, address _tokenV3) public {
        tokenV1 = ERC20Interface(_tokenV1);
        tokenV2 = ERC20Interface(_tokenV2);
        tokenV3 = ERC20Interface(_tokenV3);
    }
    /**
     * @param _from The address that has transferred this contract tokens.
     * @param _value The amount of tokens that have been transferred.
     * @param _data The extra data sent with transfer (should be nothing).
    **/
    function tokenFallback(address _from, uint _value, bytes _data)
      external
    {
        require(msg.sender == address(tokenV1));
        require(_value > 0);
        require(tokenV3.transfer(_from, _value));
        _data;
    }
    /**
     * @dev approveAndCall will be used on the old token to transfer from the user
     * to the contract, which will then return to them the new tokens.
     * @param _from The user that is making the call.
     * @param _amount The amount of tokens being transferred to this swap contract.
     * @param _token The address of the token contract (address(oldToken))--not used.
     * @param _data Extra data with the call--not used.
    **/
    function receiveApproval(address _from, uint256 _amount, address _token, bytes _data)
      public
    {
        require(msg.sender == address(tokenV2));
        require(_amount > 0);
        require(tokenV2.transferFrom(_from, address(this), _amount));
        require(tokenV3.transfer(_from, _amount));
        _token; _data;
    }
    
    /**
     * @dev Allow the owner to take Ether or tokens off of this contract if they are accidentally sent.
     * @param _tokenContract The address of the token to withdraw (0x0 if Ether).
     * @notice This allows Coinvest to take all valuable tokens from the TokenSwap contract.
    **/
    function tokenEscape(address _tokenContract)
      external
      onlyCoinvest
    {
        // Somewhat pointless require as Coinvest can withdraw V2 and exchange for more V3.
        require(_tokenContract != address(tokenV1) && _tokenContract != address(tokenV3));
        
        if (_tokenContract == address(0)) coinvest.transfer(address(this).balance);
        else {
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
        
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            lostToken.transfer(coinvest, stuckTokens);
        }    
    }

}
