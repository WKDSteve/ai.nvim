-- ai.bindings.actions.stream_prompt: the context of a streamed request (the selection marks, the diagnostics,
-- both read from the current buffer by `ai.context.assemble`) belongs to the window the action was started from.
-- The stream panel takes the focus when it opens, so `ai.stream` must still run with the source window current;
-- read in the panel's buffer, <leader>as sent no context at all (found by TESTS/sheets/ai-quick-keys.sheet.lua).
--
-- `ai`, `ui.kit` (its surface opens and focuses a real float, as the real one does) and `lib.nvim.progress` are
-- stubbed; `ai.ui.panel` and the actions are real.
---@diagnostic disable: need-check-nil
describe("ai.bindings.actions stream_prompt", function()
  ---@type table<string, { value: any }>  # boxed, so a module that was not loaded (nil) is restored too
  local saved = {}
  local source_buf, panel_buf
  ---@type { buf: integer, win: integer, req: table }|nil
  local seen

  local function stub(name, value)
    if saved[name] == nil then
      saved[name] = { value = package.loaded[name] }
    end
    package.loaded[name] = value
  end

  before_each(function()
    seen = nil
    stub("ai", {
      config = function()
        return { ui = {} }
      end,
      stream = function(req)
        seen =
          { buf = vim.api.nvim_get_current_buf(), win = vim.api.nvim_get_current_win(), req = req }
        return nil
      end,
    })
    stub("ui.kit", {
      surface = {
        open = function()
          panel_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_open_win(
            panel_buf,
            true,
            { relative = "editor", row = 1, col = 1, width = 20, height = 5 }
          )
          return {
            set_lines = function() end,
            set_last_line = function() end,
            append_lines = function() end,
            on_close = function() end,
          }
        end,
      },
    })
    stub("lib.nvim.progress", {
      create = function()
        return { update = function() end, on_cancel = function() end, finish = function() end }
      end,
    })
    package.loaded["ai.bindings.actions"] = nil
    package.loaded["ai.ui.panel"] = nil
    source_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(source_buf)
  end)

  after_each(function()
    for name, entry in pairs(saved) do
      package.loaded[name] = entry.value
    end
    saved = {}
    package.loaded["ai.bindings.actions"] = nil
    package.loaded["ai.ui.panel"] = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        vim.api.nvim_win_close(win, true)
      end
    end
    for _, buf in ipairs({ source_buf, panel_buf }) do
      if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end)

  it(
    "starts the stream with the source window current, not the panel that took the focus",
    function()
      local source_win = vim.api.nvim_get_current_win()
      require("ai.bindings.actions").stream_prompt("fix it", { diagnostics = true })
      assert.is_not_nil(seen)
      assert.are.equal(source_buf, seen.buf)
      assert.are.equal(source_win, seen.win)
      assert.are.same({ diagnostics = true }, seen.req.context)
      -- the panel keeps the focus afterwards: the answer is read there
      assert.are.equal(panel_buf, vim.api.nvim_get_current_buf())
    end
  )

  it("starts the stream without a context as well", function()
    require("ai.bindings.actions").stream_prompt("fix it", nil)
    assert.is_not_nil(seen)
    assert.are.equal("fix it", seen.req.prompt)
    assert.are.equal(source_buf, seen.buf)
  end)
end)
