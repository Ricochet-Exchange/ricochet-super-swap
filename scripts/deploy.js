// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const RexSuperSwap = await hre.ethers.getContractFactory("RexSuperSwap");
  const superSwap = await RexSuperSwap.deploy("0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45", "0x0000000000000000000000000000000000000000", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270");

  await superSwap.deployed();

  console.log("RexSuperSwap deployed to:", superSwap.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
