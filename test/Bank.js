import ether from './helpers/ether'
import {advanceBlock} from './helpers/advanceToBlock'
import {increaseTimeTo, duration} from './helpers/increaseTime'
import latestTime from './helpers/latestTime'
import EVMRevert from './helpers/EVMRevert'
import EVMThrow from './helpers/EVMThrow'
import expectThrow from './helpers/expectThrow'; 
import assertRevert from './helpers/assertRevert';
import expectEvent from './helpers/expectEvent'; 

// web3Abi required to test overloaded transfer functions
const web3Abi = require('web3-eth-abi');

// BigNumber is used for handling gwei vars
const BigNumber = web3.BigNumber

// Chai gives you a very nice, straight forward and clean assertion checking mechanisms
const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

// Contract constants
const Investment        = artifacts.require('../contracts/PostAuditTest.sol')
const Token				= artifacts.require('../contracts/CoinvestToken.sol')
const UserData			= artifacts.require('../contracts/UserData.sol')
const Bank				= artifacts.require('../contracts/Bank.sol')

// Promisify get balance of ether
const promisify = (inner) =>
  new Promise((resolve, reject) =>
    inner((err, res) => {
      if (err) { reject(err) }
      resolve(res);
    })
  );

const getBalance = (account, at) =>
  promisify(cb => web3.eth.getBalance(account, at, cb));

/********************************************************************************************************/
/*********************************************** Bank ***************************************************/
/********************************************************************************************************/

contract('Bank', function ([_, wallet]) {

    beforeEach(async function() {

        this.owner             = web3.eth.accounts[0];
        this.accountTwo        = web3.eth.accounts[1];
    
        // token = COIN token
        this.coinToken         = await Token.new({from:this.owner});
        this.token2            = await Token.new({from:this.owner}); // Used to test tokenEscape
        this.cashToken         = await Token.new({from:this.owner});
        this.bank              = await Bank.new(this.coinToken.address, this.cashToken.address, {from:this.owner});
        this.investment        = await Investment.new(this.coinToken.address, this.cashToken.address,
                                this.bank.address, this.coinToken.address, {from: this.owner});
        this.web3              = this.coinToken.web3;
    
        await this.bank.changeInvestment(this.investment.address, {from:this.owner});
    
    })

    describe('transfer', function () {

        it('should transfer COIN for investment', async function () {
            await this.coinToken.transfer(this.bank.address,100000,{from:this.owner})
            await this.bank.changeInvestment(this.owner,{from:this.owner})
            await this.bank.transfer(this.accountTwo,10000,true,{from:this.owner})

            let balance = await this.coinToken.balanceOf(this.accountTwo)
            balance.should.be.bignumber.equal(10000)
        })

        it('should transfer CASH for investment', async function () {
            await this.cashToken.transfer(this.bank.address,100000,{from:this.owner})
            await this.bank.changeInvestment(this.owner,{from:this.owner})
            await this.bank.transfer(this.accountTwo,10000,false,{from:this.owner})
            
            let balance = await this.cashToken.balanceOf(this.accountTwo)
            balance.should.be.bignumber.equal(10000)
        })

        it('should fail on non-investment call', async function () {
            await this.coinToken.transfer(this.bank.address,100000,{from:this.owner})
            //await this.bank.changeInvestment(this.owner,{from:this.owner})
            await this.bank.transfer(this.accountTwo,10000,true,{from:this.owner}).should.be.rejectedWith(EVMRevert);
        })

    })

    describe('changeInvestment', function () {

        it('should change address of investment contract', async function () {
            let original = await this.bank.investmentAddr.call()
            original.should.be.equal(this.investment.address)

            await this.bank.changeInvestment(this.owner,{from:this.owner})

            let newAddr = await this.bank.investmentAddr.call()
            newAddr.should.be.equal(this.owner)
        })

    })

    describe('tokenEscape', function () {

        it('should release all stuck tokens to coinvest', async function () {
            // Must create new token because original won't be able to be withdrawn
            this.token2 = await Token.new({from:this.owner});

            await this.token2.transfer(this.bank.address,toEther(2000),{from:this.owner})
            await this.bank.tokenEscape(this.token2.address,{from:this.owner})
    
            let bankBalance = await this.token2.balanceOf.call(this.bank.address)
            bankBalance.should.be.bignumber.equal(0)
    
            let ownerBalance = await this.token2.balanceOf.call(this.owner)
            ownerBalance.should.be.bignumber.equal(toEther(107142857))
        })
    
        // Would have to selfdestruct a contract to get Ether in here to test or something...
        it('should release Ether to coinvest', async function () {
            let firstBalance = await web3.eth.getBalance(this.owner)
    
            //await web3.eth.sendTransaction({to:this.bank.address,value:toEther(3),from:this.owner})
            await this.bank.tokenEscape(0x0,{from:this.owner})
    
            let bankBalance = await web3.eth.getBalance(this.bank.address)
            bankBalance.should.be.bignumber.equal(0)
    
            let ownerBalance = await web3.eth.getBalance(this.owner)
        })
    
        it('should fail on non-owner call', async function () {
            // Must create new token because original won't be able to be withdrawn
            this.token2 = await Token.new({from:this.owner});

            await this.token2.transfer(this.bank.address,500000000,{from:this.owner})
            await this.bank.tokenEscape(this.token2.address,{from:this.accountTwo}).should.be.rejectedWith(EVMRevert);
        })

        it('should fail on Coinvest COIN token withdrawal attempt', async function () {
            await this.coinToken.transfer(this.bank.address,500000000,{from:this.owner})
            await this.bank.tokenEscape(this.coinToken.address,{from:this.owner}).should.be.rejectedWith(EVMRevert);
        })

        it('should fail on Coinvest CASH token withdrawal attempt', async function () {
            await this.coinToken.transfer(this.bank.address,500000000,{from:this.owner})
            await this.bank.tokenEscape(this.cashToken.address,{from:this.owner}).should.be.rejectedWith(EVMRevert);
        })
    
    })
    
    
    describe('Public Variables', function () {

        it('should return coinToken contract', async function () {
            let tokenAddr = await this.bank.coinToken()
            tokenAddr.should.be.equal(this.coinToken.address)
        })

        it('should return cashToken contract', async function () {
            let tokenAddr = await this.bank.cashToken()
            tokenAddr.should.be.equal(this.cashToken.address)
        })

        it('should return investment contract', async function () {
            let investAddr = await this.bank.investmentAddr()
            investAddr.should.be.equal(this.investment.address)
        })

    })

})

    function toEther(value) {
        return web3.toWei(value, "ether")
    }