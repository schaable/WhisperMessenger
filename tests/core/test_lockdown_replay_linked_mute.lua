local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")
local Store = require("WhisperMessenger.Model.ConversationStore")

local KEY = "wow::WOW::arthas-area52"
local FRIEND = "bnet::BN::arthas#1234"

local function probeLinked(friendMuted)
  local probe = ReplayRuntime.Probe({ [1] = { text = "held hello", name = "Arthas-Area52", guid = "Player-1-ABC" } }, { { "CHAT_MSG_WHISPER", 1 } })
  local store = probe.runtime.store
  Store.EnsureConversation(store, KEY).channel = "WOW"
  local friend = Store.EnsureConversation(store, FRIEND)
  friend.channel = "BN"
  friend.muted = friendMuted or nil
  ConversationLinks.Link(ConversationLinks.Ensure(probe.runtime.accountState), KEY, FRIEND, "manual", 1)
  LockdownReplay.Kick(probe.runtime)
  ReplayRuntime.FireUntilDone(probe.runtime)
  return probe
end

-- A whisper held during a chat lock alerts once the lock lifts, unless the
-- row it shows in is muted: for a linked character, that is the friend's row.
return function()
  -- test_held_whisper_from_a_muted_friends_character_stays_quiet
  do
    local probe = probeLinked(true)
    assert(probe.runtime.lockdownReplay.lastSummary.filed == 1, "setup: the whisper must file")
    assert(#probe.notified == 0, "the muted friend's character must not alert, got " .. #probe.notified)
    probe.restore()
  end

  -- test_held_whisper_from_an_unmuted_friends_character_alerts
  do
    local probe = probeLinked(false)
    assert(#probe.notified == 1, "the character's whisper alerts, got " .. #probe.notified)
    probe.restore()
  end
end
