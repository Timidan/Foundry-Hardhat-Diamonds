const { getSelectors, FacetCutAction } = require('./libraries/diamond.js');
const { ethers, network, run } = require('hardhat');
require("@nomiclabs/hardhat-etherscan");


const verify = async (contractAddress, args) => {
    console.log("Verifying contract...");
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        });
    } catch (e) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already verified!");
        } else {
            console.log(e);
        }
    }
};

async function deployAndVerifyDiamond() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];
    const chainId = network.config.chainId;

    // deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet')
    const diamondCutFacet = await DiamondCutFacet.deploy()
    await diamondCutFacet.deployed()
    console.log('DiamondCutFacet deployed:', diamondCutFacet.address);

    // verify DiamondCutFacet
    console.log(`Waiting for blocks confirmations...`);
    await diamondCutFacet.deployTransaction.wait(6);
    await verify(diamondCutFacet.address, []);
    console.log(`Confirmed!`);



    // deploy Diamond
    const Diamond = await ethers.getContractFactory('Diamond')
    const diamond = await Diamond.deploy(
        contractOwner.address,
        diamondCutFacet.address,
    )
    await diamond.deployed()
    console.log('Diamond deployed:', diamond.address)

    // verify Diamond
    console.log(`Waiting for blocks confirmations...`);
    await diamond.deployTransaction.wait(6);
    await verify(diamond.address, [contractOwner.address,
    diamondCutFacet.address,]);
    console.log(`Confirmed!`);

    // deploy DiamondInit
    // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
    // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
    const DiamondInit = await ethers.getContractFactory('DiamondInit');
    const diamondInit = await DiamondInit.deploy()
    await diamondInit.deployed()
    console.log('DiamondInit deployed:', diamondInit.address)

    // deploy facets
    console.log('')
    console.log('Deploying facets')
    const FacetNames = ['DiamondLoupeFacet', 'OwnershipFacet']
    const cut = []
    for (const FacetName of FacetNames) {
        const Facet = await ethers.getContractFactory(FacetName)
        const facet = await Facet.deploy()
        await facet.deployed()
        console.log(`${FacetName} deployed: ${facet.address}`)

        // verify facet
        console.log(`Waiting for blocks confirmations...`);
        await facet.deployTransaction.wait(6);
        await verify(facet.address, []);
        console.log(`Confirmed!`);
        cut.push({
            facetAddress: facet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(facet),
        })
    }

    // upgrade diamond with facets
    console.log('')
    console.log('Diamond Cut:', cut)
    const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address)
    let tx
    let receipt
    // call to init function
    let functionCall = diamondInit.interface.encodeFunctionData('init')
    tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall)
    console.log('Diamond cut tx: ', tx.hash)
    receipt = await tx.wait()
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`)
    }
    console.log('Completed diamond cut')
    return diamond.address
}

if (require.main === module) {
    deployAndVerifyDiamond()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error)
            process.exit(1)
        })
}

exports.deployAndVerifyDiamond = deployAndVerifyDiamond