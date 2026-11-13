local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"

local function incoming(text, sentAt, channel)
  return { kind = "user", direction = "in", text = text, sentAt = sentAt, channel = channel, playerName = text }
end

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  return ConversationPane.Create(factory, parent, nil, nil, {
    canReact = function()
      return true
    end,
    onMessageAction = function() end,
  })
end

local function linkedContact(charConversation)
  return {
    conversationKey = FRIEND,
    displayName = "Jaina#1234",
    channel = "BN",
    linkedMembers = { { key = CHAR, conversation = charConversation } },
  }
end

-- The friend's pane shows the linked characters' whispers; reacting and
-- replying to those lines would need the character's own route, so it is off.
return function()
  Localization.Configure({ language = "enUS" })

  -- test_pane_shows_both_threads_in_order
  do
    local pane = build()
    local friendLine, charLine = incoming("bn", 10, "BN"), incoming("char", 20, "WOW")
    ConversationPane.Refresh(pane, linkedContact({ messages = { charLine } }), { messages = { friendLine } })
    local shown = pane.transcript._allMessages
    assert(#shown == 2 and shown[1] == friendLine and shown[2] == charLine, "both lines in order")
  end

  -- test_labels_name_each_lines_route
  do
    local pane = build()
    ConversationPane.Refresh(pane, linkedContact({ messages = { incoming("char", 20, "WOW") } }), { messages = { incoming("bn", 10, "BN") } })
    assert(FindUI.text(pane.frame, "- via Battle.net") ~= nil, "the friend's line is tagged Battle.net")
    assert(FindUI.text(pane.frame, "- via Whisper") ~= nil, "the character's line is tagged Whisper")
  end

  -- test_member_lines_cannot_be_reacted_or_replied_to
  do
    local pane = build()
    local friendLine, charLine = incoming("bn", 10, "BN"), incoming("char", 20, "WOW")
    ConversationPane.Refresh(pane, linkedContact({ messages = { charLine } }), { messages = { friendLine } })
    assert(pane.transcript.canReact(charLine) == false, "no reaction on a character line")
    assert(pane.transcript.canReply(charLine) == false, "no reply on a character line")
    assert(pane.transcript.canReact(friendLine) == true, "reaction on the friend's line")
    assert(pane.transcript.canReply(friendLine) == true, "reply on the friend's line")
  end

  -- test_linking_while_open_rebuilds_the_transcript
  do
    local pane = build()
    local conversation = { messages = { incoming("bn", 10, "BN") } }
    ConversationPane.Refresh(pane, { conversationKey = FRIEND, displayName = "Jaina#1234", channel = "BN" }, conversation)
    local before = pane.transcript._virtualState
    ConversationPane.Refresh(pane, linkedContact({ messages = { incoming("char", 20, "WOW") } }), conversation)
    assert(before ~= nil and pane.transcript._virtualState ~= before, "labels are redrawn with their route tags")
  end

  -- test_refreshing_the_same_linked_thread_keeps_the_transcript
  do
    local pane = build()
    local contact = linkedContact({ messages = { incoming("char", 20, "WOW") } })
    local conversation = { messages = { incoming("bn", 10, "BN") } }
    ConversationPane.Refresh(pane, contact, conversation)
    local before = pane.transcript._virtualState
    ConversationPane.Refresh(pane, contact, conversation)
    assert(pane.transcript._virtualState == before, "no rebuild without a change")
  end
end
