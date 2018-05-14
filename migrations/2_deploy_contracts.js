const Powh3d = artifacts.require('./Powh3d.sol');

module.exports = (deployer) => {
    //http://www.onlineconversion.com/unix_time.htm
    var owner = "0xe0b6a32700c7F9495B698fda5B8E51BEb510a542";

    deployer.deploy(Powh3d, owner);

};
