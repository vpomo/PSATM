var PSATM = artifacts.require("./PSATM.sol");
//import assertRevert from './helpers/assertRevert';

contract('PSATM', (accounts) => {
    var contract;
    //var owner = "0xe0b6a32700c7F9495B698fda5B8E51BEb510a542";
    var buyWei = 1*10**17; // for test
    var buyWeiNew = 1*10**12; // for test

    it('should deployed contract', async ()  => {
        assert.equal(undefined, contract);
        contract = await PSATM.deployed();
        assert.notEqual(undefined, contract);
    });

    it('get address contract', async ()  => {
        assert.notEqual(undefined, contract.address);
    });

    it('verification of sellPrice and buyPrice before the purchase', async ()  => {
        var sellPrice = await contract.sellPrice();
        //console.log("sellPrice = " + sellPrice);
        assert.equal(9e9, sellPrice);
        var buyPrice = await contract.buyPrice();
        assert.equal(11.5e9, buyPrice);
    });


it('verification of buy Token', async ()  => {
        var totalSupply = await contract.totalSupply.call();
        assert.equal(0, totalSupply);
        var totalEthereumBalance = await contract.totalEthereumBalance.call();
        //console.log("totalEthereumBalance = " + totalEthereumBalance);
        assert.equal(0, totalEthereumBalance);

        await contract.buy(accounts[1], {from:accounts[0], value:buyWei});

        var totalSupply = await contract.totalSupply.call();
        //console.log("totalSupply = " + totalSupply);
        var fundResearch = await contract.fundResearch.call();
        //console.log("fundResearch = " + fundResearch);

        var balanceOne = await contract.balanceOf(accounts[0]);
        var balanceTwo = await contract.balanceOf(accounts[1]);

        var balanceRefOne = await contract.balanceRefferalOf(accounts[0]);
        var balanceRefTwo = await contract.balanceRefferalOf(accounts[1]);


        //console.log("balanceOne = " + balanceOne + "; balanceTwo = " + balanceTwo);
        //console.log("balanceRefOne = " + balanceRefOne + "; balanceRefTwo = " + balanceRefTwo);
        assert.equal(Number(fundResearch), Number(balanceRefTwo));

        var myDividendsAccOne = await contract.myDividends(false, {from:accounts[1]});
        assert.equal(0, myDividendsAccOne);
        var myDividendsRefAccOne = await contract.myDividends(true, {from:accounts[1]});
        assert.equal(Number(balanceRefTwo), Number(myDividendsRefAccOne));
        //console.log("myDividends = " + myDividends);
        //console.log(JSON.stringify(totalSupplyTest));
        //assert.equal(Number(totalSupplyTest), Number(maxTotalSupply));

    });

    it('verification of sell Token', async ()  => {
        var totalSupply = await contract.totalSupply.call();
        //console.log("totalSupplySell = " + totalSupply);
        var totalEthereumBalance = await contract.totalEthereumBalance.call();
        //console.log("totalEthereumBalanceSell = " + totalEthereumBalance);

        await contract.buy(accounts[1], {from:accounts[3], value:buyWei});

        var balanceThree = await contract.balanceOf(accounts[3]);
        //console.log("balanceThree = " + balanceThree);
        var totalSupply = await contract.totalSupply.call();
        //console.log("totalSupplySell = " + totalSupply);

        await contract.buy(accounts[1], {from:accounts[4], value:buyWei});
        var balanceFour = await contract.balanceOf(accounts[4]);
        //console.log("balanceFour = " + balanceFour);
        var totalSupply = await contract.totalSupply.call();
        //console.log("totalSupplySell = " + totalSupply);
        assert.equal(true, Number(balanceThree) > Number(balanceFour));

    });

    it('verification of sellPrice and buyPrice after the purchase', async ()  => {
        var sellPrice = await contract.sellPrice();
        //assert.equal(9e9, sellPrice);
        // 3.52 * 10e58
        //console.log("sellPrice = " + sellPrice);
        var buyPrice = await contract.buyPrice();
        //console.log("buyPrice = " + buyPrice);
        //assert.equal(11.5e9, buyPrice);
        // 4.18 * 10e58
        assert.equal(true, Number(buyPrice) > Number(sellPrice));
    });


});



