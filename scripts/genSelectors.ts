import { ContractFactory, utils } from "ethers";
import path from "path/posix";

const args = process.argv.slice(2);

if (args.length != 1) {
  console.log(`please supply the correct parameters:
    facetName
  `);
  process.exit(1);
}

async function printSelectors(
  contractName: string,
  artifactFolderPath: string = "../out"
) {
  const contractFilePath = path.join(
    artifactFolderPath,
    `${contractName}.sol`,
    `${contractName}.json`
  );
  const contractArtifact = require(contractFilePath);
  const abi = contractArtifact.abi;
  const bytecode = contractArtifact.bytecode;
  const target = new ContractFactory(abi, bytecode);
  const signatures = Object.keys(target.interface.functions);

  const selectors = signatures.reduce((acc: string[], val) => {
    if (val !== "init(bytes)") {
      acc.push(target.interface.getSighash(val));
    }
    return acc;
  }, []);

  const coder = utils.defaultAbiCoder;
  const coded = coder.encode(["bytes4[]"], [selectors]);

  process.stdout.write(coded);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
printSelectors(args[0], args[1])
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
