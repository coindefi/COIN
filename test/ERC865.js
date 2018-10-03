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

    it('should make sender maintainer and have entire token balance', async function () {

      let address = await this.token.owner()
      address.should.be.equal(this.owner)

      let balance = await this.token.balanceOf(this.owner)
      balance.should.be.bignumber.equal(toEther(this.totalBalance))

    })

  })**/


/* ***************************** transfer ********************************* */


  /**describe('transfer', function () {

    it('should send 1000 tokens from owner to accountTwo', async function () {

			// We're gonna make a transfer first to ensure no HackerGold-esque bug occurrs
      await this.token.transfer(this.accountTwo, toEther(1000), {from: this.owner})

			let ownerBalance = await this.token.balanceOf(this.owner)
      let twoBalance = await this.token.balanceOf(this.accountTwo)

      ownerBalance.should.be.bignumber.equal(toEther(107141857))
			twoBalance.should.be.bignumber.equal(toEther(1000))
  
    })

    it('should send full balance from owner', async function () {

      await this.token.transfer(this.accountTwo, toEther(107142857), {from: this.owner})

      let ownerBalance = await this.token.balanceOf(this.owner)
			let twoBalance = await this.token.balanceOf(this.accountTwo)

			ownerBalance.should.be.bignumber.equal(0)
			twoBalance.should.be.bignumber.equal(toEther(107142857))
  
    })

    it('should emit Transfer event', async function () {

      let tx = await this.token.transfer(this.accountTwo, toEther(107142857), {from: this.owner})
      tx.logs[0].event.should.be.equal("Transfer")
  
    })

    it('should fail when address sends more tokens than it has', async function () {

      await this.token.transfer(this.owner, toEther(10000), {from: this.accountTwo}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on send to 0x0', async function () {

      await this.token.transfer(0, toEther(10000), {from: this.owner}).should.be.rejectedWith(EVMRevert);

    })

  })**/
  
  
/* ************************** approve and transferFrom *********************** */


  /**describe('approve/increaseApproval/decreaseApproval', function () {

    it('should approve 500 tokens to be sent by accountTwo', async function() {
    
      await this.token.approve(this.accountTwo, toEther(500), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })

    it('should emit Approve event', async function () {

      let tx = await this.token.approve(this.accountTwo, toEther(107142857), {from: this.owner})
      tx.logs[0].event.should.be.equal("Approval")
  
    })

    it('should increaseApproval by 500 tokens to be sent by accountTwo', async function() {
    
      await this.token.increaseApproval(this.accountTwo, toEther(500), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })

    it('should emit Approve event', async function () {

      let tx = await this.token.increaseApproval(this.accountTwo, toEther(107142857), {from: this.owner})
      tx.logs[0].event.should.be.equal("Approval")
  
    })

    it('should decreaseApproval by 500 tokens to be sent by accountTwo', async function() {
  
      await this.token.approve(this.accountTwo, toEther(1000), {from: this.owner})

      await this.token.decreaseApproval(this.accountTwo, toEther(500), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })
    
    it('should decreaseApproval to 0 if more than approve amount', async function() {
  
      await this.token.approve(this.accountTwo, toEther(500), {from: this.owner})

      await this.token.decreaseApproval(this.accountTwo, toEther(1000), {from: this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(0)

    })

    it('should emit Approve event', async function () {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      let tx = await this.token.decreaseApproval(this.accountTwo, toEther(107142857), {from: this.owner})
      tx.logs[0].event.should.be.equal("Approval")
  
    })

  })**/


/* ******************************** transferFrom ******************************** */


  /**describe('transferFrom', function () {

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

    it('should emit Transfer event', async function () {

      await this.token.approve(this.accountTwo, toEther(100), {from:this.owner})

      let tx = await this.token.transferFrom(this.owner, this.accountTwo, toEther(100), {from: this.accountTwo})
      tx.logs[0].event.should.be.equal("Transfer")

    })

    it('should fail to transferFrom tokens its not allowed to', async function() {
    
      await this.token.transferFrom(this.owner, this.accountThree, toEther(5000), {from: this.accountTwo}).should.be.rejectedWith(EVMRevert);

		})

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

  })**/


