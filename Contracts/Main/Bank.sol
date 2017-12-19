pragma solidity ^0.4.18;
import '../Ownership/Privileged.sol';
import '../Token/CoinvestToken.sol';

/**
 * @title Bank
 * @dev Bank holds all user funds so Investment contract can easily be replaced.
**/

contract Bank is Privileged {
    CoinvestToken coinvestToken; // Coinvest token that this fund will hold.

/** ********************************* Default *********************************** **/
    
    /**
     * @param _coinvestToken address of the Coinvest token.
    **/
    function Bank(address _coinvestToken)
      public
    {
        coinvestToken = CoinvestToken(_coinvestToken);
    }
    
/** ****************************** Only Investment ****************************** **/
    
    /**
     * @dev Investment contract needs to be able to disburse funds to users.
     * @param _to Address to send funds to.
     * @param _value Amount of funds to send to _to.
    **/
    function transfer(address _to, uint256 _value)
      external
      onlyPrivileged
    returns (bool success)
    {
       assert(coinvestToken.transfer(_to, _value));
       return true;
    }
    
}
