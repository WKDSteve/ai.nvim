-- TESTS/sheets/ai-claude-api-key-setup.sheet.lua -- a manual sheet (testing.nvim, docs/SHEETS.md "ask"): what only a
-- person can do before the live sheets of the Claude API can run. A key of the Console organization that receives the
-- monthly API credit of the subscription, set for ai.nvim and for ai-desktop, the spend checked in the Console. No
-- machine can sign in to the Console or decide where the key is kept.
--   testing sheets step ai.claude-api-key-setup
return {
  id = "ai.claude-api-key-setup",
  title = "By hand: a Console API key of the org with the API credit, set for ai.nvim and ai-desktop",
  task = "ai.nvim/abnahme-claude-api-funktionen-mit-dem-api-guthaben",
  engine = "manual",
  steps = {
    {
      ask = "platform.claude.com, organization switcher at the top left on the org named under Settings > Billing >"
        .. " API credit: Settings > API keys > Create key (workspace Default, a name such as ai-nvim-stevespc), key copied"
        .. " once and kept in the password manager?",
    },
    {
      ask = "Same org, Settings > Limits (spend limit) and Billing (auto reload): what happens once the monthly credit"
        .. " is used up is known and wanted (stop, or reload on the card)?",
    },
    {
      ask = "ANTHROPIC_API_KEY set for the user (setx, or a key profile in ai.nvim's keys.claude), editor restarted:"
        .. " :Ai key and :checkhealth ai say key present for claude, never the key itself?",
    },
    {
      ask = "ai-desktop holds a key: either ANTHROPIC_API_KEY in the environment it starts with, or stored with"
        .. " PUT /keys/ANTHROPIC_API_KEY (Bearer control.secret); GET /health lists anthropic as configured?",
    },
    {
      ask = "After the live sheets ai.live-claude*, ai.completion-thinking-tokens and ai.live-ai-desktop-claude: the"
        .. " Console (Usage / Cost of that org) shows their requests, and the credit went down by a few cents only?",
    },
  },
}