/*********************************** ERC865 ************************************ */


  /**describe('ERC865 Hashing', function () { 

		it('should return the correct transferPreSignedHash, ecrecover should return owner', async function() {

      // Normal transfer function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      let address = await this.token.recoverPreSigned(signature, '0xa9059cbb', this.accountTwo, 1, 0, 1, 1)
      address.should.be.equal(this.owner)

    })

		it('should return the correct approvePreSignedHash, ecrecover should return owner', async function() {

      // Normal approve function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let address = await this.token.recoverPreSigned(signature, '0x095ea7b3', this.accountTwo, 1, 0, 1, 1)
      address.should.be.equal(this.owner)

    })

		it('should return the correct increaseApprovalPreSigned, ecrecover should return owner', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      let address = await this.token.recoverPreSigned(signature, '0xd73dd623', this.accountTwo, 1, 0, 1, 1)
      address.should.be.equal(this.owner)
    
    })

		it('should return the correct decreaseApprovalPreSignedHash, ecrecover should return owner', async function() {

      // Normal decreaseApproval function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      let address = await this.token.recoverPreSigned(signature, '0x66188463', this.accountTwo, 1, 0, 1, 1)
      address.should.be.equal(this.owner)

    })

    it('should return the correct approveAndCallPreSignedHash, ecrecover should return owner', async function() {

      // Normal approveAndCall function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      let address = await this.token.recoverPreSigned(signature, '0xcae9ca51', this.accountTwo, 1, 0, 1, 1)
      address.should.be.equal(this.owner)

    })

  })**/


/* ***************************** transferPreSigned **************************** */


  /**describe('ERC865 transferPreSigned', function() {

    it('should send 100 tokens from one to two, and gas to three', async function() {

      // Normal transfer function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      // Send from owner to accountTwo with accountThree as delegate
      // signature, to address, value, gas price, nonce
      let tx = await this.token.transferPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})

      let ownerBalance = await this.token.balanceOf(this.owner)
      let twoBalance = await this.token.balanceOf(this.accountTwo)
      let threeBalance = await this.token.balanceOf(this.accountThree)
      
      // Make sure owner sent gas
      ownerBalance.should.be.bignumber.lessThan(toEther(107142757))
      twoBalance.should.be.bignumber.equal(toEther(100))
      threeBalance.should.be.bignumber.greaterThan(0)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.transferPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.equal(0)

    })

    it('should emit RedeemSignature event', async function () {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.transferPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      tx.logs[1].event.should.be.equal("SignatureRedeemed")

    })

    it('should fail on too many tokens', async function() {

      // Signing with account two (0 tokens)
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.accountTwo, preSignedHash);

      await this.token.transferPreSigned(signature, this.owner, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    
    })

    it('should fail with not enough bytes', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0x1296830d' + preRaw.substring(2, 560)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // Normal approve function sig in here
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    
    })

    it('should fail with data', async function() {

      // Normal transfer function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, "0x11", 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

  })**/


/* ******************************* approvePreSigned *************************** */


  /**describe('ERC865 approvePreSigned', function() {

    it('should approve two and give gas to three', async function() {

      // Normal approve function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, toEther(100), 0, 1, 1)

      let signature = web3.eth.sign(this.owner, preSignedHash);

      // signature, to, value, gas price, nonce
      await this.token.approvePreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      let ownerBalance = await this.token.balanceOf(this.owner)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      allowance.should.be.bignumber.equal(toEther(100))
      ownerBalance.should.be.bignumber.lessThan(toEther(107142857))
      threeBalance.should.be.bignumber.greaterThan(0)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal approve function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approvePreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.equal(0)

    })

    it('should emit RedeemSignature event', async function () {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approvePreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      tx.logs[1].event.should.be.equal("SignatureRedeemed")

    })

    it('should fail with not enough bytes', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0x617b390b' + preRaw.substring(2, 560)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree});
      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // transfer function sig here
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail with data', async function() {

      // Normal approve function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.owner, 1, "0x11", 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approvePreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

  })**/


/* ****************************** increaseApprovalPreSigned ************************* */


  /**describe('ERC865 increaseApprovalPresigned', function() {

    it('should approve two and give gas to three', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      // signature, to, value, gas price, nonce
      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      let ownerBalance = await this.token.balanceOf(this.owner)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      allowance.should.be.bignumber.equal(toEther(100))
      ownerBalance.should.be.bignumber.lessThan(toEther(107142857))
      threeBalance.should.be.bignumber.greaterThan(0)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal increaseApproval function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      assert.isOk(tx)
  
      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.equal(0)

    })

    it('should emit RedeemSignature event', async function () {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      tx.logs[1].event.should.be.equal("SignatureRedeemed")

    })

    it('should fail with not enough bytes', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0xadb8249e' + preRaw.substring(2, 560)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree})
      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // Sending with approve function sig
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.owner, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail with data', async function() {

      // Normal increaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.owner, 1, "0x11", 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.increaseApprovalPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

  })**/


