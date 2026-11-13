local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local SnapshotCache = require("WhisperMessenger.UI.ContactsList.SnapshotCache")
local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local OTHER = "wow::WOW::someone"

local function newState()
  local state = {
    settings = {},
    conversations = {
      [FRIEND] = { displayName = "Jaina#1234", channel = "BN", unreadCount = 1, lastActivityAt = 10, lastPreview = "bn", messages = {} },
      [CHAR] = { displayName = "Jainachar", channel = "WOW", unreadCount = 2, lastActivityAt = 30, lastPreview = "char", messages = {} },
      [OTHER] = { displayName = "Someone", channel = "WOW", unreadCount = 0, lastActivityAt = 20, lastPreview = "other", messages = {} },
    },
  }
  ConversationLinks.Link(ConversationLinks.Ensure(state), CHAR, FRIEND, "manual", 1)
  return state
end

local function keysOf(items)
  local keys = {}
  for index, item in ipairs(items) do
    keys[index] = item.conversationKey
  end
  return table.concat(keys, ",")
end

local function itemFor(items, key)
  for _, item in ipairs(items) do
    if item.conversationKey == key then
      return item
    end
  end
  return nil
end

-- The contact list shows one row per Battle.net friend: their linked character
-- threads fold into it, and come back as their own rows once unlinked.
return function()
  -- test_linked_character_row_is_folded_into_the_friend_row
  do
    local items = DataBuilder.BuildItemsForProfile(newState(), "me")
    assert(keysOf(items) == FRIEND .. "," .. OTHER, "got " .. keysOf(items))
  end

  -- test_friend_row_shows_the_whole_thread
  do
    local friend = itemFor(DataBuilder.BuildItemsForProfile(newState(), "me"), FRIEND)
    assert(friend, "friend row")
    assert(friend.unreadCount == 3, "unread added up")
    assert(friend.lastPreview == "char", "newest preview")
  end

  -- test_unlinked_character_gets_its_own_row_back
  do
    local state = newState()
    ConversationLinks.Unlink(state.conversationLinks, CHAR)
    local items = DataBuilder.BuildItemsForProfile(state, "me")
    assert(keysOf(items) == CHAR .. "," .. OTHER .. "," .. FRIEND, "got " .. keysOf(items))
    local friend = itemFor(items, FRIEND)
    assert(friend and friend.unreadCount == 1 and friend.linkedMembers == nil, "friend row back to its own thread")
  end

  -- test_new_character_whisper_refreshes_the_cached_friend_row
  do
    local state = newState()
    local cache = SnapshotCache.New()
    DataBuilder.BuildItemsForProfile(state, "me", cache, nil)
    local char = state.conversations[CHAR]
    char.unreadCount, char.lastActivityAt, char.lastPreview = 3, 40, "char again"
    local friend = itemFor(DataBuilder.BuildItemsForProfile(state, "me", cache, { [CHAR] = true }), FRIEND)
    assert(friend and friend.unreadCount == 4, "unread follows the character thread")
    assert(friend.lastPreview == "char again", "preview follows the character thread")
  end

  -- test_cached_character_row_is_current_after_unlink
  do
    local state = newState()
    local cache = SnapshotCache.New()
    DataBuilder.BuildItemsForProfile(state, "me", cache, nil)
    state.conversations[CHAR].lastPreview = "while linked"
    DataBuilder.BuildItemsForProfile(state, "me", cache, { [CHAR] = true })
    ConversationLinks.Unlink(state.conversationLinks, CHAR)
    local char = itemFor(DataBuilder.BuildItemsForProfile(state, "me", cache, {}), CHAR)
    assert(char and char.lastPreview == "while linked", "a hidden row's card is kept up to date")
  end
end
