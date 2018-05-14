var Powh3d = artifacts.require("./Powh3d.sol");
//import assertRevert from './helpers/assertRevert';

contract('Powh3d', (accounts) => {
    var contract;
    //var owner = "0xe0b6a32700c7F9495B698fda5B8E51BEb510a542";
    var owner = accounts[0]; // for test

    var rate = Number(8342);
    var buyWei = Number(1 * 10**18);
    var rateNew = Number(8342);
    var buyWeiNew = 5 * 10**17;
    var buyWeiMin = 1 * 10**15;
    var totalSupply = 161666667 * 10**18;

    it('should deployed contract', async ()  => {
        assert.equal(undefined, contract);
        contract = await Powh3d.deployed();
        assert.notEqual(undefined, contract);
    });

    it('get address contract', async ()  => {
        assert.notEqual(undefined, contract.address);
    });

    it('verification balance owner contract', async ()  => {
        var balanceOwner = await contract.balanceOf(owner);
        //console.log("balanceOwner = " + balanceOwner);
        assert.equal(totalSupply, balanceOwner);
    });


    it('verification of receiving Ether', async ()  => {

        var tokenAllocatedBefore = await contract.tokenAllocated.call();
        await contract.addToWhitelist(accounts[2], {from:accounts[0]});
        var isWhiteList = await contract.whitelist.call(accounts[2]);
        assert.equal(true, isWhiteList);
        var balanceAccountTwoBefore = await contract.balanceOf(accounts[2]);
        var weiRaisedBefore = await contract.weiRaised.call();
        //console.log("tokenAllocatedBefore = " + tokenAllocatedBefore);

        await contract.buyTokens(accounts[2],{from:accounts[2], value:buyWei});
        var tokenAllocatedAfter = await contract.tokenAllocated.call();
        //console.log("tokenAllocatedAfter = " + tokenAllocatedAfter + "; rate*buyWei = " + Number(rate*buyWei));
        assert.isTrue(tokenAllocatedBefore < tokenAllocatedAfter);
        assert.equal(0, tokenAllocatedBefore);
        assert.equal(Number(rate*buyWei), Number(tokenAllocatedAfter));

       var balanceAccountTwoAfter = await contract.balanceOf(accounts[2]);
        assert.isTrue(balanceAccountTwoBefore < balanceAccountTwoAfter);
        assert.equal(0, balanceAccountTwoBefore);
        assert.equal(rate*buyWei, balanceAccountTwoAfter);

        var weiRaisedAfter = await contract.weiRaised.call();
        //console.log("weiRaisedAfter = " + weiRaisedAfter);
        assert.isTrue(weiRaisedBefore < weiRaisedAfter);
        assert.equal(0, weiRaisedBefore);
        assert.equal(buyWei, weiRaisedAfter);

        var depositedAfter = await contract.getDeposited.call(accounts[2]);
        //console.log("DepositedAfter = " + depositedAfter);
        assert.equal(buyWei, depositedAfter);

        await contract.addToWhitelist(accounts[3], {from:accounts[0]});
        var isWhiteList = await contract.whitelist.call(accounts[3]);
        assert.equal(true, isWhiteList);

        var balanceAccountThreeBefore = await contract.balanceOf(accounts[3]);
        await contract.buyTokens(accounts[3],{from:accounts[3], value:buyWeiNew});
        var balanceAccountThreeAfter = await contract.balanceOf(accounts[3]);
        assert.isTrue(balanceAccountThreeBefore < balanceAccountThreeAfter);
        assert.equal(0, balanceAccountThreeBefore);
        //console.log("balanceAccountThreeAfter = " + balanceAccountThreeAfter);
        assert.equal(rateNew*buyWeiNew, balanceAccountThreeAfter);

        var balanceOwnerAfter = await contract.balanceOf(owner);
        //console.log("balanceOwnerAfter = " + Number(balanceOwnerAfter));
        //assert.equal(totalSupply - balanceAccountThreeAfter - balanceAccountTwoAfter, balanceOwnerAfter);
    });

    it('verification define period', async ()  => {
        var currentDate = 1532476800; // Jul, 25
        period = await contract.getPeriod(currentDate);
        assert.equal(10, period);

        currentDate = 1533513600; // Aug, 06
        period = await contract.getPeriod(currentDate);
        assert.equal(0, period);

        currentDate = 1534118400; // Aug, 13
        period = await contract.getPeriod(currentDate);
        assert.equal(1, period);

        currentDate = 1534723200; // Aug, 20
        period = await contract.getPeriod(currentDate);
        assert.equal(2, period);

        currentDate = 1535328000; // Aug, 27
        period = await contract.getPeriod(currentDate);
        assert.equal(3, period);

        currentDate = 1535846400; // Sep, 2
        period = await contract.getPeriod(currentDate);
        assert.equal(4, period);

        currentDate = 1537747200; // Sep, 24
        period = await contract.getPeriod(currentDate);
        assert.equal(10, period);
    });

    it('verification claim tokens', async ()  => {
        await contract.addToWhitelist(accounts[1], {from:accounts[0]});
        var isWhiteList = await contract.whitelist.call(accounts[1]);
        assert.equal(true, isWhiteList);

        var balanceAccountOneBefore = await contract.balanceOf(accounts[1]);
        assert.equal(0, balanceAccountOneBefore);
        await contract.buyTokens(accounts[1],{from:accounts[1], value:buyWei});
        var balanceAccountOneAfter = await contract.balanceOf(accounts[1]);
        await contract.transfer(contract.address,balanceAccountOneAfter,{from:accounts[1]});
        var balanceContractBefore = await contract.balanceOf(contract.address);
        assert.equal(buyWei*rate, balanceContractBefore);
        //console.log("balanceContractBefore = " + balanceContractBefore);
        var balanceAccountAfter = await contract.balanceOf(accounts[1]);
        assert.equal(0, balanceAccountAfter);
        var balanceOwnerBefore = await contract.balanceOf(owner);
        await contract.claimTokens(contract.address,{from:accounts[0]});
        var balanceContractAfter = await contract.balanceOf(contract.address);
        assert.equal(0, balanceContractAfter);
        var balanceOwnerAfter = await contract.balanceOf(owner);
        assert.equal(true, balanceOwnerBefore<balanceOwnerAfter);
    });

    it('verification tokens limit min amount', async ()  => {
        var numberTokensMinWey = await contract.validPurchaseTokens.call(buyWeiMin);
        //console.log("numberTokensMinWey = " + numberTokensMinWey);
        assert.equal(0, Number(numberTokensMinWey));
    });

    it('verification burning of tokens', async ()  => {
        var balanceOwnerBefore = await contract.balanceOf(owner);
        await contract.ownerBurnToken(1*10**18);
        var balanceOwnerAfter = await contract.balanceOf(owner);
        assert.equal(true, balanceOwnerBefore > balanceOwnerAfter);
    });

});



