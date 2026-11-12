#!/usr/bin/env bash
# Step 4: write the kona custom chain configs (the chain is not in the Superchain Registry,
# so its config is built into the proof program / prestate).
source "$(dirname "$0")/lib.sh"
cd "$WORKDIR"
for f in "$SEQ_DIR/rollup.json" "$DEPLOYER_DIR/state.json" bootstrap-superchain.json bootstrap-implementations.json; do need_file "$f"; done
mkdir -p "$PRESTATE_DIR/custom-configs"

L2_CHAIN_ID="$L2_CHAIN_ID" L1_CHAIN_ID="$L1_CHAIN_ID" GAME="$RESPECTED_GAME_TYPE" \
A="$ADMIN" SEQ="$SEQUENCER" BAT="$BATCHER" PRO="$PROPOSER" CHA="$CHALLENGER" \
python3 - <<'PY'
import json, os
e = os.environ
L2, L1 = int(e["L2_CHAIN_ID"]), int(e["L1_CHAIN_ID"])
r = json.load(open('sequencer/rollup.json'))
c = json.load(open('.deployer/state.json'))['opChainDeployments'][0]
impl = json.load(open('bootstrap-implementations.json'))
sc = json.load(open('bootstrap-superchain.json'))['superchainConfigProxyAddress']
assert r['l2_chain_id'] == L2, f"rollup.json chain {r['l2_chain_id']} != {L2}"
assert r['l1_chain_id'] == L1, f"rollup.json L1 {r['l1_chain_id']} != {L1}"
assert c['initialGameType'] == int(e["GAME"]), "initialGameType mismatch"
assert c['OptimismPortalProxy'].lower() == r['deposit_contract_address'].lower(), "Portal mismatch"
assert c['SystemConfigProxy'].lower() == r['l1_system_config_address'].lower(), "SystemConfig mismatch"
forks = ["regolith_time","canyon_time","delta_time","ecotone_time","fjord_time","granite_time",
         "holocene_time","isthmus_time","jovian_time","karst_time"]
hf = {k: r[k] for k in forks if k in r}
chain = {"Name":"mindchain","PublicRPC":"","SequencerRPC":"","Explorer":"","GovernedByOptimism":False,
 "SuperchainTime":None,"DataAvailabilityType":"eth-da","l2_chain_id":L2,
 "batch_inbox_address":r["batch_inbox_address"],"block_time":r["block_time"],
 "seq_window_size":r["seq_window_size"],"max_sequencer_drift":r["max_sequencer_drift"],
 "GasPayingToken":None,"hardfork_configuration":hf,"optimism":r["chain_op_config"],"alt_da":None,"genesis":r["genesis"],
 "Roles":{"SystemConfigOwner":e["A"],"ProxyAdminOwner":e["A"],"Guardian":e["A"],"Challenger":e["CHA"],
          "Proposer":e["PRO"],"UnsafeBlockSigner":e["SEQ"],"BatchSubmitter":e["BAT"]},
 "Addresses":{"AddressManager":c["AddressManagerImpl"],"L1CrossDomainMessengerProxy":c["L1CrossDomainMessengerProxy"],
  "L1Erc721BridgeProxy":c["L1Erc721BridgeProxy"],"L1StandardBridgeProxy":c["L1StandardBridgeProxy"],"L2OutputOracleProxy":None,
  "OptimismMintableErc20FactoryProxy":c["OptimismMintableErc20FactoryProxy"],"OptimismPortalProxy":c["OptimismPortalProxy"],
  "SystemConfigProxy":c["SystemConfigProxy"],"ProxyAdmin":c["OpChainProxyAdminImpl"],"SuperchainConfig":sc,
  "AnchorStateRegistryProxy":c["AnchorStateRegistryProxy"],"DelayedWethProxy":c["DelayedWethPermissionlessGameProxy"],
  "DisputeGameFactoryProxy":c["DisputeGameFactoryProxy"],"FaultDisputeGame":None,"Mips":impl["mipsSingletonAddress"],
  "PermissionedDisputeGame":None,"PreimageOracle":impl["preimageOracleSingletonAddress"],"DataAvailabilityChallenge":None}}
d = 'prestate/custom-configs/'
superchain = {"name":"mindchain-sepolia","config":{"name":"MindChain Sepolia",
  "l1":{"chain_id":L1,"public_rpc":"https://ethereum-sepolia-rpc.publicnode.com","explorer":"https://sepolia.etherscan.io"},
  "hardforks":hf,"superchain_config_addr":sc,"op_contracts_manager_proxy_addr":impl['opcmV2Address']},"chains":[chain]}
json.dump({"superchains":[superchain]}, open(d+'configs.json','w'), indent=2)
json.dump([{"name":"mindchain","identifier":"mindchain-sepolia/mindchain","chainId":L2,"rpc":[],"explorers":[],
  "governedByOptimism":False,"dataAvailabilityType":"eth-da","parent":{"type":"L2","chain":"sepolia"},
  "faultProofs":{"status":"permissionless"}}], open(d+'chainList.json','w'), indent=2)
dep = {"dependencies":{str(L2):{}},"overrideMessageExpiryWindow":None}
json.dump([dep], open(d+'depsets.json','w'), indent=2)
json.dump(dep, open('sequencer/depset.json','w'), indent=2)
print("genesis hash:", r["genesis"]["l2"]["hash"])
PY
ok "Wrote $PRESTATE_DIR/custom-configs/{configs,chainList,depsets}.json and sequencer/depset.json"
ok "Next: scripts/05-build-prestate.sh"
