[![Mentioned in Awesome Foundry](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/crisgarner/awesome-foundry)

# Foundry + Hardhat Diamonds

This is a mimimal template for [Diamonds](https://github.com/ethereum/EIPs/issues/2535) which allows facet selectors to be generated on the go in solidity tests!

## Installation

- Clone this repo
- Install dependencies

```bash
$ yarn && forge update
```

### Compile

```bash
$ npx hardhat compile
```

## Deployment

### Hardhat

```bash
$ npx hardhat run scripts/deploy.js
```

### Foundry

```bash
$ forge t
```

`Note`: A lot of improvements are still needed so contributions are welcome!!

Bonus: The [DiamondLoupefacet](contracts/facets/DiamondLoupeFacet.sol) uses an updated [LibDiamond](contracts/libraries//LibDiamond.sol) which utilises solidity custom errors to make debugging easier especially when upgrading diamonds. Take it for a spin!!

Need some more clarity? message me [on twitter](https://twitter.com/Timidan_x), Or join the [EIP-2535 Diamonds Discord server](https://discord.gg/kQewPw2)

## Diamond Upgrade Helper (Foundry)

This repository includes a Foundry-based helper and script that make it easy to perform EIP-2535 diamond upgrades in tests and scripts without hand-assembling selector arrays.

### Overview

- `test/helpers/DiamondUtils.sol` dynamically generates function selectors using `forge inspect <Facet> methods --json` and parses them inside Solidity via FFI.
- `test/helpers/DiamondUpgradeHelper.sol` builds one-shot Add/Replace/Remove cuts and executes diamond upgrades via `IDiamondCut`.
- `script/DiamondUpgrade.s.sol` is a generic Foundry script to upgrade an existing diamond using environment variables.

> Note: FFI must be enabled in `foundry.toml` (`ffi=true`) for selector generation.

### Installation/Setup

- Ensure remappings include `forge-std` and `solidity-stringutils` (already configured in this repo):
  - See `remappings.txt` and `foundry.toml`.
- Ensure `ffi=true` in `foundry.toml`.

### Helper APIs

Located at `test/helpers/DiamondUpgradeHelper.sol` (import and inherit in your test/script).

- `buildAddCutByName(address facetAddress, string facetName)`
  - Generates all selectors of `facetName` and returns one Add cut.
- `buildAddCutsByNames(address[] facetAddresses, string[] facetNames)`
  - Batch of Add cuts; arrays must match in length and order.
- `buildReplaceCutByName(IDiamondLoupe loupe, address facetAddress, string facetName)`
  - Computes selectors for `facetName` and returns a Replace cut for selectors that currently exist on the diamond and point to a different facet address.
- `buildReplaceCutsByNames(IDiamondLoupe loupe, address[] facetAddresses, string[] facetNames)`
  - Batch replacement; see semantics above.
- `buildAddMissingCutByName(IDiamondLoupe loupe, address facetAddress, string facetName)`
  - Add-only for selectors that do not already exist on the diamond.
- `buildExtendCutsByName(IDiamondLoupe loupe, address facetAddress, string facetName)`
  - Returns a 1–2 element array combining Replace (existing selectors) and Add (new selectors) to extend a facet implementation with new functions.
- `buildRemoveCut(bytes4[] selectors)`
  - Returns a Remove cut for the given selectors.
- `executeDiamondCut(IDiamondCut diamond, IDiamondCut.FacetCut[] cuts, address init, bytes initCalldata)`
  - Executes a diamond cut with optional init call.

### Typical Scenarios

1. Add new facets to a fresh or partially configured diamond:

```solidity
address[] memory addAddrs = new address[](2);
addAddrs[0] = address(loupeFacet);
addAddrs[1] = address(ownershipFacet);

string[] memory names = new string[](2);
names[0] = "DiamondLoupeFacet";
names[1] = "OwnershipFacet";

IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(addAddrs, names);
executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
```

2. Extend an existing facet (replace 3 existing selectors and add 1 new selector):

```solidity
// newFacet implements the same 3 old functions and 1 new
IDiamondCut.FacetCut[] memory cuts = buildExtendCutsByName(
    IDiamondLoupe(address(diamond)),
    address(newFacet),
    "YourFacetName"
);
executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
```

3. Replace an existing facet implementation (only for selectors that already exist on the diamond):

```solidity
IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = buildReplaceCutByName(IDiamondLoupe(address(diamond)), address(newFacet), "YourFacetName");
executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
```

4. Remove selectors:

```solidity
bytes4[] memory toRemove = new bytes4[](2);
toRemove[0] = YourFacet.oldFunction.selector;
toRemove[1] = bytes4(keccak256("someSig(uint256,bool)"));

IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
cuts[0] = buildRemoveCut(toRemove);
executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");
```

### Scripted Upgrades (Foundry Script)

Use `script/DiamondUpgradeExample.s.sol` with hardcoded configuration inside `run()`.

- Open `script/DiamondUpgrade.s.sol` and set:
  - `diamond` to your target diamond address
  - `addFacetAddresses` and `addFacetNames` for new facets to add
  - `replaceFacetAddresses` and `replaceFacetNames` for facets whose existing selectors should be migrated
  - `removeSelectors` for selectors to remove (optional)
  - `init` and `initCalldata` if you need an initialization call (optional)

Example (inside `run()`):

```solidity
address diamond = 0x000000000000000000000000000000000000dEaD;
address[] memory addFacetAddresses = new address[](2);
addFacetAddresses[0] = 0x1111111111111111111111111111111111111111;
addFacetAddresses[1] = 0x2222222222222222222222222222222222222222;
string[] memory addFacetNames = new string[](2);
addFacetNames[0] = "DiamondLoupeFacet";
addFacetNames[1] = "OwnershipFacet";
// Optional replace & remove
address[] memory replaceFacetAddresses = new address[](0);
string[] memory replaceFacetNames = new string[](0);
bytes4[] memory removeSelectors = new bytes4[](0);
address init = address(0);
bytes memory initCalldata = hex"";
```

Run the script with broadcast:

```bash
forge script script/DiamondUpgradeExample.s.sol:DiamondUpgradeExample \
  --rpc-url $RPC_URL \
  --private-key $PK \
  --broadcast
```

No environment variables or CLI parameters are required; all configuration is set within the script file.

### Notes & Best Practices

- The helper relies on the diamond implementing `IDiamondLoupe` for replace/add-missing/extend logic to work correctly.
- `buildReplaceCutByName` filters out selectors that are either missing on the diamond or already mapped to the provided facet address, avoiding `SameSelectorReplacement` reverts.
- `buildAddMissingCutByName` ensures only new selectors (not present on the diamond) are added.
- `buildExtendCutsByName` combines both behaviors to migrate existing selectors to a new facet and add new selectors in one call.
- For fresh deployments, prefer add-only; for migrations, prefer extend or replace.
- If you need per-selector control, you can manually filter the arrays returned by `generateSelectors(facetName)` in your own helper or use the signature hash directly.

### Troubleshooting

- Empty selector arrays cause `NoSelectorsInFacet()` reverts. Ensure your cuts contain at least one selector.
- Ensure facet names match the contract names compiled in your repo.
- Ensure FFI is enabled and `forge` is available on PATH; `forge inspect` is invoked from Solidity via `vm.ffi`.
- On very large scripts, if you hit "stack too deep", refactor into smaller functions (the provided script already does this).
