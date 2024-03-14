const { exec } = require("child_process");
const {getConfigPath, getWhitelistedNetworks} = require('../private/_helpers.js');
const { setupIbcPacketEventListener } = require('../private/_events.js');
const { setupXBallotNFTEventListener } = require('./_app-events.js');

function runSendPacketCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error(`exec error: ${error}`);
        reject(error);
      } else {
        console.log(stdout);
        resolve(true);
      }
    });
  });
}

async function runSendPacket(config) {
  const source = config.createChannel.srcChain;

  // Check if the source chain from user input is whitelisted
  const allowedNetworks = getWhitelistedNetworks();
  if (!allowedNetworks.includes(source)) {
    console.error("❌ Please provide a valid source chain");
    process.exit(1);
  }

  const script = config.isUniversal ? 'send-universal-vote-info.js' : 'send-vote-info.js';
  const command = `npx hardhat run scripts/x-ballot-nft/${script} --network ${source}`;

  try {
    await setupIbcPacketEventListener();
    await setupXBallotNFTEventListener();
    await runSendPacketCommand(command);
  } catch (error) {
    console.error("❌ Error sending packet: ", error);
    process.exit(1);
  }
}

async function main() {
  const configPath = getConfigPath();
  const config = require(configPath);

  await runSendPacket(config);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});