local Store = require("WhisperMessenger.Model.ConversationStore")
local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local OTHER = "wow::WOW::thrall"

local function setup(settings)
  local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
  Store.EnsureConversation(runtime.store, FRIEND, { channel = "BN", displayName = "Jaina#1234" })
  Store.EnsureConversation(runtime.store, CHAR, { channel = "WOW", displayName = "Jainachar" })
  Store.EnsureConversation(runtime.store, OTHER, { channel = "WOW", displayName = "Thrall" })
  local accountState = { settings = settings or {} }
  runtime.accountState = accountState
  ConversationLinks.Link(ConversationLinks.Ensure(accountState), CHAR, FRIEND, "manual", 1)
  local refreshes = 0
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = {},
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  })
  return runtime, callbacks, function()
    return refreshes
  end
end

-- Removing a friend's row removes the whole thread it shows: the friend's
-- chat and every character chat linked into it.
return function()
  -- test_removing_a_friend_removes_their_linked_characters
  do
    local runtime, callbacks, refreshes = setup()
    callbacks.onRemove({ conversationKey = FRIEND })
    assert(runtime.store.conversations[FRIEND] == nil, "the friend's chat is gone")
    assert(runtime.store.conversations[CHAR] == nil, "the linked character's chat is gone too")
    assert(runtime.store.conversations[OTHER] ~= nil, "other chats stay")
    assert(refreshes() == 1, "one refresh")
  end

  -- test_removing_keeps_the_link_for_later_chats
  do
    local runtime, callbacks = setup()
    callbacks.onRemove({ conversationKey = FRIEND })
    local entry = runtime.accountState.conversationLinks.links[CHAR]
    assert(entry and entry.primaryKey == FRIEND, "new chats with both group again")
  end

  -- test_removing_closes_the_characters_game_whisper_tab
  do
    local savedFrames, savedClose = rawget(_G, "CHAT_FRAMES"), rawget(_G, "FCF_Close")
    local closed = {}
    rawset(_G, "ChatFrame11", { isTemporary = true, inUse = true, chatType = "WHISPER", chatTarget = "Jainachar" })
    rawset(_G, "CHAT_FRAMES", { "ChatFrame11" })
    rawset(_G, "FCF_Close", function(frame)
      closed[#closed + 1] = frame
    end)
    local _, callbacks = setup({ closeGameWhisperTab = true })
    callbacks.onRemove({ conversationKey = FRIEND })
    rawset(_G, "CHAT_FRAMES", savedFrames)
    rawset(_G, "FCF_Close", savedClose)
    rawset(_G, "ChatFrame11", nil)
    assert(#closed == 1, "the character's game whisper tab closes, got " .. #closed)
  end
end
