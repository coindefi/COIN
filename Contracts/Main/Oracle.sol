pragma solidity ^0.4.17;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";
import "./Investment.sol";
import "./Privileged.sol";

/**
 * @title Oracle
 * @dev This contract queries cryptocompare every 60 seconds
 * @dev to find the most recent prices for all investable cryptos.
*/

contract Oracle is usingOraclize, Privileged {
    using strings for *;
    
    uint256 public thisPrice;
    Investment investContract;
    mapping (string => string) symbolUrls; // Symbol ("COIN") of the crypto to search and URL to search
    mapping (string => uint256) symbolIds; // Find the crypto ID of the given symbol string
    
    event newOraclizeQuery(string description);
    event newPrice(string symbol, uint256 price);

/** ****************************** Defaults ************************************* **/    

    function Oracle(address _investContract) {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        investContract = Investment(_investContract);
    }

/** ****************************** Oraclize ************************************* **/

    /**
     * @dev Normal Oraclize callback except the result is searched
     * @dev so the specific crypto whos price is updated can be found.
    **/
    function __callback(bytes32 myid, string result, bytes proof) {
        if (msg.sender != oraclize_cbAddress()) throw;
        
        string memory symbol = findSymbol(result);
        uint256 price = findPrice(result);
        newPrice(symbol, price);
        thisPrice = price;
    
        investContract.setPrice(symbolIds[symbol], price);
        update(symbol);
    }
    
    function update(string _symbol) payable {
        string _url = symbolUrls[_symbol];
        if (oraclize.getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query(60, "URL", _url);
        }
    }
    
/** ****************************** Only Owner *********************************** **/

    /**
     * @dev Owner can add a new crypto to the update list.
     * @dev In the future this can also add crypto to Investment contract.
     * @param _symbol The symbol (i.e. COIN) to be added to the list (all caps).
     * @param _url The URL that should be scraped to find the price (encased in json()).
    **/
    function updateUrls(string _symbol, string _url, uint256 _cryptoId)
      external
      onlyOwner
    returns (bool success)
    {
        symbolUrls[_symbol] = _url;
        symbolIds[_symbol] = _cryptoId;
        return true;
    }
    
/** ******************************** Internal *********************************** **/
    
    /**
     * @dev Searches result string to find which crypto is being returned.
     * @param _result The string result given back by Oraclize.
    **/
    function findSymbol(string _result)
      internal
    returns (string symbol)
    {
        var s = _result.toSlice();
        strings.slice memory part;
        s.rsplit('"'.toSlice(), part);
        s.rsplit('"'.toSlice(), part);
        s.rsplit('"'.toSlice(), part);
        s.split('"'.toSlice(), part);
        var sString = s.toString();
        return sString;
    }
    
    /**
     * @dev Searches result string to find new price of target crypto.
     * @param _result The string result given back by Oraclize.
    **/
    function findPrice(string _result)
      internal
    returns (uint256 newPrice)
    {
        var s = _result.toSlice();
        strings.slice memory part;
        s.split(':'.toSlice(), part);
        s.split(':'.toSlice(), part);
        s.rsplit('}'.toSlice(), part);
    
        var sString = s.toString();
        newPrice = parseInt(sString, 18);
        return newPrice;
    }
 
} 
