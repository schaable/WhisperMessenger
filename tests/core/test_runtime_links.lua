local RuntimeLinks = require("WhisperMessenger.Core.Bootstrap.RuntimeLinks")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local ALT = "wow::WOW::jainaalt"
local OTHER = "wow::WOW::someone"

local function linkedRuntime()
  return {
    accountState = {
      conversationLinks = {
        links = {
          [CHAR] = { primaryKey = FRIEND, source = "auto", linkedAt = 1 },
          [ALT] = { primaryKey = FRIEND, source = "manual", linkedAt = 1 },
        },
        unlinked = {},
      },
    },
    store = { conversations = { [FRIEND] = {}, [CHAR] = {}, [ALT] = {}, [OTHER] = {} } },
  }
end

-- Link lookups against the live runtime: the account's saved link map and
-- the conversation store. A runtime without either behaves as unlinked.
return function()
  -- test_primary_of_maps_a_linked_character_to_the_friend
  do
    local runtime = linkedRuntime()
    assert(RuntimeLinks.PrimaryOf(runtime, CHAR) == FRIEND, "character thread shows in the friend's thread")
    assert(RuntimeLinks.PrimaryOf(runtime, FRIEND) == FRIEND, "the friend's thread is its own")
    assert(RuntimeLinks.PrimaryOf(runtime, OTHER) == OTHER, "an unlinked thread is its own")
    assert(RuntimeLinks.PrimaryOf(runtime, nil) == nil, "no key, no thread")
  end

  -- test_primary_of_without_link_map_returns_the_key
  do
    assert(RuntimeLinks.PrimaryOf({ store = { conversations = {} } }, CHAR) == CHAR, "no link map")
    assert(RuntimeLinks.PrimaryOf({}, CHAR) == CHAR, "no store")
    assert(RuntimeLinks.PrimaryOf(nil, CHAR) == CHAR, "no runtime")
  end

  -- test_members_of_lists_the_friends_linked_characters
  do
    local members = RuntimeLinks.MembersOf(linkedRuntime(), FRIEND)
    assert(#members == 2 and members[1] == ALT and members[2] == CHAR, "sorted members")
    assert(#RuntimeLinks.MembersOf({}, FRIEND) == 0, "no link map, no members")
    assert(#RuntimeLinks.MembersOf(linkedRuntime(), nil) == 0, "no key, no members")
  end

  -- test_same_thread_compares_the_threads_keys_are_shown_in
  do
    local runtime = linkedRuntime()
    assert(RuntimeLinks.SameThread(runtime, FRIEND, CHAR) == true, "friend and linked character")
    assert(RuntimeLinks.SameThread(runtime, CHAR, ALT) == true, "two characters of the same friend")
    assert(RuntimeLinks.SameThread(runtime, FRIEND, OTHER) == false, "different people")
  end

  -- test_primary_conversation_is_the_record_a_key_is_shown_in
  do
    local runtime = linkedRuntime()
    local friend = runtime.store.conversations[FRIEND]
    assert(RuntimeLinks.PrimaryConversation(runtime, CHAR) == friend, "a linked character shows in the friend's record")
    assert(RuntimeLinks.PrimaryConversation(runtime, OTHER) == runtime.store.conversations[OTHER], "an unlinked thread is its own")
    assert(RuntimeLinks.PrimaryConversation({}, CHAR) == nil, "no store, no record")
    assert(RuntimeLinks.PrimaryConversation(runtime, nil) == nil, "no key, no record")
  end
end
