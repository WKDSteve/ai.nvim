-- TESTS/sheets/ai-key-command.sheet.lua -- an API key that comes from a command (`pass show anthropic` in the docs):
-- the config names a key profile with `command`, :Ai key picks it, :Ai ask runs the command first (ai.keys, the one
-- process ai.nvim starts for a key) and sends the request with the key it printed. The command is a real process
-- (TESTS/sheets/fixtures/print_key.lua under `nvim -l`, a fake key); the request to the Claude API is a stub of
-- lib.nvim.net.curl in the child (no curl, no network): it records whether the key arrived and answers like the API.
return {
  id = "ai.key-command",
  title = "A key profile with a command: :Ai key picks it, :Ai ask runs the command and sends its key",
  feature = "ai.key-command",
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
        -- the network: the module transport.lua holds, its two calls replaced in place
        _G.http = {}
        local curl = require("lib.nvim.net.curl")
        curl.fetch_json = function(url, opts, cb)
          local key = opts.secret_headers and opts.secret_headers["x-api-key"]
          _G.http[#_G.http + 1] = { url = url, key_from_command = key == "sk-ant-sheet-not-a-real-key" }
          vim.schedule(function()
            cb(true, {
              type = "message",
              content = { { type = "text", text = "Hello from the stub" } },
              stop_reason = "end_turn",
              usage = { input_tokens = 3, output_tokens = 4 },
            }, { code = 0 })
          end)
        end
        curl.fetch_stream = function()
          error("the sheet asks, it does not stream", 0)
        end
        require("ui").setup({})
        require("ai").setup({
          provider = "claude",
          agent = false,
          keys = {
            claude = {
              profiles = {
                vault = {
                  command = { vim.v.progpath, "-u", "NONE", "-l", vim.fn.getcwd() .. "/TESTS/sheets/fixtures/print_key.lua" },
                },
              },
            },
          },
        })
      ]],
      note = "a key profile `vault` whose key a command prints; the Claude API is a stub",
    },
    { input = ":Ai key vault<CR>", note = "pick the profile" },
    {
      wait = [[_G.noted("key profile 'vault' for claude")]],
      timeout = 5000,
      note = "it says so (the command has not run yet)",
    },
    { input = ":Ai ask Say hello<CR>", note = "ask" },
    {
      wait = [[_G.float_open() and _G.on_screen("Hello from the stub")]],
      timeout = 20000,
      note = "the viewer shows the answer",
    },
    {
      expect = [[_G.eq(_G.http, { { url = _G.http[1].url, key_from_command = true } })]],
      note = "one request, with the key the command printed (never shown)",
    },
    {
      expect = [[not _G.on_screen("sk-ant-")]],
      note = "the key is nowhere on the screen",
    },
  },
  judge = { "the viewer shows the answer; nothing of the key" },
  manual = {
    "once with a real password manager (`pass show anthropic`, `op read ...`): its prompt does not block the editor",
  },
}
