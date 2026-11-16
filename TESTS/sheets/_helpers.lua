-- TESTS/sheets/_helpers.lua -- what the ai.nvim test sheets need in their child editor. Not a sheet
-- (`testing.sheet` only reads *.sheet.lua); a sheet's `requires` and its first step run it with `dofile`, the
-- child's cwd is the project root. TESTS/ai/sheets_spec.lua names this directory in its @cache-inputs, so a change
-- here re-runs the sheets.
--
-- No sheet here reaches a real AI provider: `_G.use_fake()` registers a provider "sheet" that answers from a
-- script, records every request in `_G.requests` and answers asynchronously (vim.schedule / a timer) like a real
-- one, so the `wait` steps of a sheet are honest. The live sheets (`live = { ... }`) are the exception: they set up
-- nothing of this and talk to the real API, and only under `testing sheets run --live`.

-- luacheck: globals vim

local M = {}

---Put ui.nvim (ui.kit: the prompt popup, the viewer, the stream panel, the badge) on the runtimepath. For
---`requires`: false when it is not to be found ($UI_NVIM_DIR, .deps/ui.nvim, ../ui.nvim, the lazy.nvim
---directory of the real editor), which makes the sheet a reported skip. TESTS/minimal_init.lua deliberately
---leaves it out (TESTS/README.md); only the sheets that press the quick-action keys need it.
---@return boolean
function M.add_ui()
  if pcall(require, "ui.kit") then
    return true
  end
  local root = vim.fn.getcwd()
  local candidates = {
    vim.env.UI_NVIM_DIR or "", -- never nil: ipairs would stop at the hole
    root .. "/.deps/ui.nvim",
    vim.fs.dirname(root) .. "/ui.nvim",
    vim.fs.normalize(vim.fn.stdpath("data")) .. "/lazy/ui.nvim",
  }
  for _, dir in ipairs(candidates) do
    if dir and dir ~= "" and vim.fn.isdirectory(dir .. "/lua/ui/kit") == 1 then
      vim.opt.rtp:append(dir)
      return pcall(require, "ui.kit")
    end
  end
  return false
end

vim.o.swapfile = false
vim.opt.shortmess:append("I")

-- Every notification is kept instead of shown: a long one would become a hit-enter prompt.
_G.notes = {}
vim.notify = function(msg)
  _G.notes[#_G.notes + 1] = tostring(msg)
end

---Whether a notification so far contains `text` (plain).
---@param text string
---@return boolean
function _G.noted(text)
  for _, n in ipairs(_G.notes) do
    if n:find(text, 1, true) then
      return true
    end
  end
  return false
end

---`got == want`, or an error that says what came instead (the failure line of the sheet shows it).
---@param got any
---@param want any
---@return boolean
function _G.eq(got, want)
  if not vim.deep_equal(got, want) then
    error(("got %s, wanted %s"):format(vim.inspect(got), vim.inspect(want)), 0)
  end
  return true
end

---The screen as text, one row per line.
---@return string
function _G.screen_text()
  vim.cmd("redraw")
  local rows = {}
  for row = 1, vim.o.lines do
    local cells = {}
    for col = 1, vim.o.columns do
      cells[#cells + 1] = vim.fn.screenstring(row, col)
    end
    rows[#rows + 1] = table.concat(cells)
  end
  return table.concat(rows, "\n")
end

---Whether the screen shows `text` (plain, within one row).
---@param text string
---@return boolean
function _G.on_screen(text)
  return _G.screen_text():find(text, 1, true) ~= nil
end

---The text of the first line of the current buffer.
---@return string
function _G.line()
  return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
end

---Every request the fake provider got, in order: `{ kind = "ask"|"stream", prompt, system }`.
_G.requests = {}

---Register the fake provider "sheet" (it replaces nothing built in) and make it the one every request resolves
---to. `answer` is the text of an ask and, split at its spaces, the chunks of a stream; `delay_ms` how long it
---"thinks" first (default 50).
---@param answer string
---@param delay_ms? integer
function _G.use_fake(answer, delay_ms)
  delay_ms = delay_ms or 50
  require("ai.providers").register({
    id = "sheet",
    name = "Sheet stand-in",
    available = function()
      return true
    end,
    capabilities = { streaming = true },
    ask = function(req, cb)
      _G.requests[#_G.requests + 1] = { kind = "ask", prompt = req.prompt, system = req.system }
      vim.defer_fn(function()
        cb(true, { text = _G.answer or answer, stop_reason = "end_turn", provider = "sheet" })
      end, delay_ms)
    end,
    stream = function(req, handlers)
      _G.requests[#_G.requests + 1] = { kind = "stream", prompt = req.prompt, system = req.system }
      local chunks = vim.split(_G.answer or answer, " ", { plain = true })
      local i = 0
      local timer = assert(vim.uv.new_timer())
      local stopped = false
      timer:start(
        delay_ms,
        delay_ms,
        vim.schedule_wrap(function()
          if stopped then
            return
          end
          i = i + 1
          if i <= #chunks then
            handlers.on_chunk((i > 1 and " " or "") .. chunks[i])
            return
          end
          stopped = true
          timer:stop()
          timer:close()
          handlers.on_done({
            text = _G.answer or answer,
            stop_reason = "end_turn",
            provider = "sheet",
          })
        end)
      )
      -- what the panel keeps to cancel a stream (`:kill()`), as of a vim.SystemObj
      return {
        kill = function()
          if not stopped then
            stopped = true
            timer:stop()
            timer:close()
          end
        end,
      }
    end,
  })
end

---The last request the fake provider got, or an error naming that there was none.
---@return { kind: string, prompt: string, system: string|nil }
function _G.last_request()
  return _G.requests[#_G.requests] or error("the fake provider got no request", 0)
end

---Whether a window of the current tab is a float.
---@return boolean
function _G.float_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return true
    end
  end
  return false
end

---The extmark ghost text of the completion (row 0-based), as one string; "" when none is shown.
---@return string
function _G.ghost_text()
  local ns = vim.api.nvim_get_namespaces()["ai_completion_ghost"]
  if not ns then
    return ""
  end
  local parts = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    for _, chunk in ipairs(m[4].virt_text or {}) do
      parts[#parts + 1] = chunk[1]
    end
    for _, vl in ipairs(m[4].virt_lines or {}) do
      local row = {}
      for _, chunk in ipairs(vl) do
        row[#row + 1] = chunk[1]
      end
      parts[#parts + 1] = "\n" .. table.concat(row)
    end
  end
  return table.concat(parts)
end

return M
