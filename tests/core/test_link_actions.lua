local LinkActions = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.LinkActions")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local OTHER_CHAR = "wow::WOW::someone"

local function newRuntime()
  return {
    accountState = {},
    store = { conversations = { [FRIEND] = { displayName = "Jaina" }, [CHAR] = { displayName = "Jainachar" }, [OTHER_CHAR] = {} } },
    now = function()
      return 1000
    end,
  }
end

local function newActions(runtime, calls)
  return LinkActions.Create({
    runtime = runtime,
    refreshWindow = function()
      calls[#calls + 1] = "refresh"
    end,
    selectConversation = function(key)
      calls[#calls + 1] = "select " .. key
    end,
  })
end

-- The contact menu's link entries: list the friends a row can join, link a
-- character to a friend by hand, and split them again without losing history.
return function()
  -- test_targets_pair_each_friend_key_with_its_conversation
  do
    local runtime = newRuntime()
    local targets = newActions(runtime, {}).targetsFor({ conversationKey = CHAR })
    assert(#targets == 1 and targets[1].key == FRIEND, "the friend is the only target")
    assert(targets[1].conversation == runtime.store.conversations[FRIEND], "with its conversation for the label")
  end

  -- test_targets_without_a_store_are_empty
  do
    local actions = LinkActions.Create({ runtime = {} })
    assert(#actions.targetsFor({ conversationKey = CHAR }) == 0, "nothing to link to")
  end

  -- test_link_saves_a_manual_link
  do
    local runtime = newRuntime()
    newActions(runtime, {}).link({ conversationKey = CHAR }, FRIEND)
    local entry = runtime.accountState.conversationLinks.links[CHAR]
    assert(entry and entry.primaryKey == FRIEND, "character linked to the friend")
    assert(entry.source == "manual" and entry.linkedAt == 1000, "a manual link made now")
  end

  -- test_link_refreshes_the_window
  do
    local calls = {}
    newActions(newRuntime(), calls).link({ conversationKey = CHAR }, FRIEND)
    assert(#calls == 1 and calls[1] == "refresh", "one refresh, got " .. table.concat(calls, ","))
  end

  -- test_linking_the_open_character_opens_the_friends_thread
  do
    local calls, runtime = {}, newRuntime()
    runtime.activeConversationKey = CHAR
    newActions(runtime, calls).link({ conversationKey = CHAR }, FRIEND)
    assert(#calls == 1 and calls[1] == "select " .. FRIEND, "the merged thread opens, got " .. table.concat(calls, ","))
  end

  -- test_linking_accepts_a_character_request
  do
    local runtime = newRuntime()
    runtime.store.conversations[CHAR].request = true
    newActions(runtime, {}).link({ conversationKey = CHAR }, FRIEND)
    assert(runtime.store.conversations[CHAR].request == nil, "a friend's character is no stranger")
  end

  -- test_a_refused_link_changes_nothing
  do
    local calls, runtime = {}, newRuntime()
    runtime.store.conversations[OTHER_CHAR].request = true
    newActions(runtime, calls).link({ conversationKey = OTHER_CHAR }, CHAR)
    assert(next(runtime.accountState.conversationLinks.links) == nil, "no link")
    assert(runtime.store.conversations[OTHER_CHAR].request == true, "still a request")
    assert(#calls == 0, "no refresh")
  end

  -- test_unlink_splits_the_pair_and_refreshes
  do
    local calls, runtime = {}, newRuntime()
    local actions = newActions(runtime, calls)
    actions.link({ conversationKey = CHAR }, FRIEND)
    actions.unlink({ conversationKey = FRIEND }, CHAR)
    local state = runtime.accountState.conversationLinks
    assert(state.links[CHAR] == nil, "link removed")
    assert(state.unlinked[CHAR] == FRIEND, "split remembered so auto-link leaves it")
    assert(runtime.store.conversations[CHAR] ~= nil, "the character's history stays")
    assert(calls[2] == "refresh", "window refreshed")
  end

  -- test_window_callbacks_expose_the_link_actions
  do
    local callbacks = WindowCallbacks.Create({ runtime = newRuntime(), characterState = {} })
    local actions = callbacks.linkActions
    assert(type(actions) == "table" and type(actions.targetsFor) == "function", "row menus get the link actions")
    assert(type(actions.link) == "function" and type(actions.unlink) == "function", "link and unlink")
  end
end
