# Coinvest
Coinvest is a decentralized stock exchange that allows users to invest in an array of cryptocurrencies in a very simple manner. When a user wants to make a trade, the Coinvest Token ("COIN") is sent to the contract along with a list of the cryptonized assets the user would like to invest in. The amounts and prices of purchased assets are recorded in USD and when a user would like to liquidate their holdings, they follow the same process of selling a certain amount of chosen assets and their address is returned COIN in the USD value of the profits earned. This will all be handled through the easy-to-use Coinvest frontend so now anyone can invest in cryptocurrencies.
</br>
</br>
The Ropsten test network Investment contract address is: 0xd4f7f998e67ced910ef817b4a29314c529d58e93.
</br>
Do not send anything on the main network to this address!
</br>
It does not require tokens to invest; it's simply a demo so you can purchase as much as you'd like of anything.
</br>
</br>
<h2>Contracts</h2>
Coinvest is made up of 4 main contracts:
</br>
CoinvestToken.sol, Investment.sol, Bank.sol, and Oracle.sol.
</br>
</br>
<h2>CoinvestToken.sol</h2>
CoinvestToken ("COIN") is a default ERC20. It's used as the currency required to make all trades on Investment.sol and is the currency that Bank.sol holds.
</br>
<h2>Investment.sol</h2>
The Investment contract is the real meat of Coinvest. Here users (or, more likely, the Coinvest frontend acting for a user) may invest in singular cryptonized assets or a fund containing multiple cryptonized assets, liquidate their past purchases, and examine their holdings. All user and trade data is stored in this contract and it is the only contract in the system besides CoinvestToken.sol that users may interact with.
</br>
<h2>Bank.sol</h2>
The Bank contract holds all user funds that are invested. They are held here so that in the case where Investment needs an upgrade, user funds are not disturbed. Only Investment may transfer funds out of bank and it will only ever be able to do that when a user is liquidating assets. The Coinvest team will never be able to withdraw funds from the Bank.
</br>
<h2>Oracle.sol</h2>
The Oracle contract uses Oraclize to get current market price data on the supported cryptonized assets. It currently gets data from cryptocompare.com every 60 seconds and contacts Investment to update the prices so user's can invest at the going rates.
</br>
</br>
<h2>How to Use</h2>
The most likely scenario in which a user will interact with these contracts is through the Coinvest frontend. In that case, these steps will all be done without the user having to interact with any smart contracts. A user is still able, however, to interact directly with the contracts if desired. The way in which an investment works is as follows:
</br></br>
One must first approve the contract to spend COIN from their account. To do this, the user will call the "approve" function on the Coinvest token contract with the Investment contract as the spender and the amount of COIN desired to be invested as the value.
</br>
</br>
After the investment contract has been approved to spend the user's COIN, the user will then call the "invest" function on the Investment contract. In this function they will enter a list of the cryptonized asset IDs to invest in, the amounts (in the asset's lowest denomination) they would like to invest in each, and whether or not they want each trade to be a short. If the Investment contract can take sufficient payment from the buyer at the asset's current prices, each investment's information (asset ID, initial price, amount bought) is saved on the blockchain and an event is emitted with the list and amounts of asset investments.
</br>
</br>
The user may check their entire portfolio value using the holdings function or they may check each trade individually by calling the userHoldings mapping with their address and the cryptonized asset ID.
</br>
</br>
To liquidate, the user may take similar steps as they would to invest. They submit a list of the assets they would like to liquidate, the amounts of each asset, and whether they want to liquidate shorts or buys. The Investment contract sells the desired amounts of each asset, clears the holdings from a user's portfolio, and sends funds in COIN equivalent to the asset's USD value to the user's address.
</br>
</br>
<h2>Security</h2>
Coinvest has put extreme emphasis on the security of our users. We've spent much time designing a system that cannot be taken advantage of by anyone, including ourselves. We will be creating a DAO so users will have control in the future when we need to switch out contracts, but, until then, we'll keep the structure of the contracts the same but change all owners of the contracts to blank addresses.
</br>
</br>
This means no one can switch out the contracts to begin with--even to upgrade them. We will keep this secure but non-upgradeable version of the system until we launch our DAO, at which point we will liquidate all user funds to their addresses and stop using the initial contracts. We will then launch the contracts again with the DAO as an owner so the community will be able to decide on upgrades from then on. We will never again have to liquidate all user funds and have them reinvest once the system is owned by our DAO.

