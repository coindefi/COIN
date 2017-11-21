pragma solidity ^0.4.17;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";
import "./Investment.sol";

/**
 * @title Oracle
 * @dev This contract queries cryptocompare every 60 seconds
 * @dev to find the most recent prices for all investible cryptos.
*/

contract Oracle is usingOraclize {
    using strings for *;
    
    // Cryptocompare API URL
    string url = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=BTC,ETH,XRP,LTC,DASH,BCH,XMR,XEM,EOS&tsyms=USD";

    // These are used to split a raw string to determine prices of each asset.
    string[] separators = ['{"BTC":{"USD":','},"ETH":{"USD":','},"XRP":{"USD":','},"LTC":{"USD":','},"DASH":{"USD":','},"BCH":{"USD":','},"XMR":{"USD":','},"XEM":{"USD":','},"EOS":{"USD":','}}'];

    Investment investContract;

    event newOraclizeQuery(string description);

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
    
        uint256[9] memory prices = findPrices(result);
        
        investContract.setPrices(prices);
        update();
    }
    
    function update() payable {
        if (oraclize.getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query(60, "URL", url, 500000);
        }
    }
    
/** ******************************** Internal *********************************** **/

    /**
     * @dev Cycles through a list of separators to split the api
     * @dev result string. Returns list so that we can update invest contract with values.
     * @param _result The raw string returned from the cryptocompare api with all crypto prices.
    **/
    function findPrices(string _result) 
      internal
    returns (uint256[9] finals)
    {
        for(uint256 i = 0; i < separators.length - 1; i++) {
            var s = _result.toSlice();
            strings.slice memory part;
            s.split(separators[i].toSlice(), part);
            s.rsplit(separators[i + 1].toSlice(), part);
            
            var sString = s.toString();
            uint256 newPrice = parseInt(sString, 18);
            finals[i] = newPrice;
        }
    }

} 
