## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Localhost Dev

```shell
$ forge install
$ npm install
$ cp .env.example .env.development # Create Dev Env
$ chmod -R 777 ./script/cmd # Chmod Scripts
$ ./script/cmd/anvil.sh # Run in seperate shell
$ ./script/cmd/dssDeploy_anvil.sh # Deploy Sample Dss
$ cat ./script/output/31337/dssDeploy.artifacts.json ## Artifacts deployed here
$ ./script/cmd/run_jobs.sh # Run Jobs every 5 seconds
```

### Build (For Scripts)
```shell 
$ #NODE
$ npm install
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
