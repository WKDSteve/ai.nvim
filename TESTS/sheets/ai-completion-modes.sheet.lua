-- TESTS/sheets/ai-completion-modes.sheet.lua -- the three settings of the inline completion, each in its own
-- start of the editor: "manual" (:checkhealth ai names trigger and provider), "auto" (a pause while typing asks
-- by itself, once, and :checkhealth warns about the cost) and `enable = false` (the keys do nothing of ai.nvim,
-- <Tab> is a plain <Tab>, :checkhealth says "disabled"). Live-testing plan of ai.nvim, section 11 (7, 8, 10).
-- The provider is the stand-in of _helpers.lua (no network).
return {
  id = "ai.completion-modes",
  title = "Completion: manual, auto and disabled, each with what :checkhealth ai says about it",
  task = "ai.nvim/live-plan-ai-live-testing-plan-sortieren-erledigtes-abhaken",
  sizes = { { rows = 30, cols = 100 } },
  steps = {
    -- manual
    {
      lua = [[
        dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
        _G.use_fake("42")
        require("ai").setup({ provider = "sheet", completion = { enable = true, trigger = "manual" } })
        vim.cmd("checkhealth ai")
        _G.health = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      ]],
      timeout = 30000,
      note = "completion = manual; :checkhealth ai",
    },
    {
      expect = [[_G.health:find("ai.nvim: completion", 1, true) and _G.health:find("trigger = manual", 1, true)]],
      note = "the completion section names the trigger",
    },
    {
      expect = [[_G.health:find("provider = sheet (completion.provider, falling back to provider)", 1, true)]],
      note = "and the provider it falls back to",
    },
    {
      expect = [[not _G.health:find("auto-trigger fires a request", 1, true)]],
      note = "no cost warning for manual",
    },

    -- auto
    { restart = true },
    {
      lua = [[
        dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
        _G.use_fake("42")
        require("ai").setup({
          provider = "sheet",
          completion = { enable = true, trigger = "auto", idle_ms = 300 },
        })
        vim.bo.filetype = "lua"
      ]],
      note = "completion = auto, 300 ms idle",
    },
    { input = "ilocal x = ", note = "type a line without pausing" },
    {
      wait = [[_G.ghost_text() == "42" and _G.on_screen("local x = 42")]],
      timeout = 5000,
      note = "after the pause the suggestion shows without the trigger key",
    },
    {
      expect = [[_G.eq(#_G.requests, 1)]],
      note = "one request for the whole typed line, not one per key",
    },
    { input = "<Esc>", note = "back to Normal mode" },
    {
      wait = [[vim.api.nvim_get_mode().mode == "n" and _G.ghost_text() == ""]],
      note = "the ghost goes with it",
    },
    {
      lua = [[
        vim.cmd("checkhealth ai")
        _G.health = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      ]],
      timeout = 30000,
    },
    {
      expect = [[_G.health:find("trigger = auto", 1, true) and _G.health:find("auto-trigger fires a request", 1, true)]],
      note = ":checkhealth ai warns that auto asks on every pause",
    },

    -- disabled
    { restart = true },
    {
      lua = [[
        dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
        _G.use_fake("42")
        require("ai").setup({ provider = "sheet", completion = { enable = false } })
        vim.bo.expandtab = false
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = " })
      ]],
      note = "completion.enable = false",
    },
    {
      expect = [[vim.fn.maparg("<C-\\><C-a>", "i") == "" and vim.fn.maparg("<C-]>", "i") == ""]],
      note = "the trigger and dismiss keys are not bound",
    },
    { input = "A", note = "into Insert mode" },
    { wait = [[vim.api.nvim_get_mode().mode == "i"]] },
    { input = "<C-\\><C-a>", note = "the trigger key" },
    {
      lua = [[vim.defer_fn(function() _G.waited = true end, 500)]],
      note = "time for a request that would answer after 50 ms",
    },
    { wait = [[_G.waited]] },
    {
      expect = [[_G.eq(#_G.requests, 0) and _G.ghost_text() == ""]],
      note = "asks nothing, shows nothing",
    },
    { input = "<Esc>" },
    {
      wait = [[vim.api.nvim_get_mode().mode == "n"]],
      note = "back in Normal mode (what the unbound keys left in the line does not matter)",
    },
    { lua = [[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = " })]] },
    { input = "A<Tab><Esc>", note = "<Tab> in Insert mode" },
    { wait = [[_G.line() == "local x = \t"]], note = "is a plain tab" },
    {
      lua = [[
        vim.cmd("checkhealth ai")
        _G.health = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      ]],
      timeout = 30000,
    },
    {
      expect = [[_G.health:find("disabled (config.completion.enable = false)", 1, true)]],
      note = ":checkhealth ai says it is disabled",
    },
  },
}
