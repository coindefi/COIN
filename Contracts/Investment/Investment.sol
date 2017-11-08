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

    //RojaxToken token;
    // Has investing and liquidating been paused (may not do either function if so)
    bool public tradingPaused;
    
    // Brokers that are allowed to buy and sell for customers. They can NOT take money,
    // but can mess around with investments so trust is necessary. Only Coinvest to start.
    mapping (address => bool) public allowedBrokers;
    
    mapping (uint256 => CryptoAsset) public cryptoAssets;

    // Mapping of arrays of all the cryptos a user holds
    mapping (address => uint256[]) public userCryptos;
    
    // Mapping of arrays of all the cryptos a user is shorting
    mapping (address => uint256[]) public userShortCryptos;
    
    // The tokens and number of tokens held by each user: user => cryptoId => amount held
    mapping (address => mapping (uint256 => uint256)) public userHoldings;
    
    // The amount and initial prices of shorts held by users: user => crypto ID => (amount, intial price)[]
    // Each short must be saved separately in an array because we must save each trade's initial price
    mapping (address => mapping (uint256 => ShortInfo[])) public userShortHoldings;

    event Invest(address indexed buyer, bytes32 indexed fundName, uint256[] cryptoIds, uint256[] amounts, bool[] shorts, address indexed broker);
    event Liquidate(address indexed seller, bytes32 indexed fundName, uint256[] cryptoIds, uint256[] amounts, address indexed broker);

    struct CryptoAsset {
        uint256 cryptoId;           // Assigned unique ID fo the crypto
        string name;                // Symbol of the crypto
        uint256 price;              // In USD / 10^18
        uint256 decimals;           // Number of decimal places the crypto has
    }
    
    struct ShortInfo {
        uint256 amount;             // The unique ID of the crypto being shorted
        uint256 investAmount;       // Original amount invested: 2 * amount * originalPrice to account for price rise
        uint256 originalPrice;      // The price that the short was initiated at
    }

/** ********************************** Defaults ************************************* **/
    
    /**
     * @dev Owner declaration will be changed to Ownable.solidity
    **/
    function Investment() public {
        //token = new RojaxToken();
    }
    
