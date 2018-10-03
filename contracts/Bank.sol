pragma solidity ^0.4.24;
import './Ownable.sol';
import './ERC20Interface.sol';

/**
 * @title Bank
 * @dev Bank holds all user funds so Investment contract can easily be replaced.
**/
contract Bank is Ownable {
    
    address public investmentAddr;      // Investment contract address used to allow withdrawals
    address public coinToken;           // COIN token address.
    address public cashToken;           // CASH token address.

    /**
     * @param _coinToken address of the Coinvest token.
     * @param _cashToken address of the CASH token.
    **/
    constructor(address _coinToken, address _cashToken)
      public
    {
        coinToken = _coinToken;
        cashToken = _cashToken;
    }

/** ****************************** Only Investment ****************************** **/
    
    /**
     * @dev Investment contract needs to be able to disburse funds to users.
     * @param _to Address to send funds to.
     * @param _value Amount of funds to send to _to.
     * @param _isCoin True if the crypto to be transferred is COIN, false if it is CASH.
    **/
    function transfer(address _to, uint256 _value, bool _isCoin)
      external
    returns (bool success)
    {
        require(msg.sender == investmentAddr);

        ERC20Interface token;
        if (_isCoin) token = ERC20Interface(coinToken);
        else token = ERC20Interface(cashToken);

        require(token.transfer(_to, _value));
        return true;
    }
    
/** ******************************* Only Owner ********************************** **/
    
    /**
     * @dev Owner may change the investment address when contracts are being updated.
     * @param _newInvestment The address of the new investment contract.
    **/
    function changeInvestment(address _newInvestment)
      external
      onlyOwner
    {
        require(_newInvestment != address(0));
        investmentAddr = _newInvestment;
    }
    
/** ****************************** Only Coinvest ******************************* **/

    /**
     * @dev Allow the owner to take non-COIN Ether or tokens off of this contract if they are accidentally sent.
     * @param _tokenContract The address of the token to withdraw (0x0 if Ether)--cannot be COIN.
    **/
    function tokenEscape(address _tokenContract)
      external
      onlyCoinvest
    {
        require(_tokenContract != coinToken && _tokenContract != cashToken);
        if (_tokenContract == address(0)) coinvest.transfer(address(this).balance);
        else {
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
        
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            lostToken.transfer(coinvest, stuckTokens);
        }    
    }

}
