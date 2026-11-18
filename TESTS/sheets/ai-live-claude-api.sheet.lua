-- TESTS/sheets/ai-live-claude-api.sheet.lua -- a live sheet (testing.nvim, docs/SHEETS.md "Live sheets"): what the
-- provider `claude` sends to the real Messages API beyond a bare prompt. A system prompt is obeyed, a small
-- max_tokens stops with stop_reason "max_tokens" and real usage numbers, an image and a PDF attachment are read
-- (fixtures in TESTS/sheets/fixtures/live: a red square, a page with the code word ZEBRA-4711), and a temperature
-- goes through on a model that takes one. All five requests run at once on the cheapest model that can do all of it.
--
-- Runs only with:  testing sheets run --live --sheet ai.live-claude-api --root <ai.nvim>
-- (into its task instead: --task <the task below> --tasks <vault>; --sheet takes no --tasks)
-- (ANTHROPIC_API_KEY set; never on CI, a skip without --live or without the key)
return {
  id = "ai.live-claude-api",
  title = "Live: claude system prompt, max_tokens stop, usage, image, PDF and temperature against the real API",
  task = "ai.nvim/abnahme-claude-api-funktionen-mit-dem-api-guthaben",
  live = {
    env = { "ANTHROPIC_API_KEY" },
    hosts = { "api.anthropic.com" },
    cost = "five short requests on claude-haiku-4-5, one with a small image and one with a one-page PDF: about a cent",
  },
  steps = {
    {
      lua = [[
        vim.g.live = vim.empty_dict()
        require("ai").setup({ provider = "claude", keymaps = { enable = false }, completion = { enable = false } })
        ---Keep one answer under `name` in vim.g.live (a string on failure, the response fields on success).
        function _G.keep(name)
          return function(ok, res)
            local all = vim.g.live
            all[name] = ok and { ok = true, text = res.text, stop_reason = res.stop_reason, usage = res.usage }
              or { ok = false, text = tostring(type(res) == "table" and (res.message or res.msg) or res) }
            vim.g.live = all
          end
        end
      ]],
      note = "ai.nvim with claude as the provider, no keys bound",
    },
    {
      lua = [[
        local ai = require("ai")
        local att = require("ai.attachments")
        local model = "claude-haiku-4-5"
        local png = assert(att.from_file("TESTS/sheets/fixtures/live/red-square.png"))
        local pdf = assert(att.from_file("TESTS/sheets/fixtures/live/codeword.pdf"))
        ai.ask({
          model = model,
          system = "Whatever you are asked, answer with exactly the word BANANA and nothing else.",
          prompt = "What is two plus two?",
          max_tokens = 64,
        }, _G.keep("system"))
        ai.ask({ model = model, prompt = "Write a long poem about the sea.", max_tokens = 16 }, _G.keep("cut"))
        ai.ask({
          model = model,
          prompt = "Which colour fills this image? Answer with one English word.",
          attachments = { png },
          max_tokens = 64,
        }, _G.keep("image"))
        ai.ask({
          model = model,
          prompt = "What is the code word in this document? Answer with the code word only.",
          attachments = { pdf },
          max_tokens = 64,
        }, _G.keep("pdf"))
        ai.ask({ model = model, prompt = "Reply with exactly the word: PONG", temperature = 0, max_tokens = 64 },
          _G.keep("temperature"))
      ]],
      note = "five requests at once: system, a tiny max_tokens, an image, a PDF, temperature 0",
    },
    { wait = "vim.tbl_count(vim.g.live) == 5", timeout = 90000, note = "all five answered" },
    {
      expect = [[vim.g.live.system.ok and vim.g.live.system.text:upper():find("BANANA", 1, true)
        or error("system: " .. vim.inspect(vim.g.live.system, { newline = " ", indent = "" }), 0)]],
      note = "the system prompt was obeyed (BANANA instead of 4)",
    },
    {
      expect = [[vim.g.live.cut.ok and vim.g.live.cut.stop_reason == "max_tokens"
        or error("cut: " .. vim.inspect(vim.g.live.cut, { newline = " ", indent = "" }), 0)]],
      note = "max_tokens 16 stops the poem with stop_reason max_tokens, not as an error",
    },
    {
      expect = [[(function(u)
        return type(u) == "table" and (u.input_tokens or 0) > 0 and (u.output_tokens or 0) > 0
          and u.output_tokens <= 16
      end)(vim.g.live.cut.usage) or error("usage: " .. vim.inspect(vim.g.live.cut.usage, { newline = " ", indent = "" }), 0)]],
      note = "usage carries real input and output tokens, the output within the cap",
    },
    {
      expect = [[vim.g.live.image.ok and vim.g.live.image.text:upper():find("RED", 1, true)
        or error("image: " .. vim.inspect(vim.g.live.image, { newline = " ", indent = "" }), 0)]],
      note = "the image was read: it says red",
    },
    {
      expect = [[vim.g.live.pdf.ok and vim.g.live.pdf.text:upper():find("ZEBRA", 1, true)
        and vim.g.live.pdf.text:find("4711", 1, true)
        or error("pdf: " .. vim.inspect(vim.g.live.pdf, { newline = " ", indent = "" }), 0)]],
      note = "the PDF was read whole: it names ZEBRA-4711",
    },
    {
      expect = [[vim.g.live.temperature.ok and vim.g.live.temperature.text:upper():find("PONG", 1, true)
        or error("temperature: " .. vim.inspect(vim.g.live.temperature, { newline = " ", indent = "" }), 0)]],
      note = "temperature 0 is accepted by a model that takes one",
    },
    {
      measure = "vim.g.live.image.usage and vim.g.live.image.usage.input_tokens or -1",
      name = "claude image request input tokens",
      unit = "tokens",
      min = 1,
      note = "what a 64x64 image costs as input",
    },
  },
  manual = {
    "In the Claude Console (Usage / Cost of the org the key belongs to): the requests of this run are booked there, against the monthly API credit",
  },
}
