-- TESTS/sheets/ai-live-claude.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets"): the provider
-- `claude` against the real Anthropic API. Live-testing plan of ai.nvim, sections 1 to 3 and 9: available(), ask() with
-- a fixed answer, stream() arriving in more than one piece, and the error path with a wrong key (a readable error,
-- never an empty success). The wrong key is passed per request (`api_key`), so the real key is never changed.
--
-- Runs only with:  testing sheets run --live --sheet ai.live-claude --root <ai.nvim>
-- (into its task instead: --task <the task below> --tasks <vault>; --sheet takes no --tasks)
-- (ANTHROPIC_API_KEY set; never on CI, a skip without --live or without the key)
return {
  id = "ai.live-claude",
  title = "Live: claude available, ask, stream and a wrong key against the real API",
  task = "ai.nvim/live-plan-ai-live-testing-plan-sortieren-erledigtes-abhaken",
  live = {
    env = { "ANTHROPIC_API_KEY" },
    hosts = { "api.anthropic.com" },
    cost = "three short requests (the default model, at most 2048 output tokens, room for thinking), one of them refused: about a cent",
  },
  steps = {
    {
      lua = [[
        vim.g.live = vim.empty_dict()
        require("ai").setup({ provider = "claude", keymaps = { enable = false }, completion = { enable = false } })
      ]],
      note = "ai.nvim with claude as the provider, no keys bound",
    },
    {
      expect = [[require("ai.providers").get("claude").available()]],
      note = "available() with the key set (no network)",
    },
    {
      lua = [[
        require("ai").ask({ prompt = "Reply with exactly the word: PONG", max_tokens = 1024 }, function(ok, res)
          vim.g.live = vim.tbl_extend("force", vim.g.live, {
            ask_ok = ok,
            ask = ok and res.text or tostring(type(res) == "table" and res.message or res),
          })
        end)
      ]],
      note = "ask once",
    },
    { wait = "vim.g.live.ask ~= nil", timeout = 60000, note = "the answer came" },
    {
      expect = [[vim.g.live.ask_ok and vim.g.live.ask:upper():find("PONG", 1, true)
        or error("ask: " .. tostring(vim.g.live.ask), 0)]],
      note = "it says PONG",
    },
    {
      lua = [[
        vim.g.chunks = 0
        require("ai").stream({ prompt = "Count from 1 to 5, one number per line", max_tokens = 1024 }, {
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
      note = "stream once",
    },
    { wait = "vim.g.live.stream ~= nil", timeout = 60000, note = "the stream ended" },
    {
      expect = [[vim.g.live.stream_ok and vim.g.live.stream:find("5", 1, true)
        or error("stream: " .. tostring(vim.g.live.stream), 0)]],
      note = "it counted to 5",
    },
    {
      measure = "vim.g.chunks",
      name = "claude stream pieces",
      unit = "chunks",
      min = 2,
      note = "the answer arrived in pieces, not in one block at the end",
    },
    {
      lua = [[
        require("ai").ask({ prompt = "test", api_key = "sk-invalid-key-for-the-sheet" }, function(ok, res)
          vim.g.live = vim.tbl_extend("force", vim.g.live, {
            bad_ok = ok,
            bad = ok and res.text or tostring(type(res) == "table" and res.message or res),
          })
        end)
      ]],
      note = "ask with a wrong key",
    },
    { wait = "vim.g.live.bad ~= nil", timeout = 60000, note = "it answered" },
    {
      expect = [[vim.g.live.bad_ok == false and #vim.g.live.bad > 0
        or error("a wrong key gave: " .. vim.inspect(vim.g.live.bad), 0)]],
      note = "a readable error, not an empty success",
    },
  },
  manual = {
    "In the real editor: :checkhealth ai lists claude as available; :Ai ask and :Ai stream show the answer",
  },
}
