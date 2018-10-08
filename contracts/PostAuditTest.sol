pragma solidity ^0.4.24;
import './SafeMathLib.sol';
import './Ownable.sol';
import './Strings.sol';
import './UserData.sol';
import './Bank.sol';
import './ERC20Interface.sol';
//import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract PostAuditTest is Ownable//, usingOraclize 
{ 

    using SafeMathLib for uint256;
    using strings for *;
    
    Bank public bank;
    UserData public userData;
    
    address public coinToken;
    address public cashToken;
    uint256 public customGasPrice;
    string public coinUrl = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=COIN,";
    string public cashUrl = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=CASH,";
    bool public paused;
    
    uint256 public constant COIN_ID = 0;
    uint256 public constant COIN_INV = 1;
    uint256 public constant CASH_ID = 2;
    uint256 public constant CASH_INV = 3;
    
    // Stores all trade info so Oraclize can return and update.
    // idsAndAmts stores both the crypto ID and amounts with a uint8 and uint248 respectively.
    struct TradeInfo {
        bool isBuy;
        bool isCoin;
        address beneficiary;
        uint256[] idsAndAmts;
    }
    
    // Oraclize ID => TradeInfo.
    mapping(bytes32 => TradeInfo) trades;

    // Even indices are normal cryptos, odd are inverses--empty string if either does not exist.
    string[] public cryptoSymbols;

    // Balance of a user's free trades.
    mapping(address => uint256) public freeTrades;

    event newOraclizeQuery(string description);
    event Buy(address indexed buyer, uint256[] cryptoIds, uint256[] amounts, uint256[] prices, bool isCoin);
    event Sell(address indexed seller, uint256[] cryptoIds, uint256[] amounts, uint256[] prices, bool isCoin);

/** ********************************** Defaults ************************************* **/
    
    /**
     * @dev Constructor function, construct with coinvest token.
     * @param _coinToken The address of the Coinvest COIN token.
     * @param _cashToken Address of the Coinvest CASH token.
     * @param _bank Contract where all of the user Coinvest tokens will be stored.
     * @param _userData Contract where all of the user balances will be stored.
    **/
    constructor(address _coinToken, address _cashToken, address _bank, address _userData)
      public
      payable
    {
        coinToken = _coinToken;
        cashToken = _cashToken;
        bank = Bank(_bank);
        userData = UserData(_userData);

        //oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        
        addCrypto(0, "COIN,", true);
        addCrypto(0, "CASH,", true);
        addCrypto(0, "BTC,", true);
        addCrypto(0, "ETH,", true);
        addCrypto(0, "XRP,", true);
        addCrypto(0, "LTC,", true);
        addCrypto(0, "DASH,", true);
        addCrypto(0, "BCH,", true);
        addCrypto(0, "XMR,", true);
        addCrypto(0, "XEM,", true);
        addCrypto(0, "EOS,", true);

        customGasPrice = 20000000000;
        //oraclize_setCustomGasPrice(customGasPrice);
    }
  
    /**
     * @dev Used by Coinvest-associated wallets to fund the contract.
            Users may also pay within a buy or sell call if no funds are available.
    **/
    function()
      external
      payable
      onlyAdmin
    {
        
    }
  
/** *************************** ApproveAndCall FallBack **************************** **/
  
    /**
     * @dev ApproveAndCall will send us data, we'll determine if the beneficiary is the sender, then we'll call this contract.
    **/
    function receiveApproval(address _from, uint256 _amount, address _token, bytes _data) 
      public
    {
        require(msg.sender == coinToken || msg.sender == cashToken);

        // check here to make sure _from == beneficiary in data
        address beneficiary;
        assembly {
            beneficiary := mload(add(_data,36))
        }
        require(_from == beneficiary);
        
        require(address(this).delegatecall(_data));
        _token; _amount;
    }
  
/** ********************************** External ************************************* **/
    
    /**
     * @dev User calls to invest, will then call Oraclize and Oraclize adds holdings.
     * @dev User must first approve this contract to transfer enough tokens to buy.
     * @param _beneficiary The user making the call whose balance will be updated.
     * @param _cryptoIds The Ids of the cryptos to invest in.
     * @param _amounts The amount of each crypto the user wants to buy, delineated in 10 ^ 18 wei.
     * @param _isCoin True/False of the crypto that is being used to invest is COIN/CASH.
    **/
    function buy(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _isCoin)
      public
      payable
      notPaused
      onlySenderOrToken(_beneficiary)
    {
        require(_cryptoIds.length == _amounts.length);
        getPrices(_beneficiary, _cryptoIds, _amounts, _isCoin, true);
    }
    
    /**
     * @dev User calls to sell holdings with same parameters as buy.
    **/
    function sell(address _beneficiary, uint256[] _cryptoIds, uint256[] _amounts, bool _isCoin)
      public
      payable
      notPaused
      onlySenderOrToken(_beneficiary)
    {
        require(_cryptoIds.length == _amounts.length);
        getPrices(_beneficiary, _cryptoIds, _amounts, _isCoin, false);
    }
    
/** ********************************** Internal ************************************ **/
    
    /**
     * @dev Broker will call this for an investor to invest in one or multiple assets
     * @param _beneficiary The address that is being bought for
     * @param _cryptoIds The list of uint IDs for each crypto to buy
     * @param _amounts The amounts of each crypto to buy (measured in 10 ** 18 wei!)
     * @param _prices The price of each bought crypto at time of callback.
     * @param _coinValue The amount of coin to transferFrom from user.
     * @param _isCoin True/False of the crypto that is being used to invest is COIN/CASH.
    **/
    function finalizeBuy(address _beneficiary, uint256[] memory _cryptoIds, uint256[] memory _amounts, uint256[] memory _prices, uint256 _coinValue, bool _isCoin)
      internal
    {
        ERC20Interface token;
        if (_isCoin) token = ERC20Interface(coinToken);
        else token = ERC20Interface(cashToken);

        uint256 fee = 4990000000000000000 * (10 ** 18) / _prices[0];
        if (freeTrades[_beneficiary] >  0) freeTrades[_beneficiary] = freeTrades[_beneficiary].sub(1);
        else require(token.transferFrom(_beneficiary, coinvest, fee));
        
        require(token.transferFrom(_beneficiary, bank, _coinValue));

        // We want to allow actual COIN/CASH exchange so users have easy access and we can "CASH" out fees
        if (_cryptoIds[0] == COIN_ID && _cryptoIds.length == 1) {
            require(bank.transfer(_beneficiary, _amounts[0], true));
        } else if (_cryptoIds[0] == CASH_ID && _cryptoIds.length == 1) {
            require(bank.transfer(_beneficiary, _amounts[0], false));
        } else {
            userData.modifyHoldings(_beneficiary, _cryptoIds, _amounts, true);
        }

        emit Buy(_beneficiary, _cryptoIds, _amounts, _prices, _isCoin);
    }
    
    /**
     * @param _beneficiary The address that is being sold for
     * @param _cryptoIds The list of uint IDs for each crypto
     * @param _amounts The amounts of each crypto to sell (measured in 10 ** 18 wei!)
     * @param _prices The prices of each crypto at time of callback.
     * @param _coinValue The amount of COIN to be transferred to user.
     * @param _isCoin True/False of the crypto that is being used to invest is COIN/CASH.
    **/
    function finalizeSell(address _beneficiary, uint256[] memory _cryptoIds, uint256[] memory _amounts, uint256[] memory _prices, uint256 _coinValue, bool _isCoin)
      internal
    {   
        uint256 fee = 4990000000000000000 * (10 ** 18) / _prices[0];
        if (freeTrades[_beneficiary] > 0) freeTrades[_beneficiary] = freeTrades[_beneficiary].sub(1);
        else {
            require(_coinValue > fee);
            require(bank.transfer(coinvest, fee, _isCoin));
            _coinValue = _coinValue.sub(fee);
        }

        require(bank.transfer(_beneficiary, _coinValue, _isCoin));
        
        // Subtract from balance of each held crypto for user.
        userData.modifyHoldings(_beneficiary, _cryptoIds, _amounts, false);
        
        emit Sell(_beneficiary, _cryptoIds, _amounts, _prices, _isCoin);
    }
    
/** ******************************** Only Owner ************************************* **/
    
    /**
     * @dev Owner may add a crypto to the investment contract.
     * @param _index Id of the crypto if an old one is being altered, 0 if new crypto is to be added.
     * @param _symbol Symbol of the new crypto.
     * @param _inverse Whether or not an inverse should be added following a pushed crypto.
    **/
    function addCrypto(uint256 _index, string memory _symbol, bool _inverse)
      public
      onlyOwner
    {
        // If a used index is to be changed, only alter that symbol.
        if (_index > 0) {
            cryptoSymbols[_index] = _symbol;
        } else { // If we are adding a new symbol, push either the symbol or blank string after.
            cryptoSymbols.push(_symbol);
            if (_inverse) cryptoSymbols.push(_symbol);
            else cryptoSymbols.push("");
        }
    }
    
    /**
     * @dev Allows Coinvest to reward users with free platform trades.
     * @param _users List of users to reward.
     * @param _trades List of free trades to give to each.
    **/
    function addTrades(address[] _users, uint256[] _trades)
      external
      onlyCoinvest
    {
        require(_users.length == _trades.length);
        
        for (uint256 i = 0; i < _users.length; i++) {
            freeTrades[_users[i]] = freeTrades[_users[i]].add(_trades[i]);
        }     
    }

    /**
     * @dev Allows the owner of the contract to pause all buys and sells.
     * @param _paused True to halt operations, false to continue.
    **/
    function alterPause(bool _paused)
      external
      onlyOwner
    {
        paused = _paused;
    }

    /**
     * @dev Allows owner to change address of other contracts in the system.
     * @param _coinToken Address of the COIN token contract.
     * @param _cashToken Address of the CASH token contract.
     * @param _bank Address of the bank contract.
     * @param _userData Address of the user data contract.
    **/
    function changeContracts(address _coinToken, address _cashToken, address _bank, address _userData)
      external
      onlyOwner
    {
        coinToken = _coinToken;
        cashToken = _cashToken;
        bank = Bank(_bank);
        userData = UserData(_userData);
    }

    /**
     * @dev Needed in case our crypto symbols change or to switch from CryptoCompare (if site is compatible).
     * @param _coinUrl The CryptoCompare API URL of the COIN token.
     * @param _cashUrl The CryptoCompare API URL of the CASH token, if there is one.
    **/
    function changeUrls(string _coinUrl, string _cashUrl)
      external
      onlyOwner
    {
        coinUrl = _coinUrl;
        cashUrl = _cashUrl;
    }
    
/** ********************************* Modifiers ************************************* **/
    
    /**
     * @dev For buys and sells we only want an approved broker or the buyer/seller
     * @dev themselves to mess with the buyer/seller's portfolio
     * @param _beneficiary The buyer or seller whose portfolio is being modified
    **/
    modifier onlySenderOrToken(address _beneficiary)
    {
        require(msg.sender == _beneficiary || msg.sender == coinToken || msg.sender == cashToken);
        _;
    }
    
    /**
     * @dev Ensures the contract cannot be used if Coinvest pauses it.
    **/
    modifier notPaused()
    {
        require(!paused);
        _;
    }
    
/** ******************************************************************************** **/
/** ******************************* Oracle Logic *********************************** **/
/** ******************************************************************************** **/

    /**
     * @dev Here we Oraclize to CryptoCompare to get prices for these cryptos.
     * @param _beneficiary The user who is executing the buy or sell.
     * @param _cryptos The IDs of the cryptos to get prices for.
     * @param _amounts Amount of each crypto to buy.
     * @param _isCoin True/False of the crypto that is being used to invest is COIN/CASH.
     * @param _buy Whether or not this is a buy (as opposed to sell).
    **/
    function getPrices(address _beneficiary, uint256[] memory _cryptos, uint256[] memory _amounts, bool _isCoin, bool _buy) 
      public
    {
        //if (oraclize_getPrice("URL") > address(this).balance) {
        //    emit newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        //} else {
        //   emit newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            //string memory fullUrl = 
            craftUrl(_cryptos, _isCoin); // This is kept in test to ensure craftUrl requires work
            
            //bytes32 queryId = oraclize_query("URL", fullUrl, 150000 + 40000 * _cryptos.length);
            bytes32 queryId = 0x0000000000000000000000000000000000000000000000000000000000000001;
            trades[queryId] = TradeInfo(_buy, _isCoin, _beneficiary, bitConv(_cryptos, _amounts));
        //}
    }
    
    /**
     * @dev Oraclize calls and should simply set the query array to the int results.
     * @param myid Unique ID of the Oraclize query, index for save idsAndAmts.
     * @param result JSON string of CryptoCompare's return.
     * @param proof Proof of validity of the Oracle call--not used.
    **/
    function __callback(bytes32 myid, string result, bytes proof)
      public
    {
        //require(msg.sender == oraclize_cbAddress());
        proof;

        TradeInfo memory tradeInfo = trades[myid];
        (uint256[] memory cryptos, uint256[] memory amounts) = bitRec(tradeInfo.idsAndAmts);

        address beneficiary = tradeInfo.beneficiary;
        bool isBuy = tradeInfo.isBuy;
        bool isCoin = tradeInfo.isCoin;
    
        uint256[] memory cryptoValues = decodePrices(cryptos, result, isCoin);
        uint256 value = calculateValue(amounts, cryptoValues);
        
        if (isBuy) finalizeBuy(beneficiary, cryptos, amounts, cryptoValues, value, isCoin);
        else finalizeSell(beneficiary, cryptos, amounts, cryptoValues, value, isCoin);
    }
    
/** ******************************* Constants ************************************ **/
    
    /**
     * @dev Crafts URL for Oraclize to grab data from.
     * @param _cryptos The uint256 crypto ID of the cryptos to search.
     * @param _isCoin True if COIN is being used as the investment token.
    **/
    function craftUrl(uint256[] memory _cryptos, bool _isCoin)
      public
      view
    returns (string memory url)
    {
        if (_isCoin) url = coinUrl;
        else url = cashUrl;

        for (uint256 i = 0; i < _cryptos.length; i++) {
            uint256 id = _cryptos[i];

            // This loop ensures only one of each crypto is being bought.
            for (uint256 j = 0; j < _cryptos.length; j++) {
                if (i == j) break;
                require(id != _cryptos[j]);
            }

            require(bytes(cryptoSymbols[id]).length > 0);
            url = url.toSlice().concat(cryptoSymbols[id].toSlice());
        }
        url = url.toSlice().concat("&tsyms=USD".toSlice());
        return url;
    }

    /**
     * @dev Cycles through a list of separators to split the api
     * @dev result string. Returns list so that we can update invest contract with values.
     * @param _cryptos The cryptoIds being decoded.
     * @param _result The raw string returned from the cryptocompare api with all crypto prices.
     * @param _isCoin True/False of the crypto that is being used to invest is COIN/CASH.
    **/
    function decodePrices(uint256[] memory _cryptos, string memory _result, bool _isCoin) 
      public
      pure
    returns (uint256[] memory prices)
    {
        strings.slice memory s = _result.toSlice();
        strings.slice memory delim = 'USD'.toSlice();
        s.split(delim).toString();

        prices = new uint256[](_cryptos.length + 1);
        
        //Find price of COIN first.
        string memory coinPart = s.split(delim).toString();
        prices[0] = parseInt(coinPart,18);

        // Each crypto is advanced one in the prices array because COIN/CASH is index 0.
        for(uint256 i = 0; i < _cryptos.length; i++) {
            uint256 crypto = _cryptos[i];
            bool isInverse = crypto % 2 > 0;
            
            // This loop is necessary because cryptocompare will only return 1 value when the same crypto is queried twice (in case of inverse).
            for (uint256 j = 0; j < _cryptos.length; j++) {
                if (j == i) break;
                if ((isInverse && _cryptos[j] == crypto - 1) || (!isInverse && _cryptos[j] == crypto + 1)) {
                    prices[i+1] = (10 ** 36) / prices[j+1];
                    break;
                }
            }
            
            // If the crypto is COIN we don't want it to split price (because CryptoCompare will only return the first query)
            if ((prices[i+1] == 0 && _isCoin && (crypto == COIN_ID || crypto == COIN_INV)) ||
                (prices[i+1] == 0 && !_isCoin && (crypto == CASH_ID || crypto == CASH_INV))) {
                
                if (!isInverse) prices[i+1] = prices[0];
                else prices[i+1] = (10 ** 36) / prices[0];
            }

            // Normal cases
            else if (prices[i+1] == 0) {
                string memory part = s.split(delim).toString();
        
                uint256 price = parseInt(part,18);
                if (price > 0 && !isInverse) prices[i+1] = price;
                else if (price > 0) prices[i+1] = (10 ** 36) / price;
            }
        }

        for (uint256 k = 0; k < prices.length; k++) require(prices[k] > 0);
        return prices;
    }

    /**
     * @dev Calculate the COIN value of the cryptos to be bought/sold.
     * @param _amounts The amount (in 10 ** 18) of the cryptos being bought.
     * @param _cryptoValues The value of the cryptos at time of call.
    **/
    function calculateValue(uint256[] memory _amounts, uint256[] memory _cryptoValues)
      public
      pure
    returns (uint256 value)
    {
        for (uint256 i = 0; i < _amounts.length; i++) {
            value = value.add(_cryptoValues[i+1].mul(_amounts[i]).div(_cryptoValues[0]));
        }
    }
    
    /**
     * @dev Converts given cryptos and amounts into a single uint256[] array.
     * @param _cryptos Array of the crypto Ids to be bought.
     * @param _amounts Array containing the amounts of each crypto to buy.
    **/
    function bitConv(uint256[] memory _cryptos, uint256[] memory _amounts)
      internal
      pure
    returns (uint256[] memory combined)
    {
        combined = new uint256[](_cryptos.length); 
        for (uint256 i = 0; i < _cryptos.length; i++) {
            combined[i] = _cryptos[i];
            combined[i] |= _amounts[i] << 8;
        }
        return combined;
    }
    
    /**
     * @dev Recovers the cryptos and amounts from combined array.
     * @param _idsAndAmts Array of uints containing both crypto Id and amount.
    **/
    function bitRec(uint256[] memory _idsAndAmts) 
      public
      pure
    returns (uint256[] memory cryptos, uint256[] memory amounts) 
    {
        cryptos = new uint256[](_idsAndAmts.length);
        amounts = new uint256[](_idsAndAmts.length);

        for (uint256 i = 0; i < _idsAndAmts.length; i++) {
            cryptos[i] = uint256(uint8(_idsAndAmts[i]));
            amounts[i] = uint256(uint248(_idsAndAmts[i] >> 8));
        }
        return (cryptos, amounts);
    }
    
/** *************************** Only Owner *********************************** **/

    /**
     * @dev Change Oraclize gas limit and price.
     * @param _newGasPrice New gas price to use in wei.
    **/
    function changeGas(uint256 _newGasPrice)
      external
      onlyOwner
    {
        customGasPrice = _newGasPrice;
        //oraclize_setCustomGasPrice(_newGasPrice);
    }
    
/** ************************** Only Coinvest ******************************* **/

    /**
     * @dev Allow the owner to take ERC20 tokens off of this contract if they are accidentally sent.
     * @param _tokenContract The address of the token to withdraw (0x0 if Ether).
     * @param _amount The amount of Ether to withdraw (because some needs to be left for Oraclize).
    **/
    function tokenEscape(address _tokenContract, uint256 _amount)
      external
      onlyCoinvest
    {
        if (_tokenContract == address(0)) coinvest.transfer(_amount);
        else {
            ERC20Interface lostToken = ERC20Interface(_tokenContract);
        
            uint256 stuckTokens = lostToken.balanceOf(address(this));
            lostToken.transfer(coinvest, stuckTokens);
        }
    }
    

 /** ************************** Temp ************************************ **/
    
    // parseInt
    function parseInt(string _a) internal pure returns (uint) {
        return parseInt(_a, 0);
    }

    // parseInt(parseFloat*10^_b)
    function parseInt(string _a, uint _b) internal pure returns (uint) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i=0; i<bresult.length; i++){
            if ((bresult[i] >= 48)&&(bresult[i] <= 57)){
                if (decimals){
                   if (_b == 0) break;
                    else _b--;
                }
                mint *= 10;
                mint += uint(bresult[i]) - 48;
            } else if (bresult[i] == 46) decimals = true;
        }
        if (_b > 0) mint *= 10**_b;
        return mint;
    }

}