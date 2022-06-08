const { AbiCoder } = require('ethers/lib/utils')
const { artifacts, ethers } = require('hardhat')
const hre = require('hardhat')
const args = process.argv.slice(2)

if (args.length != 1) {
  console.log(`please supply the correct parameters:
    facetName
  `)
  process.exit(1)
}

async function printSelectors(contractName) {
  const target = await ethers.getContractFactory(contractName)
  const signatures = Object.keys(target.interface.functions)

  const selectors = signatures.reduce((acc, val) => {
    if (val !== 'init(bytes)') {
      acc.push(target.interface.getSighash(val))
    }
    return acc
  }, [])

  const coder = ethers.utils.defaultAbiCoder
  const coded = coder.encode(['bytes4[]'], [selectors])

  process.stdout.write(coded)
}

function getAbi(contractname) {
  const abi = artifacts.readArtifactSync(contractname).abi
  return abi
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
printSelectors(args[0])
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
