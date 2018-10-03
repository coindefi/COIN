pragma solidity ^0.4.24;
import './Ownable.sol';
import './ERC20Interface.sol';
import './SafeMathLib.sol';

contract UserData is Ownable {
    using SafeMathLib for uint256;

    // Contract that is allowed to modify user holdings (investment.sol).
    address public investmentAddress;
    
    // Address => crypto Id => amount of crypto wei held
    mapping (address => mapping (uint256 => uint256)) public userHoldings;

    /**
     * @param _investmentAddress Beginning address of the investment contract that may modify holdings.
    **/
    constructor(address _investmentAddress) 
      public
    {
        investmentAddress = _investmentAddress;
    }
    
    /**
     * @dev Investment contract has permission to modify user's holdings on a buy or sell.
     * @param _beneficiary The user who is buying or selling tokens.
     * @param _cryptoIds The IDs of the cryptos being bought and sold.
     * @param _amounts The amount of each crypto being bought and sold.
     * @param _buy True if the purchase is a buy, false if it is a sell.
    **/
    function modifyHoldings(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _buy)
      external
    {
        require(msg.sender == investmentAddress);
        require(_cryptoIds.length == _amounts.length);
        
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            if (_buy) {
                userHoldings[_beneficiary][_cryptoIds[i]] = userHoldings[_beneficiary][_cryptoIds[i]].add(_amounts[i]);
            } else {
                userHoldings[_beneficiary][_cryptoIds[i]] = userHoldings[_beneficiary][_cryptoIds[i]].sub(_amounts[i]);
            }
        }
    }

/** ************************** Constants *********************************** **/
    
    /**
     * @dev Return the holdings of a specific address. Returns dynamic array of all cryptos.
     *      Start and end is used in case there are a large number of cryptos in total.
     * @param _beneficiary The address to check balance of.
     * @param _start The beginning index of the array to return.
     * @param _end The (inclusive) end of the array to return.
    **/
    function returnHoldings(address _beneficiary, uint256 _start, uint256 _end)
      external
      view
    returns (uint256[] memory holdings)
    {
        require(_start <= _end);
        
        holdings = new uint256[](_end.sub(_start)+1); 
        for (uint256 i = 0; i < holdings.length; i++) {
            holdings[i] = userHoldings[_beneficiary][_start+i];
        }
        return holdings;
    }
    
/** ************************** Only Owner ********************************** **/
    
    /**
     * @dev Used to switch out the investment contract address to a new one.
     * @param _newAddress The address of the new investment contract.
    **/
    function changeInvestment(address _newAddress)
      external
      onlyOwner
    {
        investmentAddress = _newAddress;
    }
    
/** ************************** Only Coinvest ******************************* **/
    
    /**
     * @dev Allow the owner to take Ether or tokens off of this contract if they are accidentally sent.
     * @param _tokenContract The address of the token to withdraw (0x0 if Ether).
    **/
    function tokenEscape(address _tokenContract)
      external
      onlyCoinvest
    {
        if (_tokenContract == address(0)) coinvest.transfer(address(this).balance);
        else {
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
        
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            lostToken.transfer(coinvest, stuckTokens);
        }    
    }
    
}
