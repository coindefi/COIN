pragma solidity ^0.4.17;
import './SafeMath.sol';
import './OwnableOracle.sol';
//import './CoinvestToken.sol';

/**
 * @dev This contract accepts COIN deposit with a list of every crypto in desired portfolio
 * @dev (and the % of each) stores this information, then disburses withdrawals when requested
 * @dev in COIN depending on the new price of the coins in the portfolio
**/

contract Investment is OwnableOracle {
    using SafeMath for uint256;

    //CoinvestToken token;
    bool public tradingPaused; // Owner may pause trading in case of an error in the contract.
    uint256 public totalCryptos; // Number of cryptos currently supported. We use this to loop through holdings.

    
    mapping (address => bool) public allowedBrokers; // Addresses allowed to buy and sell for users.
    mapping (uint256 => CryptoAsset) public cryptoAssets; // All information on each supported crypto.
    
    // User address => cryptoId => array of info for each trade for that crypto
    mapping (address => mapping (uint256 => Holding[])) public userHoldings;
    
    event Invest(address indexed buyer, uint256[] indexed cryptoIds, uint256[] amounts, bool[] indexed shorts, address broker);
    event Liquidate(address indexed seller, uint256[] indexed cryptoIds, uint256[] amounts, bool[] indexed shorts, address broker);
    
    /**
     * @dev CryptoAsset represents all the information of a supported crpto.
    **/
    struct CryptoAsset {
        uint256 cryptoId;           // Assigned unique ID for the crypto.
        string name;                // Symbol of the crypto.
        uint256 price;              // In USD / 10^18
        uint256 decimals;           // Number of decimal places the crypto has.
    }

    /**
     * @dev Holding represents information for a single trade of a certain crypto.
    **/
    struct Holding {
        uint256 cryptoId;           // Assigned unique ID for the crypto.
        uint256 amount;             // Amount (in the crypto's wei) that you bought in this trade.
        uint256 initialPrice;       // Price at which this trade was made.
        uint256 investAmount;
        bool short;
    }
    
/** ********************************** External ************************************* **/
    
    /**
     * @dev Broker (or buyer) will call invest to buy or short an array (could be just 1) of cryptos.
     * @param _beneficiary The address that is being bought for.
     * @param _cryptoIds The list of uint IDs for each crypto to buy.
     * @param _amounts The amounts of each crypto to buy (measured in COIN wei!).
     * @param _shorts Whether or not this crypto trade is a short.
    **/
    function invest(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool[] _shorts)
      external
      onlyBrokerOrSender(_beneficiary)
      tradeable()
    returns (bool success)
    {
        require(_cryptoIds.length == _amounts.length && _amounts.length == _shorts.length);
        
        uint256 investAmount;
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            uint256 currentPrice = cryptoAssets[_cryptoIds[i]].price;
            require(currentPrice > 0 && _amounts[i] > 0);
            
            // Execute a single buy for each of the desired buys/shorts.
            investAmount += buy(_beneficiary, _cryptoIds[i], _amounts[i], _shorts[i]);
        }
        
        //uint256 fee = investAmount / 1000;
        //token.transferFrom(msg.sender, owner, fee);
        //token.transferFrom(msg.sender, this, investAmount - fee);
        Invest(_beneficiary, _cryptoIds, _amounts, _shorts, msg.sender);
        return true;
    }

    /**
     * @dev Investor or broker will call this for an investor to sell one or multiple assets.
     * @param _beneficiary The address that is being sold for
     * @param _cryptoIds The list of uint IDs for each crypto
     * @param _amounts The amounts of each crypto to sell (measured in COIN wei!)
     * @param _shorts Whether or not this crypto trade is a short.
    **/
    function liquidate(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool[] _shorts)
      external
      onlyBrokerOrSender(_beneficiary)
      tradeable()
    returns (bool success)
    {
        require(_cryptoIds.length == _amounts.length && _amounts.length == _shorts.length);
        
        uint256 withdrawAmount;
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            require(_amounts[i] > 0);
            withdrawAmount += sell(_beneficiary, _cryptoIds[i], _amounts[i], _shorts[i]);
        }
        
        //uint256 fee = withdrawAmount / 1000;
        //token.transfer(owner, fee);
        //token.transfer(_beneficiary, withdrawAmount - fee);
        Liquidate(_beneficiary, _cryptoIds, _amounts, _shorts, msg.sender);
        return true;
    }
    
