import ether from './helpers/ether'
import {advanceBlock} from './helpers/advanceToBlock'
import {increaseTimeTo, duration} from './helpers/increaseTime'
import latestTime from './helpers/latestTime'
import EVMRevert from './helpers/EVMRevert'

const BigNumber = web3.BigNumber

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const MinervaToken = artifacts.require('../contracts/MinervaToken')

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

contract('MinervaToken', function ([_, wallet]) {

  before(async function() {
    //Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock()

    this.owner    = web3.eth.accounts[0];
    this.receiver = web3.eth.accounts[1];
    this.partner  = web3.eth.accounts[2];
    this.bank     = web3.eth.accounts[3];

    this.token = await MinervaToken.new(this.owner, this.owner);
    await this.token.updateMaxDailyBonus(1000000000000000000000000000000000000000000,{from:this.owner})
  })

  it('should have no tokens for owner', async function () {
    let balance = await this.token.balanceOf(this.owner);
    balance.should.be.bignumber.equal(0);
  })

  describe('-- MINTING --', function () {

    it('should mint 1000 tokens and update total supply to 1000', async function () {
      await this.token.mint(this.receiver, ether(1000), {from: this.owner});
      
      let supply = await this.token.totalSupply.call();
      supply.should.be.bignumber.equal(ether(1000));
    })

    it('should mint 1000 tokens to receiver', async function () {
      await this.token.mint(this.receiver, ether(1000), {from: this.owner});

      let balance = await this.token.balanceOf(this.receiver);
      balance.should.be.bignumber.equal(ether(2000));
    })

    it('should fail minting if not minter (revert)', async function () {
      await this.token.mint(this.receiver, ether(1000), {from: this.receiver}).should.be.rejectedWith(EVMRevert);
    })

  })

  describe('-- APPROVING AND TRANSFERRING TOKENS --', function () {

    it('should transfer 500 from receiver to owner', async function () {
      await this.token.transfer(this.owner, ether(500), {from: this.receiver});

      let balance = await this.token.balanceOf(this.owner);
      balance.should.be.bignumber.equal(ether(500));
    })

    it('should fail transfering tokens user doesnt have', async function () {
      await this.token.transfer(this.owner, ether(10000), {from: this.receiver}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail when owner tries to transferFrom without approval', async function () {
      await this.token.transferFrom(this.receiver, this.owner, ether(500), {from: this.owner}).should.be.rejectedWith(EVMRevert);
    })

    it('receiver approves owner to spend 500 tokens -> owner transfer 250 to itself', async function () {
      await this.token.approve(this.owner, ether(500), {from: this.receiver});
      await this.token.transferFrom(this.receiver, this.owner, ether(250), {from: this.owner});

      let balance = await this.token.balanceOf(this.owner);
      balance.should.be.bignumber.equal(ether(750));

    })

  })

  describe('-- BURNING TOKENS --', function () {

    it('receiver should burn 500 tokens', async function () {
      await this.token.burn(ether(500), {from: this.receiver});

      let balance = await this.token.balanceOf(this.receiver);
      balance.should.be.bignumber.equal(ether(750));

    })

    it('should fail burning tokens user doesnt have', async function () {
      await this.token.burn(ether(1000), {from: this.receiver}).should.be.rejectedWith(EVMRevert);
    })

    it('receiver should burn 500 -> check total supply', async function () {

      let startingSupply = await this.token.totalSupply.call();

      await this.token.burn(ether(500), {from: this.receiver});

      let supply = await this.token.totalSupply.call();
      supply.should.be.bignumber.equal(startingSupply.toNumber() - ether(500));

    })

    it('owner approves receiver 50 tokens, receiver burns 50 for owner', async function () {
      await this.token.approve(this.receiver, ether(50), {from: this.owner});
      await this.token.burnFrom(this.owner, ether(50), {from: this.receiver});

      let balance = await this.token.balanceOf(this.receiver);
      balance.should.be.bignumber.equal(ether(250));

    })

    it('owner approves receiver 50 tokens, receiver burns 50 for owner -> check total supply', async function () {

      let startingSupply = await this.token.totalSupply.call();

      await this.token.approve(this.receiver, ether(50), {from: this.owner});
      await this.token.burnFrom(this.owner, ether(50), {from: this.receiver});

      let supply = await this.token.totalSupply.call();
      supply.should.be.bignumber.equal(startingSupply.toNumber() - ether(50));

    })

  })


  describe('-- PARTNER FUNCTIONALITY --', function () {

    it('add partner', async function () {
      await this.token.updatePartner(this.partner, 100, {from: this.owner});

      let isPartner = await this.token.partners.call(this.partner);
      isPartner.should.be.bignumber.equal(100);

    })

    it('fail adding partner (not owner)', async function () {
      await this.token.updatePartner(this.partner, 100, {from: this.receiver}).should.be.rejectedWith(EVMRevert);
    })

    it('direct calls to add tokens should fail', async function () {
      try {
        await this.token.addTokens(1000, 10);
      } catch (error) {
        assert.isAbove(error.message.search('not a function'), -1, 'not a function');
      }
    })

    it('change reward rate to 5%', async function () {
      await this.token.updateReward(50, {from: this.owner});
      let reward = await this.token.rewardRate();
      reward.should.be.bignumber.equal(50);
    })

    it('should fail to change reward rate by non-owner', async function () {
      await this.token.updateReward(60, {from: this.receiver}).should.be.rejectedWith(EVMRevert);
    })

    it('transfer 200 tokens to partner and make sure reward rate creates the right amount of bonus tokens', async function () {
      await this.token.transfer(this.partner, ether(200), {from: this.receiver})

      let balance = await this.token.balanceOf(this.partner);
      balance.should.be.bignumber.equal(ether(210));

    })


  })


  describe('-- OWNER UPDATING FUNCTIONALITY --', function () {

    it('change owner', async function () {
      await this.token.ownerUpdate(0, 0, 0, this.receiver, {from: this.owner});
      let owner = await this.token.owner();
      owner.should.equal(this.receiver);
    })
    
    it('fail adding partner (not owner)', async function () {
      await this.token.updatePartner(this.partner, 100, {from: this.owner}).should.be.rejectedWith(EVMRevert);
    })

    it('change owner and fail on second try (since owner changed)', async function () {
      await this.token.ownerUpdate(0, 0, 0, this.owner, {from: this.receiver});
      await this.token.ownerUpdate(0, 0, 0, this.receiver, {from: this.receiver}).should.be.rejectedWith(EVMRevert);
    })

    it('change voting address', async function () {
      await this.token.ownerUpdate(0, this.receiver, 0, 0, {from: this.owner});
      let voting = await this.token.votingAddress();
      voting.should.equal(this.receiver);
    })

    it('change bank address', async function () {
      await this.token.ownerUpdate(0, 0, this.bank, 0, {from: this.owner});
      let bank = await this.token.bankAddress();
      bank.should.equal(this.bank);
    })

  })

  describe('-- INDIVIDUAL PARTNERSHIP FUNCTIONALITY --', function () {

    it('update partners individual reward rate to 5%', async function () {
      await this.token.updatePartner(this.partner, 105, {from: this.owner}); // 105% = 5% bonus

      let isPartner = await this.token.partners.call(this.partner);
      isPartner.should.be.bignumber.equal(105);

    })

    it('mint 1000 more tokens for receiver', async function () {
      await this.token.mint(this.receiver, ether(1000), {from: this.owner});
    })

    it('transfer 200 tokens to partner and make sure reward rate creates the right amount of bonus tokens', async function () {
      
      await this.token.transfer(this.partner, ether(100), {from: this.receiver})

      let balance = await this.token.balanceOf(this.partner);
      balance.should.be.bignumber.equal(ether(315.25));

    })

  })
  describe('-- TAX RATE FUNCTIONALITY --', function () {

    it('change tax rate to 5%', async function () {
      await this.token.ownerUpdate(5, 0, 0, 0, {from: this.owner});
      let tax = await this.token.taxRate();
      tax.should.be.bignumber.equal(5);
    })

    it('transfer 200 tokens to partner and make sure bank has correct amount of tokens from tax', async function () {
      await this.token.transfer(this.partner, ether(100), {from: this.receiver})

      let balance = await this.token.balanceOf(this.partner);
      balance.should.be.bignumber.equal(ether(420.2375));

      let bankBalance = await this.token.balanceOf(this.bank);
      bankBalance.should.be.bignumber.equal(ether(0.2625));

    })

  })

  describe('-- MAX DAILY BONUS --', function () {

    it('should make new day and change mintedToday to new amount, not mint more than max daily', async function () {
      let lastDay = await this.token.lastDay.call()
      await increaseTimeTo(lastDay + duration.days(2));

      await this.token.mint(this.owner, ether(500), {from: this.owner});
      await this.token.updateMaxDailyBonus(100, {from:this.owner});
      await this.token.updateReward(10,{from:this.owner});
      await this.token.updatePartner(this.partner,100,{from:this.owner});

      let firstBalance = await this.token.balanceOf(this.partner);
      await this.token.transfer(this.partner,5000,{from:this.owner});
      await this.token.transfer(this.partner,3000,{from:this.owner});
      await this.token.transfer(this.partner,10000,{from:this.owner});
      
      let thirdBalance = await this.token.balanceOf(this.partner);
      let b = new BigNumber(18077)
      thirdBalance.should.be.bignumber.equal(firstBalance.plus(b));

      let newDay = await this.token.lastDay.call()
      newDay.should.be.bignumber.equal(lastDay + duration.days(2))
    })

  })

})
