-- TESTS/sheets/ai-live-claude-keys.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets"): key
-- profiles (docs/configuration.md "Key profiles") with a real key. The child copies its ANTHROPIC_API_KEY into a key
-- file of its own temp directory and defines two profiles: `datei` (that file) and `leer` (a variable that is
-- empty). `leer` must fail with missing_api_key even while ANTHROPIC_API_KEY is set (a chosen profile never falls
-- back to the default variable); `datei` must reach the real API after the variable is gone; `:Ai key reset`
-- (keys.reset) then has no key left and claude is not available. No line the plugin shows carries the key. The file is removed at the end.
--
-- Runs only with:  testing sheets run --live --sheet ai.live-claude-keys --root <ai.nvim>
-- (into its task instead: --task <the task below> --tasks <vault>; --sheet takes no --tasks)
-- (ANTHROPIC_API_KEY set; never on CI, a skip without --live or without the key)
return {
  id = "ai.live-claude-keys",
  title = "Live: claude key profiles (file, empty, reset) with a real key, no fallback, the key never shown",
  task = "ai.nvim/abnahme-claude-api-funktionen-mit-dem-api-guthaben",
  live = {
    env = { "ANTHROPIC_API_KEY" },
    hosts = { "api.anthropic.com" },
    cost = "one short request on claude-haiku-4-5 (the other two fail before sending): well under a cent",
  },
  steps = {
    {
      lua = [[
        _G.sheet_key = vim.env.ANTHROPIC_API_KEY
        _G.key_file = vim.fn.tempname() .. ".key"
        vim.fn.writefile({ _G.sheet_key }, _G.key_file)
        -- the last step removes it; this also covers a run that fails or is stopped before it
        vim.api.nvim_create_autocmd("VimLeavePre", {
          callback = function()
            os.remove(_G.key_file)
          end,
        })
        vim.env.AI_SHEET_EMPTY_KEY = nil
        require("ai").setup({
          provider = "claude",
          keymaps = { enable = false },
          completion = { enable = false },
          keys = {
            claude = {
              profiles = {
                datei = { file = _G.key_file },
                leer = { env = "AI_SHEET_EMPTY_KEY" },
              },
            },
          },
        })
        ---Ask once and keep the result under `name` in vim.g.live.
        function _G.ask_as(name)
          require("ai").ask(
            { model = "claude-haiku-4-5", prompt = "Reply with exactly the word: PONG", max_tokens = 64 },
            function(ok, res)
              local all = vim.g.live or vim.empty_dict()
              all[name] = ok and { ok = true, text = res.text }
                or { ok = false, kind = type(res) == "table" and res.kind or nil, text = tostring(type(res) == "table" and res.message or res) }
              vim.g.live = all
            end
          )
        end
      ]],
      note = "a key file in the child's temp directory, profiles datei and leer",
    },
    {
      lua = [[
        require("ai.keys").use("leer", "claude")
        _G.ask_as("leer")
      ]],
      note = "profile leer while ANTHROPIC_API_KEY is still set",
    },
    { wait = "vim.g.live and vim.g.live.leer ~= nil", timeout = 30000, note = "it answered" },
    {
      expect = [[vim.g.live.leer.ok == false and vim.g.live.leer.kind == "missing_api_key"
        or error("leer: " .. vim.inspect(vim.g.live.leer, { newline = " ", indent = "" }), 0)]],
      note = "missing_api_key: no quiet fallback to ANTHROPIC_API_KEY",
    },
    {
      lua = [[
        vim.env.ANTHROPIC_API_KEY = nil
        require("ai.keys").use("datei", "claude")
        _G.ask_as("datei")
      ]],
      note = "the variable gone, profile datei",
    },
    { wait = "vim.g.live.datei ~= nil", timeout = 60000, note = "it answered" },
    {
      expect = [[vim.g.live.datei.ok and vim.g.live.datei.text:upper():find("PONG", 1, true)
        or error("datei: " .. vim.inspect(vim.g.live.datei, { newline = " ", indent = "" }), 0)]],
      note = "the key from the file reached the real API",
    },
    {
      expect = [[(function()
        local line = require("ai.keys").describe("claude")
        return line:find("datei", 1, true) and line:find("key present", 1, true)
          and not line:find(_G.sheet_key, 1, true) or error("describe: " .. line:gsub(vim.pesc(_G.sheet_key), "<KEY>"), 0)
      end)()]],
      note = ":Ai key's line names the profile and key present, never the key",
    },
    {
      lua = [[
        vim.cmd("checkhealth ai")
        _G.health = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        vim.cmd("bwipeout!")
      ]],
      timeout = 30000,
      note = ":checkhealth ai with profile datei in force",
    },
    {
      expect = [[(function()
        local h = _G.health
        if h:find(_G.sheet_key, 1, true) then
          error("checkhealth printed the key", 0)
        end
        return h:find("claude: available", 1, true) and h:find("claude: profile datei (file, key present)", 1, true)
          or error("checkhealth: " .. h:gsub("\n", " | "):sub(1, 600), 0)
      end)()]],
      note = ":checkhealth ai: claude available, its profile and key present, never the key",
    },
    {
      lua = [[
        require("ai.keys").reset("claude")
        _G.ask_as("reset")
      ]],
      note = "keys.reset: back to the default variable, which is gone",
    },
    { wait = "vim.g.live.reset ~= nil", timeout = 30000, note = "it answered" },
    {
      expect = [[vim.g.live.reset.ok == false and vim.g.live.reset.kind == "provider_resolution"
        or error("reset: " .. vim.inspect(vim.g.live.reset, { newline = " ", indent = "" }), 0)]],
      note = "no profile and no variable: claude is not available (provider_resolution, as the specs say;"
        .. " missing_api_key is only for a chosen profile without a key), nothing sent",
    },
    {
      expect = [[(function()
        for _, n in ipairs(_G.notes or {}) do
          if n:find(_G.sheet_key, 1, true) then
            error("a notification carried the key", 0)
          end
        end
        os.remove(_G.key_file)
        return vim.fn.filereadable(_G.key_file) == 0
      end)()]],
      note = "no notification carried the key; the key file is removed",
    },
  },
}
