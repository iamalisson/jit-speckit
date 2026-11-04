# Every third-party action and tool version jit-speckit writes into a project, in one place.
# Actions are pinned to full commit SHAs: tags can be moved (aquasecurity/trivy-action, March 2026).
# Downloaded binaries are verified against their published SHA-256.
# shellcheck shell=bash disable=SC2034  # read by level.sh

PIN_CHECKOUT="actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0"
PIN_SETUP_NODE="actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0"
PIN_PNPM="pnpm/action-setup@fc06bc1257f339d1d5d8b3a19a8cae5388b55320 # v4.4.0"
PIN_RUST_TOOLCHAIN="dtolnay/rust-toolchain@683b588c487a69d01f6c6ddf40f036ff682cc2c8 # master"
PIN_RUST_CACHE="Swatinem/rust-cache@d1527c8f67ef9af357290475d4af4b0fab8f12e0 # v2.9.3"
PIN_SETUP_UV="astral-sh/setup-uv@d4b2f3b6ecc6e67c4457f6d3e41ec42d3d0fcb86 # v5.4.2"
PIN_SETUP_PYTHON="actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5.6.0"
PIN_SETUP_GO="actions/setup-go@40f1582b2485089dde7abd97c1529aa768e1baff # v5.6.0"
PIN_ZIZMOR="zizmorcore/zizmor-action@45d7276c9ca790aabd705e31ca99c6185c3e76dd # v0.8.1"

GITLEAKS_VERSION="8.30.1"
GITLEAKS_SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb" # linux_x64 tarball
OSV_VERSION="2.7.0"
OSV_SHA256="160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b"     # linux_amd64 binary
SEMGREP_VERSION="1.183.0"
