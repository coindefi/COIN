<h1>Coinvest Platform</h1>
The Coinvest Platform allows users to buy and sell cryptocurrencies from any blockchain in an easy, simple, and decentralized manner. 
<br>
<br>
The platform works by accepting an investment request from a user, Oraclizing to get the current market price of the crypto, calculating how much the desired amount will cost, then updating the user’s balance and transferring their COIN tokens to the bank or from the bank. A user may buy a single crypto, an index fund of cryptos, or even inverse cryptos.
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
The Oraclize call calls the cryptocompare API to find the price of the desired cryptos then returns the string of prices in the callback transaction. In the case of inverse cryptos, the regular crypto is queried and price of inverse is determined based upon that. User balances are updated and funds are not transferred until this callback, ensuring that the transaction does not confirm until the correct amount of COIN has been transferred.
<br>
<br>
Because of Oraclize being utilized within this contract we must maintain a balance of Ether in order to pay for the Oraclize transactions (and charge a fee to users in either COIN or Ether).
<br>
<br>
Investment employs “receiveApproval” in order to accommodate the COIN token. Because of this, users can use the “approveAndCall” function on the COIN contract to approve the investment contract to withdraw tokens from their account and make the “buy” or “sell” call all in one transaction. 
<br>
<br>
Using the COIN token’s “approveAndCallPreSigned” function, a user may buy and sell on the investment contract using COIN as gas for the transaction. 
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
User balances may be checked by calling the returnHoldings function on UserData. This will return 2 arrays, one for normal cryptos and one for inverse cryptos, that show the balance of each crypto. Balances are ordered by crypto Id, e.g. BTC is id 1 so index 1 is BTC balance. 
<br>
<h2>Security and Updatability</h2>
To maintain the benefits of decentralization we must not allow ourselves to have complete control of these contracts. At the moment we achieve modularization for updatability by having functions on each contract that can be used to change the address of a contract it communicates with, allowing us to launch a new contract then update that address on the other contracts. 
<br>
<br>
The functions to modify these addresses are only able to be called by the owner of a contract but that gives the owner full control of the system. We will likely upgrade to using a DAO in the near future to mitigate the dangers of centralized ownership.
<br>
<h2>Crypto IDs</h2>
0: COIN<br> 
1: BTC <br>
2: ETH <br>
3: XRP <br>
4: LTC <br>
5: DASH <br>
6: BCH <br>
7: XMR <br>
8: XEM <br>
9: EOS 

