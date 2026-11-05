#!/usr/bin/env bash
# Detect the project's stacks from manifest files at the repository root.
# Prints one stack per line: rust | node:<npm|pnpm|yarn> | python:<uv|pip> | go
# Prints nothing when no stack is recognized.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

if [[ -f Cargo.toml ]]; then echo rust; fi
if [[ -f package.json ]]; then
  if [[ -f pnpm-lock.yaml ]] || grep -q '"packageManager": *"pnpm' package.json; then echo node:pnpm
  elif [[ -f yarn.lock ]]; then echo node:yarn
  else echo node:npm
  fi
fi
if [[ -f pyproject.toml || -f requirements.txt ]]; then
  if [[ -f uv.lock ]]; then echo python:uv; else echo python:pip; fi
fi
if [[ -f go.mod ]]; then echo go; fi
