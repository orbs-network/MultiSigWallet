#!/bin/zsh -l
set -euo pipefail

: ${OWNERS:?} ${REQUIRED:?}

factory=$(forge config --json | jq -r .create2_deployer)
salt=${$(cast abi-encode 'f(uint256)' ${SALT:-0})#0x}
temp_dir=$(mktemp -d)
trap 'rm -r "$temp_dir"' EXIT

forge build contracts/solidity/MultiSigWallet.sol --use 0.4.15 \
  --out "$temp_dir/out" --cache-path "$temp_dir/cache" >/dev/null
artifact=$temp_dir/out/MultiSigWallet.sol/MultiSigWallet.json
bytecode=$(jq -r .bytecode.object $artifact)
args=$(cast abi-encode 'f(address[],uint256)' $OWNERS $REQUIRED)
init_code=0x${bytecode#0x}${args#0x}
address=$(cast create2 --salt $salt --init-code $init_code)
payload=0x$salt${init_code#0x}

print -r -- "Address: $address"
print -r -- "Owners: $OWNERS"
print -r -- "Required: $REQUIRED"

code=$(cast code $address)
[[ $code == 0x ]] || {
  print -r -- 'Already deployed.'
  exit 0
}
cast estimate $factory $payload >/dev/null
[[ ${1:-} == --broadcast ]] || exit 0
cast send $factory $payload
code=$(cast code $address)
[[ $code != 0x ]]
