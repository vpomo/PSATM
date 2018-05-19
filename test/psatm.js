var PSATM = artifacts.require("./PSATM.sol");
//import assertRevert from './helpers/assertRevert';

contract('PSATM', (accounts) => {
    var contract;
    //var owner = "0xe0b6a32700c7F9495B698fda5B8E51BEb510a542";
    var buyWei = 1*10**17; // for test

    it('should deployed contract', async ()  => {
        assert.equal(undefined, contract);
        contract = await PSATM.deployed();
        assert.notEqual(undefined, contract);
    });

    it('get address contract', async ()  => {
        assert.notEqual(undefined, contract.address);
    });

    it('verification of buy Token', async ()  => {
        var totalSupply = await contract.totalSupply.call();
        assert.equal(0, totalSupply);
        var totalEthereumBalance = await contract.totalEthereumBalance.call();
        console.log("totalEthereumBalance = " + totalEthereumBalance);
        assert.equal(0, totalEthereumBalance);

        await contract.buy(accounts[1], {from:accounts[0], value:buyWei});
        var totalSupply = await contract.totalSupply.call();
        console.log("totalSupply = " + totalSupply);
var totalEthereumBalance = await contract.totalEthereumBalance.call();
console.log("totalEthereumBalance = " + totalEthereumBalance);

//console.log(JSON.stringify(totalSupplyTest));
//assert.equal(Number(totalSupplyTest), Number(maxTotalSupply));

    });

});



