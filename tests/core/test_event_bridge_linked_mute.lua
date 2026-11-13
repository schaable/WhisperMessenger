local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")
local Store = require("WhisperMessenger.Model.ConversationStore")

local FRIEND = "bnet::BN::jaina#1234"
local STUBBED_GLOBALS = { "PlaySound", "FlashClientIcon", "InCombatLockdown", "C_Timer" }

local function whisper(runtime)
  EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", "hi", "Jainachar", "", "", "", "", "", "", "", "", 1, "Player-1-ABC")
end

local function characterKey(runtime)
  for key, conversation in pairs(runtime.store.conversations) do
    if conversation.channel == "WOW" then
      return key
    end
  end
  return nil
end

-- Muting a Battle.net friend's row silences the whispers of the characters
-- linked into it: that row is the one the player sees and mutes.
return function()
  local saved = {}
  for _, name in ipairs(STUBBED_GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  local flashes = 0
  rawset(_G, "FlashClientIcon", function()
    flashes = flashes + 1
  end)
  rawset(_G, "PlaySound", function() end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "C_Timer", { After = function() end })

  -- Whispers to one chat alert once per 2 seconds, so the test whisper comes later.
  local clock = 100
  local function linkedRuntime(friendMuted)
    clock = 100
    local runtime = {
      store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
      localProfileId = "me",
      now = function()
        return clock
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      accountState = { settings = {} },
    }
    local friend = Store.EnsureConversation(runtime.store, FRIEND)
    friend.channel = "BN"
    whisper(runtime)
    ConversationLinks.Link(ConversationLinks.Ensure(runtime.accountState), characterKey(runtime), FRIEND, "manual", 1)
    friend.muted = friendMuted or nil
    flashes, clock = 0, 200
    return runtime
  end

  -- test_muted_friend_silences_a_linked_characters_whisper
  do
    local runtime = linkedRuntime(true)
    whisper(runtime)
    assert(flashes == 0, "no flash for a muted friend's character, got " .. flashes)
  end

  -- test_unmuted_friend_lets_the_characters_whisper_alert
  do
    local runtime = linkedRuntime(false)
    whisper(runtime)
    assert(flashes == 1, "the character's whisper alerts, got " .. flashes)
  end

  for _, name in ipairs(STUBBED_GLOBALS) do
    rawset(_G, name, saved[name])
  end
end
