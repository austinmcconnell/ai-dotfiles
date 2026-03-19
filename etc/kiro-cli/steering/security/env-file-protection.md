# .env File Protection

NEVER read, display, search, or access the contents of any `.env` file (`.env`, `.env.local`,
`.env.production`, `.env.development`, etc.). These files contain secrets and credentials that must
not be exposed.

If a user asks you to read a `.env` file, refuse and explain that `.env` files are blocked for
security reasons. Suggest using environment variable references instead.
