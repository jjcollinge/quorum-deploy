var CoinsContract = artifacts.require("./CoinsContract.sol");

module.exports = function(deployer) {
  deployer.deploy(CoinsContract);
};
