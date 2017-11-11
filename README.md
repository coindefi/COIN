# Coinvest

Coinvest is made up of 4 main contracts:
</br>
CoinvestToken.sol, Investment.sol, Bank.sol, and Oracle.sol.
</br>
</br>
<h2>CoinvestToken.sol</h2>
</br>
CoinvestToken ("COIN") is a default ERC20. It's used as the currency required to make all trades on Investment.sol and is the currency that Bank.sol holds.
</br>
<h2>Investment.sol</h2>
</br>
The Investment contract is the real meat of Coinvest. Here users (or, more likely, the Coinvest frontend acting for a user) may invest in singular cryptonized assets or a fund containing multiple cryptonized assets, liquidate their past purchases, and examine their holdings. All user and trade data is stored in this contract and it is the only contract in the system besides CoinvestToken.sol that users may interact with.
</br>
<h2>Bank.sol</h2>
</br>
The Bank contract holds all user funds that are invested. They are held here so that in the case where Investment needs an upgrade, user funds are not disturbed. Only Investment may transfer funds out of bank and it will only ever be able to do that when a user is liquidating assets. The Coinvest team will never be able to withdraw funds from the Bank.
</br>
<h2>Oracle.sol</h2>
</br>
The Oracle contract uses Oraclize to get current market price data on the supported cryptonized assets. It currently gets data from cryptocompare.com every 60 seconds and contacts Investment to update the prices so user's can invest at the going rates.
</br>
</br>
<h2>Security</h2>
Coinvest has put extreme emphasis on the security of our users. We've spent much time designing a system that cannot be taken advantage of by anyone, including ourselves. We will be creating a DAO so users will have control in the future when we need to switch out contracts, but, until then, we'll keep the structure of the contracts the same but change all owners of the contracts to blank addresses.
</br>
</br>
This means no one can switch out the contracts to begin with--even to upgrade them. We will keep this secure but non-upgradeable version of the system until we launch our DAO, at which point we will liquidate all user funds to their addresses and stop using the initial contracts. We will then launch the contracts again with the DAO as an owner so the community will be able to decide on upgrades from then on. We will never again have to liquidate all user funds and have them reinvest once the system is owned by our DAO.
