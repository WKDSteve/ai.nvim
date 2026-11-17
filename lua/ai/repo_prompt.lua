---@module 'ai.repo_prompt'
--- A project's own system prompt, read from a file in its repository (`.ai.md` at the project root by default,
--- gp.nvim's `.gp.md` idea) -- the system-prompt part only: no hooks, no commands registered from the file, no
--- placeholders (the text goes out as it stands, `{{...}}` included).
---
--- A file in a repository that instructs a model is prompt injection from every clone that carries one, so it is
--- never used on its own:
---   * only an agent with `repo_prompt = true` (`config.agents`) asks for it; no agent does by default;
---   * its content must be trusted first, per file and per content: `:Ai trust` shows the file, `:Ai trust allow`
---     records the SHA-256 of exactly what was shown (a file changed in between is refused, review it again).
---     The record lives in this plugin's own store (`stdpath("state")/ai.nvim/repo_prompt_trust.json`); a
---     changed file is untrusted again until it is reviewed;
---   * a missing, too large or untrusted file refuses the request with an error that names what to do, instead of
---     sending it without the prompt that was asked for.
--- The project root is the one of the current buffer's file (`.git`, `lib.nvim.fs.find_root`), else of the working
--- directory; the file name is relative to it and may not leave it.

local lib_error = require("lib.lua.error")

local M = {}

---@internal
---Content hashes shown by `show()` this session, per file: `allow()` trusts only what was shown.
---@type table<string, string>
local shown = {}

---@internal
---The file `show()` showed last this session: `:Ai trust allow` is typed in the review popup, whose scratch buffer
---belongs to no repository (it would fall back to the working directory, maybe another repository).
---@type string|nil
local last_shown = nil

---@internal
---Where the trust records live; a function so a spec can point it at a temp file.
---@return string
function M.store_path()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "ai.nvim", "repo_prompt_trust.json")
end

---@internal
---@return table<string, string> sha256 per absolute file path
local function read_store()
  local f = io.open(M.store_path(), "rb")
  if not f then
    return {}
  end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  -- an unreadable store trusts nothing (fail closed), it is not repaired here
  return ok and type(data) == "table" and data or {}
end

---@internal
---@param data table<string, string>
---@return boolean ok
---@return string|nil err
local function write_store(data)
  local path = M.store_path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f, err = io.open(path, "wb")
  if not f then
    return false, err
  end
  f:write(vim.json.encode(vim.tbl_isempty(data) and vim.empty_dict() or data))
  f:close()
  return true
end

---@internal
---The configured file name, checked: relative, inside the root.
---@return string|nil name
---@return LibErrorValue|nil err
local function file_name()
  local cfg = require("ai").config()
  local name = cfg.repo_prompt and cfg.repo_prompt.file or ".ai.md"
  local normalized = vim.fs.normalize(name)
  local bad = normalized == ""
    or normalized:match("^/")
    or normalized:match("^%a:")
    or normalized:match("^~")
    or vim.tbl_contains(vim.split(normalized, "/", { plain = true }), "..")
  if bad then
    return nil,
      lib_error.new(
        "repo_prompt_invalid_path",
        ("ai: repo_prompt.file = %q must be a path relative to the project root that stays inside it"):format(
          name
        ),
        { file = name }
      )
  end
  return normalized
end

---Where the repository's prompt file of `bufnr` is (it need not exist).
---@param bufnr? integer default: the current buffer
---@return string|nil path absolute, normalized
---@return LibErrorValue|nil err
function M.locate(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name, err = file_name()
  if not name then
    return nil, err
  end
  local start = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) or ""
  if start == "" or vim.bo[bufnr].buftype ~= "" then
    start = vim.fn.getcwd()
  end
  local root = require("lib.nvim.fs.find_root")({ markers = { ".git" } }).find(start)
  if not root then
    return nil,
      lib_error.new(
        "repo_prompt_no_root",
        ("ai: the agent asks for the repository's prompt file, but %s is in no repository (no .git above it)"):format(
          start
        ),
        { start = start }
      )
  end
  return vim.fs.normalize(vim.fs.joinpath(root, name))
end

