---@module 'ai.context.mcp'
--- A read-only MCP tool call as one section of the request's context.
---
--- The **caller** names the server, the tool and its arguments (`context.mcp = { server, tool, args }`); ai.nvim makes
--- that one call before the request and puts the result into the prompt as text. The model never sees a tool and
--- cannot ask for one: this is part of building the context, not an agent loop (docs/scope.md). A poisoned log can
--- bend the answer; it cannot trigger an action.
---
--- `server` is the id of a client the caller created with `lib.nvim.mcp` (`mcp.client({ id = ..., cmd | url })`);
--- `client` may be given instead, any table with the client's `call_tool`. `context.mcp_allowed` is a list of
--- `"<server>/<tool>"` entries: empty (the default) means no restriction, non-empty means only those calls. A malformed
--- list refuses every call (see `ai.config`'s fail-closed values). The call is awaited (bounded by `timeout_ms`), and
--- every failure is an entry in `errors`, never a raised error: a context section that cannot be built must not take
--- the request down with it.

local M = {}

M.DEFAULT_TIMEOUT_MS = 15000
---The longest result text put into the prompt; more is cut and says so.
M.MAX_CHARS = 20000

---@class Ai.ContextMcp
---@field server? string id of a `lib.nvim.mcp` client created by the caller
---@field client? table instead of `server`: a client (`call_tool(name, args, cb, opts)`)
---@field tool string the tool to call (read-only by the caller's choice and by `context.mcp_allowed`)
---@field args? table the tool's arguments
---@field timeout_ms? integer default 15000

---Why a call may not be made, or nil.
---@param label string `"<server>/<tool>"`
---@return string|nil
local function refused(label)
  local ok, config = pcall(require, "ai.config")
  local cfg = ok and config.get() or nil
  local list = cfg and cfg.context and cfg.context.mcp_allowed
  if list == nil or (type(list) == "table" and #list == 0 and next(list) == nil) then
    return nil
  end
  if type(list) ~= "table" or not vim.islist(list) then
    return 'context.mcp_allowed is not a list of "<server>/<tool>" entries'
  end
  if not vim.tbl_contains(list, label) then
    return ("%s is not on context.mcp_allowed"):format(label)
  end
  return nil
end

---The text of a tool result: its text content, else the structured content as JSON.
---@param res table
---@return string
local function text_of(res)
  local parts = {}
  for _, item in ipairs(res.content or {}) do
    if type(item) == "table" and item.type == "text" and type(item.text) == "string" then
      parts[#parts + 1] = item.text
    end
  end
  if #parts == 0 and res.structuredContent ~= nil then
    local ok, encoded = pcall(vim.json.encode, res.structuredContent)
    if ok then
      parts[1] = encoded
    end
  end
  return table.concat(parts, "\n")
end

---Make the call and append its result as a section. Failures go to `errors`.
---@param spec Ai.ContextMcp|nil
---@param sections string[]
---@param errors string[]
function M.add(spec, sections, errors)
  if type(spec) ~= "table" then
    return
  end
  if type(spec.tool) ~= "string" or spec.tool == "" then
    errors[#errors + 1] = "context.mcp needs a tool name"
    return
  end
  if spec.args ~= nil and type(spec.args) ~= "table" then
    errors[#errors + 1] = "context.mcp.args must be a table"
    return
  end
  local server = type(spec.server) == "string" and spec.server or nil
  local label = ("%s/%s"):format(server or "?", spec.tool)
  local why = refused(label)
  if why then
    errors[#errors + 1] = "mcp context refused: " .. why
    return
  end

  local client = spec.client
  if not client and server then
    local ok, mcp = pcall(require, "lib.nvim.mcp")
    client = ok and mcp.get(server) or nil
    if not client then
      errors[#errors + 1] = ("mcp server %q is not registered (create it with lib.nvim.mcp first)"):format(
        server
      )
      return
    end
  end
  if type(client) ~= "table" or type(client.call_tool) ~= "function" then
    errors[#errors + 1] = "context.mcp needs a server id or a client"
    return
  end

  local timeout = spec.timeout_ms or M.DEFAULT_TIMEOUT_MS
  local done, result, call_err = false, nil, nil
  local started, call_error = pcall(client.call_tool, client, spec.tool, spec.args, function(res, e)
    done, result, call_err = true, res, e
  end, { timeout_ms = timeout })
  if not started then
    errors[#errors + 1] = ("mcp call %s failed: %s"):format(label, tostring(call_error))
    return
  end
  vim.wait(timeout + 1000, function()
    return done
  end, 10)

  if not done then
    errors[#errors + 1] = ("mcp call %s did not answer in %d ms"):format(label, timeout)
  elseif call_err then
    errors[#errors + 1] = ("mcp call %s failed: %s"):format(
      label,
      tostring(call_err.message or call_err.code)
    )
  elseif type(result) ~= "table" then
    errors[#errors + 1] = ("mcp call %s returned nothing"):format(label)
  elseif result.isError then
    errors[#errors + 1] = ("mcp tool %s reported an error: %s"):format(
      label,
      text_of(result):sub(1, 200)
    )
  else
    local text = text_of(result)
    if text ~= "" then
      if #text > M.MAX_CHARS then
        text = text:sub(1, M.MAX_CHARS) .. "\n[truncated]"
      end
      sections[#sections + 1] = ("Result of the tool %s (called by the editor, not by you):\n```\n%s\n```"):format(
        label,
        text
      )
    end
  end
end

return M
