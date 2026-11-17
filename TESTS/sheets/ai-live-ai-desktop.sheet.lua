-- TESTS/sheets/ai-live-ai-desktop.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets"): the provider
-- `ai_desktop` against a real local ai-desktop server. Live-testing plan of ai.nvim, section 5: ask() with a fixed answer, stream()
-- arriving in more than one piece, and the error path with the service unreachable (a readable error, no hang, never an
-- empty success): the child points AI_DESKTOP_HOST at a closed port, the running service is not touched.
--
-- Runs only with:  testing sheets run --live --sheet ai.live-ai-desktop --root <ai.nvim> [--tasks <vault>]
-- (AI_DESKTOP_HOST=http://127.0.0.1:8080 set as the opt-in, ai-desktop started (`build/ai-desktop.exe`) with Ollama behind it; never on CI, a skip without --live or without the variable)
return {
  id = "ai.live-ai-desktop",
  title = "Live: ai_desktop ask, stream and an unreachable service against the real local ai-desktop server",
  task = "ai.nvim/abnahme-ai-live-plan-echte-keys-ollama-ai-desktop",
  live = {
    env = { "AI_DESKTOP_HOST" },
    hosts = { "127.0.0.1" },
    cost = "none: a local ai-desktop server, two short requests",
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
        require("ai").ask({ prompt = "Reply with exactly the word: PONG", max_tokens = 1024 }, function(ok, res)
          vim.g.live = vim.tbl_extend("force", vim.g.live, {
            ask_ok = ok,
            ask = ok and res.text or tostring(type(res) == "table" and res.message or res),
          })
        end)
      ]],
      note = "ask once",
    },
    {
      wait = "vim.g.live.ask ~= nil",
      timeout = 120000,
      note = "the answer came (a cold model loads first)",
    },
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
    { wait = "vim.g.live.stream ~= nil", timeout = 120000, note = "the stream ended" },
    {
      expect = [[vim.g.live.stream_ok and vim.g.live.stream:find("5", 1, true)
        or error("stream: " .. tostring(vim.g.live.stream), 0)]],
      note = "it counted to 5",
    },
    {
      measure = "vim.g.chunks",
      name = "ai_desktop stream pieces",
      unit = "chunks",
      min = 2,
      note = "the answer arrived in pieces, not in one block at the end",
    },
    {
      lua = [[
        vim.env.AI_DESKTOP_HOST = "http://127.0.0.1:9"
        require("ai").ask({ prompt = "test" }, function(ok, res)
          vim.g.live = vim.tbl_extend("force", vim.g.live, {
            down_ok = ok,
            down = ok and res.text or tostring(type(res) == "table" and res.message or res),
          })
        end)
      ]],
      note = "ask with the service unreachable (a closed port)",
    },
    { wait = "vim.g.live.down ~= nil", timeout = 30000, note = "it answered, no hang" },
    {
      expect = [[vim.g.live.down_ok == false and #vim.g.live.down > 0
        or error("an unreachable service gave: " .. vim.inspect(vim.g.live.down), 0)]],
      note = "a readable error, not an empty success",
    },
  },
  manual = {
    "With ai-desktop running and Ollama stopped: :Ai ask shows the Ollama error ai-desktop passes on, no crash",
  },
}
