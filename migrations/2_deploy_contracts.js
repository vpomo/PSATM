const PSATM = artifacts.require('./PSATM.sol');

module.exports = (deployer) => {
    //http://www.onlineconversion.com/unix_time.htm
    var ownerFundResearch = "0x135671C8BE605D909588E1b30720EFF5091a1552";

    deployer.deploy(PSATM, ownerFundResearch);

};
