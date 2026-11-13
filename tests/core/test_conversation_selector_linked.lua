local ConversationSelector = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")
local Store = require("WhisperMessenger.Model.ConversationStore")
local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"

local function incoming(text, sentAt)
  return { kind = "user", direction = "in", text = text, sentAt = sentAt }
end

local function build()
  local accountState = {}
  ConversationLinks.Ensure(accountState)
  local characterState = {}
  local runtime = { store = Store.New({}), accountState = accountState }
  local selector = ConversationSelector.Create({
    runtime = runtime,
    characterState = characterState,
    markConversationRead = Store.MarkRead,
    presenceCache = { RefreshPresence = function() end },
    requestAvailability = function() end,
  })
  return selector, runtime, characterState
end

local function addConversation(runtime, key, messages, unreadCount)
  local conversation = Store.EnsureConversation(runtime.store, key)
  conversation.messages = messages
  conversation.unreadCount = unreadCount
  return conversation
end

local function linkedThread(friendMessages, friendUnread, charMessages, charUnread)
  local selector, runtime, characterState = build()
  addConversation(runtime, FRIEND, friendMessages, friendUnread)
  addConversation(runtime, CHAR, charMessages, charUnread)
  ConversationLinks.Link(runtime.accountState.conversationLinks, CHAR, FRIEND, "manual", 1)
  return selector, runtime, characterState
end

-- Every opener (row click, reply-to-last, preview click, auto-open) goes
-- through selectConversation, so a linked character always opens its friend.
return function()
  -- test_opening_a_linked_character_opens_the_friend_thread
  do
    local selector, runtime, characterState = linkedThread({ incoming("bn", 1) }, 0, { incoming("char", 2) }, 1)
    selector.selectConversation(CHAR)
    assert(runtime.activeConversationKey == FRIEND, "the friend's thread is open")
    assert(characterState.activeConversationKey == FRIEND, "and is remembered for this character")
  end

  -- test_opening_the_friend_marks_linked_characters_read
  do
    local selector, runtime = linkedThread({ incoming("bn", 1) }, 1, { incoming("char", 2) }, 1)
    selector.selectConversation(FRIEND)
    assert(runtime.store.conversations[FRIEND].unreadCount == 0, "friend thread read")
    assert(runtime.store.conversations[CHAR].unreadCount == 0, "linked character thread read too")
  end

  -- test_divider_sits_before_the_oldest_unread_line_of_the_whole_thread
  do
    local charLine = incoming("char new", 20)
    local selector, runtime = linkedThread({ incoming("bn old", 10), incoming("bn new", 30) }, 1, { charLine }, 1)
    selector.selectConversation(FRIEND)
    assert(runtime.unreadDivider and runtime.unreadDivider.conversationKey == FRIEND, "divider for the friend thread")
    assert(runtime.unreadDivider.message == charLine, "divider before the character's unread line")
  end

  -- test_divider_prefers_the_friend_line_on_equal_time
  do
    local bnLine = incoming("bn new", 20)
    local selector, runtime = linkedThread({ bnLine }, 1, { incoming("char new", 20) }, 1)
    selector.selectConversation(FRIEND)
    assert(runtime.unreadDivider and runtime.unreadDivider.message == bnLine, "friend line first on a tie")
  end

  -- test_an_unlinked_character_opens_on_its_own
  do
    local selector, runtime = linkedThread({ incoming("bn", 1) }, 0, { incoming("char", 2) }, 1)
    ConversationLinks.Unlink(runtime.accountState.conversationLinks, CHAR)
    selector.selectConversation(CHAR)
    assert(runtime.activeConversationKey == CHAR, "the character's own thread is open")
    assert(runtime.store.conversations[FRIEND].unreadCount == 0, "friend thread untouched")
  end
end
