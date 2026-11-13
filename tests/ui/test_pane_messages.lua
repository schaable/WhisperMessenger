local PaneMessages = require("WhisperMessenger.UI.ConversationPane.PaneMessages")

local CHAR = "wow::WOW::jainachar"

local function incoming(text, sentAt)
  return { kind = "user", direction = "in", text = text, sentAt = sentAt }
end

local function newView()
  return { transcript = {} }
end

-- The lines the conversation pane shows: the open conversation's own lines
-- and, for a Battle.net friend with linked characters, theirs in one timeline.
return function()
  -- test_unlinked_conversation_shows_its_own_lines
  do
    local view = newView()
    local conversation = { messages = { incoming("bn", 1) } }
    local messages = PaneMessages.Build(view, { conversationKey = "bnet::BN::jaina#1234", channel = "BN" }, conversation)
    assert(messages == conversation.messages, "the stored list itself")
    assert(view.transcript.linkedThread == false, "not a linked thread")
  end

  -- test_linked_conversation_shows_every_line_in_order
  do
    local view = newView()
    local charConversation = { messages = { incoming("char", 2) } }
    local contact = { channel = "BN", linkedMembers = { { key = CHAR, conversation = charConversation } } }
    local messages = PaneMessages.Build(view, contact, { messages = { incoming("bn1", 1), incoming("bn2", 3) } })
    assert(#messages == 3 and messages[1].text == "bn1" and messages[2].text == "char" and messages[3].text == "bn2", "merged in order")
    assert(view.transcript.linkedThread == true, "a linked thread")
  end

  -- test_is_member_line_spots_the_linked_characters_lines
  do
    local view = newView()
    local friendLine, charLine = incoming("bn", 1), incoming("char", 2)
    local contact = { channel = "BN", linkedMembers = { { key = CHAR, conversation = { messages = { charLine } } } } }
    PaneMessages.Build(view, contact, { messages = { friendLine } })
    assert(PaneMessages.IsMemberLine(view, charLine) == true, "character line")
    assert(PaneMessages.IsMemberLine(view, friendLine) == false, "the friend's own line")
  end

  -- test_is_member_line_false_once_unlinked
  do
    local view = newView()
    local charLine = incoming("char", 2)
    local linked = { channel = "BN", linkedMembers = { { key = CHAR, conversation = { messages = { charLine } } } } }
    PaneMessages.Build(view, linked, { messages = {} })
    PaneMessages.Build(view, { channel = "WOW" }, { messages = { charLine } })
    assert(PaneMessages.IsMemberLine(view, charLine) == false, "the character's own thread")
  end

  -- test_is_linked_needs_linked_members
  do
    assert(PaneMessages.IsLinked({ linkedMembers = { { key = CHAR } } }) == true, "with members")
    assert(PaneMessages.IsLinked({ linkedMembers = {} }) == false, "empty members")
    assert(PaneMessages.IsLinked({}) == false, "no members")
    assert(PaneMessages.IsLinked(nil) == false, "no contact")
  end
end