/** ********************************** External ************************************* **/
    
    /**
     * @dev Broker (or buyer) will call invest and may buy or short.
     * @param _beneficiary The address that is being bought for
     * @param _fundName The name the broker chooses for this combination of cryptonized assets
     * @param _cryptoIds The list of uint IDs for each crypto to buy
     * @param _amounts The amounts of each crypto to buy (measured in COIN wei!)
    **/
    function invest(address _beneficiary, bytes32 _fundName, uint256[] _cryptoIds, uint256[] _amounts, bool[] _shorts)
      onlyBrokerOrSender(_beneficiary)
      tradeable()
      external
    returns (bool success)
    {
        require(_cryptoIds.length == _amounts.length && _amounts.length == _shorts.length);
        
        uint256 investAmount;
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            CryptoAsset storage crypto = cryptoAssets[_cryptoIds[i]];
            uint256 amount = _amounts[i];
            require(crypto.price > 0 && amount > 0);
            
            if (_shorts[i]) {
                investAmount += short(_beneficiary, crypto.cryptoId, amount);
            } else {
                investAmount += buy(_beneficiary, crypto.cryptoId, amount);
            }
        }

        //uint256 fee = investAmount / 1000;
        //token.transferFrom(msg.sender, owner, fee);
        //token.transferFrom(msg.sender, this, investAmount - fee);
        Invest(_beneficiary, _fundName, _cryptoIds, _amounts, _shorts, msg.sender);
        return true;
    }
    
    /**
     * @dev function buy *buys* a single crypto (as opposed to shorting).
     * @param _beneficiary The address of the buyer
     * @param _cryptoId The unique ID for the crypto being bought
     * @param _amount The amount of the crypto to buy
    **/
    function buy(address _beneficiary, uint256 _cryptoId, uint256 _amount) 
      internal
    returns (uint256 investAmount)
    {
        // Add the crypto to the array of user's holdings if not already there
        if (userHoldings[_beneficiary][_cryptoId] == 0) {
            userCryptos[_beneficiary].push(_cryptoId);
        }
            
        // Add crypto amounts to user Holdings
        // SafeMath prevents (unlikely) overflow
        userHoldings[_beneficiary][_cryptoId] = userHoldings[_beneficiary][_cryptoId].add(_amount);
            
        // Keep track of the COIN value of the investment to later accept as payment
        investAmount = investAmount.add(calculateCoinValue(_cryptoId, _amount));
        return investAmount;
    }
    
    /**
     * @dev function short *shorts* a single crypto (as opposed to buying).
     * @param _beneficiary The address of the buyer
     * @param _cryptoId The unique ID of the crypto to short
     * @param _amount The amount of the crypto to short
    **/
    function short(address _beneficiary, uint256 _cryptoId, uint256 _amount)
      internal
    returns (uint256 investAmount)
    {
        // Find how much the user must pay to makes this investment
        investAmount = investAmount.add(calculateCoinValue(_cryptoId, _amount));
        ShortInfo memory shortInfo = ShortInfo(_amount, investAmount, cryptoAssets[_cryptoId].price);

        // Add the crypto to the array of user's holdings if not already there
        if (userShortHoldings[_beneficiary][_cryptoId].length == 0) {
            userShortCryptos[_beneficiary].push(_cryptoId);
        }

        // Add crypto amounts to user Holdings
        // SafeMath prevents (unlikely) overflow
        userShortHoldings[_beneficiary][_cryptoId].push(shortInfo);
        
        return investAmount;
    }
    
    /**
     * @dev Broker will call this for an investor to sell one or multiple assets.
     * @dev Broker has the ability to sell whenever--trust, yes--terrible, no.
     * @dev Can fix this by having a user approve a sale, but this saves gas.
     * @param _beneficiary The address that is being sold for
     * @param _fundName The name the broker chooses for this combination of cryptonized assets
     * @param _cryptoIds The list of uint IDs for each crypto
     * @param _amounts The amounts of each crypto to sell (measured in COIN wei!)
    **/
    function liquidate(address _beneficiary, bytes32 _fundName, uint256[] _cryptoIds, uint256[] _amounts, bool[] _shorts)
      onlyBrokerOrSender(_beneficiary)
      tradeable()
      external
    returns (bool success)
    {
        require(_cryptoIds.length == _amounts.length && _amounts.length == _shorts.length);
        
        uint256 withdrawAmount;
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            uint256 cryptoId = _cryptoIds[i];
            uint256 amount = _amounts[i];
            require(amount > 0);
            
            if (_shorts[i]) {
                withdrawAmount += cover(_beneficiary, cryptoId, amount);
            } else {
                withdrawAmount += sell(_beneficiary, cryptoId, amount);
            }
        }

        //uint256 fee = withdrawAmount / 1000;
        //token.transfer(owner, fee);
        //token.transfer(_beneficiary, withdrawAmount - fee);
        Liquidate(_beneficiary, _fundName, _cryptoIds, _amounts, msg.sender);
        return true;
    }
    
    function sell(address _beneficiary, uint256 _cryptoId, uint256 _amount)
      internal
    returns (uint256 withdrawAmount)
    {
        require(_amount > 0);
            
        // Add crypto amounts to user Holdings
        // SafeMath sub ensures underflow safety
        userHoldings[_beneficiary][_cryptoId] = userHoldings[_beneficiary][_cryptoId].sub(_amount);

        // If balance is decremented to 0, remove holding from user's list            
        if (userHoldings[_beneficiary][_cryptoId] == 0) { 
            deleteHolding(_cryptoId, _beneficiary, false);
        }
            
        // Keep track of the COIN value of the investment to later accept as payment
        withdrawAmount = withdrawAmount.add(calculateCoinValue(_cryptoId, _amount));
        return withdrawAmount;
    }
    
    function cover(address _beneficiary, uint256 _cryptoId, uint256 _amount) 
      internal
    returns (uint256 withdrawAmount)
    {
        require(_amount > 0);
        
        // Total amount covered (added to after each trade that doesn't complete cover)
        uint256 amountCovered;
        
        for (uint256 i = 0; i < userShortHoldings[_beneficiary][_cryptoId].length; i++) {
            ShortInfo memory shortInfo = userShortHoldings[_beneficiary][_cryptoId][i];
            
            // Amount of crypto that was shorted in this particular trade
            uint256 tradeAmount = shortInfo.amount;
            amountCovered += tradeAmount;

            // Amount that needs to be covered from this trade
            uint256 coverAmount;

            // If we've exceeded the total amount to be covered, cover only a fraction of the trade
            if (amountCovered >= _amount) {
                coverAmount = amountCovered.sub(_amount);
            } else {
                coverAmount = tradeAmount;
            }

            // Add crypto amounts to user Holdings
            // SafeMath sub ensures underflow safety
            shortInfo.amount = shortInfo.amount.sub(coverAmount);

            uint256 investPercent = coverAmount * 0xffffff / tradeAmount;
            uint256 investAmount = shortInfo.investAmount * investPercent / 0xffffff;
            
            withdrawAmount += calculateShortValue(_cryptoId, investAmount, coverAmount);

            // If balance is decremented to 0, remove holding from user's list            
            if (shortInfo.amount == 0) { 
                deleteHolding(_cryptoId, _beneficiary, true);
            }
        }
        // By the way, these returns aren't necessary but the explicitiveness is nice.
        // They may be taken out later if we want to save the tiny amount of gas.
        return withdrawAmount;
    }
    
    /**
     * @dev Returns an array of crypto asset IDs that the user has holdings in.
     * @dev Must go through normal holdings first then short holdings after.
     * @param _user The user whose holdings should be checked
    **/
    function holdings(address _user)
      external
      constant
    returns (uint256 coinValue)
    {
        uint256[] storage cryptos = userCryptos[_user];
        for (uint256 i = 0; i < cryptos.length; i++) {
            CryptoAsset storage crypto = cryptoAssets[cryptos[i]];
            uint256 holding = userHoldings[_user][crypto.cryptoId];
            
            uint256 cryptoValue = calculateCoinValue(crypto.cryptoId, holding);
            coinValue = coinValue.add(cryptoValue);
        }

        uint256[] storage shortCryptos = userShortCryptos[_user];
        for (uint256 j = 0; j < shortCryptos.length; j++) {
            CryptoAsset storage shortCrypto = cryptoAssets[shortCryptos[j]];
            ShortInfo[] storage shortHoldings = userShortHoldings[_user][shortCrypto.cryptoId];

            for (uint256 k = 0; k < shortHoldings.length; k++) {
                uint256 shortCryptoValue = calculateShortValue(shortCrypto.cryptoId, shortHoldings[k].amount, shortHoldings[k].investAmount);
                coinValue = coinValue.add(shortCryptoValue);
                //coinValue += shortCryptoValue;   
            }
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
    function deleteHolding(uint256 _cryptoId, address _user, bool _short)
      internal
    returns (bool success)
    {
        if (_short) {
            uint256[] storage shortHoldings = userShortCryptos[_user];
            for (uint256 i = 0; i < shortHoldings.length; i++) {
                if (shortHoldings[i] == _cryptoId) {
                    shortHoldings[i] = shortHoldings[shortHoldings.length - 1];
                    shortHoldings.length--;
                    return true;
                }
            }
        }

        uint256[] storage holdings = userCryptos[_user];
        for (uint256 j = 0; j < holdings.length; j++) {
            if (holdings[j] == _cryptoId) {
                holdings[j] = holdings[holdings.length - 1];
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
      internal view
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
        coinAmount = eachTokenValue * _amount / cryptoAssets[0].price; 
        return coinAmount;
    }
    
    function calculateShortValue(uint256 _cryptoId, uint256 _amount, uint256 _investAmount)
      internal
      view
    returns (uint256 coinAmount)
    {
        uint256 currentValue = calculateCoinValue(_cryptoId, _amount);
        uint256 returnAmount;
        if (_investAmount * 2 >= currentValue) {
            returnAmount = _investAmount * 2 - currentValue;
            uint256 returnPercent = returnAmount * 0xffffff / _investAmount;
            coinAmount = _investAmount * returnPercent / (100 * 0xffffff);
        }
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
        
        for (uint256 i = 0; i < _cryptoIds.length; i++) {
            require(cryptoAssets[_cryptoIds[i]].price > 0);
            cryptoAssets[_cryptoIds[i]].price = _prices[i];
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
    
    /**
     * @dev Owner can call to stop any trading activity on the contract.
     * @dev Useful when this contract becomes deprecated but maybe a ransom risk?
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
     * @dev themselves to mess with the buyer/seller's portfolio
     * @param beneficiary The buyer or seller whose portfolio is being modified
    **/
    modifier onlyBrokerOrSender(address beneficiary)
    {
        require(allowedBrokers[msg.sender] || msg.sender == beneficiary);
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
