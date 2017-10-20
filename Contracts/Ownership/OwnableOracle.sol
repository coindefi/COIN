pragma solidity ^0.4.17;

contract OwnableOracle {
    address public owner;
    address public oracle;
    address public ownerElect;

/** ******************************** Defaults ********************************** **/

    /**
     * @dev Owner and oracle set to msg.sender to begin with
    **/
    function OwnableOracle()
      public
    {
        owner = msg.sender;
        oracle = msg.sender;
    }
    
    /**
     * @dev Fallback function rejects everything.
    **/
    function ()
      public
      payable
    {
        revert();
    }
    
/** ******************************** External ********************************** **/
    
    /**
     * @dev Using this strategy we can ensure owner is never transferred
     * @dev to an address no one has control over.
    **/
    function acceptOwnership()
      external
    returns (bool success)
    {
        require(msg.sender == ownerElect);
        
        owner = ownerElect;
        ownerElect = 0;
        return true;
    }
    
/** ******************************* Only Owner ********************************* **/
    
    /**
     * @dev Changes the address allowed to modify current crypto prices.
     * @param _newOracle The new address of the oracle
    **/
    function changeOracle(address _newOracle)
      onlyOwner
      external
    returns (bool success)
    {
        require(_newOracle != 0);
        
        oracle = _newOracle;
        return true;
    }
    
    /**
     * @dev Transfers ownership of the contract (for price setting)
     * @dev Will be modularized later
     * @param _newOwner The address to transfer ownership to
    **/
    function electNewOwner(address _newOwner)
      onlyOwner
      external
    returns (bool success)
    {
        require(_newOwner != 0);
        
        ownerElect = _newOwner;
        return true;
    }
    
/** ******************************** Modifiers ********************************* **/
    
    /**
     * @dev Owner is used to add/remove allowedBrokers, change oracle,
     * @dev add new tokens, and change crypto cryptoDecimals
    **/
    modifier onlyOwner()
    {
        require(msg.sender == owner);
        _;
    }
    
    /**
     * @dev Oracle sets the current market prices for cryptoPrices
    **/
    modifier onlyOracle()
    {
        require(msg.sender == oracle);
        _;
    }
}
