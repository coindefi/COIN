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

contract('UserData', function ([_, wallet]) {

    beforeEach(async function() {
  
      this.owner             = web3.eth.accounts[0];
      this.accountTwo        = web3.eth.accounts[1];
  
      this.token             = await Token.new({from:this.owner});
      this.userData          = await UserData.new("", {from:this.owner});
      this.web3              = this.token.web3;
  
      await this.userData.changeInvestment(this.owner, {from:this.owner});                
  
    })

    describe('modifyHoldings', function () {

        it('should increase holdings on buy', async function () {
            await this.userData.modifyHoldings(this.owner,[1,2],[1,2],true,{from:this.owner})
            let btc = await this.userData.userHoldings.call(this.owner,1)
            let eth = await this.userData.userHoldings.call(this.owner,2)
            btc.should.be.bignumber.equal(1)
            eth.should.be.bignumber.equal(2)
        })

        it('should decrease holdings on sell', async function () {
            await this.userData.modifyHoldings(this.owner,[1,2],[10,20],true,{from:this.owner})
            await this.userData.modifyHoldings(this.owner,[1,2],[5,10],false,{from:this.owner})

            let btc = await this.userData.userHoldings.call(this.owner,1)
            let eth = await this.userData.userHoldings.call(this.owner,2)

            btc.should.be.bignumber.equal(5)
            eth.should.be.bignumber.equal(10)
        })

        it('should fail on non-investment call', async function () {
            await this.userData.modifyHoldings(this.owner,[1,2],[10,20],true,{from:this.accountTwo}).should.be.rejectedWith(EVMRevert);
        })

    })

    describe('changeInvestment', function () {

        it('should change address of investment contract', async function () {
            let original = await this.userData.investmentAddress.call()
            original.should.be.equal(this.owner)

            await this.userData.changeInvestment(this.accountTwo,{from:this.owner})

            let newAddr = await this.userData.investmentAddress.call()
            newAddr.should.be.equal(this.accountTwo)
        })

        it('should fail on non-owner call', async function () {
            await this.userData.changeInvestment(this.accountTwo,{from:this.accountTwo}).should.be.rejectedWith(EVMRevert);
        })

    })

    describe('tokenEscape', function () {

        it('should release all stuck tokens to coinvest', async function () {
            await this.token.transfer(this.userData.address,toEther(2000),{from:this.owner})
            await this.userData.tokenEscape(this.token.address,{from:this.owner})
    
            let dataBalance = await this.token.balanceOf.call(this.userData.address)
            dataBalance.should.be.bignumber.equal(0)
    
            let ownerBalance = await this.token.balanceOf.call(this.owner)
            ownerBalance.should.be.bignumber.equal(toEther(107142857))
        })
    
        // Would have to selfdestruct a contract to get Ether in here to test or something...
        it('should release Ether to coinvest', async function () {
            let firstBalance = await web3.eth.getBalance(this.owner)
    
            //await web3.eth.sendTransaction({to:this.bank.address,value:toEther(3),from:this.owner})
            await this.userData.tokenEscape(0x0,{from:this.owner})
    
            let dataBalance = await web3.eth.getBalance(this.userData.address)
            dataBalance.should.be.bignumber.equal(0)
    
            let ownerBalance = await web3.eth.getBalance(this.owner)
        })
    
        it('should fail on non-owner call', async function () {
            await this.token.transfer(this.userData.address,500000000,{from:this.owner})
            await this.userData.tokenEscape(this.token.address,{from:this.accountTwo}).should.be.rejectedWith(EVMRevert);
        })
    
      })
    
    describe('returnHoldings', function () {

        it('should return correct holdings for user', async function () {
            await this.userData.modifyHoldings(this.owner,[1,2],[1,2],true,{from:this.owner})

            let holdings = await this.userData.returnHoldings.call(this.owner,0,10)
            holdings[1].should.be.bignumber.equal(1)
            holdings[2].should.be.bignumber.equal(2)
        })

        it('should return correct holdings with start of 10', async function () {
            await this.userData.modifyHoldings(this.owner,[11,12],[1,2],true,{from:this.owner})

            let holdings = await this.userData.returnHoldings.call(this.owner,10,12)
            holdings[1].should.be.bignumber.equal(1)
            holdings[2].should.be.bignumber.equal(2)
        })

        it('should return single holding', async function () {
            await this.userData.modifyHoldings(this.owner,[11],[1],true,{from:this.owner})

            let holdings = await this.userData.returnHoldings.call(this.owner,11,11)
            holdings[0].should.be.bignumber.equal(1)
        })

        it('should fail when end is less than start', async function () {
            await this.userData.modifyHoldings(this.owner,[11,12],[1,2],true,{from:this.owner})

            let holdings = await this.userData.returnHoldings.call(this.owner,12,1).should.be.rejectedWith(EVMRevert);
        })

    })

    describe('Public Variables', function () {

        it('should return investment contract', async function () {
            let investAddr = await this.userData.investmentAddress.call()
            investAddr.should.be.equal(this.owner)
        })

    })

    function toEther(value) {
        return web3.toWei(value, "ether")
    }

})
