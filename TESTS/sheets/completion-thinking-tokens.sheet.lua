-- TESTS/sheets/completion-thinking-tokens.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets").
-- The ghost completion caps its answer at completion.max_tokens = 512 with effort "low"; a model that thinks
-- first may spend the cap and stop at max_tokens, and the suggestion is thrown away. This asks each model once, the
-- way the completion asks; the output tokens of each model are measured (notes in the task, -1 = the request
-- failed), then no model may err or stop at max_tokens (the failure line carries stop_reason and usage).
--
-- Runs only with:  testing sheets run --live --sheet ai.completion-thinking-tokens --root <ai.nvim> [--tasks <vault>]
-- (ANTHROPIC_API_KEY set; never on CI, a skip without --live or without the key)
return {
  id = "ai.completion-thinking-tokens",
  title = "Completion: thinking tokens against max_tokens 512 (5.x, Fable)",
  task = "ai.nvim/completion-thinking-tokens-gegen-max-tokens-512-live-messen",
  live = {
    env = { "ANTHROPIC_API_KEY" },
    hosts = { "api.anthropic.com" },
    cost = "three requests of at most 512 output tokens (Opus 5.5, Sonnet 5.5, Fable 5.2): a few cents",
  },
  steps = {
    {
      lua = [[
        vim.g.live_results = vim.empty_dict()
        local claude = require("ai.providers.claude")
        local p, sys = require("ai.completion.prompt").build("local function add(a, b)\n  return ", "\nend\n", "lua")
        for _, model in ipairs({ "claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-2" }) do
          claude.ask({ prompt = p, system = sys, model = model, max_tokens = 512, effort = "low" }, function(ok, res)
            local all = vim.g.live_results
            all[model] = ok and { stop_reason = res.stop_reason, usage = res.usage }
              or { error = tostring(type(res) == "table" and (res.message or res.msg) or res) }
            vim.g.live_results = all
          end)
        end
      ]],
      note = "one completion request per model, as the ghost completion sends it",
    },
    {
      wait = "vim.tbl_count(vim.g.live_results) == 3",
      timeout = 90000,
      note = "all three answered",
    },
    {
      measure = "(vim.g.live_results['claude-opus-5-5'].usage or {}).output_tokens or -1",
      name = "Opus 5.5 output tokens",
      unit = "tokens",
    },
    {
      measure = "(vim.g.live_results['claude-sonnet-5-5'].usage or {}).output_tokens or -1",
      name = "Sonnet 5.5 output tokens",
      unit = "tokens",
    },
    {
      measure = "(vim.g.live_results['claude-fable-5-2'].usage or {}).output_tokens or -1",
      name = "Fable 5.2 output tokens",
      unit = "tokens",
    },
    {
      expect = [[(function()
        for _, r in pairs(vim.g.live_results) do
          if r.error or r.stop_reason == "max_tokens" then
            error("stop_reason and usage: " .. vim.inspect(vim.g.live_results, { newline = " ", indent = "" }), 0)
          end
        end
        return true
      end)()]],
      note = "no model errs or stops at max_tokens",
    },
  },
}
