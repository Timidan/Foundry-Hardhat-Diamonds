const dotenv = require('dotenv');
dotenv.config();
/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('@nomiclabs/hardhat-ethers');
module.exports = {
    solidity: '0.8.18',
    defaultNetwork: "goerli",
    networks: {
        goerli: {
            url: process.env.GOERLI_RPC,
            accounts: [process.env.PRIVATE_KEY1]
        }
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN,
        customChains: [],
    }
}