/** ********************************** Constants ************************************** **/
    
    /**
     * @dev holdings is used to find a user's total worth.
     * @param _user The user whose holdings should be checked.
     * @returns coinValue The combined COIN value of all of a user's holdings.
    **/
    function holdings(address _user)
      external
      constant
    returns (uint256 coinValue)
    {
        for (uint256 i = 0; i < totalCryptos; i++) {
            for (uint256 j = 0; j < userHoldings[_user][i].length; j++) 
            {
                Holding memory holding = userHoldings[_user][i][j];
                if (holding.short) {
                    coinValue += calculateShortValue(holding.cryptoId, holding.amount, holding.investAmount);
                } else {
                    coinValue += calculateCoinValue(holding.cryptoId, holding.amount);
                }
            }
        }
        return coinValue;
    }
    
    /**
     * @dev holdingLength is used to find the amount of trades a user has for each crypto.
     * @dev This is used by frontends so they can look through each trade separately.
     * @param _user The desired address to check trades of.
     * @param _cryptoId The desired cryptonized asset to check trades of.
     * @returns length The number of trades a user has executed for this specific crypto.
    **/
    function holdingLength(address _user, uint256 _cryptoId)
      external
      constant
    returns (uint256 length)
    {
        return userHoldings[_user][_cryptoId].length;
    }
    
/** ********************************** Internal ************************************** **/
    
    /**
     * @dev buy buys or shorts a single crypto for a user. Called by the invest function.
     * @param _beneficiary The address of the buyer.
     * @param _cryptoId The unique ID of the crypto to buy.
     * @param _amount The amount of the crypto to buy.
     * @param _short Whether or not this investment is a short.
     * @returns investAmount The COIN cost of this investment.
    **/
    function buy(address _beneficiary, uint256 _cryptoId, uint256 _amount, bool _short)
      internal
    returns (uint256 investAmount)
    {
        // Find how much the user must pay to makes this investment
        investAmount = calculateCoinValue(_cryptoId, _amount);
        uint256 initialPrice = cryptoAssets[_cryptoId].price;

        Holding memory holding = Holding(_cryptoId, _amount, initialPrice, investAmount, _short);
        userHoldings[_beneficiary][_cryptoId].push(holding);
        
        return investAmount;
    }
    
    /**
     * @dev sell either sells a held asset or covers a short. Called by the liquidate function.
     * @param _beneficiary The address of the investor.
     * @param _cryptoId The unique ID of the crypto to sell/cover.
     * @param _amount The amount (in crypto wei!) to sell/cover.
     * @param _short Whether or not whether this liquidation is a short.
     * @returns withdrawAmount The COIN value of this liquidation.
    **/
    function sell(address _beneficiary, uint256 _cryptoId, uint256 _amount, bool _short) 
      internal
    returns (uint256 withdrawAmount)
    {
        // Total amount sold (added to after each trade that doesn't complete sell)
        uint256 amountSold;

        for (uint256 i = 0; i < userHoldings[_beneficiary][_cryptoId].length; i++) {
            if (amountSold >= _amount) return withdrawAmount;
            
            Holding memory holding = userHoldings[_beneficiary][_cryptoId][i];
            uint256 tradeAmount = holding.amount;
            amountSold += tradeAmount;

            // Amount that needs to be sold from this trade.
            uint256 sellAmount;

            // If we've exceeded the total amount to be sold, sell only a fraction of the trade
            if (amountSold >= _amount) {
                sellAmount = tradeAmount.sub(amountSold - _amount);
            } else {
                sellAmount = tradeAmount;
            }
    
            // Subtract the amount sold from the trade.
            holding.amount = holding.amount.sub(sellAmount);

            // We need this percent to find the original investment amount of a fraction of a trade.
            uint256 investPercent = sellAmount * 0xffffff / tradeAmount;
            uint256 investAmount = holding.investAmount * investPercent / 0xffffff;
            
            if (_short) withdrawAmount += calculateShortValue(_cryptoId, investAmount, sellAmount);
            else withdrawAmount += calculateCoinValue(_cryptoId, sellAmount);

            // If balance is decremented to 0, remove this trade from userHoldings.            
            if (holding.amount == 0) delete userHoldings[_beneficiary][_cryptoId][i];
        }
        return withdrawAmount;
    }
    
    /**
     * @dev Calculates how many COIN wei an amount of a crypto asset is worth.
     * @param _cryptoId The symbol of the cryptonized asset.
     * @param _amount The amount of the cryptonized asset desired.
     * @returns coinAmount The value in COIN of this crypto position.
    **/
    function calculateCoinValue(uint256 _cryptoId, uint256 _amount)
      internal 
      view
    returns (uint256 coinAmount)
    {
        CryptoAsset memory crypto = cryptoAssets[_cryptoId];
        uint256 currentCoinValue = cryptoAssets[0].price;
        uint256 tokenValue = crypto.price;
        
        // We must get the coinAmount in COIN "wei" so coin is made 18 decimals longer
        // eachTokenValue finds the amount of COINs 1 token is worth
        uint256 eachTokenValue = tokenValue * (10 ** 18) / currentCoinValue;
        
        // We must now find the COIN value of the desired amount of the token
        // _amount will be given in native token "wei" so we must make sure we account for that
        coinAmount = eachTokenValue * _amount / (10 ** crypto.decimals); 
        return coinAmount;
    }
    
    /**
     * @dev Calculates the value of a certain short position.
     * @param _cryptoId The unique ID of the cryptonized asset.
     * @param _amount The amount of the asset that was shorted.
     * @param _investAmount The amount invested in the asset at time of purchase (in COIN).
     * @returns coinAmount The current value of this short position.
    **/
    function calculateShortValue(uint256 _cryptoId, uint256 _amount, uint256 _investAmount)
      internal
      view
    returns (uint256 coinAmount)
    {
        uint256 currentValue = calculateCoinValue(_cryptoId, _amount);

        // If current value is greater than original value * 2, the value of the short is 0.
        if (_investAmount * 2 >= currentValue) coinAmount = _investAmount * 2 - currentValue;
        return coinAmount;
    }
    
