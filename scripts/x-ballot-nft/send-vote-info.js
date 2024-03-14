// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require('hardhat');
const { getConfigPath } = require('../private/_helpers.js');
const { getIbcApp } = require('../private/_vibc-helpers.js');

async function main() {
    const accounts = await hre.ethers.getSigners();
    const config = require(getConfigPath());
    const sendConfig = config.sendPacket;

    const networkName = hre.network.name;
    // Get the contract type from the config and get the contract
    const ibcApp = await getIbcApp(networkName);

    const voterAddress = accounts[1].address;
    const recipient = voterAddress;

    // console.log(`Casting a vote from address: ${voterAddress}`);
    await ibcApp.connect(accounts[1]).vote(1);
    // console.log("Vote cast");

    // Do logic to prepare the packet
    const channelId = sendConfig[`${networkName}`]["channelId"];
    const channelIdBytes = hre.ethers.encodeBytes32String(channelId);
    const timeoutSeconds = sendConfig[`${networkName}`]["timeout"];
    
    // Send the packet
    // console.log(`Sending a packet via IBC to mint an NFT for ${recipient} related to vote from ${voterAddress}`);
    await ibcApp.connect(accounts[0]).sendPacket(
        channelIdBytes,
        timeoutSeconds,
        voterAddress,
        recipient
      );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});