-- TESTS/sheets/ai-claude-cli.sheet.lua -- a question through the Claude Code CLI as a user asks it: the provider is
-- switched with :Ai provider claude-cli, :Ai ask sends the prompt, the answer comes up in the ui.nvim viewer. The CLI
-- is the stand-in of the provider's spec (TESTS/ai/fixtures/fake_claude.lua, run as `nvim -l`; it prints the same
-- stream-json events as `claude -p`), so the provider's own process start (providers/claude_cli.lua) runs for real
-- and nothing reaches a model. What the real CLI does with a login is a live check (ai.nvim's live-testing plan).
return {
  id = "ai.claude-cli",
  title = ":Ai provider claude-cli, :Ai ask: the CLI is started, its answer is shown in the viewer",
  feature = "ai.claude-cli",
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
        require("ai.providers.claude_cli").command =
          { vim.v.progpath, "-u", "NONE", "-l", vim.fn.getcwd() .. "/TESTS/ai/fixtures/fake_claude.lua" }
      ]],
      note = "ai.nvim and ui.nvim set up, the claude CLI is the stand-in",
    },
    { input = ":Ai provider claude-cli<CR>", note = "switch the provider" },
    {
      wait = [[require("ai.config").get().provider == "claude-cli"]],
      timeout = 5000,
      note = "the provider is switched",
    },
    { expect = [[_G.noted("provider set to claude-cli")]], note = "it says so" },
    { input = ":Ai ask Say hello<CR>", note = "ask" },
    {
      wait = [[_G.float_open() and _G.on_screen("Hello")]],
      timeout = 20000,
      note = "the viewer shows the CLI's answer",
    },
    {
      expect = [[vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "Hello"]],
      note = "exactly the answer, not the events around it",
    },
    { input = "q", note = "close the viewer" },
    { wait = [[not _G.float_open()]], timeout = 5000 },
  },
  judge = { "the viewer shows the answer as text, nothing of the CLI's JSON" },
  manual = {
    "once with the real `claude` and a login: the answer of the model comes up the same way",
  },
}
