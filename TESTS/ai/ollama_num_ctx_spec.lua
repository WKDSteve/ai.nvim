-- `config.ollama.num_ctx`: how it reaches an Ollama request (and no other),
-- how a bad value is rejected, what the provider sends, and the warning for a
-- prompt that likely does not fit. Without `num_ctx` Ollama uses its own,
-- GPU-dependent default (4096 on a 12 GB card) and silently drops the
-- beginning of a longer prompt.
---@diagnostic disable: missing-fields, need-check-nil

describe("ollama num_ctx", function()
  local messages, original_notify, seen

  local function reset()
    for _, name in ipairs({ "ai", "ai.config", "ai.providers", "ai.policy", "ai.providers.ollama" }) do
      package.loaded[name] = nil
    end
    package.loaded["ai.providers.transport"] = nil
  end

  before_each(function()
    reset()
    seen = nil
    messages = {}
    original_notify = vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg)
      messages[#messages + 1] = msg
    end
  end)

  after_each(function()
    vim.notify = original_notify
    package.loaded["lib.nvim.net.curl"] = nil
    package.loaded["lib.nvim.notify"] = nil
    reset()
  end)

  describe("resolution", function()
    ---Recording stand-ins under the ids `ollama` and `fake`.
    local function setup(opts)
      require("ai.config").setup(opts)
      local reg = require("ai.providers")
      reg.load_builtin()
      for _, id in ipairs({ "ollama", "fake" }) do
        reg.register({
          id = id,
          available = function()
            return true
          end,
          ask = function(req, cb)
            seen = req
            cb(true, { text = "ok", provider = id })
          end,
          stream = function()
            return nil
          end,
        })
      end
    end

    local function ask(req)
      req.prompt = req.prompt or "hi"
      require("ai").ask(req, function() end)
      return seen
    end

    it("fills the configured default into an ollama request", function()
      setup({})
      assert.are.equal(32768, ask({ provider = "ollama" }).num_ctx)
    end)

    it("takes the configured value", function()
      setup({ ollama = { num_ctx = 8192 } })
      assert.are.equal(8192, ask({ provider = "ollama" }).num_ctx)
    end)

    it("lets the request's own num_ctx win", function()
      setup({ ollama = { num_ctx = 8192 } })
      assert.are.equal(4096, ask({ provider = "ollama", num_ctx = 4096 }).num_ctx)
    end)

    it("sends none with num_ctx = false", function()
      setup({ ollama = { num_ctx = false } })
      assert.is_nil(ask({ provider = "ollama" }).num_ctx)
    end)

    it("does not add num_ctx to another provider's request", function()
      setup({ ollama = { num_ctx = 8192 } })
      assert.is_nil(ask({ provider = "fake" }).num_ctx)
    end)
  end)

  describe("config", function()
    it("knows the key: no unknown-key warning, no issue", function()
      local config = require("ai.config")
      local cfg = config.setup({ ollama = { num_ctx = 16384 } })
      assert.are.equal(16384, cfg.ollama.num_ctx)
      assert.are.same({}, config.issues())
      for _, m in ipairs(messages) do
        assert.is_nil(m:find("unknown config key", 1, true), m)
      end
    end)

    it("accepts false", function()
      local config = require("ai.config")
      assert.is_false(config.setup({ ollama = { num_ctx = false } }).ollama.num_ctx)
      assert.are.same({}, config.issues())
    end)

    for _, bad in ipairs({ 0, -1, 1.5, "32768", true, math.huge }) do
      it(("drops %s to the default and reports it"):format(vim.inspect(bad)), function()
        local config = require("ai.config")
        local cfg = config.setup({ ollama = { num_ctx = bad } })
        assert.are.equal(32768, cfg.ollama.num_ctx)
        local issues = table.concat(config.issues(), "\n")
        assert.is_truthy(issues:find("ollama.num_ctx", 1, true), issues)
      end)
    end
  end)

  describe("provider", function()
    local body, warned

    before_each(function()
      body, warned = nil, {}
      package.loaded["lib.nvim.net.curl"] = {
        fetch_json = function(_, opts, cb)
          body = vim.json.decode(opts.body)
          cb(true, { message = { content = "ok" }, done_reason = "stop" })
        end,
        fetch_stream = function(_, opts, handlers)
          body = vim.json.decode(opts.body)
          handlers.on_chunk('{"done":true,"done_reason":"stop"}')
          handlers.on_done({ code = 0, signal = 0, stdout = "", stderr = "" })
        end,
      }
      package.loaded["lib.nvim.notify"] = {
        create = function()
          return {
            warn = function(msg)
              warned[#warned + 1] = msg
            end,
          }
        end,
      }
    end)

    it("sends num_ctx as options.num_ctx, next to temperature", function()
      require("ai.providers.ollama").ask(
        { prompt = "hi", num_ctx = 8192, temperature = 0.2 },
        function() end
      )
      assert.are.same({ num_ctx = 8192, temperature = 0.2 }, body.options)
    end)

    it("sends no options at all when neither is set", function()
      require("ai.providers.ollama").ask({ prompt = "hi" }, function() end)
      assert.is_nil(body.options)
    end)

    it("stream sends num_ctx too", function()
      require("ai.providers.ollama").stream({ prompt = "hi", num_ctx = 8192 }, {})
      assert.are.equal(8192, body.options.num_ctx)
    end)

    it("warns when the prompt likely does not fit, and still sends it", function()
      -- 3.5 characters per token: 4000 characters are about 1143 tokens
      local ok
      require("ai.providers.ollama").ask(
        { prompt = string.rep("x", 4000), num_ctx = 1024 },
        function(a)
          ok = a
        end
      )
      assert.are.equal(1, #warned)
      assert.is_truthy(warned[1]:find("num_ctx (1024)", 1, true), warned[1])
      assert.is_true(ok)
      assert.are.equal(1024, body.options.num_ctx)
    end)

    it("counts the system prompt as well", function()
      require("ai.providers.ollama").ask(
        { prompt = "hi", system = string.rep("s", 4000), num_ctx = 1024 },
        function() end
      )
      assert.are.equal(1, #warned)
    end)

    it("warns in stream as well", function()
      require("ai.providers.ollama").stream({ prompt = string.rep("x", 4000), num_ctx = 1024 }, {})
      assert.are.equal(1, #warned)
    end)

    it("does not warn when the prompt fits", function()
      require("ai.providers.ollama").ask(
        { prompt = string.rep("x", 3000), num_ctx = 1024 },
        function() end
      )
      assert.are.same({}, warned)
    end)

    it("checks nothing without num_ctx", function()
      require("ai.providers.ollama").ask({ prompt = string.rep("x", 400000) }, function() end)
      assert.are.same({}, warned)
    end)
  end)
end)
