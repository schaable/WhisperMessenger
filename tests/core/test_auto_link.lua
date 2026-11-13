local AutoLink = require("WhisperMessenger.Core.Bootstrap.AutoLink")
local RuntimeLinks = require("WhisperMessenger.Core.Bootstrap.RuntimeLinks")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local GUID = "Player-1-0000AAAA"

local function newRuntime()
  local runtime = {
    accountState = { settings = {} },
    characterState = {},
    store = {
      conversations = {
        [FRIEND] = { channel = "BN", battleTag = "Jaina#1234", messages = {} },
        [CHAR] = { channel = "WOW", guid = GUID, messages = {} },
      },
    },
    now = function()
      return 500
    end,
    guidLookups = 0,
  }
  runtime.bnetApi = {
    GetAccountInfoByGUID = function(guid)
      runtime.guidLookups = runtime.guidLookups + 1
      if guid == GUID then
        return { bnetAccountID = 7, battleTag = "Jaina#1234" }
      end
      return nil
    end,
  }
  return runtime
end

local function characterWhisper(runtime, eventName)
  AutoLink.AfterWhisper(runtime, eventName or "CHAT_MSG_WHISPER", { guid = GUID }, { conversationKey = CHAR })
end

local function friendWhisper(runtime)
  local payload = { accountInfo = { battleTag = "Jaina#1234", gameAccountInfo = { playerGuid = GUID } } }
  AutoLink.AfterWhisper(runtime, "CHAT_MSG_BN_WHISPER", payload, { conversationKey = FRIEND })
end

local function linkOf(runtime)
  local state = runtime.accountState.conversationLinks
  return state and state.links[CHAR]
end

-- A whisper tells us which Battle.net friend plays a character: the
-- character's thread joins the friend's thread on its own, when both exist.
return function()
  -- test_character_whisper_links_to_the_friend_who_plays_it
  do
    local runtime = newRuntime()
    characterWhisper(runtime)
    local entry = linkOf(runtime)
    assert(entry and entry.primaryKey == FRIEND, "character thread joined the friend's thread")
    assert(entry.source == "auto" and entry.linkedAt == 500, "an automatic link made now")
  end

  -- test_whisper_to_a_character_links_too
  do
    local runtime = newRuntime()
    characterWhisper(runtime, "CHAT_MSG_WHISPER_INFORM")
    assert(linkOf(runtime) ~= nil, "your own whisper to the character links it")
  end

  -- test_friend_whisper_links_the_character_they_are_playing
  do
    local runtime = newRuntime()
    friendWhisper(runtime)
    assert(linkOf(runtime) and linkOf(runtime).primaryKey == FRIEND, "linked from the friend's side")
  end

  -- test_no_link_without_the_friends_thread
  do
    local runtime = newRuntime()
    runtime.store.conversations[FRIEND] = nil
    characterWhisper(runtime)
    assert(linkOf(runtime) == nil, "never links to a thread that doesn't exist")
  end

  -- test_no_link_when_the_setting_is_off
  do
    local runtime = newRuntime()
    runtime.accountState.settings.autoLinkBattleNetCharacters = false
    characterWhisper(runtime)
    friendWhisper(runtime)
    assert(linkOf(runtime) == nil, "automatic linking is off")
  end

  -- test_a_pair_the_player_split_stays_split
  do
    local runtime = newRuntime()
    runtime.accountState.conversationLinks = { links = {}, unlinked = { [CHAR] = FRIEND } }
    characterWhisper(runtime)
    assert(linkOf(runtime) == nil, "unlinked by hand, so not linked again")
  end

  -- test_a_secret_guid_is_never_looked_up
  do
    local runtime = newRuntime()
    local previous = rawget(_G, "issecretvalue")
    rawset(_G, "issecretvalue", function(value)
      return value == GUID
    end)
    characterWhisper(runtime)
    friendWhisper(runtime)
    rawset(_G, "issecretvalue", previous)
    assert(runtime.guidLookups == 0, "no lookup with a secret GUID")
    assert(linkOf(runtime) == nil, "nothing linked")
  end

  -- test_missing_or_failing_lookup_links_nothing
  do
    local runtime = newRuntime()
    runtime.bnetApi = {}
    characterWhisper(runtime)
    runtime.bnetApi = {
      GetAccountInfoByGUID = function()
        error("not available")
      end,
    }
    characterWhisper(runtime)
    assert(linkOf(runtime) == nil, "nothing linked")
  end

  -- test_an_already_linked_character_is_not_looked_up_again
  do
    local runtime = newRuntime()
    characterWhisper(runtime)
    characterWhisper(runtime)
    assert(runtime.guidLookups == 1, "one lookup, got " .. runtime.guidLookups)
  end

  -- test_other_events_learn_nothing
  do
    local runtime = newRuntime()
    AutoLink.AfterWhisper(runtime, "CHAT_MSG_AFK", { guid = GUID }, { conversationKey = CHAR })
    AutoLink.AfterWhisper(runtime, "CHAT_MSG_WHISPER", { guid = GUID }, nil)
    assert(runtime.guidLookups == 0 and linkOf(runtime) == nil, "only stored whispers teach links")
  end

  -- test_linking_the_open_character_opens_the_friends_thread
  do
    local runtime = newRuntime()
    runtime.activeConversationKey = CHAR
    runtime.characterState.activeConversationKey = CHAR
    characterWhisper(runtime)
    assert(runtime.activeConversationKey == FRIEND, "the merged thread is open")
    assert(runtime.characterState.activeConversationKey == FRIEND, "and stays open after a reload")
  end

  -- test_a_thread_joining_the_open_thread_is_read
  do
    local runtime = newRuntime()
    runtime.activeConversationKey = FRIEND
    runtime.isConversationOpen = function(key)
      return RuntimeLinks.SameThread(runtime, runtime.activeConversationKey, key)
    end
    runtime.store.conversations[CHAR].unreadCount = 2
    characterWhisper(runtime)
    assert(runtime.store.conversations[CHAR].unreadCount == 0, "its lines show in the open thread")
  end

  -- test_a_thread_joining_a_closed_thread_stays_unread
  do
    local runtime = newRuntime()
    runtime.isConversationOpen = function()
      return false
    end
    runtime.store.conversations[CHAR].unreadCount = 2
    characterWhisper(runtime)
    assert(runtime.store.conversations[CHAR].unreadCount == 2, "still unread")
  end
end