/* ************************** decreaseApprovalPreSigned **************************** */


  /**describe('ERC865 decreaseApprovalPresigned', function() {

    it('should approve two and give gas to three', async function() {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal decreaseApproval function sig, to address, value, extra data, gas price, nonce of 2 (although it shouldn't matter)
      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, toEther(100), 0, 1, 2)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 2, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      let ownerBalance = await this.token.balanceOf(this.owner)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      allowance.should.be.bignumber.equal(toEther(400))
      ownerBalance.should.be.bignumber.lessThan(toEther(107142857))
      threeBalance.should.be.bignumber.greaterThan(0)

    })


    it('should increment nonce', async function() {
      
      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas price', async function() {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal decreaseApproval function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, toEther(100), 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 0, 1, {from:this.accountThree})
      assert.isOk(tx)

      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.equal(0)

    })

    it('should emit RedeemSignature event', async function () {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, 1, 0, 1, {from:this.accountThree})
      tx.logs[1].event.should.be.equal("SignatureRedeemed")

    })

    it('should fail with not enough bytes', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0x8be52783' + preRaw.substring(2, 560)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))
    
    })

    it('should decrease to 0 on too many tokens', async function() {

      // Approve first so we can decrease
      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Only 500 approved, decreasing by 600
      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, toEther(600), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(600), 1, 1, {from:this.accountThree})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(0)
 
    })

    it('should fail on repeat sig', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash('0x66188463', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})
      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // increaseApproval function sig here
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail with data', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      // Normal decreaseApproval function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xd73dd623', this.accountTwo, toEther(100), "0x11", 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.decreaseApprovalPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

     })

  })**/


/* ************************* approveAndCallPreSigned ************************* */


  /**describe('ERC865 approveAndCallPresigned', function() {

    it('should approve two and give gas to three', async function() {

      // Normal approveAndCall function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      // signature, to, value, gas price, nonce
      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, toEther(100), 0, 1, 1, {from:this.accountThree})

      let testBalance = await this.token.balanceOf(this.testContract.address)
      let ownerBalance = await this.token.balanceOf(this.owner)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      testBalance.should.be.bignumber.equal(toEther(100))
      ownerBalance.should.be.bignumber.lessThan(toEther(107142857))
      threeBalance.should.be.bignumber.greaterThan(0)

    })

    it('should increment nonce', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);
      
      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree})
      
      let nonce = await this.token.getNonce(this.owner)
      nonce.should.be.bignumber.equal(1)

    })

    it('should succeed with 0 gas', async function() {

      // Normal approveAndCall function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 0, 1, {from:this.accountThree})
      assert.isOk(tx)

      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.equal(0)

    })

    it('should succeed with data', async function() {

      // Normal approveAndCall function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 1, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 1, 1, 1, {from:this.accountThree})
      assert.isOk(tx)

    })

    it('should emit RedeemSignature event', async function () {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 0, 1, {from:this.accountThree})
      tx.logs[2].event.should.be.equal("SignatureRedeemed")

    })

    it('should fail with not enough bytes', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'bytes', 'uint256', 'uint256']
      let parameters = [signature, this.testContract.address, 1, '0x00', 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0xc8d4b389' + preRaw.substring(2, 760)

      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))
    
    })

    it('should fail on too many tokens', async function() {

      // Signing with account two
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.accountTwo, preSignedHash);

      await this.token.approveAndCallPreSigned(signature, this.owner, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail on repeat sig', async function() {

      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree})
      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail on wrong function sig', async function() {

      // Sending with approve function sig
      let preSignedHash = await this.token.getPreSignedHash('0x095ea7b3', this.testContract.address, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);
    })

    it('should fail on call to wallet address', async function() {

      // Normal approveAndCall function sig, to address, value, extra data of '1', gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xcae9ca51', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.approveAndCallPreSigned(signature, this.testContract.address, 1, 0, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

  })**/

