pragma solidity ^0.4.17;
import './SafeMath.sol';
import './OwnableOracle.sol';
import './StandardToken.sol';

/**
 * @dev This contract accepts COIN deposit with a list of every crypto in desired portfolio
 * @dev (and the % of each) stores this information, then disburses withdrawals when requested
 * @dev in COIN depending on the new price of the coins in the portfolio
**/

contract Investment is OwnableOracle {
    using SafeMath for uint256;

    RojaxToken token;
    
    // Brokers that are allowed to buy and sell for customers. They can NOT take money,
    // but can mess around with investments so trust is necessary. Only Coinvest to start.
    mapping (address => bool) public allowedBrokers;
    
    mapping (uint256 => CryptoAsset) public cryptoAssets;

    // Mapping of arrays of all the cryptos a user holds
    mapping (address => uint256[]) public userCryptos;
    
    // The tokens and number of tokens held by each user: user => cryptoId => amount held
    mapping (address => mapping (uint256 => uint256)) public userHoldings;

    event Buy(address indexed buyer, uint256[] indexed cryptoIds, uint256[] indexed amounts, address broker);
    event Sell(address indexed seller, uint256[] indexed cryptoIds, uint256[] indexed amounts, address broker);

    struct CryptoAsset
    {
        uint256 cryptoId;
        string name;
        uint256 price;
        uint256 decimals;
    }

/** ********************************** Defaults ************************************* **/
    
    /**
     * @dev Owner declaration will be changed to Ownable.solidity
    **/
    function Investment()
    {
        token = new RojaxToken();
    }
    
/** ********************************** External ************************************* **/
    
    /**
     * @dev Broker will call this for an investor to invest in one or multiple assets
     * @param _beneficiary The address that is being bought for
     * @param _cryptoIds The list of uint IDs for each crypto to buy
     * @param _amounts The amounts of each crypto to buy (measured in COIN wei!)
    **/
    function buy(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts)
      onlyBrokerOrSender(_beneficiary)
      external
    returns (bool success)
    {
        require(_cryptoIds.length == _amounts.length);
        
        uint256 investAmount;
        for (uint256 i = 0; i < _cryptoIds.length; i++)
        {
            uint256 cryptoId = _cryptoIds[i];
            uint256 amount = _amounts[i];
            require(cryptoAssets[cryptoId].price > 0 && amount > 0);
            
            // Add the crypto to the array of user's holdings if not already there
            if (userHoldings[_beneficiary][cryptoId] == 0) userCryptos[_beneficiary].push(cryptoId);
            
            // Add crypto amounts to user Holdings
            // SafeMath prevents (unlikely) overflow
            userHoldings[_beneficiary][cryptoId] = userHoldings[_beneficiary][cryptoId].add(amount);
            
            // Keep track of the COIN value of the investment to later accept as payment
            investAmount = investAmount.add(calculateCoinValue(cryptoId, amount));
        }
        //token.transferFrom(msg.sender, this, investAmount);
        Buy(_beneficiary, _cryptoIds, _amounts, msg.sender);
        return true;
    }
    
    /**
     * @dev Broker will call this for an investor to sell one or multiple assets.
     * @dev Broker has the ability to sell whenever--trust, yes--terrible, no.
     * @dev Can fix this by having a user approve a sale, but this saves gas.
     * @param _beneficiary The address that is being sold for
     * @param _cryptoIds The list of uint IDs for each crypto
     * @param _amounts The amounts of each crypto to sell (measured in COIN wei!)
    **/
    function sell(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts)
      onlyBrokerOrSender(_beneficiary)
      external
    returns (bool success)
    {
        require(_cryptoIds.length == _amounts.length);
        
        uint256 withdrawAmount;
        for (uint256 i = 0; i < _cryptoIds.length; i++)
        {
            uint256 cryptoId = _cryptoIds[i];
            uint256 amount = _amounts[i];
            require(cryptoAssets[cryptoId].price > 0 && amount > 0);
            
            // Add crypto amounts to user Holdings
            // SafeMath sub ensures underflow safety
            userHoldings[_beneficiary][cryptoId].sub(amount);

            // If balance is decremented to 0, remove holding from user's list            
            if (userHoldings[_beneficiary][cryptoId] == 0) deleteHolding(cryptoId, _beneficiary);
            
            // Keep track of the COIN value of the investment to later accept as payment
            withdrawAmount = withdrawAmount.add(calculateCoinValue(cryptoId, amount));
        }
        //token.transfer(_beneficiary, withdrawAmount);
        Sell(_beneficiary, _cryptoIds, _amounts, msg.sender);
        return true;
    }
    
    /**
     * @dev Returns an array of crypto asset IDs that the user has holdings in
     * @param _user The user whose holdings should be checked
    **/
    function holdings(address _user)
      external
      constant
    returns (uint256 coinValue)
    {
        uint256[] cryptos = userCryptos[_user];
        for (uint256 i = 0; i < cryptos.length; i++)
        {
            CryptoAsset crypto = cryptoAssets[cryptos[i]];
            uint256 holding = userHoldings[_user][crypto.cryptoId];
            
            uint256 cryptoValue = calculateCoinValue(crypto.price, holding);
            coinValue += cryptoValue;
        }
        return coinValue;
    }
    
/** ********************************** Internal ************************************** **/

    /**
     * @dev Deletes the crypto symbol from user's userCryptos array.
     * @dev Only called from sell when holdings for the crypto decrements to 0.
     * @param _cryptoId The symbol of the crypto to be taken off the user's list
     * @param _user The user whose holdings must be changed
    **/
    function deleteHolding(uint256 _cryptoId, address _user)
      internal
    returns (bool success)
    {
        uint256[] storage holdings = userCryptos[_user];
        for (uint256 i = 0; i < holdings.length; i++)
        {
            if (holdings[i] == _cryptoId) 
            {
                holdings[i] = holdings[holdings.length - 1];
                holdings.length--;
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Calculates how many COIN wei an amount of a crypto asset is worth
     * @param _cryptoId The symbol of the cryptonized asset
     * @param _amount The amount of the cryptonized asset desired
    **/
    function calculateCoinValue(uint256 _cryptoId, uint256 _amount)
      internal
    returns (uint256 coinAmount)
    {
        CryptoAsset memory crypto = cryptoAssets[_cryptoId];
        uint256 currentCoinValue = crypto.price;
        uint256 tokenValue = cryptoAssets[0].price;
        
        // We must get the coinAmount in COIN "wei" so coin is made 18 decimals longer
        // eachTokenValue finds the amount of COINs 1 token is worth
        uint256 eachTokenValue = tokenValue * (10 ** 18) / currentCoinValue;
        
        // We must now find the COIN value of the desired amount of the token
        // _amount will be given in native token "wei" so we must make sure we account for that
        coinAmount = eachTokenValue * (10 ** crypto.decimals) / _amount; 
        return coinAmount;
    }
    
/** ********************************* Only Oracle *********************************** **/
    
    /**
     * @dev Oracle sets the current market price for all used cryptos
     * @param _cryptoIds Market symbols of the cryptos
     * @param _prices The new market prices of the cryptos
    **/
    function setPrices(uint256[] _cryptoIds, uint256[] _prices)
      onlyOracle
      external
    returns (bool success)
    {
        require(_cryptoIds.length == _prices.length);
        
        for (uint256 i = 0; i < _cryptoIds.length; i++)
        {
            require(cryptoAssets[_cryptoIds[i]].price > 0);
            cryptoAssets[_cryptoIds[i]].price == _prices[i];
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
    function addCrypto(uint256 _cryptoId, string _symbol, uint256 _price, uint256 _decimals)
      onlyOwner
      external
    returns (bool success)
    {
        require(_decimals > 0 && _price > 0);
        
        CryptoAsset memory crypto = CryptoAsset(_cryptoId, _symbol, _price, _decimals);
        cryptoAssets[_cryptoId] = crypto;
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
