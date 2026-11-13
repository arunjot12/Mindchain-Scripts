# MindChain scripts

Deploy and run a MindChain L2 (OP Stack, custom gas token, game type 9 with challenger) on Sepolia.
Every value lives in `config.env`, including the private keys (devnet only). A key left empty there
is asked for at runtime instead. Every key is checked against its role address before use, and keys
are passed to the services by environment variable, never on the command line.

**`config.env` contains private keys:** it is owner-readable only (`chmod 600`), excluded by
`.gitignore` and not included by `tools/backup.sh`. Never commit, share or paste it. Never put the
admin key on a server, and never use these keys on mainnet.

Run all scripts with `bash` (works from fish, zsh or bash), from this folder.

## Before you start

0. Create your own config from the template (it is not committed):
   `cp config.example.env config.env`
1. Put all binaries in this folder's `bin/` (not committed):
   - build from the mind-chain repo and copy: `bash scripts/build-binaries.sh`
   - or, if you already built them in the repo: `bash scripts/build-binaries.sh --copy`
   It fills `bin/` with `mc-deployer cannon kona-host mc-node mc-reth mc-batcher mc-proposer mc-challenger`.
2. Create 5 keys (`cast wallet new`, once per role): admin, sequencer, batcher, proposer, challenger.
   Fund on Sepolia: admin ~1 ETH, batcher ~0.5 ETH, proposer 2-4 ETH (0.08 ETH bond per proposal),
   challenger ~0.5 ETH. Sequencer needs nothing.
3. Edit `config.env`: RPC and beacon URLs, the 5 addresses and their private keys, a new `L2_CHAIN_ID`,
   and a new `WORKDIR` for every new chain.
4. Keep the machine awake while the chain runs (`caffeinate -dimsu` on macOS). If the node stops
   for hours, catching up again takes hours.

## Deploy (in order)

| Step | Command | Time | Notes |
|---|---|---|---|
| 0 | `bash scripts/00-check.sh` | 10 s | tools, binaries, repo fix, config |
| 1 | `bash scripts/01-bootstrap.sh` | 5-10 min | admin key; shared contracts + OPCM |
| 2 | `bash scripts/02-intent.sh` | 5 s | writes `intent.toml` from config.env; read it |
| 3 | `bash scripts/03-prepare.sh` | 2 min | admin key; **prints GENESIS TIME. Clock starts now** |
| 4 | `bash scripts/04-kona-configs.sh` | 5 s | chain config for the proof program |
| 5 | `bash scripts/05-build-prestate.sh` | ~30 min | Colima/Docker; do not interrupt. Stops Colima when done (`KEEP_COLIMA=true` to keep it) |
| 6 | `bash scripts/06-deploy.sh` | 5 min | admin key (same as step 3); deploys + verifies |
| - | `bash tools/backup.sh` | 5 s | do it right after step 6 |

Steps 4-6 must finish **before the genesis time** printed by step 3 (`GENESIS_DELAY_MINUTES`, default 15 min
after step 3; enough with a cached prestate build). If it passes, redo steps 3-6. First build ever (no
cache, ~30 min): set `GENESIS_DELAY_MINUTES=45`.

## Run the chain (one terminal tab each, in this order)

| Order | Command | Key |
|---|---|---|
| 1 | `bash run/mc-reth.sh` | - |
| 2 | `bash run/mc-node.sh` | - (waits for genesis by itself) |
| 3 | `bash run/batcher.sh` | batcher |
| 4 | `bash run/proposer.sh` | proposer (start when `tools/status.sh` shows caught up) |
| 5 | `bash run/challenger.sh` | challenger |

Logs: `$WORKDIR/logs/*.log`.

## Tools

| Command | What it does |
|---|---|
| `bash tools/status.sh` | health of every component, L1 gap, games, balances, recent errors |
| `bash tools/verify-l1.sh` | game type 9 respected, game impl, bond, prestate on-chain |
| `bash tools/mint-nila.sh 1000000 [address]` | mint gas token on L2 via L1 deposit (admin key) |
| `bash tools/backup.sh` | back up deployment files (no databases, no keys) |
| `bash tools/stop.sh [service...]` | stop services cleanly in safe order (challenger, proposer, batcher, mc-node, mc-reth) |

## Healthy chain

- `unsafe` rises every 2 s; `safe` a few minutes behind; `finalized` ~15-20 min behind safe.
- `l1_gap` under 10.
- Challenger log: `Game info ... status="In Progress"` with no repeated errors. An honest game stays
  In Progress for 3.5 days, then resolves DEFENDER_WINS.

## Problems we hit and how the scripts avoid them

| Problem | Avoided by |
|---|---|
| Private key pasted into a command or chat | keys asked silently, checked against role address |
| Placeholder left in intent (`0xADMIN`) | intent generated from config.env and checked |
| `respectedGameType` ignored (game type 5) | placed under `[chains.deployOverrides]`; checked after prepare |
| Prestate build fails: `rust/op-reth not found` | step 0/5 check the Dockerfile; fix is in the repo (`git pull`) |
| `KONA_CUSTOM_CONFIGS_DIR ... not a directory` | absolute path used |
| Wrong prestate (single vs interop) | type 9 uses the interop (`-int`) prestate; saved to `prestate/PRESTATE_HASH` |
| `continue`: no prestate committed | step 6 commits the prestate first |
| Sequencer started before genesis builds nothing | `run/mc-node.sh` waits for genesis |
| `context deadline exceeded` / slow catch-up | low-latency `L1_RPC_URL`; separate `L1_TX_RPC_URL` key for the other services |
| Proposer: cannot get sync status | start it only when caught up (`tools/status.sh`) |
| Laptop sleep stops the chain for hours | keep it awake, or run on a server |

## After downtime (catching up)

1. `bash run/mc-node.sh verifier` (no block building, faster catch-up). Do not restart it while catching up.
2. Watch `bash tools/status.sh` until `l1_gap` < 10.
3. Ctrl+C, then `bash run/mc-node.sh` (sequencer). Then restart the proposer.
# Mindchain-Scripts
