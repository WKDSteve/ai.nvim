-- TESTS/sheets/ai-completion-blink.sheet.lua -- the inline completion next to blink.cmp, on the user's installed
-- config (`config = "user"`): with blink's menu open, <Tab> moves in the menu (blink binds it buffer-locally to
-- select_next) and writes no ghost suggestion of ai.nvim. Live-testing plan of ai.nvim, section 11 (5).
-- Every request goes to the stand-in provider of _helpers.lua (no network): the provider and the completion
-- provider are pointed at it before anything is typed. A skip on CI and where there is no installed config.
return {
  id = "ai.completion-blink",
  title = "Completion with blink.cmp: <Tab> with the menu open moves in the menu, no suggestion is written",
  task = "ai.nvim/abnahme-ai-live-plan-echte-keys-ollama-ai-desktop",
  config = "user",
  sizes = { { rows = 30, cols = 100 } },
  steps = {
    {
      wait = "package.loaded['lazy'] ~= nil",
      timeout = 60000,
      note = "the installed config started",
    },
    {
      lua = [[
        vim.cmd.enew()
        vim.bo.filetype = "lua"
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local alpha_one = 1", "local alpha_two = 2" })
      ]],
      note = "a Lua buffer with two words that start alike",
    },
    { input = "Go", note = "a new line, Insert mode (loads ai.nvim and blink.cmp)" },
    {
      wait = [[vim.api.nvim_get_mode().mode == "i" and package.loaded["ai"] ~= nil and package.loaded["blink.cmp"] ~= nil]],
      timeout = 30000,
      note = "both are loaded",
    },
    {
      lua = [[
        dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
        _G.use_fake("ZZZ")
        local cfg = require("ai.config").get()
        cfg.provider = "sheet"
        cfg.completion.provider = "sheet"
        cfg.agent = false
      ]],
      note = "every ai.nvim request goes to the stand-in from here on",
    },
    { input = "alpha", note = "type the start of the word" },
    {
      wait = [[require("blink.cmp").is_menu_visible()]],
      timeout = 15000,
      note = "blink's menu is open",
    },
    { lua = [[_G.before = require("blink.cmp").get_selected_item_idx() or 0]] },
    { input = "<Tab>", note = "<Tab> with the menu open" },
    {
      wait = [[(require("blink.cmp").get_selected_item_idx() or 0) ~= _G.before]],
      timeout = 5000,
      note = "the selection in the menu moved",
    },
    {
      expect = [[not vim.api.nvim_get_current_line():find("ZZZ", 1, true)
        and not vim.api.nvim_get_current_line():find("\t", 1, true)]],
      note = "no suggestion and no tab were written",
    },
    { expect = [[_G.ghost_text() == ""]], note = "no ghost text shows" },
  },
}
