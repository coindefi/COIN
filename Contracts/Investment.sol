pragma solidity ^0.4.17;
import './Math/SafeMath.sol';
import './Ownership/OwnableOracle.sol';

/**
 * @dev This contract accepts COIN deposit with a list of every crypto in desired portfolio
 * @dev (and the % of each) stores this information, then disburses withdrawals when requested
 * @dev in COIN depending on the new price of the coins in the portfolio
**/

contract Token { 
    function transfer(address _to, uint256 _value) returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool);
}

contract Investment is OwnableOracle {
    using SafeMath for uint256;

    Token token;
    
    // Brokers that are allowed to buy and sell for customers. They can NOT take money,
    // but can mess around with investments so trust is necessary. Only Coinvest to start.
    mapping (address => bool) public allowedBrokers;
    
    // Mapping that keeps track of the lowest denomination of each crypto (all lowercase)
    mapping (string => uint256) public cryptoDecimals;
    
    // Mapping of the current market price of each crypto (in USD / 10e18 and all lowercase)
    mapping (string => uint256) public cryptoPrices;
    
    // Mapping of arrays of all the cryptos users hold
    mapping (address => string[]) userCryptos;
    
    // The tokens and number of tokens held by each user (all lowercase)
    mapping (address => mapping (string => uint256)) public userHoldings;

    event Buy(address indexed buyer, string[] indexed symbols, uint256[] indexed amounts, address broker);
    event Sell(address indexed seller, string[] indexed symbols, uint256[] indexed amounts, address broker);

/** ********************************** Defaults ************************************* **/
    
    /**
     * @dev Owner declaration will be changed to Ownable.solidity
     * @param _token Address of the COIN token so contract can transfer them
    **/
    function Investment(address _token)
    {
        require(_token != 0);
        
        token = Token(_token);
    }
    
    /**
     * @dev If anyone tries to send Ether here, revert.
    **/
    function ()
      public
      payable
    {
        revert();
    }
    
/** ********************************** External ************************************* **/
    
    /**
     * @dev Broker will call this for an investor to invest in one or multiple assets
     * @param _beneficiary The address that is being bought for
     * @param _symbols The symbol for each crypto to invest in
     * @param _amounts The amounts of each crypto to buy (measured in COIN wei!)
    **/
    function buy(address _beneficiary, string[] _symbols, uint256[] _amounts)
      onlyBrokerOrSender(_beneficiary)
      external
    returns (bool success)
    {
        require(_symbols.length == _amounts.length);
        
        uint256 investAmount;
        for (uint256 i = 0; i < _symbols.length; i++)
        {
            string memory crypto = _symbols[i];
            uint256 amount = _amounts[i];
            require(cryptoPrices[crypto] > 0 && amount > 0);
            
            // Add the crypto to the array of user's holdings if not already there
            if (userHoldings[_beneficiary][crypto] == 0) userCryptos[_beneficiary].push(crypto);
            
            // Add crypto amounts to user Holdings
            // SafeMath prevents (unlikely) overflow
            userHoldings[_beneficiary][crypto] = userHoldings[_beneficiary][crypto].add(amount);
            
            // Keep track of the COIN value of the investment to later accept as payment
            investAmount = investAmount.add(calculateCoinValue(crypto, amount));
        }
        assert(token.transferFrom(msg.sender, this, investAmount));
        Buy(_beneficiary, _symbols, _amounts, msg.sender);
        return true;
    }
    
    /**
     * @dev Broker will call this for an investor to sell one or multiple assets.
     * @dev Broker has the ability to sell whenever--trust, yes--terrible, no.
     * @dev Can fix this by having a user approve a sale, but this saves gas.
     * @param _beneficiary The address that is being sold for
     * @param _symbols The symbol for each crypto to sell
     * @param _amounts The amounts of each crypto to sell (measured in COIN wei!)
    **/
    function sell(address _beneficiary, string[] _symbols, uint256[] _amounts)
      onlyBrokerOrSender(_beneficiary)
      external
    returns (bool success)
    {
        require(_symbols.length == _amounts.length);
        
        uint256 withdrawAmount;
        for (uint256 i = 0; i < _symbols.length; i++)
        {
            string memory crypto = _symbols[i];
            uint256 amount = _amounts[i];
            require(cryptoPrices[crypto] > 0 && amount > 0);
            
            // Add crypto amounts to user Holdings
            // SafeMath sub ensures underflow safety
            userHoldings[_beneficiary][crypto].sub(amount);

            // If balance is decremented to 0, remove holding from user's list            
            if (userHoldings[_beneficiary][crypto] == 0) deleteHolding(crypto, _beneficiary);
            
            // Keep track of the COIN value of the investment to later accept as payment
            withdrawAmount = withdrawAmount.add(calculateCoinValue(crypto, amount));
        }
        assert(token.transfer(_beneficiary, withdrawAmount));
        Sell(_beneficiary, _symbols, _amounts, msg.sender);
        return true;
    }
    
    function holdings(address _user)
      external
      constant
    returns (string[] cryptos)
    {
        return userCryptos[_user];
    }
    
/** ********************************** Internal ************************************** **/

    /**
     * @dev Deletes the crypto symbol from user's userCryptos array.
     * @dev Only called from sell when holdings for the crypto decrements to 0.
     * @param _symbol The symbol of the crypto to be taken off the user's list
     * @param _user The user whose holdings must be changed
    **/
    function deleteHolding(string _symbol, address _user)
      internal
    returns (bool success)
    {
        string[] storage holdings = userCryptos[_user];
        for (uint256 i = 0; i < holdings.length; i++)
        {
            if (stringsEqual(holdings[i], _symbol)) 
            {
                holdings[i] = holdings[holdings.length - 1];
                holdings.length--;
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Solidity needs this to compare two strings (for crypto symbols)
     * @param _a First string for the comparison
     * @param _b Second string for the comparison
    **/
    function stringsEqual(string storage _a, string memory _b) 
      internal 
    returns (bool equal) 
    {
		bytes storage a = bytes(_a);
		bytes memory b = bytes(_b);
		
		if (a.length != b.length)
			return false;
		
		for (uint i = 0; i < a.length; i ++)
		{
			if (a[i] != b[i]) return false;
		}
		return true;
	}

    /**
     * @dev Calculates how many COIN wei an amount of a crypto asset is worth
     * @param _symbol The symbol of the cryptonized asset
     * @param _amount The amount of the cryptonized asset desired
    **/
    function calculateCoinValue(string _symbol, uint256 _amount)
      internal
    returns (uint256 coinAmount)
    {
        uint256 currentCoinValue = cryptoPrices['coin'];
        uint256 tokenValue = cryptoPrices[_symbol];
        
        // We must get the coinAmount in COIN "wei" so coin is made 18 decimals longer
        // eachTokenValue finds the amount of COINs 1 token is worth
        uint256 eachTokenValue = tokenValue * (10 ** 18) / currentCoinValue;
        
        // We must now find the COIN value of the desired amount of the token
        // _amount will be given in native token "wei" so we must make sure we account for that
        coinAmount = eachTokenValue * (10 ** cryptoDecimals[_symbol]) / _amount; 
        return coinAmount;
    }
    
/** ********************************* Only Oracle *********************************** **/
    
    /**
     * @dev Oracle sets the current market price for all used cryptos
     * @param _symbols Market symbols of the cryptos
     * @param _prices The new market prices of the cryptos
    **/
    function setPrices(string[] _symbols, uint256[] _prices)
      onlyOracle
      external
    returns (bool success)
    {
        require(_symbols.length == _prices.length);
        
        for (uint256 i = 0; i < _symbols.length; i++)
        {
            require(cryptoPrices[_symbols[i]] > 0);
            cryptoPrices[_symbols[i]] == _prices[i];
        }
        return true;
    }
    
/** ********************************* Only Owner ************************************* **/
    
    /**
     * @dev Adds a new crypto for investing
     * @param _symbol Market symbol of the new crypto
     * @param _decimals How many decimal places the crypto has
     * @param _price Current market price to begin the crypto selling at
    **/
    function addCrypto(string _symbol, uint256 _decimals, uint256 _price)
      onlyOwner
      external
    returns (bool success)
    {
        require(_decimals > 0 && _price > 0);
        
        cryptoDecimals[_symbol] = _decimals;
        cryptoPrices[_symbol] = _price;
        return true;
    }
    
    /**
     * @dev Owner can either add or remove a broker from allowedBrokers.
     * @dev At the beginning this will only be the Coinvest frontend.
     * @param _broker The address of the broker whose status will be modified
     * @param _add True if the broker is being added, False if the broker is being deleted
    **/
    function modifyBroker(address _broker, bool _add)
      onlyOwner
      external
    returns (bool success)
    {
        require(_broker != 0);
        
        allowedBrokers[_broker] = _add;
        return true;
    }
    
/** ********************************* Modifiers ************************************* **/
    
    /**
     * @dev For buys and sells we only want an approved broker or the buyer/seller
     * @dev themselves to mess with the buyer/seller's portfolio
     * @param beneficiary The buyer or seller whose portfolio is being modified
    **/
    modifier onlyBrokerOrSender(address beneficiary)
    {
        require(allowedBrokers[msg.sender] || msg.sender == beneficiary);
        _;
    }
}
