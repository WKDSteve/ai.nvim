-- TESTS/sheets/ai-live-claude-models.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets"): the
-- model table of the provider `claude` (lua/ai/providers/claude.lua: EFFORT_MODELS, SAMPLING_REJECTED) against the
-- real Messages API. Each current model gets one request with an effort level; the provider sends it as
-- output_config.effort, lowers it where the model lacks it (xhigh on Opus 4.5 becomes high) or drops it (Sonnet 4.5
-- takes none). A wrong table entry shows here as an HTTP 400 for that model. A model id that does not exist must
-- come back as a readable error.
--
-- Runs only with:  testing sheets run --live --sheet ai.live-claude-models --root <ai.nvim> [--tasks <vault>]
-- (ANTHROPIC_API_KEY set; never on CI, a skip without --live or without the key)
return {
  id = "ai.live-claude-models",
  title = "Live: claude effort per model (5.x, Fable, 4.5) and an unknown model against the real API",
  task = "ai.nvim/abnahme-claude-api-funktionen-mit-dem-api-guthaben",
  live = {
    env = { "ANTHROPIC_API_KEY" },
    hosts = { "api.anthropic.com" },
    cost = "seven short requests (Opus 5.5, Sonnet 5.5, Haiku 5.5, Fable 5.2, Opus 4.5, Sonnet 4.5, one refused),"
      .. " at most 8192 output tokens each (thinking at xhigh/max counts against it): a few cents, at worst some 20",
  },
  steps = {
    {
      lua = [[
        vim.g.live = vim.empty_dict()
        require("ai").setup({ provider = "claude", keymaps = { enable = false }, completion = { enable = false } })
        -- model id -> effort asked for; the comment says what the provider sends
        vim.g.cases = {
          ["claude-opus-5-5"] = "xhigh", -- xhigh
          ["claude-sonnet-5-5"] = "max", -- max
          ["claude-haiku-5-5"] = "low", -- low
          ["claude-fable-5-2"] = "medium", -- medium
          ["claude-opus-4-5"] = "xhigh", -- lowered to high
          ["claude-sonnet-4-5"] = "high", -- dropped: the model takes no effort
        }
        for model, effort in pairs(vim.g.cases) do
          require("ai").ask(
            { model = model, effort = effort, prompt = "Reply with exactly the word: PONG", max_tokens = 8192 },
            function(ok, res)
              local all = vim.g.live
              all[model] = ok and { ok = true, text = res.text, stop_reason = res.stop_reason, usage = res.usage }
                or { ok = false, text = tostring(type(res) == "table" and (res.message or res.msg) or res) }
              vim.g.live = all
            end
          )
        end
      ]],
      note = "one request per model, each with an effort level",
    },
    { wait = "vim.tbl_count(vim.g.live) == 6", timeout = 120000, note = "all six answered" },
    {
      expect = [[(function()
        local bad = {}
        for model, r in pairs(vim.g.live) do
          if not (r.ok and r.text:upper():find("PONG", 1, true)) then
            bad[#bad + 1] = model .. ": " .. vim.inspect(r, { newline = " ", indent = "" })
          end
        end
        return #bad == 0 or error(table.concat(bad, "\n"), 0)
      end)()]],
      note = "every model answered PONG: no HTTP 400 for an effort or a sampling parameter",
    },
    {
      expect = [[(function()
        local claude = require("ai.providers.claude")
        return claude.accepts_effort("claude-opus-4-5", "high") and not claude.accepts_effort("claude-opus-4-5", "xhigh")
          and not claude.accepts_effort("claude-sonnet-4-5")
      end)()]],
      note = "the table the requests above went through (no network): Opus 4.5 high yes, xhigh no; Sonnet 4.5 none",
    },
    {
      measure = [[vim.g.live["claude-opus-5-5"].usage and vim.g.live["claude-opus-5-5"].usage.output_tokens or -1]],
      name = "claude-opus-5-5 xhigh PONG output tokens",
      unit = "tokens",
      note = "what thinking at xhigh costs for a one-word answer",
    },
    {
      lua = [[
        require("ai").ask({ model = "claude-does-not-exist-1", prompt = "test", max_tokens = 64 }, function(ok, res)
          vim.g.unknown = { ok = ok, text = ok and res.text or tostring(type(res) == "table" and res.message or res) }
        end)
      ]],
      note = "ask a model id that does not exist",
    },
    { wait = "vim.g.unknown ~= nil", timeout = 60000, note = "it answered" },
    {
      expect = [[vim.g.unknown.ok == false and #vim.g.unknown.text > 0
        or error("an unknown model gave: " .. vim.inspect(vim.g.unknown, { newline = " ", indent = "" }), 0)]],
      note = "a readable error naming the problem, not an empty success",
    },
  },
}