/** ********************************* Only Oracle *********************************** **/
    
    /**
     * @dev Oracle sets the current market price for all used cryptos.
     * @param _cryptoIds Market symbols of the cryptos.
     * @param _prices The new market prices of the cryptos.
    **/
    function setPrices(uint256[] _cryptoIds, uint256[] _prices)
      external
      onlyOracle
    returns (bool success)
    {
        require(_cryptoIds.length == _prices.length);
        
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            require(cryptoAssets[_cryptoIds[i]].price > 0);
            cryptoAssets[_cryptoIds[i]].price = _prices[i];
        }
        return true;
    }
    
/** ********************************* Only Owner ************************************* **/
    
    /**
     * @dev Adds a new crypto for investing.
     * @param _symbol Market symbol of the new crypto.
     * @param _decimals How many decimal places the crypto has.
     * @param _price Current market price to begin the crypto selling at.
    **/
    function addCrypto(uint256 _cryptoId, string _symbol, uint256 _price, uint256 _decimals)
      external
      onlyOwner
    returns (bool success)
    {
        require(_decimals > 0 && _price > 0);
        
        CryptoAsset memory crypto = CryptoAsset(_cryptoId, _symbol, _price, _decimals);
        cryptoAssets[_cryptoId] = crypto;
        totalCryptos++;
        return true;
    }
    
    /**
     * @dev Owner can either add or remove a broker from allowedBrokers.
     * @dev At the beginning this will only be the Coinvest frontend.
     * @param _broker The address of the broker whose status will be modified.
     * @param _add True if the broker is being added, False if the broker is being deleted.
    **/
    function modifyBroker(address _broker, bool _add)
      external
      onlyOwner
    returns (bool success)
    {
        require(_broker != 0);
        allowedBrokers[_broker] = _add;
        return true;
    }
    
    /**
     * @dev Owner can call to stop any trading activity on the contract.
     * @notice Useful when this contract becomes deprecated but maybe a ransom risk?
     * @param _stop Whether to stop (true) or start (false) the contract.
    **/
    function pauseTrading(bool _stop)
      external
      onlyOwner
    returns (bool success)
    {
        tradingPaused = _stop;
        return true;
    }
    
/** ********************************* Modifiers ************************************* **/
    
    /**
     * @dev For buys and sells we only want an approved broker or the buyer/seller
     * @dev themselves to mess with the buyer/seller's portfolio.
     * @param beneficiary The buyer or seller whose portfolio is being modified.
    **/
    modifier onlyBrokerOrSender(address _beneficiary)
    {
        require(allowedBrokers[msg.sender] || msg.sender == _beneficiary);
        _;
    }
    
    /**
     * @dev Checks whether trading has been paused.
    **/
    modifier tradeable()
    {
        require(!tradingPaused);
        _;
    }
}
