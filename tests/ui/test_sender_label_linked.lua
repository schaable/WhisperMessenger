local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")
local Localization = require("WhisperMessenger.Locale.Localization")

local LINKED = { linkedThread = true }

local function findChildWithText(frame, text)
  for _, child in ipairs(frame.children) do
    if child.text == text then
      return child
    end
  end
  return nil
end

local function line(direction, channel, senderName)
  return { direction = direction, kind = "user", text = "hi", sentAt = 1000, playerName = "Jaina", channel = channel, senderName = senderName }
end

-- In a linked thread every label says which route its line took, so Battle.net
-- and character whispers stay apart in the one timeline.
return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  -- test_incoming_linked_line_tags_its_route_after_the_name
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, line("in", "BN"), 400, 0, LINKED)
    local nameFS = findChildWithText(result.frame, "Jaina")
    local tagFS = findChildWithText(result.frame, "- via Battle.net")
    assert(tagFS ~= nil and tagFS.shown ~= false, "route tag shown")
    assert(tagFS.point[1] == "LEFT" and tagFS.point[2] == nameFS and tagFS.point[3] == "RIGHT", "tag right of the name")
  end

  -- test_outgoing_linked_line_tags_its_route_after_you
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, line("out", "WOW"), 400, 0, LINKED)
    local youFS = findChildWithText(result.frame, "You")
    local tagFS = findChildWithText(result.frame, "- via Whisper")
    assert(tagFS ~= nil and tagFS.shown ~= false, "route tag shown")
    assert(tagFS.point[1] == "RIGHT" and tagFS.point[2] == result.frame, "tag at the right edge")
    assert(tagFS.point[4] == -Layout.MESSAGE_EDGE_INSET, "tag keeps the edge inset")
    assert(youFS, "You label")
    assert(youFS.point[1] == "RIGHT" and youFS.point[2] == tagFS and youFS.point[3] == "LEFT", "You left of the tag")
  end

  -- test_outgoing_linked_line_from_an_alt_keeps_the_alt_name_last
  do
    local previousUnitName = rawget(_G, "UnitName")
    rawset(_G, "UnitName", function()
      return "Arthas"
    end)
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, line("out", "BN", "Uther"), 400, 0, LINKED)
    rawset(_G, "UnitName", previousUnitName)
    local altFS = findChildWithText(result.frame, "- Uther")
    local tagFS = findChildWithText(result.frame, "- via Battle.net")
    assert(altFS ~= nil and tagFS ~= nil, "both tags shown")
    assert(tagFS.point[1] == "RIGHT" and tagFS.point[2] == altFS and tagFS.point[3] == "LEFT", "route tag left of the alt name")
  end

  -- test_outgoing_line_outside_a_linked_thread_has_no_tag
  do
    local result = SenderLabel.CreateSenderLabel(factory, contentFrame, line("out", "BN"), 400, 0, nil)
    assert(findChildWithText(result.frame, "- via Battle.net") == nil, "no route tag")
  end
end