---@internal
---The file `allow()`/`forget()` act on: from a buffer of a file, its repository; from any other buffer (the review
---popup of `:Ai trust`, a help or terminal buffer) the file shown last, when there is one.
---@param bufnr? integer
---@return string|nil path
---@return LibErrorValue|nil err
local function target(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file_buffer = vim.api.nvim_buf_is_valid(bufnr)
    and vim.bo[bufnr].buftype == ""
    and vim.api.nvim_buf_get_name(bufnr) ~= ""
  if not file_buffer and last_shown then
    return last_shown
  end
  return M.locate(bufnr)
end

---@internal
---Read the file, within the size cap.
---@param path string
---@return string|nil text
---@return LibErrorValue|nil err
local function read(path)
  local cfg = require("ai").config()
  local max = cfg.repo_prompt and cfg.repo_prompt.max_bytes or 16384
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil,
      lib_error.new(
        "repo_prompt_missing",
        ("ai: the agent asks for the repository's prompt file, and %s does not exist"):format(path),
        { path = path }
      )
  end
  local function too_large(size)
    return nil,
      lib_error.new(
        "repo_prompt_too_large",
        ("ai: %s has %d bytes, more than repo_prompt.max_bytes = %d -- it is not sent"):format(
          path,
          size,
          max
        ),
        { path = path, size = size, max = max }
      )
  end
  -- checked before reading (a huge file is never read) and after (it may have grown in between)
  if stat.size > max then
    return too_large(stat.size)
  end
  local f = io.open(path, "rb")
  if not f then
    return nil,
      lib_error.new("repo_prompt_missing", ("ai: %s cannot be read"):format(path), { path = path })
  end
  local text = f:read(max + 1) or ""
  f:close()
  if #text > max then
    return too_large(#text)
  end
  return text
end

---The trusted prompt text of the repository of `bufnr`, or why there is none.
---@param bufnr? integer default: the current buffer
---@return string|nil text
---@return LibErrorValue|nil err kinds: `repo_prompt_invalid_path`, `repo_prompt_no_root`, `repo_prompt_missing`, `repo_prompt_too_large`, `repo_prompt_untrusted`
function M.load(bufnr)
  local path, err = M.locate(bufnr)
  if not path then
    return nil, err
  end
  local text, rerr = read(path)
  if not text then
    return nil, rerr
  end
  local trusted = read_store()[path]
  if trusted ~= vim.fn.sha256(text) then
    return nil,
      lib_error.new(
        "repo_prompt_untrusted",
        ("ai: %s is %s -- review it with :Ai trust, then :Ai trust allow"):format(
          path,
          trusted and "changed since it was trusted" or "not trusted"
        ),
        { path = path }
      )
  end
  return text
end

---Read the repository's prompt file for review and remember what was shown, so that `allow()` trusts exactly
---that content. Does not trust anything itself.
---@param bufnr? integer
---@return { path: string, text: string, trusted: boolean }|nil info
---@return LibErrorValue|nil err
function M.show(bufnr)
  local path, err = M.locate(bufnr)
  if not path then
    return nil, err
  end
  local text, rerr = read(path)
  if not text then
    return nil, rerr
  end
  local hash = vim.fn.sha256(text)
  shown[path] = hash
  last_shown = path
  return { path = path, text = text, trusted = read_store()[path] == hash }
end

---Trust the content of the repository's prompt file that `show()` returned this session (from a buffer that is no
---file, such as the review popup itself: the file shown last). A file not shown, or
---changed since, is refused: what is trusted is always what was read.
---@param bufnr? integer
---@return string|nil path trusted
---@return LibErrorValue|nil err
function M.allow(bufnr)
  local path, err = target(bufnr)
  if not path then
    return nil, err
  end
  local text, rerr = read(path)
  if not text then
    return nil, rerr
  end
  local hash = vim.fn.sha256(text)
  if shown[path] == nil or shown[path] ~= hash then
    return nil,
      lib_error.new(
        "repo_prompt_unreviewed",
        ("ai: %s was %s -- review it with :Ai trust first"):format(
          path,
          shown[path] and "changed since :Ai trust showed it" or "not shown yet this session"
        ),
        { path = path }
      )
  end
  local data = read_store()
  data[path] = hash
  local ok, werr = write_store(data)
  if not ok then
    return nil,
      lib_error.new(
        "repo_prompt_store",
        ("ai: the trust record could not be written (%s): %s"):format(
          M.store_path(),
          tostring(werr)
        ),
        { path = path }
      )
  end
  return path
end

---Forget the trust record of the repository's prompt file (the next request with it is refused again).
---@param bufnr? integer
---@return string|nil path forgotten (also when it had no record)
---@return LibErrorValue|nil err
function M.forget(bufnr)
  local path, err = target(bufnr)
  if not path then
    return nil, err
  end
  shown[path] = nil
  local data = read_store()
  if data[path] ~= nil then
    data[path] = nil
    local ok, werr = write_store(data)
    if not ok then
      return nil,
        lib_error.new(
          "repo_prompt_store",
          ("ai: the trust record could not be written (%s): %s"):format(
            M.store_path(),
            tostring(werr)
          ),
          { path = path }
        )
    end
  end
  return path
end

---@internal
---For the specs: forget what `show()` remembered this session.
function M._reset()
  shown = {}
  last_shown = nil
end

return M
