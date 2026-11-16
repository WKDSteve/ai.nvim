-- TESTS/sheets/ai-completion-ghost.sheet.lua -- the inline completion (ghost text) as it is typed, with a UI
-- attached: the manual trigger key shows the suggestion as dimmed text at the cursor, <Tab> takes it (text and
-- cursor), <C-]> drops it, typing drops it, a suggestion of several lines shows them all, and <Tab> while the
-- popup menu is open belongs to the menu, not to the suggestion. Live-testing plan of ai.nvim, section 11.
-- The provider is the stand-in of _helpers.lua (no network); the quality of real suggestions is a hand check.
return {
  id = "ai.completion-ghost",
  title = "Completion: trigger shows ghost text, <Tab> accepts, <C-]> and typing dismiss, the menu keeps <Tab>",
  task = "ai.nvim/live-plan-ai-live-testing-plan-sortieren-erledigtes-abhaken",
  sizes = { { rows = 24, cols = 80 } },
  steps = {
    {
      lua = [[
        dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
        _G.use_fake("42")
        require("ai").setup({ provider = "sheet", completion = { enable = true, trigger = "manual" } })
        vim.bo.filetype = "lua"
        vim.bo.expandtab = false
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = " })
      ]],
      note = "ai.nvim with the default keys, completion on (manual), a Lua buffer with a half-written line",
    },
    { input = "A", note = "into Insert mode at the end of the line" },
    { wait = [[vim.api.nvim_get_mode().mode == "i"]] },

    -- the manual trigger
    { input = "<C-\\><C-a>", note = "the trigger key <C-\\><C-a>" },
    {
      wait = [[_G.ghost_text() == "42" and _G.on_screen("local x = 42")]],
      timeout = 5000,
      note = "the suggestion shows at the cursor",
    },
    { hl = { text = "42", group = "Comment" }, note = "dimmed, in the colour of a comment" },
    {
      expect = [[_G.eq(_G.line(), "local x = ") and _G.eq(#_G.requests, 1)]],
      note = "nothing is written yet; one request went out",
    },
    {
      expect = [[_G.last_request().prompt:find("local x = ", 1, true) ~= nil]],
      note = "the request carries the text before the cursor",
    },

    -- <Tab> accepts
    { input = "<Tab>", note = "accept" },
    {
      wait = [[_G.line() == "local x = 42" and _G.ghost_text() == ""]],
      note = "the suggestion is written and the ghost is gone",
    },
    {
      expect = [[_G.eq(vim.api.nvim_win_get_cursor(0), { 1, 12 }) and vim.api.nvim_get_mode().mode == "i"]],
      note = "the cursor stands after the inserted text, still in Insert mode",
    },

    -- <C-]> dismisses
    { lua = [[_G.answer = " + 1"]], note = "the next suggestion" },
    { input = "<C-\\><C-a>" },
    { wait = [[_G.ghost_text() == " + 1"]], timeout = 5000, note = "a suggestion shows" },
    { input = "<C-]>", note = "dismiss" },
    {
      wait = [[_G.ghost_text() == "" and not _G.on_screen("+ 1")]],
      note = "the ghost is gone",
    },
    { expect = [[_G.eq(_G.line(), "local x = 42")]], note = "and nothing was written" },

    -- typing dismisses
    { input = "<C-\\><C-a>" },
    { wait = [[_G.ghost_text() == " + 1"]], timeout = 5000, note = "a suggestion shows again" },
    { input = ";", note = "type on instead of accepting" },
    {
      wait = [[_G.ghost_text() == "" and _G.line() == "local x = 42;"]],
      note = "the typed text stays, the suggestion that no longer fits is gone",
    },

    -- several lines
    { lua = [[_G.answer = "\nlocal y = 1\nlocal z = 2"]], note = "a suggestion of three lines" },
    { input = "<C-\\><C-a>" },
    {
      wait = [[_G.on_screen("local y = 1") and _G.on_screen("local z = 2")]],
      timeout = 5000,
      note = "every line of it shows below the cursor line",
    },
    { input = "<Tab>", note = "accept it" },
    {
      wait = [[vim.api.nvim_buf_line_count(0) == 3]],
      note = "three lines are written",
    },
    {
      expect = [[_G.eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "local x = 42;", "local y = 1", "local z = 2" })]],
    },
    {
      expect = [[_G.eq(vim.api.nvim_win_get_cursor(0), { 3, 11 })]],
      note = "the cursor stands at the end of the last inserted line",
    },

    -- <Tab> with the popup menu open
    {
      lua = [[
        _G.answer = "ZZZ"
        vim.api.nvim_buf_set_lines(0, -1, -1, false, { "-- alpha alpine" })
      ]],
      note = "a suggestion that must not land; two words for the keyword completion",
    },
    { input = "<CR>alp", note = "a new line, the start of a word the buffer has" },
    { input = "<C-\\><C-a>" },
    { wait = [[_G.ghost_text() == "ZZZ"]], timeout = 5000, note = "a suggestion shows" },
    { input = "<C-n>", note = "the built-in keyword completion opens its menu" },
    { wait = [[vim.fn.pumvisible() == 1]], timeout = 5000, note = "the menu is open" },
    { input = "<Tab>", note = "<Tab> while the menu is open" },
    {
      wait = [[vim.fn.pumvisible() == 0]],
      timeout = 5000,
      note = "the menu took the key",
    },
    {
      expect = [[not _G.line():find("ZZZ") and not vim.api.nvim_buf_get_lines(0, 3, 4, false)[1]:find("ZZZ")]],
      note = "the suggestion was not written",
    },
  },
  manual = {
    "In the real editor with blink.cmp: with its menu open, <Tab> moves in the menu and writes no suggestion",
    "Against a real provider (ollama, claude, openai, gemini): the suggestions are usable; note latency and quality",
  },
}
