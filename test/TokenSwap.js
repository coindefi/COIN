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
const TokenSwap         = artifacts.require('../contracts/TokenSwap.sol')
const Token				= artifacts.require('../contracts/CoinvestToken.sol')
const Token223    = artifacts.require('../contracts/Coinvest223.sol')

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

  contract('Investment', function ([_, wallet]) {

    beforeEach(async function() {
  
      this.owner            = web3.eth.accounts[0];
      this.accountTwo       = web3.eth.accounts[1];
  
      this.tokenV1          = await Token223.new(0,{from:this.owner});
      this.tokenV2          = await Token.new({from:this.owner});
      this.tokenV3          = await Token.new({from:this.owner});
      this.tokenSwap        = await TokenSwap.new(this.tokenV1.address, this.tokenV2.address, this.tokenV3.address, {from:this.owner});
  
      // Put all new tokens into the token swap contract.
      let balance = await this.tokenV3.balanceOf(this.owner)
      await this.tokenV3.transfer(this.tokenSwap.address, balance, {from:this.owner})

    })
  
  /** ********************************** Core ***************************************** */
  
  
    describe('V2 -> V3 Swap', function () {

        it('should exchange full amount and decrement accordingly', async function () {
            let initialBalance = await this.tokenV2.balanceOf(this.owner)
            await this.tokenV2.approveAndCall(this.tokenSwap.address, initialBalance, '')

            let oldTokenBal = await this.tokenV2.balanceOf(this.owner)
            oldTokenBal.should.be.bignumber.equal(0)

            let newTokenBal = await this.tokenV3.balanceOf(this.owner)
            newTokenBal.should.be.bignumber.equal(initialBalance)

            let newSwapBal = await this.tokenV3.balanceOf(this.tokenSwap.address)
            newSwapBal.should.be.bignumber.equal(0)
        })

        it('should exchange 10 token wei', async function () {
          await this.tokenV2.approveAndCall(this.tokenSwap.address, 10, '')

          let newTokenBal = await this.tokenV3.balanceOf(this.owner)
          newTokenBal.should.be.bignumber.equal(10)
        })

        it('should fail if tokenV2 is not caller', async function () {
            await this.tokenSwap.receiveApproval(this.owner,100,this.tokenV2.address,'', {from:this.owner}).should.be.rejectedWith(EVMRevert)
        })

        it('should fail if amount is 0', async function () {
          await this.tokenV2.approveAndCall(this.tokenSwap.address, 0, '').should.be.rejectedWith(EVMRevert)
        })

    })

    describe('V1 -> V3 Swap', function () {

      it('should exchange full amount and decrement accordingly', async function () {
          let initialBalance = await this.tokenV1.balanceOf(this.owner)
          await this.tokenV1.transfer(this.tokenSwap.address, initialBalance)

          let v1bal = await this.tokenV1.balanceOf(this.owner)
          v1bal.should.be.bignumber.equal(0)

          let v3bal = await this.tokenV3.balanceOf(this.owner)
          v3bal.should.be.bignumber.equal(initialBalance)

          let newSwapBal = await this.tokenV3.balanceOf(this.tokenSwap.address)
          newSwapBal.should.be.bignumber.equal(0)
      })

      it('should exchange 10 token wei', async function () {
        await this.tokenV1.transfer(this.tokenSwap.address, 10)

        let newTokenBal = await this.tokenV3.balanceOf(this.owner)
        newTokenBal.should.be.bignumber.equal(10)
      })

      it('should fail if token V1 is not caller', async function () {
          await this.tokenSwap.tokenFallback(this.owner,100,'').should.be.rejectedWith(EVMRevert)
      })

      it('should fail if amount is 0', async function () {
        await this.tokenV1.transfer(this.tokenSwap.address, 0).should.be.rejectedWith(EVMRevert)
      })

    })

    describe('tokenEscape', function () {

      it('should be able to transfer any ERC20 off this contract to owner', async function () {
        await this.tokenV2.transfer(this.tokenSwap.address, 1000, {from:this.owner})
        let tokenBalance = await this.tokenV2.balanceOf(this.tokenSwap.address)
        tokenBalance.should.be.bignumber.equal(1000)
  
        await this.tokenSwap.tokenEscape(this.tokenV2.address, {from:this.owner})
        let tokenBalanceTwo = await this.tokenV2.balanceOf(this.tokenSwap.address)
        tokenBalanceTwo.should.be.bignumber.equal(0)
      })

      it('should not be able to transfer tokenV1 or tokenV3 off contract', async function () {
        await this.tokenV1.transfer(this.tokenSwap.address, 1000, {from:this.owner})
        let tokenBalance = await this.tokenV1.balanceOf(this.tokenSwap.address)
        tokenBalance.should.be.bignumber.equal(1000)
        await this.tokenSwap.tokenEscape(this.tokenV1.address, {from:this.owner}).should.be.rejectedWith(EVMRevert)

        await this.tokenSwap.tokenEscape(this.tokenV3.address, {from:this.owner}).should.be.rejectedWith(EVMRevert)
      })

      it('should fail on non-owner call', async function () {
        await this.tokenV2.transfer(this.tokenSwap.address, 1000, {from:this.owner})
        await this.tokenSwap.tokenEscape(this.tokenV2.address, {from:this.accountTwo}).should.be.rejectedWith(EVMRevert)
      })

    })

    describe('Constants', function () {

      it('should have correct addresses on construction', async function () {
        let tokenV1 = await this.tokenSwap.tokenV1.call()
        let tokenV2 = await this.tokenSwap.tokenV2.call()
        let tokenV3 = await this.tokenSwap.tokenV3.call()
        tokenV1.should.be.equal(this.tokenV1.address)
        tokenV2.should.be.equal(this.tokenV2.address)
        tokenV3.should.be.equal(this.tokenV3.address)
      })

    })

})

