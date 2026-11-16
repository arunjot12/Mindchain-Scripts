# MindChain scripts

Scripts to deploy and run a MindChain L2 on Sepolia (OP Stack, custom gas token NILA, permissionless
fault proofs with game type 9), and to let other PCs join a running chain with their own
mc-reth, mc-node, mc-proposer and mc-challenger.

All scripts run with `bash` (from fish, zsh or bash) from this folder. Every setting lives in one file,
`config.env`.

## Contents

| Path | What it is |
|---|---|
| `config.example.env` | Template. Copy to `config.env` (never committed) |
| `bin/` | All binaries (filled by `scripts/build-binaries.sh`, never committed) |
| `scripts/` | Deploy a new chain, steps `00` to `06` |
| `run/` | Run one component in the foreground (one terminal tab each) |
| `tools/` | Status, checks, stop, backup, mint, sharing with other PCs |
| `join/` | For another PC joining an existing chain |

## Two ways to use these scripts

- **Network operator** (you run the chain): sections [Setup](#setup), [Deploy a new chain](#deploy-a-new-chain)
  and [Run the chain](#run-the-chain). Runs the only sequencer and batcher.
- **Joining PC** (someone runs their own node, proposer and challenger on an existing chain):
  section [Join an existing chain](#join-an-existing-chain-from-another-pc).

## Security

- `config.env` holds private keys (devnet/testnet only). It is owner-readable only (`chmod 600`),
  excluded by `.gitignore` and not included in backups or join packs. Never commit, share or paste it.
- A key left empty in `config.env` is asked for at runtime (hidden input).
- Every key is checked against its role address before use, and keys reach the services by environment
  variable, never on the command line.
- The admin key never goes on a server. Each PC uses its own proposer and challenger keys.
- Never use these keys on mainnet.

## Setup

1. **Config:** `cp config.example.env config.env`, then edit it:
   Sepolia RPC and beacon URLs, the 5 role addresses (and their keys), a new `L2_CHAIN_ID`
   (unused, check chainlist.org), and a new `WORKDIR` for every new chain.
2. **Binaries** into `bin/`:
   - build from the mind-chain repo and copy: `bash scripts/build-binaries.sh`
   - or copy ones already built there: `bash scripts/build-binaries.sh --copy`
   It fills `bin/` with `mc-deployer cannon kona-host mc-node mc-reth mc-batcher mc-proposer mc-challenger`.
3. **Keys:** 5 separate keys (`cast wallet new`, once per role): admin, sequencer, batcher, proposer,
   challenger.
4. **Funding (Sepolia ETH):** admin ~1, batcher ~0.5, proposer 2-4 (each proposal locks a 0.08 ETH bond
   for ~10 days), challenger ~0.5. The sequencer needs none.
5. **Tools:** `cast` (Foundry), `jq`, `python3`, `just`, Colima/Docker (prestate build).
6. **Keep the machine awake** while the chain runs (`caffeinate -dimsu` on macOS). A node that stops for
   hours needs hours to catch up.

## Deploy a new chain

| Step | Command | Time | Notes |
|---|---|---|---|
| 0 | `bash scripts/00-check.sh` | 10 s | tools, binaries, repo, config |
| 1 | `bash scripts/01-bootstrap.sh` | 5-10 min | admin key; superchain contracts + OPCM (skip by copying `bootstrap-*.json` from an earlier deploy) |
| 2 | `bash scripts/02-intent.sh` | 5 s | writes `intent.toml` from `config.env`; read it |
| 3 | `bash scripts/03-prepare.sh` | 2 min | admin key; **fixes the genesis time, the clock starts** |
| 4 | `bash scripts/04-kona-configs.sh` | 5 s | chain config for the proof program |
| 5 | `bash scripts/05-build-prestate.sh` | 5-30 min | Docker build; stops Colima when done (`KEEP_COLIMA=true` keeps it) |
| 6 | `bash scripts/06-deploy.sh` | 5 min | admin key (same as step 3); deploys and verifies |
| - | `bash tools/backup.sh` | 5 s | right after step 6 |

**Genesis deadline:** type 9 needs the chain's genesis inside the prestate, so step 3 fixes genesis in the
future and steps 4-6 must finish before it. `GENESIS_DELAY_MINUTES` (default 15) sets how far ahead:
enough with a cached prestate build. For the first build on a machine (~30 min) use 45. Run 3 to 6 back
to back; if genesis passes first, redo steps 3-6.

## Run the chain

One terminal tab each, in this order. Logs go to `$WORKDIR/logs/`.

| Order | Command | Key | When |
|---|---|---|---|
| 1 | `bash run/mc-reth.sh` | - | first |
| 2 | `bash run/mc-node.sh` | - (sequencer key only with P2P) | waits for genesis by itself |
| 3 | `bash run/batcher.sh` | batcher | right after mc-node |
| 4 | `bash run/proposer.sh` | proposer | when `tools/status.sh` shows `finalized` > 0 and `l1_gap` < 10 (~20-25 min after genesis) |
| 5 | `bash run/challenger.sh` | challenger | after the first game exists |

**Stop:** Ctrl+C in each tab (challenger, proposer, batcher, mc-node, mc-reth), or from anywhere:
`bash tools/stop.sh` (all, safe order) or `bash tools/stop.sh mc-batcher mc-proposer` (some).

**After downtime:** `bash run/mc-node.sh verifier` (no block building, faster catch-up). Do not restart it
while it catches up: each restart starts again from the last safe block. When `tools/status.sh` shows
`l1_gap` < 10, Ctrl+C and start `bash run/mc-node.sh` (sequencer), then the proposer.

## Tools

| Command | What it does |
|---|---|
| `bash tools/status.sh` | health of every component: blocks, L1 gap, batcher, games, balances, recent errors |
| `bash tools/verify-l1.sh` | L1 contracts: game type 9 respected, game implementation, bond, prestate |
| `bash tools/mint-nila.sh 1000000 [address]` | mint the gas token on L2 via an L1 deposit (admin key) |
| `bash tools/backup.sh` | back up the deployment files (no databases, no keys) |
| `bash tools/stop.sh [service...]` | stop services cleanly in safe order |
| `bash tools/p2p-info.sh` | this node's P2P addresses, for another PC's fast sync |
| `bash tools/make-join-pack.sh` | one file for another PC to join this chain |

## Healthy chain

- `unsafe` rises every 2 s; `safe` a few minutes behind; `finalized` ~15-20 min behind `safe`.
- `l1_gap` under 10.
- Batcher nonce on L1 rises every few minutes.
- A new game every `PROPOSAL_INTERVAL` (default 6 h), type 9.
- Challenger log: `Game info ... status="In Progress"` with no repeated errors. An honest game stays
  In Progress for 3.5 days, then resolves DEFENDER_WINS.

## Sharing this chain with other PCs

**P2P (fast sync).** Another PC's node downloads blocks from your sequencer instead of rebuilding them
from L1. On your PC set in `config.env`: `P2P_ENABLED=true`, `P2P_ADVERTISE_IP=<your IP>`
(`ipconfig getifaddr en0`) and `SEQUENCER_PRIVATE_KEY` (signs blocks so peers accept them). Restart
mc-reth and mc-node. Ports TCP+UDP `9222` (mc-node) and `30304` (mc-reth) must be reachable from the other
PC. `bash tools/p2p-info.sh` prints the two values the other PC needs (the join pack includes them).

**Direct RPC (testing only).** Another PC can use your node instead of running its own: set
`RPC_BIND_ADDR=0.0.0.0` and restart mc-reth and mc-node; the other PC sets
`L2_RPC_URL=http://<your IP>:9545` and `NODE_RPC_URL=http://<your IP>:8547`. Local network only:
these RPCs have no password, and the other PC then depends on your node.

## Join an existing chain from another PC

Anyone can join a running chain with their own **mc-reth + mc-node** (follower: never builds blocks),
**mc-proposer** and **mc-challenger**. They check the chain from L1 and post/defend claims about it in
the same DisputeGameFactory. The operator stays the only sequencer and batcher.

**Operator's PC** (once per joining PC; enable P2P first for fast sync):

    bash tools/make-join-pack.sh

It writes `~/mindchain-join-<chain>-<date>.tgz`: chain files (genesis, rollup config, contract
addresses, prestate) and a pre-filled `config.join.env`, with no private keys. Give the joining PC:
this scripts folder (without `config.env`), the binaries (`bin/`) and the pack.

**Joining PC:**

| Step | Command |
|---|---|
| 1 | `bash join/setup.sh ~/mindchain-join-<chain>-<date>.tgz` (creates `config.env`, unpacks the chain files) |
| 2 | Edit `config.env`: own Sepolia URLs, **new** `PROPOSER`/`CHALLENGER` addresses and keys, `P2P_ADVERTISE_IP`. Fund both (>= 0.5 ETH each) |
| 3 | `bash join/start-all.sh`: mc-reth + mc-node, waits until synced, then mc-proposer and mc-challenger (all in background) |
| or | one at a time: `bash join/start-node.sh`, `bash join/start-proposer.sh`, `bash join/start-challenger.sh` |
| - | `bash join/status.sh`: what runs, genesis check against the chain, chain health |
| - | `bash join/stop.sh`: stops mc-challenger, mc-proposer, mc-node, mc-reth |

To confirm both PCs follow the same chain, compare a block hash on both:
`cast block 500 --field hash --rpc-url http://127.0.0.1:9545`.

## Main settings in `config.env`

| Setting | Meaning |
|---|---|
| `WORKDIR` | deployment folder; a new one for every chain |
| `L2_CHAIN_ID` | the chain's ID; unique, cannot change after deploy |
| `GENESIS_DELAY_MINUTES` | how far after step 3 genesis is placed (default 15) |
| `L1_RPC_URL` | Sepolia RPC for mc-deployer and mc-node; low latency matters most here |
| `L1_TX_RPC_URL` | Sepolia RPC for batcher, proposer, challenger (separate key recommended) |
| `L1_BEACON_URL` | Sepolia beacon API (blob data) |
| `L1_TRUST_RPC` | `true` skips re-checking L1 data (faster catch-up; trusted provider only) |
| `DA_TYPE` | `blobs` or `calldata` |
| `PROPOSAL_INTERVAL` | time between proposals (each locks 0.08 ETH for ~10 days) |
| `P2P_ENABLED`, `P2P_ADVERTISE_IP`, `SYNC_MODE`, `P2P_STATIC_PEERS`, `RETH_TRUSTED_PEERS` | P2P and fast sync |
| `RPC_BIND_ADDR`, `L2_RPC_URL`, `NODE_RPC_URL` | sharing a node's RPCs, or using another PC's node |

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| `Key is for 0x..., but <Role> is 0x...` | wrong key for that role in `config.env` |
| `Set L1_RPC_URL ...` / `Set L2_CHAIN_ID ...` | placeholders still in `config.env` |
| Prestate build: `rust/op-reth not found` | old mind-chain repo: `git -C <repo> pull origin main` |
| Prestate build: `Docker is not running` | Colima start was interrupted; step 5 restarts it, or `colima stop --force; colima start` |
| `Genesis time has passed` | redo steps 3-6 (larger `GENESIS_DELAY_MINUTES` if the build is slow) |
| `unsafe` stays 0 after genesis | mc-node started before genesis with an old script; restart it |
| `safe` stays 0, batcher nonce rising | mc-node cannot read L1 fast enough; use a faster `L1_RPC_URL` |
| `context deadline exceeded` in logs | slow L1 RPC; occasional is harmless, constant needs a better RPC |
| `current_l1` moves at Sepolia's pace, gap constant | catch-up too slow: `run/mc-node.sh verifier`, faster RPC, `L1_TRUST_RPC=true` |
| Proposer: `cannot get sync status` / `still behind target` | mc-node busy or catching up; wait, start the proposer when synced |
| Proposer: insufficient funds | fund the proposer (0.08 ETH bond per proposal + gas) |
| Joining PC: `unsafe` stays 0 | P2P ports blocked (`nc -zv <IP> 9222`), or wrong sequencer key on the operator PC |
| Joining PC: `genesis ... != chain genesis` | wrong pack or `config.env` for this chain |
