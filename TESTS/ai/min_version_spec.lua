-- The minimum Neovim version is promised in four places and exercised in one:
-- the extra leg of .github/workflows/ci.yml. A promise no job runs drifts
-- silently, so this spec fails when the floor moves in only some of them.
---@diagnostic disable: need-check-nil

package.path = vim.fn.getcwd() .. "/TESTS/?.lua;" .. package.path
local S = require("docs_support")

---@param rel string path relative to the repository root
---@return string
local function read(rel)
  local f = assert(io.open(S.ROOT .. "/" .. rel, "rb"), "missing file: " .. rel)
  local text = f:read("*a")
  f:close()
  return text
end

describe("minimum Neovim version", function()
  it("is run by a CI leg and promised with the same minor version everywhere", function()
    local minor = read(".github/workflows/ci.yml"):match("nvim:%s*v0%.(%d+)%.%d+")
    -- The plain call raises: the lines below cannot run without a version.
    assert(minor, "ci.yml has no leg pinned to the minimum version")

    local floor = "0." .. minor
    local escaped = vim.pesc(floor)
    assert.is_truthy(read("README.md"):find("Neovim%-" .. escaped .. "%%2B"), "README.md badge")
    assert.is_truthy(
      read("docs/requirements.md"):find("Neovim >= " .. escaped),
      "docs/requirements.md"
    )
    assert.is_truthy(read("doc/ai.txt"):find("Neovim >= " .. escaped), "doc/ai.txt")
    assert.is_truthy(
      read("lua/ai/health.lua"):find("version_ok({ 0, " .. minor .. ", 0 })", 1, true),
      "lua/ai/health.lua"
    )
  end)
end)
