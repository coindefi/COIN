pragma solidity ^0.4.24;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;
  address public coinvest;
  mapping (address => bool) public admins;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
    coinvest = msg.sender;
    admins[owner] = true;
    admins[coinvest] = true;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  modifier onlyCoinvest() {
      require(msg.sender == coinvest);
      _;
  }

  modifier onlyAdmin() {
      require(admins[msg.sender]);
      _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
  
  /**
   * @dev Changes the Coinvest wallet that will receive funds from investment contract.
   * @param _newCoinvest The address of the new wallet.
  **/
  function transferCoinvest(address _newCoinvest) 
    external
    onlyCoinvest
  {
    require(_newCoinvest != address(0));
    coinvest = _newCoinvest;
  }

  /**
   * @dev Used to add admins who are allowed to add funds to the investment contract.
   * @param _user The address of the admin to add or remove.
   * @param _status True to add the user, False to remove the user.
  **/
  function alterAdmin(address _user, bool _status)
    external
    onlyCoinvest
  {
    require(_user != address(0));
    require(_user != coinvest);
    admins[_user] = _status;
  }

}