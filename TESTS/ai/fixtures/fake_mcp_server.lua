-- A fake MCP server for TESTS/ai/context_mcp_spec.lua: JSON-RPC 2.0, one JSON message per line on stdin/stdout.
-- Run: nvim --headless -u NONE -l TESTS/ai/fixtures/fake_mcp_server.lua
-- Tools: `echo` (text + structured), `report` (structured only), `boom` (isError), `big` (a very long text).

local function out(msg)
  io.stdout:write(vim.json.encode(msg) .. "\n")
  io.stdout:flush()
end

for line in io.stdin:lines() do
  local ok, msg = pcall(vim.json.decode, line)
  if ok and type(msg) == "table" then
    if msg.method == "initialize" then
      out({
        jsonrpc = "2.0",
        id = msg.id,
        result = {
          protocolVersion = msg.params.protocolVersion,
          capabilities = { tools = vim.empty_dict() },
          serverInfo = { name = "fake", version = "0" },
        },
      })
    elseif msg.method == "tools/call" then
      local name = msg.params.name
      local result
      if name == "echo" then
        result = {
          content = { { type = "text", text = "echo:" .. vim.json.encode(msg.params.arguments) } },
          isError = false,
        }
      elseif name == "report" then
        result = { content = {}, structuredContent = { failed = 2 }, isError = false }
      elseif name == "boom" then
        result = { content = { { type = "text", text = "it broke" } }, isError = true }
      elseif name == "big" then
        result = { content = { { type = "text", text = string.rep("x", 30000) } }, isError = false }
      end
      if result then
        out({ jsonrpc = "2.0", id = msg.id, result = result })
      else
        out({ jsonrpc = "2.0", id = msg.id, error = { code = -32602, message = "unknown tool" } })
      end
    end
  end
end