/* *************************** revokeSignature ******************************* */


  /**describe('revokeSignature', function () {

    it('should make invalid signature and fail on attempt to send', async function() {

      // Arbitrary transfer preSigned
      // 0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      await this.token.revokeSignature(signature)

      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);     

    })

    it('should emit RedeemSignature event', async function () {

      // Normal transfer function sig, to address, value, extra data, ZERO gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, 1, 0, 0, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let tx = await this.token.revokeSignature(signature)
      tx.logs[0].event.should.be.equal("SignatureRedeemed")

    })

  })

  describe('revokeSignaturePreSigned', function () {

    it('should revoke signature and send gas to delegate', async function() {

      // Arbitrary transfer preSigned
      let signature = '0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301'

      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 1)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 1, {from: this.accountThree})
      assert.isOk(tx)

      // Make sure signature is revoked
      await this.token.transferPreSigned(signature, this.accountTwo, 1, 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert);     

      let threeBalance = await this.token.balanceOf(this.accountThree)
      threeBalance.should.be.bignumber.greaterThan(0)

    })

    it('should succeed with 0 gas', async function() {

      // Arbitrary transfer preSigned
      let signature = '0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301'

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

    it('should emit RedeemSignature event', async function () {

      let signature = '0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301'
      
      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 0)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 0, {from: this.accountThree})
      tx.logs[0].event.should.be.equal("SignatureRedeemed")

    })

    it('should fail on repeat sig', async function() {

      // Arbitrary transfer preSigned
      let signature = '0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301'

      // Signature to revoke, gas price
      let revokeHash = await this.token.getRevokeHash(signature, 0)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      // Revoke the signature
      let tx = await this.token.revokeSignaturePreSigned(revokeSig, signature, 0, {from: this.accountThree})
      assert.isOk(tx)

      await this.token.revokeSignaturePreSigned(revokeSig, signature, 0, {from: this.accountThree}).should.be.rejectedWith(EVMRevert);

    })

    it('should fail with not enough bytes', async function() {

      // Arbitrary transfer preSigned
      let signature = '0xf93425ee98d803f3a2e8a647ac655d02db00b2d42f1f3a7a79cb349309b6affd220f7f15a44d5798b255f8f45563f1bb10a7485608291eda8445b0cab55fd73301'

      let revokeHash = await this.token.getRevokeHash(signature, 0)
      let revokeSig = web3.eth.sign(this.owner, revokeHash);

      let typesArray = ['bytes', 'bytes', 'uint256']
      let parameters = [revokeSig, signature, 0]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0xe391a7c4' + preRaw.substring(2, 700)

      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))
    
    })

  })**/


/******************************** Fallback *************************************/


  /**describe('Fallback', function () {

    it('should redirect to our preSigned function from arbitrary sig', async function () {

      // arbitrary function sig => transferPreSigned sig
      await this.token.updateStandard('0xdeadbeef', '0x1296830d', {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0xdeadbeef' + preRaw.substring(2)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      let tx = web3.eth.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData})
      assert.isOk(tx)

      let ownerBalance = await this.token.balanceOf(this.owner)
      let twoBalance = await this.token.balanceOf(this.accountTwo)
      let threeBalance = await this.token.balanceOf(this.accountThree)

      ownerBalance.should.be.bignumber.lessThan(toEther(107142857))
      twoBalance.should.be.bignumber.equal(toEther(100))
      threeBalance.should.be.bignumber.greaterThan(0)

    })

    it('should redirect to our preSigned function from arbitrary sig', async function () {

      // arbitrary function sig => transferPreSigned sig
      await this.token.updateStandard('0xdeadbeef', '0x1296830d', {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0xdeadbeef' + preRaw.substring(2)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      let tx = web3.eth.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData})

    })

    it('should fail on unrecognized sig', async function () {

      // arbitrary function sig => transferPreSigned sig
      await this.token.updateStandard('0xdeadbeef', '0x1296830d', {from:this.owner})

      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      let typesArray = ['bytes', 'address', 'uint256', 'uint256', 'uint256']
      let parameters = [signature, this.accountTwo, toEther(100), 1, 1]
      let preRaw = web3Abi.encodeParameters(typesArray, parameters);
      let rawData = '0xdeadbead' + preRaw.substring(2)

      // transferPreSigned input. From is owner, to this.accountTwo, 
      expectThrow(this.token.sendTransaction({from:this.accountThree,to:this.token.address,gas:1000000,data:rawData}))

    })

  })**/


