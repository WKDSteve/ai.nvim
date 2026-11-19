-- TESTS/sheets/fixtures/print_key.lua -- the key command of TESTS/sheets/ai-key-command.sheet.lua, run as
-- `nvim -u NONE -l print_key.lua`: prints a key the way `pass show anthropic` would (a blank line first, which
-- ai.keys skips, then the key). Not a real key: the request it goes into is answered by a stub.
io.stdout:write("\n", "sk-ant-sheet-not-a-real-key", "\n")
io.stdout:flush()
os.exit(0)
