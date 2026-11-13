local AutoLink = require("WhisperMessenger.Core.Bootstrap.AutoLink")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local ALT = "wow::WOW::jainaalt"
local GUID = "Player-1-0000AAAA"

local function newRuntime()
  return {
    accountState = { settings = {} },
    store = {
      conversations = {
        [FRIEND] = { channel = "BN", battleTag = "Jaina#1234", guid = GUID, messages = {} },
        [CHAR] = { channel = "WOW", guid = GUID, messages = {} },
        [ALT] = { channel = "WOW", guid = "Player-1-0000BBBB", messages = {} },
      },
    },
  }
end

-- The friend list says which character each friend is playing right now.
local function friendMap(playerGuid)
  return {
    ["Jaina#1234"] = {
      bnetAccountID = 7,
      accountInfo = { bnetAccountID = 7, battleTag = "Jaina#1234", gameAccountInfo = { playerGuid = playerGuid } },
    },
  }
end

local function linkOf(runtime, key)
  return runtime.accountState.conversationLinks and runtime.accountState.conversationLinks.links[key]
end

-- A friend-list scan links the character each friend is playing into that
-- friend's thread, and names both threads as changed for the refresh.
return function()
  -- test_scan_links_the_character_a_friend_is_playing
  do
    local runtime = newRuntime()
    AutoLink.FromFriendScan(runtime, friendMap(GUID), {})
    assert(linkOf(runtime, CHAR) and linkOf(runtime, CHAR).primaryKey == FRIEND, "character linked to the friend")
    assert(linkOf(runtime, ALT) == nil, "a character they aren't playing stays apart")
  end

  -- test_scan_marks_both_threads_changed
  do
    local changedKeys = {}
    AutoLink.FromFriendScan(newRuntime(), friendMap(GUID), changedKeys)
    assert(changedKeys[CHAR] == true and changedKeys[FRIEND] == true, "both rows are rebuilt")
  end

  -- test_scan_without_a_new_link_changes_nothing
  do
    local runtime, changedKeys = newRuntime(), {}
    AutoLink.FromFriendScan(runtime, friendMap(GUID), {})
    AutoLink.FromFriendScan(runtime, friendMap(GUID), changedKeys)
    assert(next(changedKeys) == nil, "nothing new to rebuild")
  end

  -- test_scan_skips_a_friend_not_in_game
  do
    local runtime = newRuntime()
    AutoLink.FromFriendScan(runtime, friendMap(nil), {})
    assert(linkOf(runtime, CHAR) == nil, "no character, no link")
  end

  -- test_scan_with_the_setting_off_links_nothing
  do
    local runtime = newRuntime()
    runtime.accountState.settings.autoLinkBattleNetCharacters = false
    AutoLink.FromFriendScan(runtime, friendMap(GUID), {})
    assert(linkOf(runtime, CHAR) == nil, "automatic linking is off")
  end
end
