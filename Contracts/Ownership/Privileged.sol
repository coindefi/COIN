pragma solidity ^0.4.18;
import './Ownable.sol';

/**
 * @title Privileged
 * @dev The Privileged contract gives rights to a certain address.
 * @dev Privileged is beneath owner in that the owner can change privileged address.
 */
 
contract Privileged is Ownable {
  address public privilegedAddress;

  event PrivilegeTransferred(address indexed previousPrivilege, address indexed newPrivilege);

  /**
   * @dev The Privileged constructor sets the original `white person` of the contract to the sender
   * account.
   */
  function Privileged() {
    privilegedAddress = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the privileged.
   */
  modifier onlyPrivileged() {
    require(msg.sender == privilegedAddress);
    _;
  }

  /**
   * @dev Allows the current owner (likely a DAO) to change the privileged address.
   * @param newPrivileged The address to transfer privilege to.
   */
  function transferPrivilege(address newPrivileged) onlyOwner public {
    require(newPrivileged != address(0));
    PrivilegeTransferred(privilegedAddress, newPrivileged);
    privilegedAddress = newPrivileged;
  }

}
