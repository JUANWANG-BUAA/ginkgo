# Shared Network Freeze

The shared network/authentication stack is frozen at Android Beta.9,
`c4afc0c3f5edad5cded1352da5b536001edb430a`.
The user confirmed successful login on 2026-11-03.

Read `docs/NETWORK-FREEZE.md` at the repository root before any edit here.
Do not refactor, optimize, replace dependencies, realign with UBAA, or change
HTTP/CAS/captcha/redirect/Cookie/route/session/vault/retry behavior without
explicit user authorization for that specific frozen change. Report security
issues before editing. Feature work is not authorization to unfreeze this stack.

Use the existing network and authentication entry points for business modules.
Do not introduce alternate transports or password recovery/retry paths.
Do not weaken golden transcripts, mutation checks, or the freeze manifest/gate.
Run `python3 scripts/check-network-freeze.py` from the repository root.
