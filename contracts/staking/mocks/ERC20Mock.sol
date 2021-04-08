pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20("Coin Utility Token", "COIN") {

  function mintToSelf(uint256 amount) public {
    _mint(msg.sender, amount);
  }

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }

}
