-- TESTS/sheets/ai-quick-keys.sheet.lua -- the quick-action keys under the default prefix <leader>a, in Normal and
-- Visual mode, with a UI attached and the real ui.nvim: <leader>aa asks (a prompt, then the answer in a viewer),
-- <leader>as streams a typed task with the context into the panel, <leader>ae explains the context in a badge.
-- In Visual mode the selected lines go along, and with `context.diagnostics` the buffer's diagnostics arrive in
-- the request as "<file>:<line>: [<severity>] <message>". Live-testing plan of ai.nvim, section 7.
-- The provider is the stand-in of _helpers.lua (no network). Needs ui.nvim ($UI_NVIM_DIR, .deps/, beside this
-- repository, or the lazy.nvim directory of the real editor); without it the sheet is a reported skip.
return {
  id = "ai.quick-keys",
  title = "Quick-action keys <leader>aa/as/ae in Normal and Visual mode, with selection and diagnostics",
  task = "ai.nvim/live-plan-ai-live-testing-plan-sortieren-erledigtes-abhaken",
  sizes = { { rows = 30, cols = 100 } },
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_ui()]],
      reason = "ui.nvim is not to be found",
    },
  },
  steps = {
    {
      lua = [[
        dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
        _G.use_fake("PONG from the sheet")
        require("ui").setup({})
        require("ai").setup({ provider = "sheet", context = { diagnostics = true } })
        vim.api.nvim_buf_set_name(0, "sheet.lua")
        vim.bo.filetype = "lua"
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local a = 1", "local b = 2", "return a + c" })
        vim.bo.modified = false
        local ns = vim.api.nvim_create_namespace("sheet")
        vim.diagnostic.set(ns, 0, {
          { lnum = 2, col = 11, severity = vim.diagnostic.severity.ERROR, message = "undefined global c" },
        })
      ]],
      note = "a Lua buffer with a diagnostic on line 3, ai.nvim with context.diagnostics on",
    },

    -- <leader>aa, Normal mode
    { input = "\\aa", note = "<leader>aa" },
    { wait = [[_G.float_open()]], timeout = 5000, note = "a prompt opens" },
    { input = "Reply with PONG<CR>", note = "type the question" },
    { wait = [[_G.on_screen("PONG from the sheet")]], timeout = 5000, note = "the answer shows" },
    {
      expect = [[_G.eq(_G.last_request().kind, "ask") and _G.last_request().prompt:find("Reply with PONG", 1, true)]],
      note = "asked once (not streamed), with the typed text",
    },
    { input = "q", note = "close the viewer" },
    { wait = [[not _G.float_open()]], timeout = 5000 },

    -- <leader>aa, Visual mode
    { input = "ggVj", note = "select lines 1 and 2" },
    { wait = [[vim.api.nvim_get_mode().mode == "V"]] },
    { input = "\\aa", note = "<leader>aa on the selection" },
    {
      wait = [[_G.float_open() and vim.api.nvim_get_mode().mode ~= "V"]],
      timeout = 5000,
      note = "a prompt opens",
    },
    { input = "What is this?<CR>" },
    { wait = [[#_G.requests == 2 and _G.on_screen("PONG from the sheet")]], timeout = 5000 },
    {
      expect = [[(function()
        local p = _G.last_request().prompt
        return p:find("local a = 1", 1, true) and p:find("local b = 2", 1, true)
          and not p:find("return a + c", 1, true) and p:find("What is this?", 1, true)
      end)()]],
      note = "the selected lines go along, the third does not",
    },
    { input = "q" },
    { wait = [[not _G.float_open()]], timeout = 5000 },

    -- <leader>as, Normal mode: streamed into the panel
    { input = "\\as", note = "<leader>as" },
    { wait = [[_G.float_open()]], timeout = 5000, note = "a prompt opens" },
    { input = "fix the diagnostic<CR>" },
    {
      wait = [[_G.on_screen("PONG from the sheet")]],
      timeout = 5000,
      note = "the answer streams into the panel",
    },
    {
      expect = [[_G.eq(_G.last_request().kind, "stream")
        and _G.last_request().prompt:find("sheet.lua:3: [ERROR] undefined global c", 1, true)
        and _G.last_request().prompt:find("fix the diagnostic", 1, true)]],
      note = "streamed, with the diagnostic as <file>:<line>: [<severity>] <message>",
    },
    { input = "q", note = "close the panel (it has the focus)" },
    { wait = [[not _G.float_open()]], timeout = 5000 },

    -- <leader>as, Visual mode
    { input = "ggV", note = "select line 1" },
    { wait = [[vim.api.nvim_get_mode().mode == "V"]] },
    { input = "\\as" },
    { wait = [[_G.float_open() and vim.api.nvim_get_mode().mode ~= "V"]], timeout = 5000 },
    { input = "rename it<CR>" },
    { wait = [[#_G.requests == 4 and _G.on_screen("PONG from the sheet")]], timeout = 5000 },
    {
      expect = [[_G.eq(_G.last_request().kind, "stream") and _G.last_request().prompt:find("local a = 1", 1, true)
        and not _G.last_request().prompt:find("local b = 2", 1, true)]],
      note = "streamed with the selected line",
    },
    { input = "q" },
    { wait = [[not _G.float_open()]], timeout = 5000 },

    -- <leader>ae, Normal mode: a badge
    { lua = [[_G.answer = "BADGE answer"]] },
    { input = "\\ae", note = "<leader>ae" },
    { wait = [[_G.on_screen("BADGE answer")]], timeout = 5000, note = "the explanation shows" },
    {
      expect = [[_G.eq(_G.last_request().kind, "ask")
        and _G.last_request().prompt:find("Explain this briefly", 1, true)
        and _G.last_request().prompt:find("undefined global c", 1, true)]],
      note = "asked with the context (here the diagnostic), no prompt to type",
    },

    -- <leader>ae, Visual mode
    { input = "<Esc>ggjV", note = "select line 2" },
    { wait = [[vim.api.nvim_get_mode().mode == "V"]] },
    { input = "\\ae" },
    { wait = [[#_G.requests == 6]], timeout = 5000 },
    {
      expect = [[_G.last_request().prompt:find("local b = 2", 1, true)
        and not _G.last_request().prompt:find("local a = 1", 1, true)]],
      note = "the selected line is what is explained",
    },
  },
  judge = { "the prompt, the viewer, the panel and the badge read well at this size" },
  manual = {
    "In the real editor: <leader>aa/as/ae against a real provider (with which-key: the group reads ai.nvim)",
  },
}
