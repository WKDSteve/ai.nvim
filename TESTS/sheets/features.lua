-- TESTS/sheets/features.lua -- the catalog of ai.nvim's functionalities (testing.nvim docs/SHEETS.md, "Feature
-- sheets and the catalog"). Read as data: no code, no requires. A sheet names the one it checks with `feature`.
-- `perf` says why `testing perf` does not measure a functionality through its own sheet (testing.nvim docs/PERF.md):
-- here always a request that would reach a real model (a paid key) or a server only a person runs.
return {
  -- The processes ai.nvim starts itself (`testing perf scan`).
  {
    id = "ai.claude-cli",
    title = "Ask through the Claude Code CLI: :Ai provider claude-cli, then :Ai ask, the answer in a viewer",
    surface = { "command:Ai provider", "command:Ai ask" },
    docs = "docs/configuration.md",
  },
  {
    id = "ai.copilot-cli",
    title = "Ask through the GitHub Copilot CLI: :Ai provider copilot, then :Ai ask, the answer in a viewer",
    surface = { "command:Ai provider", "command:Ai ask" },
    docs = "docs/configuration.md",
  },
  {
    id = "ai.key-command",
    title = "An API key from a command (keys.<provider>.profiles.<name>.command), chosen with :Ai key",
    surface = { "command:Ai key", "config:keys" },
    docs = "docs/configuration.md",
  },
  -- The HTTP providers: lib.nvim's curl starts the process (ai/providers/transport.lua). A sheet answers them from
  -- a stub (no curl); the measurement of the real request is a live sheet, which costs or needs a local server.
  {
    id = "ai.cloud-api",
    title = "Ask and stream through a cloud API (Claude, OpenAI, Gemini) with curl",
    surface = { "command:Ai ask", "command:Ai stream" },
    docs = "docs/configuration.md",
    perf = "manual:a real request costs money on a paid key; the live sheets ai.live-claude, ai.live-openai and "
      .. "ai.live-gemini measure it under `testing sheets run --live`, only with Stefan's approval",
  },
  {
    id = "ai.local-server",
    title = "Ask and stream through a local server (Ollama, ai-desktop) with curl",
    surface = { "command:Ai ask", "command:Ai stream" },
    docs = "docs/configuration.md",
    perf = "manual:needs a running Ollama or ai-desktop server; the live sheets ai.live-ollama and "
      .. "ai.live-ai-desktop measure it under `testing sheets run --live`",
  },
}
