-- TESTS/sheets/ai-copilot-cli.sheet.lua -- a question through the GitHub Copilot CLI as a user asks it: the provider
-- is switched with :Ai provider copilot, :Ai ask sends the prompt, the answer comes up in the ui.nvim viewer. The CLI
-- is the stand-in of the provider's spec (TESTS/ai/fixtures/fake_copilot.lua, run as `nvim -l`; it prints the JSON
-- events of `copilot --output-format json`, a commentary message before the answer), so the provider's own process
-- start (providers/copilot.lua) runs for real and nothing reaches a model or an account.
return {
  id = "ai.copilot-cli",
  title = ":Ai provider copilot, :Ai ask: the CLI is started, only its final answer is shown in the viewer",
  feature = "ai.copilot-cli",
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
        require("ui").setup({})
        require("ai").setup({})
        -- where a user points the provider at another binary; here the stand-in of the provider's spec
        require("ai.providers.copilot").command =
          { vim.v.progpath, "-u", "NONE", "-l", vim.fn.getcwd() .. "/TESTS/ai/fixtures/fake_copilot.lua" }
      ]],
      note = "ai.nvim and ui.nvim set up, the copilot CLI is the stand-in",
    },
    { input = ":Ai provider copilot<CR>", note = "switch the provider" },
    {
      wait = [[require("ai.config").get().provider == "copilot"]],
      timeout = 5000,
      note = "the provider is switched",
    },
    { expect = [[_G.noted("provider set to copilot")]], note = "it says so" },
    { input = ":Ai ask Say hello<CR>", note = "ask" },
    {
      wait = [[_G.float_open() and _G.on_screen("Hello")]],
      timeout = 20000,
      note = "the viewer shows the CLI's answer",
    },
    {
      expect = [[_G.eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Hello" })]],
      note = "only the final answer, not the commentary before it",
    },
    { input = "q", note = "close the viewer" },
    { wait = [[not _G.float_open()]], timeout = 5000 },
  },
  judge = { "the viewer shows the answer as text, nothing of the CLI's JSON or its commentary" },
  manual = {
    "once with the real `copilot` and a login: the answer of the model comes up the same way",
  },
}
