pragma solidity ^0.4.18;
/**
 * @title ERC20 interface
 */
 
contract ERC20Base {
  // Keeps track of your total tokens
  uint256 public totalSupply;

  // Standard events for reporting to the blockchain/web3
  event Transfer(address indexed _from, address indexed _to, uint indexed _amount);
  event Approval(address indexed _from, address indexed _spender, uint indexed _amount);

  // Return balance of your token
  function balanceOf(address _owner) external constant returns (uint256);

  // Send tokens between wallets/contracts
  function transfer(address _to, uint256 _amount) external returns (bool);

  // Allowing and Sending tokens on other wallet's behalf
  function approve(address _spender, uint256 _amount) external returns (bool);
  function allowance(address _owner, address _spender) external constant returns (uint256);
  function transferFrom(address _from, address _to, uint _amount) external returns (bool);
}
