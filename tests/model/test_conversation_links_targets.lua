local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")

local FRIEND = "bnet::BN::jaina#1234"
local OTHER_FRIEND = "bnet::BN::thrall#5678"
local CHAR = "wow::WOW::jainachar"
local ALT = "wow::WOW::jainaalt-argentdawn"

local function conversationsFor(keys)
  local conversations = {}
  for _, key in ipairs(keys) do
    conversations[key] = { messages = {} }
  end
  return conversations
end

-- The threads a character's thread can be linked to by hand: the ones Link
-- would accept, so the menu never offers a choice that does nothing.
return function()
  local conversations = conversationsFor({ FRIEND, OTHER_FRIEND, CHAR, ALT })

  -- test_targets_are_every_thread_the_character_may_join_sorted
  do
    local targets = ConversationLinks.Targets(ConversationLinks.Ensure({}), conversations, CHAR)
    assert(#targets == 2, "two friends, no characters, got " .. #targets)
    assert(targets[1] == FRIEND and targets[2] == OTHER_FRIEND, "sorted friend keys")
  end

  -- test_targets_skip_a_thread_that_is_itself_linked_in
  do
    local state = ConversationLinks.Ensure({})
    state.links[OTHER_FRIEND] = { primaryKey = FRIEND, source = "manual" }
    local targets = ConversationLinks.Targets(state, conversations, CHAR)
    assert(#targets == 1 and targets[1] == FRIEND, "a member can't become a primary")
  end

  -- test_a_thread_others_are_linked_into_has_no_targets
  do
    local state = ConversationLinks.Ensure({})
    state.links[ALT] = { primaryKey = CHAR, source = "manual" }
    assert(#ConversationLinks.Targets(state, conversations, CHAR) == 0, "a primary can't become a member")
  end
end
