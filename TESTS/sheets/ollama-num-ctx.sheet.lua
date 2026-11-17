-- TESTS/sheets/ollama-num-ctx.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets").
-- Without `num_ctx` Ollama uses a GPU-dependent context window (4096 tokens on a 12 GB card) and silently drops the
-- beginning of a longer prompt. This sends a prompt of about 7000 tokens whose first line holds a secret word and
-- asks for it at the end: with `ollama.num_ctx` (32768, the default) the model must name it. Measured by hand on
-- 2026-11-10: without num_ctx the prompt was cut to 4095 tokens and the answer came back empty.
--
-- Runs only with:
--   AI_OLLAMA_HOST=http://127.0.0.1:11434 testing sheets run --live --sheet ai.ollama-num-ctx --root <ai.nvim>
-- (a running Ollama with one of the models below; never on CI, a skip without --live or without the variable)
return {
  id = "ai.ollama-num-ctx",
  title = "Ollama: a long prompt arrives whole (num_ctx)",
  live = {
    env = { "AI_OLLAMA_HOST" },
    hosts = { "127.0.0.1", "localhost" },
    cost = "none (a local model); one request of about 7000 prompt tokens, up to a minute with a cold model",
  },
  steps = {
    {
      lua = [[
        local host = vim.env.AI_OLLAMA_HOST or ""
        local out = vim.system({ "curl", "-s", "--max-time", "5", host .. "/api/tags" }, { text = true }):wait()
        assert(out.code == 0, "Ollama not reachable at " .. host .. " (curl exit " .. out.code .. ")")
        local tags = vim.json.decode(out.stdout)
        local have = {}
        for _, m in ipairs(tags.models or {}) do
          have[m.name] = true
        end
        for _, name in ipairs({ "gemma4:12b-it-qat", "qwen3.6:35b-a3b-coding", "qwen3.5:9b" }) do
          if have[name] then
            vim.g.sheet_model = name
            return
          end
        end
        error("none of gemma4:12b-it-qat, qwen3.6:35b-a3b-coding, qwen3.5:9b is pulled", 0)
      ]],
      note = "Ollama answers and has one of the models",
    },
    {
      lua = [[
        local lines = { "The secret word is FLAMINGO. Remember it.", "" }
        for i = 1, 400 do
          lines[#lines + 1] = ("local value_%d = compute(%d, 'filler text for the context window')"):format(i, i)
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Question: what is the secret word from the very first line? Answer with the word only."
        require("ai.config").setup({ keymaps = { enable = false }, usercmds = { enable = false } })
        vim.g.sheet_answer = vim.NIL
        require("ai").ask({
          provider = "ollama",
          model = vim.g.sheet_model,
          prompt = table.concat(lines, "\n"),
          timeout_ms = 240000,
        }, function(ok, res)
          vim.g.sheet_answer = ok and res.text or ("error: " .. tostring(res.message or res))
        end)
      ]],
      note = "one long request with the default ollama.num_ctx",
    },
    {
      wait = "vim.g.sheet_answer ~= vim.NIL",
      timeout = 300000,
      note = "the model answered",
    },
    {
      expect = [[(function()
        local answer = vim.g.sheet_answer
        if type(answer) ~= "string" or not answer:upper():find("FLAMINGO", 1, true) then
          error("answer without the secret word (the prompt's beginning was dropped?): " .. vim.inspect(answer), 0)
        end
        return true
      end)()]],
      note = "the secret word of the first line came back",
    },
  },
  judge = {},
}
