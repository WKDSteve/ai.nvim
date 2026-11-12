-- TESTS/ai/context_mcp_spec.lua -- the MCP context source: the caller names one read-only tool call, ai.nvim makes
-- it before the request and adds the result as text; the allow-list only narrows; every failure is an `errors` entry.

local mcp = require("lib.nvim.mcp")
local context = require("ai.context")

local fake = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h"))
  .. "/fixtures/fake_mcp_server.lua"

---@param id string
---@return table client
local function client(id)
  return mcp.client({
    id = id,
    cmd = { vim.v.progpath, "--headless", "-u", "NONE", "-l", fake },
    timeout_ms = 5000,
  })
end

describe("ai.context mcp", function()
  local made = {}
  local function new(id)
    made[#made + 1] = id
    return client(id)
  end

  after_each(function()
    for _, id in ipairs(made) do
      pcall(mcp.forget, id)
    end
    made = {}
    -- lib.nvim.mcp registers one VimLeavePre group the first time a client exists: drop it so the state guard sees
    -- nothing left behind (the module stays loaded, so the registry is the one the spec's clients live in)
    pcall(vim.api.nvim_del_augroup_by_name, "lib.nvim.mcp")
    package.loaded["ai.config"] = nil
  end)

  before_each(function()
    package.loaded["ai.config"] = nil
    require("ai.config").setup({})
  end)

  it("calls the tool the caller names and adds its text as a section", function()
    new("ctx1")

    local block, errors =
      context.assemble({ mcp = { server = "ctx1", tool = "echo", args = { run = "42" } } })

    assert.is_nil(errors)
    assert.truthy(block:find("Result of the tool ctx1/echo", 1, true))
    assert.truthy(block:find('echo:{"run":"42"}', 1, true))
    assert.truthy(block:find("called by the editor, not by you", 1, true))
  end)

  it("uses the structured content when the tool sends no text", function()
    new("ctx2")

    local block = context.assemble({ mcp = { server = "ctx2", tool = "report" } })

    assert.truthy(block:find('{"failed":2}', 1, true))
  end)

  it("cuts a long result and says so", function()
    new("ctx3")

    local block = context.assemble({ mcp = { server = "ctx3", tool = "big" } })

    assert.truthy(block:find("[truncated]", 1, true))
    assert.is_true(#block < 21000)
  end)

  it(
    "reports a tool that failed, an unknown tool and an unregistered server as errors, never as a raise",
    function()
      new("ctx4")

      local _, boom = context.assemble({ mcp = { server = "ctx4", tool = "boom" } })
      local _, unknown = context.assemble({ mcp = { server = "ctx4", tool = "nope" } })
      local block, missing = context.assemble({ mcp = { server = "nobody", tool = "echo" } })

      assert.truthy(boom[1]:find("reported an error: it broke", 1, true))
      assert.truthy(unknown[1]:find("unknown tool", 1, true))
      assert.truthy(missing[1]:find("is not registered", 1, true))
      assert.are.equal("", block)
    end
  )

  it(
    "refuses a call that is not on a non-empty context.mcp_allowed, and allows one that is",
    function()
      new("ctx5")
      require("ai.config").setup({ context = { mcp_allowed = { "ctx5/echo" } } })

      local refused_block, refused =
        context.assemble({ mcp = { server = "ctx5", tool = "report" } })
      local allowed_block, allowed = context.assemble({ mcp = { server = "ctx5", tool = "echo" } })

      assert.truthy(refused[1]:find("is not on context.mcp_allowed", 1, true))
      assert.are.equal("", refused_block)
      assert.is_nil(allowed)
      assert.truthy(allowed_block:find("ctx5/echo", 1, true))
    end
  )

  it("fails closed on a malformed context.mcp_allowed", function()
    new("ctx6")
    require("ai.config").setup({ context = { mcp_allowed = "ctx6/echo" } })

    local block, errors = context.assemble({ mcp = { server = "ctx6", tool = "echo" } })

    assert.are.equal("", block)
    assert.truthy(errors[1]:find("is not on context.mcp_allowed", 1, true))
  end)

  it("needs a tool name and well-formed arguments", function()
    new("ctx7")

    local _, no_tool = context.assemble({ mcp = { server = "ctx7" } })
    local _, bad_args = context.assemble({ mcp = { server = "ctx7", tool = "echo", args = "x" } })

    assert.truthy(no_tool[1]:find("needs a tool name", 1, true))
    assert.truthy(bad_args[1]:find("args must be a table", 1, true))
  end)

  it("adds nothing when mcp is off", function()
    local block, errors = context.assemble({ mcp = false })

    assert.are.equal("", block)
    assert.is_nil(errors)
  end)
end)
