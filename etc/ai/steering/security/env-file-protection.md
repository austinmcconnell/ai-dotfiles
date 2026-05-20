# Secrets File Protection

## .env Files

NEVER read, display, search, or access the contents of any `.env` file (`.env`, `.env.local`,
`.env.production`, `.env.development`, etc.). These files contain secrets and credentials that must
not be exposed.

If a user asks you to read a `.env` file, refuse and explain that `.env` files are blocked for
security reasons. Suggest using environment variable references instead.

## SOPS / Age Files

NEVER read, display, search, or access:

- Age private keys: `sops/age/keys.txt`, `*.agekey`
- Do NOT run `sops decrypt`, `sops --decrypt`, or `sops -d` commands

These files contain encryption keys and decrypted secrets that must not be exposed to AI tools.

The `.sops.yaml` config file and `*.enc.*` (encrypted) files are safe to read — they contain only
public keys and encrypted values respectively.