/******************************** Constants ************************************/


  /**describe('Constants', function () {

    it('should return the correct total supply of tokens', async function() {

      let tokenSupply = await this.token.totalSupply()
      tokenSupply.should.be.bignumber.equal(toEther(107142857))

    })

    it('should return the correct balance of address', async function() {
    
      let balance = await this.token.balanceOf(this.owner)
      balance.should.be.bignumber.equal(toEther(107142857))
      
    })

    it('should return the correct allowance for address', async function() {

      await this.token.approve(this.accountTwo, toEther(500), {from:this.owner})

      let allowance = await this.token.allowance(this.owner, this.accountTwo)
      allowance.should.be.bignumber.equal(toEther(500))

    })

    it('should return the correct symbol', async function() {

      let symbol = await this.token.symbol()
      symbol.should.be.equal("COIN")

    })

    it('should return the correct decimals', async function() {

      let decimals = await this.token.decimals()
      decimals.should.be.bignumber.equal(18)

    })

    it('should return the correct name', async function() {

      let name = await this.token.name()
      name.should.be.equal("Coinvest COIN V2 Token")

    })

  })**/


/******************************* Maintainer *************************************/


  /**describe('updateStandard', function () { 

    it('should declare standards correctly', async function () {

      await this.token.updateStandard("0xdeadbeef", "0x1296830d", {from:this.owner})
      let result = await this.token.standardSigs("0xdeadbeef")
      result.should.be.equal("0x1296830d")

    })

    it('should fail on non-owner call', async function () {

      await this.token.updateStandard("0xdeadbeef", "0x1296830d", {from:this.accountTwo}).should.be.rejectedWith(EVMRevert)

    })

    it('should fail when setting an unacceptable value', async function () {

      await this.token.updateStandard("0xdeadbeef", "0xa9059cbb", {from:this.owner}).should.be.rejectedWith(EVMRevert);

    })

  })

  describe('token_escape', function () {

    it('should be able to transfer any ERC20 off this contract to owner', async function () {

      await this.token.transfer(this.token.address, 1000, {from:this.owner})
      let tokenBalance = await this.token.balanceOf(this.token.address)
      tokenBalance.should.be.bignumber.equal(1000)

      await this.token.token_escape(this.token.address, {from:this.owner})
      let tokenBalanceTwo = await this.token.balanceOf(this.token.address)
      tokenBalanceTwo.should.be.bignumber.equal(0)

    })

    it('should fail on non-owner call', async function () {

      await this.token.transfer(this.token.address, 1000, {from:this.owner})
      await this.token.token_escape(this.token.address, {from:this.accountTwo}).should.be.rejectedWith(EVMRevert)

    })

  })**/

/* ************************* Sig Test ********************************** */

  describe('ERC865 transferPreSigned', function() {

    it('should fail with altered signature', async function() {

      // Normal transfer function sig, to address, value, extra data, gas price, nonce
      let preSignedHash = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      let signature = web3.eth.sign(this.owner, preSignedHash);

      console.log("Normal signature:",signature)

      let secondSig = web3.eth.accounts.sign(preSignedHash, "c4939332fec695d19f07ea0eb7a99167a970d52700f1c1c6b9e44c7d4668b026")
      console.log("Second signature", secondSig)

      // Send from owner to accountTwo with accountThree as delegate
      // signature, to address, value, gas price, nonce
      //let tx = await this.token.transferPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})
      //assert.isOk(tx)

      //let preSignedHash2 = await this.token.getPreSignedHash('0xa9059cbb', this.accountTwo, toEther(100), 0, 1, 1)
      //let signature2 = web3.eth.sign(this.owner, preSignedHash2);
      //signature2 = signature2.slice(0, -2) + '1'

      //console.log(signature2)
      //let signature2 = "0x14b07a15d658defd8a68fdd00a3248fabfa702211c19b43af95fb147a8e4a455B4739099E05ECA66BAD0317C6DCD9D906387EFBFF284F14505B7F5AE25164CC601"
      //console.log("Altered signature:",signature2)

      //await this.token.transferPreSigned(signature2, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree}).should.be.rejectedWith(EVMRevert)

      //let tx2 = await this.token.transferPreSigned(signature, this.accountTwo, toEther(100), 1, 1, {from:this.accountThree})
     // assert(tx2.isOk)

    })


  })

/* **************************************************************************** */

  function toEther(value) {
    return web3.toWei(value, "ether")
  }

})