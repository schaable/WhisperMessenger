rawset(_G, "time", rawget(_G, "time") or os.time)
rawset(_G, "date", rawget(_G, "date") or os.date)

local ExportMenuEntry = require("WhisperMessenger.UI.ContactsList.ExportMenuEntry")
local ExportPanel = require("WhisperMessenger.UI.ContactsList.ExportPanel")
local Localization = require("WhisperMessenger.Locale.Localization")

local T1 = 1700000000

local function line(text, sentAt, playerName)
  return { direction = "in", kind = "user", text = text, sentAt = sentAt, playerName = playerName }
end

-- Exporting a friend's row exports the thread it shows: the friend's lines
-- and their linked characters' lines, in order, each under its own sender.
return function()
  Localization.Configure({ language = "enUS" })
  local savedShow = ExportPanel.Show
  local shown
  rawset(ExportPanel, "Show", function(content)
    shown = content
    return true
  end)

  local item = {
    channel = "BN",
    displayName = "Jaina",
    conversation = { messages = { line("first over bnet", T1, "Jaina#1234"), line("third over bnet", T1 + 120, "Jaina#1234") } },
    linkedMembers = { { key = "wow::WOW::jainachar", conversation = { messages = { line("second from a mage", T1 + 60, "Jainachar") } } } },
  }

  -- test_export_holds_the_whole_thread_in_order
  ExportMenuEntry.Open(item)
  rawset(ExportPanel, "Show", savedShow)
  assert(shown ~= nil and #shown.lines == 3, "three lines, got " .. tostring(shown and #shown.lines))
  assert(string.find(shown.lines[1], "Jaina#1234: first over bnet", 1, true), "friend's line first: " .. shown.lines[1])
  assert(string.find(shown.lines[2], "Jainachar: second from a mage", 1, true), "character's line second: " .. shown.lines[2])
  assert(string.find(shown.lines[3], "Jaina#1234: third over bnet", 1, true), "friend's newer line last: " .. shown.lines[3])
end
