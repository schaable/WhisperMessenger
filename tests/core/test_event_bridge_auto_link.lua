local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local AutoLink = require("WhisperMessenger.Core.Bootstrap.AutoLink")
local Store = require("WhisperMessenger.Model.ConversationStore")

local FRIEND = "bnet::BN::jaina#1234"
local GUID = "Player-1-0000AAAA"
local STUBBED_GLOBALS = { "PlaySound", "FlashClientIcon", "InCombatLockdown", "C_Timer" }

local function newRuntime()
  local runtime = {
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    localProfileId = "me",
    now = function()
      return 1000
    end,
    availabilityByGUID = {},
    pendingOutgoing = {},
    accountState = { settings = {} },
    bnetApi = {
      GetAccountInfoByGUID = function(guid)
        return guid == GUID and { bnetAccountID = 7, battleTag = "Jaina#1234" } or nil
      end,
    },
  }
  Store.EnsureConversation(runtime.store, FRIEND).channel = "BN"
  return runtime
end

local WHISPER_ARGS = { "hi", "Jainachar-Area52", "", "", "", "", "", "", "", "", 40, GUID }

local function characterKey(runtime)
  for key, conversation in pairs(runtime.store.conversations) do
    if conversation.channel == "WOW" then
      return key
    end
  end
  return nil
end

local function linkedTo(runtime)
  local state = runtime.accountState.conversationLinks
  local key = characterKey(runtime)
  local entry = state and key and state.links[key]
  return entry and entry.primaryKey
end

-- Whispers teach links as they are stored, live or replayed after a chat
-- lock, and a failing learner never costs the whisper its refresh.
return function()
  local saved = {}
  for _, name in ipairs(STUBBED_GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  rawset(_G, "PlaySound", function() end)
  rawset(_G, "FlashClientIcon", function() end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "C_Timer", { After = function() end })

  -- test_live_character_whisper_links_its_thread
  do
    local runtime = newRuntime()
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", unpack(WHISPER_ARGS))
    assert(linkedTo(runtime) == FRIEND, "joined the friend's thread, got " .. tostring(linkedTo(runtime)))
  end

  -- test_replayed_character_whisper_links_its_thread
  do
    local runtime = newRuntime()
    EventBridge.RouteReplayedEvent(runtime, nil, "CHAT_MSG_WHISPER", 800, unpack(WHISPER_ARGS))
    assert(linkedTo(runtime) == FRIEND, "joined the friend's thread, got " .. tostring(linkedTo(runtime)))
  end

  -- test_replayed_whisper_still_returns_the_router_result
  do
    local result = EventBridge.RouteReplayedEvent(newRuntime(), nil, "CHAT_MSG_WHISPER", 800, unpack(WHISPER_ARGS))
    assert(type(result) == "table" and result.conversationKey ~= nil, "the caller still gets the stored conversation")
  end

  -- test_a_failing_learner_keeps_the_refresh
  do
    local original = AutoLink.AfterWhisper
    rawset(AutoLink, "AfterWhisper", function()
      error("learner failed")
    end)
    local refreshed
    local ok = pcall(EventBridge.RouteLiveEvent, newRuntime(), function(key)
      refreshed = key
    end, "CHAT_MSG_WHISPER", unpack(WHISPER_ARGS))
    rawset(AutoLink, "AfterWhisper", original)
    assert(ok, "the whisper route doesn't fail")
    assert(refreshed ~= nil, "the window still refreshes")
  end

  for _, name in ipairs(STUBBED_GLOBALS) do
    rawset(_G, name, saved[name])
  end
end
