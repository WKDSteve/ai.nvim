-- TESTS/sheets/ai-live-ai-desktop-claude.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets"): the
-- provider `ai_desktop` with a claude- model, so a real local ai-desktop server routes the request to its Anthropic
-- backend (README "Cloud backends": the claude- prefix, the key from its environment or its key store). ask() with a
-- fixed answer, stream() in more than one piece, and a claude- model that does not exist (the Anthropic error passed
-- on, readable, no hang). The child has no Anthropic key: only ai-desktop holds one.
--
-- Runs only with:  testing sheets run --live --sheet ai.live-ai-desktop-claude --root <ai.nvim> [--tasks <vault>]
-- (AI_DESKTOP_HOST=http://127.0.0.1:8080 set as the opt-in, ai-desktop started with an ANTHROPIC_API_KEY of its own;
-- never on CI, a skip without --live or without the variable)
return {
  id = "ai.live-ai-desktop-claude",
  title = "Live: ai_desktop routes a claude- model to Anthropic (ask, stream, unknown model)",
  task = "ai-desktop/abnahme-claude-backend-mit-dem-api-guthaben",
  live = {
    env = { "AI_DESKTOP_HOST" },
    hosts = { "127.0.0.1" },
    cost = "three short requests through ai-desktop on claude-haiku-4-5 (one refused): well under a cent of the key"
      .. " ai-desktop holds",
  },
  steps = {
    {
      lua = [[
        vim.g.live = vim.empty_dict()
        require("ai").setup({ provider = "ai_desktop", keymaps = { enable = false }, completion = { enable = false } })
      ]],
      note = "ai.nvim with ai_desktop as the provider, no keys bound",
    },
    {
      lua = [[
        require("ai").ask({ model = "claude-haiku-4-5", prompt = "Reply with exactly the word: PONG" }, function(ok, res)
          vim.g.live = vim.tbl_extend("force", vim.g.live, {
            ask_ok = ok,
            ask = ok and res.text or tostring(type(res) == "table" and res.message or res),
          })
        end)
      ]],
      note = "ask once with a claude- model",
    },
    { wait = "vim.g.live.ask ~= nil", timeout = 60000, note = "the answer came" },
    {
      expect = [[vim.g.live.ask_ok and vim.g.live.ask:upper():find("PONG", 1, true)
        or error("ask: " .. tostring(vim.g.live.ask), 0)]],
      note = "it says PONG (an 'ANTHROPIC_API_KEY not set' here: ai-desktop has no key)",
    },
    {
      lua = [[
        vim.g.chunks = 0
        require("ai").stream({ model = "claude-haiku-4-5", prompt = "Count from 1 to 5, one number per line" }, {
          on_chunk = function()
            vim.g.chunks = vim.g.chunks + 1
          end,
          on_done = function(res)
            vim.g.live = vim.tbl_extend("force", vim.g.live, { stream_ok = true, stream = res.text })
          end,
          on_error = function(err)
            vim.g.live = vim.tbl_extend("force", vim.g.live, { stream_ok = false, stream = err.message })
          end,
        })
      ]],
      note = "stream once with a claude- model",
    },
    { wait = "vim.g.live.stream ~= nil", timeout = 60000, note = "the stream ended" },
    {
      expect = [[vim.g.live.stream_ok and vim.g.live.stream:find("5", 1, true)
        or error("stream: " .. tostring(vim.g.live.stream), 0)]],
      note = "it counted to 5",
    },
    {
      measure = "vim.g.chunks",
      name = "ai_desktop claude stream pieces",
      unit = "chunks",
      min = 2,
      note = "the answer arrived in pieces, not in one block at the end",
    },
    {
      lua = [[
        require("ai").ask({ model = "claude-does-not-exist-1", prompt = "test" }, function(ok, res)
          vim.g.live = vim.tbl_extend("force", vim.g.live, {
            bad_ok = ok,
            bad = ok and res.text or tostring(type(res) == "table" and res.message or res),
          })
        end)
      ]],
      note = "ask a claude- model that does not exist",
    },
    { wait = "vim.g.live.bad ~= nil", timeout = 60000, note = "it answered, no hang" },
    {
      expect = [[vim.g.live.bad_ok == false and #vim.g.live.bad > 0
        or error("an unknown model gave: " .. vim.inspect(vim.g.live.bad, { newline = " ", indent = "" }), 0)]],
      note = "a readable error, not an empty success",
    },
  },
  manual = {
    "ai-desktop dashboard, usage view: the requests of this run show up under anthropic / claude-haiku-4-5",
  },
}
