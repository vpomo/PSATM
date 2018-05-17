var Powh3d = artifacts.require("./Powh3d.sol");
//import assertRevert from './helpers/assertRevert';

contract('Powh3d', (accounts) => {
    var contract;
    //var owner = "0xe0b6a32700c7F9495B698fda5B8E51BEb510a542";
    var owner = accounts[0]; // for test

    it('should deployed contract', async ()  => {
        assert.equal(undefined, contract);
        contract = await Powh3d.deployed();
        assert.notEqual(undefined, contract);
    });

    it('get address contract', async ()  => {
        assert.notEqual(undefined, contract.address);
    });

    it('verification of receiving Ether', async ()  => {

    });

});



