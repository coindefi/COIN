<h1>Coinvest Platform</h1>
The Coinvest Platform allows users to buy and sell cryptocurrencies from any blockchain in an easy, simple, and decentralized manner. 
<br>
<br>
The platform works by accepting an investment request from a user, Oraclizing to get the current market price of the crypto, calculating how much the desired amount will cost, then updating the user’s balance and transferring their COIN or CASH tokens to the bank or from the bank. A user may buy a single crypto, an index fund of cryptos, or even inverse cryptos.
<br>
<br>
Index funds simply refer to buying multiple cryptos at the same time. They are not currently stored separately from individually bought crypto balances because of gas concerns. The frontend will show your investment as an index fund when it sees a past event showing you bought a set of cryptos at the same time. You may sell cryptos bought in an index fund individually.
<br>
<br>
Inverse crypto refers to a token representing the inverse price of a certain crypto. For example, if ETH is currently trading at a price of $500, Inverse ETH would be trading at a price of 1/ETH, or $0.002. This means that if ETH price drops in half, Inverse ETH doubles, effectively mimicking a short position. 
<br>
<br>
All funds on the platform are stored in COIN and it never transfers any other token: they’re all simply kept as balances on the UserData contract. 
<br>
<h2>Contracts</h2>
<b>Investment.sol:</b>
<br>
The Investment contract is the core of the system. It contains the logic for accepting “buy” and “sell” calls, Oraclizing, decoding the callback, transferring funds, and updating UserData.
<br>
<br>
The Oraclize call calls the cryptocompare API to find the price of the desired cryptos then returns the string of prices in the callback transaction. In the case of inverse cryptos, the regular crypto is queried and price of inverse is determined based upon that. User balances are updated and funds are not transferred until this callback, ensuring that the transaction does not confirm until the correct amount of COIN or CASH has been transferred.
<br>
<br>
Because of Oraclize being utilized within this contract we must maintain a balance of Ether in order to pay for the Oraclize transactions (and possibly charge a fee to users in either COIN or Ether).
<br>
<br>
Investment employs “receiveApproval” in order to accommodate the COIN and CASH tokens. Because of this, users can use the “approveAndCall” function on the COIN contract to approve the investment contract to withdraw tokens from their account and make the “buy” or “sell” call all in one transaction. 
<br>
<br>
Using the COIN token’s “approveAndCallPreSigned” function, a user may buy and sell on the investment contract using COIN as gas for the transaction. 
<br>
<br>
The investment contract also allows any user to exchange COIN for CASH or vice versa. This works the same as another investment--querying both prices from CryptoCompare--but returns user the purchased token instead of adding it as a balance on UserData.
<br>
<br>
<b>UserData.sol:</b>
<br>
The sole purpose of this contract is to keep track of user balances. It’s been separated from the investment contract in order to allow us to easily update the investment contract without needing to reset all user data.
<br>
<br>
The investment contract is the only address with permission to modify holdings and modify the current amount of cryptos.
<br>
<br>
<b>Bank.sol:</b>
<br>
As with UserData, this contract has been separated to allow for easy updating. The only purpose it serves is to hold the primary reserve funds and only allow the investment contract to withdraw funds (to then send to users). 
<br>
<h2>How to Use</h2>
The most likely scenario in which a user will interact with these contracts is through the Coinvest frontend. In that case, these steps will all be done without the user having to interact with any smart contracts. A user is still able, however, to interact directly with the contracts if desired. The way in which an investment works is as follows: 
<br>
<br>
If approveAndCall is not being used, one must first approve the contract to spend COIN from their account. To do this, the user will call the "approve" function on the Coinvest token contract with the Investment contract as the spender and the amount of COIN desired to be invested as the value. 
<br>
<br>
After the investment contract has been approved to spend the user's COIN, the user will then call the "buy" or “sell” function on the Investment contract. In this function they will enter a list of the cryptonized asset IDs to invest in and the amounts (with 10 ** 18 decimals) they would like to invest in each. The investment contract then Oraclizes for current market price of the crypto and, upon callback, will update the UserData contract and take or give COIN to/from the user.
<br>
<br>
(If approveAndCall or approveAndCallPreSigned is being used, the approve and invest call can both be made at once.) 
<br>
<br>
User balances may be checked by calling the returnHoldings function on UserData. Because there is the possibility of having a large number of cryptos, we allow for a start and end of the array of the cryptos to be returned. This may be just a single crypto as well (7,7). 
<br>
<h2>Security and Updatability</h2>
To maintain the benefits of decentralization we must not allow ourselves to have complete control of these contracts. At the moment we achieve modularization for updatability by having functions on each contract that can be used to change the address of a contract it communicates with, allowing us to launch a new contract then update that address on the other contracts. 
<br>
<br>
The functions to modify these addresses are only able to be called by the owner of a contract but that gives the owner full control of the system. We will likely upgrade to using a DAO in the near future to mitigate the dangers of centralized ownership.
<br>
<h1>Tokens</h1>
The COIN token is based on the ERC865 proposal, allowing users to pay for gas using tokens rather than ether. This works by having a user sign a transaction hash with all desired data, then any delegate broadcasting the parameters and signed hash to the network in order for a transaction to be made.
<br>
We’ve created COIN V3 because of a vulnerability in COIN V2. In COIN V2, signatures were used as unique identifiers to block any potential replay attacks on pre-signed transactions. The problem with this design was that it was vulnerable to transaction malleability. While transaction malleability was fixed for transactions on the Ethereum network by restricting signatures to the lower half of the EC, it was not fixed on the ecrecover pre-compiled contract, therefore allowing a signature to be replayed using its counterpart.
<br>
To fix this problem, COIN V3 now uses the transaction hash of the pre-signed transaction as a unique identifier. This method ensures that, once a transaction is sent, it may never be sent again (of course, unless a new nonce is used).
<br>
<h2>Bug Bounty</h2>
As of 10/3/18 Coinvest has opened a bug bounty for the new versions of the COIN and CASH tokens as well as all of the investment contracts. This bug bounty will end when the contracts are launched on mainnet (for tokens this will be sooner than for the investment contracts).
<br>
<br>
The rewards and criteria are as follows:
<br>
<br>
Critical: 15 ETH
<br>
A critical bug is a bug that will enable stealing of funds, major loss of funds, or permanent disablement of a contract.
<br>
<br>
Major: 5 ETH
<br>
A major bug significantly affects the ability of the contract to operate. These would include ERC incompatibilities (ERC865 not applicable because of its lack of maturity) and certain functions being unable to operate.
<br>
<br>
Minor: 1 ETH
<br>
Minor bugs entail an issue regarding the contract not operating as it was designed, but in a non-threatening manner.
<br>
<br>
All rewards will be given at the sole discretion of Coinvest. To submit a bug, please e-mail security@coinve.st with a description of the bug, the situation in which it would occur, and your proposed severity.

