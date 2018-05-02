import ether from './helpers/ether'
import {advanceBlock} from './helpers/advanceToBlock'
import {increaseTimeTo, duration} from './helpers/increaseTime'
import latestTime from './helpers/latestTime'
import EVMRevert from './helpers/EVMRevert'
import EVMThrow from './helpers/EVMThrow'

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
const Token               = artifacts.require('../contracts/CoinvestToken')
const testContract				= artifacts.require('../contracts/TestApproveAndCall')

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

contract('Token', function ([_, wallet]) {

  beforeEach(async function() {

    this.owner             = web3.eth.accounts[0];
    this.accountTwo        = web3.eth.accounts[1];
    this.accountThree      = web3.eth.accounts[2];
    this.accountFour       = web3.eth.accounts[3];

    this.totalBalance      = 107142857;

    this.token             = await Token.new({from: this.owner});
		this.testContract			 = await testContract.new({from: this.owner});	

    this.web3              = this.token.web3;

  })

  /**describe('Construction', function () { 

    it('0x4e7 should be maintainer and have entire token balance', async function () {

      let address = await this.token.owner()
      address.should.be.equal(this.owner)

      let balance = await this.token.balanceOf(this.owner)
      balance.should.be.bignumber.equal(toEther(this.totalBalance))

    })

  })**/


/* ***************************** transfer ********************************* */


  /**describe('Transfers', function () {

		// Make sure transfer succeeds
    it('should send 1000 tokens from owner to accountTwo', async function () {

			// We're gonna make a transfer first to ensure no HackerGold-esque bug occurrs
      await this.token.transfer(this.accountTwo, toEther(1000), {from: this.owner})

			let ownerBalance = await this.token.balanceOf(this.owner)
      let twoBalance = await this.token.balanceOf(this.accountTwo)

      ownerBalance.should.be.bignumber.equal(toEther(107141857))
			twoBalance.should.be.bignumber.equal(toEther(1000))
  
    })

		// Make sure transfer succeeds when sending full balance
    it('should send full balance from owner', async function () {

      await this.token.transfer(this.accountTwo, toEther(107142857), {from: this.owner})

      let ownerBalance = await this.token.balanceOf(this.owner)
			let twoBalance = await this.token.balanceOf(this.accountTwo)

			ownerBalance.should.be.bignumber.equal(0)
			twoBalance.should.be.bignumber.equal(toEther(107142857))
  
    })

		// Make sure transfer fails when needed
    it('should fail when address sends more tokens than it has', async function () {

      await this.token.transfer(this.owner, toEther(10000), {from: this.accountTwo}).should.be.rejectedWith(EVMRevert);

    })

  })**/
  
  
/* ************************** approve and transferFrom *********************** */


  describe('Approves', function () {

		// Make sure approve succeeds
    it('should approve 500 tokens to be sent by accountTwo', async function() {
    
      await this.token.approve(this.accountTwo, toEther(500), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })

		// Make sure approve fails when needed
    it('should fail to approve tokens it doesnt have', async function() {
    
      await this.token.approve(this.accountThree, toEther(5000), {from: this.accountTwo}).should.be.rejectedWith(EVMRevert);

    })

		// Make sure approve succeeds
    it('should increaseApproval 500 tokens to be sent by accountTwo', async function() {
    
      await this.token.increaseApproval(this.accountTwo, toEther(500), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })

		// Make sure approve succeeds
    it('should fail on increaseApproval it doesn\'t have', async function() {
    
      await this.token.increaseApproval(this.owner, toEther(500), {from: this.accountTwo}).should.be.rejectedWith(EVMRevert);

    })

    // Make sure approve succeeds
    it('should decreaseApproval 500 tokens to be sent by accountTwo', async function() {
  
      await this.token.approve(this.accountTwo, toEther(1000), {from: this.owner})

      await this.token.decreaseApproval(this.accountTwo, toEther(500), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })
    
    // Make sure approve succeeds
    it('decreaseApproval should go to 0 if more than approve amount', async function() {
  
      await this.token.approve(this.accountTwo, toEther(500), {from: this.owner})

      await this.token.decreaseApproval(this.accountTwo, toEther(1000), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(0)

    })

  })


/* ******************************** transferFrom ******************************** */


  /**describe('transferFrom', function () {

		// Make sure transferFrom succeeds and balances are changed correctly
    it('should transfer 500 tokens on behalf of owner to accountFour', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from: this.owner})

      await this.token.transferFrom(this.owner, this.accountFour, toEther(500), {from: this.accountTwo})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(0)

			let newReceiverBalance = await this.token.balanceOf(this.accountFour)
			let newSenderBalance = await this.token.balanceOf(this.owner)

			newReceiverBalance.should.be.bignumber.equal(toEther(500))
			newSenderBalance.should.be.bignumber.equal(toEther(107142357))

    })


		// Make sure transferFrom succeeds and balances are changed correctly when sending full balance
    it('should transferFrom full balance to accountTwo', async function() {

      await this.token.approve(this.accountTwo, toEther(107142857), {from: this.owner})

      await this.token.transferFrom(this.owner, this.accountTwo, toEther(107142857), {from: this.accountTwo})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(0)

			let newReceiverBalance = await this.token.balanceOf(this.accountTwo)
			let newSenderBalance = await this.token.balanceOf(this.owner)

			newReceiverBalance.should.be.bignumber.equal(toEther(107142857))
			newSenderBalance.should.be.bignumber.equal(0)

    })

  		// Make sure transferFrom fails without allowance
    it('should fail to transferFrom tokens its not allowed to', async function() {
    
      await this.token.transferFrom(this.owner, this.accountThree, toEther(5000), {from: this.accountTwo}).should.be.rejectedWith(EVMRevert);

		})

		// Make sure transferFrom fails when trying to transfer more than balance: accountFour should have 500 tokens
		it('should fail when sending more than "from" balance', async function() {

			await this.token.approve(this.accountTwo, toEther(107142857), {from: this.owner})

			await this.token.transfer(this.accountTwo, toEther(400), {from:this.owner})

			await this.token.transferFrom(this.owner, this.accountTwo, toEther(107142857), {from:this.accountTwo}).should.be.rejectedWith(EVMRevert);

    })

  })**/


/* ****************************** approveAndCall ********************************** */


  /**describe('approveAndCall', function () {

		it('should give 500 allowance and immediately transferFrom', async function() {

			await this.token.approveAndCall(this.testContract.address, toEther(500), '0x0', {from:this.owner})

			let allowance = await this.token.allowance(this.owner, this.testContract.address)
      allowance.should.be.bignumber.equal(0)

      let contractBalance = await this.token.balanceOf(this.testContract.address)
      let ownerBalance = await this.token.balanceOf(this.owner)

      contractBalance.should.be.bignumber.equal(toEther(500))
      ownerBalance.should.be.bignumber.equal(toEther(107142357))

		})

		it('should give full balance allowance and immediately transferFrom', async function() {

			await this.token.approveAndCall(this.testContract.address, toEther(107142857), '0x0', {from:this.owner})

			let allowance = await this.token.allowance(this.owner, this.testContract.address)
      allowance.should.be.bignumber.equal(0)

      let contractBalance = await this.token.balanceOf(this.testContract.address)
      let ownerBalance = await this.token.balanceOf(this.owner)

      contractBalance.should.be.bignumber.equal(toEther(107142857))
      ownerBalance.should.be.bignumber.equal(0)

		})

		it('should fail on too much allowance', async function() {

      // One Ether over max
			await this.token.approveAndCall(this.testContract.address, toEther(107142858), '0x0', {from:this.owner}).should.be.rejectedWith(EVMRevert);

		})

  })**/


/*********************************** ERC865 ************************************ */


  /**describe('ERC865 Hashing', function () { 

		it('should return the correct hash, ecrecover should return owner', async function() {

      // Normal transfer function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let address = await this.token.recoverPreSigned(signature, 0xa9059cbb, this.accountTwo, 1, 0, 1, 1)
      address.should.be.equal(this.owner)
    
    })

  })**/


/* ***************************** transferPreSigned **************************** */


  describe('ERC865 transferPreSigned', function() {

    it('should give value to two and gas to three', async function() {

      // Normal transfer function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      // Send from owner to accountTwo with accountThree as delegate
      // signature, to address, value, gas price, nonce
      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})

      let twoBalance = await this.token.balanceOf(this.accountTwo)
      let threeBalance = await this.token.balanceOf(this.accountThree)
      
      twoBalance.should.be.bignumber.equal(1)
      //threeBalance.should.be.bignumber.equal(110432)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.transferPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should fail on too many tokens', async function() {

      // Signing with account two (0 tokens)
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.accountTwo, preSignedHash);

      await this.token.transferPreSigned(signature, this.owner, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // Normal approve function sig in here
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail with data', async function() {

      // Normal increaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.owner, 1, 1, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

  })


/* ******************************* approvePreSigned *************************** */


  describe('ERC865 approvePreSigned', function() {

    it('should approve two and give gas to three', async function() {

      // Normal approve function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let balance = await this.token.balanceOf(this.owner)

      // signature, to, value, gas price, nonce
      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      allowance.should.be.bignumber.equal(1)
      //threeBalance.should.be.bignumber.equal(110432)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.accountTwo, 1, 1, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      console.log

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal approve function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approvePreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should fail on too many tokens', async function() {

      // Sending from account two
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.accountTwo, preSignedHash);

      await this.token.approvePreSigned(signature, this.owner, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree});
      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // transfer function sig here
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail with data', async function() {

      // Normal approve function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.owner, 1, 1, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

  })



/* ****************************** increaseApprovalPreSigned ************************* */


  /**describe('ERC865 increaseApprovalPresigned', function() {

    it('should approve two and give gas to three', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      // signature, to, value, gas price, nonce
      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      let threeBalance = await this.token.balanceOf(this.accountThree)
      //console.log(threeBalance)

      allowance.should.be.bignumber.equal(1)
      //threeBalance.should.be.bignumber.equal(110432)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.accountTwo, 1, 1, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should fail on too many tokens', async function() {

      // Signing with account two
      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.accountTwo, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.owner, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // Sending with approve function sig
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail with data', async function() {

      // Normal increaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.owner, 1, 1, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

  })**/


/* ************************** decreaseApprovalPreSigned **************************** */


  /**describe('ERC865 decreaseApprovalPresigned', function() {

    it('should approve two and give gas to three', async function() {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal approve function sig, to address, value, extra data, gas price, nonce of 2 (although it shouldn't matter)
      let preSignedHash = await this.token.getPreSignedHash(0x66188463, this.accountTwo, toEther(100), 0, 1, 2)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 2, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      allowance.should.be.bignumber.equal(toEther(400))
      //threeBalance.should.be.bignumber.equal(110432)

    })


    it('should increment nonce', async function() {
      
      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash(0x66188463, this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas price', async function() {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal decreaseApproval function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0x66188463, this.accountTwo, toEther(100), 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 0, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should decrease to 0 on too many tokens', async function() {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Only 500 approved, decreasing by 600
      let preSignedHash = await this.token.getPreSignedHash(0x66188463, this.accountTwo, toEther(600), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(600), 1, 1, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(0)
 
    })

    it('should fail on repeat sig', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash(0x66188463, this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})
      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // increaseApproval function sig here
      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail with data', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal decreaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xd73dd623, this.accountTwo, toEther(100), 1, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

     })

  })**/


/* ************************* approveAndCallPreSigned ************************* */


  describe('ERC865 approveAndCallPresigned', function() {

    it('should approve two and give gas to three', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      // signature, to, value, gas price, nonce
      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree})

      let testBalance = await this.token.balanceOf(this.testContract.address)
      let threeBalance = await this.token.balanceOf(this.accountThree)
      //console.log(threeBalance)

      testBalance.should.be.bignumber.equal(1)
      //threeBalance.should.be.bignumber.equal(110432)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.testContract.address, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should fail on too many tokens', async function() {

      // Signing with account two
      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.accountTwo, preSignedHash);

      await this.token.approveAndCallPreSigned(signature, this.owner, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree})
      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // Sending with approve function sig
      let preSignedHash = await this.token.getPreSignedHash(0x095ea7b3, this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should succeed with data', async function() {

      // Normal increaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.testContract.address, 1, 1, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 1, 1, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should fail on call to wallet address', async function() {

      // Normal increaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash(0xcae9ca51, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

  })

/* *************************** revokeSignature ******************************* */


  /**describe('revokeSignature', function () {

    it('should make invalid signature and fail on attempt to send', async function() {

      // Arbitrary transfer preSigned
      // 0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301
      let preSignedHash = await this.token.getPreSignedHash(0xa9059cbb, this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.revokeSignature(signature)

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);     

    })

  })

  describe('revokeSignaturePreSigned', function () {

    it('should revoke signature and send gas to delegate', async function() {

      // Arbitrary transfer preSigned
      let signature = 0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301

      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 1)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 1, {from: this.accountThree})
      assert.isOk(tx)

      // Check delegate balance
      let threeBalance = await this.token.balanceOf(this.accountThree)
      console.log("Three balance:", threeBalance)

      // Make sure signature is revoked
      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);     

    })

    it('should increment nonce', async function() {

      // Arbitrary transfer preSigned
      let signature = 0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301

      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 1)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 1, {from: this.accountThree})
      assert.isOk(tx)

      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Arbitrary transfer preSigned
      let signature = 0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301

      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 0)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 0, {from: this.accountThree})
      assert.isOk(tx)

      // Check delegate balance
      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.equal(0)

      // Make sure signature is revoked
      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);     

    })

    it('should fail on repeat sig', async function() {

      // Arbitrary transfer preSigned
      let signature = 0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301

      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 0)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 0, {from: this.accountThree})
      assert.isOk(tx)

      await this.token.revokeSignaturePreSigned(revokeSig, signature, 0, {from: this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

  })**/


/******************************** Constants ************************************/


/**describe('Constants', function () {

  it('totalSupply should return the correct total supply of tokens', async function() {

    let tokenSupply = await this.token.totalSupply()
    tokenSupply.should.be.bignumber.equal(toEther(107142857))

  })

  it('balanceOf should return the correct balance of address', async function() {
  
    let balance = await this.token.balanceOf(this.owner)
    balance.should.be.bignumber.equal(toEther(107142857))
    
  })

  it('allowance should return the correct allowance for address', async function() {

    await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

    let allowance = await this.token.allowance(this.owner, this.accountTwo)
    allowance.should.be.bignumber.equal(toEther(500))

  })

})**/


/******************************* Maintainer *************************************/


  /**describe('updateStandard', function () { 

    it('should declare standards correctly', async function () {

      await this.token.updateStandard("0xdeadbeef", "0xcae9ca51", {from:this.owner})
      let result = await this.token.standardSigs("0xdeadbeef")
      result.should.be.equal("0xcae9ca51")

    })

    // Add require checks here

  })**/

  function toEther(value) {
    return web3.toWei(value, "ether")
  }

})