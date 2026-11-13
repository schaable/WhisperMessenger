local ConversationLinks = require("WhisperMessenger.Model.ConversationLinks")

local FRIEND = "bnet::BN::jaina#1234"
local OTHER_FRIEND = "bnet::BN::thrall#5678"
local CHAR = "wow::WOW::jainachar"
local ALT = "wow::WOW::jainaalt-argentdawn"

local function newState()
  return ConversationLinks.Ensure({})
end

local function conversationsFor(keys)
  local conversations = {}
  for _, key in ipairs(keys) do
    conversations[key] = { messages = {} }
  end
  return conversations
end

-- Character threads can be linked to a Battle.net friend's thread. The map is
-- saved, records never move, and grouping only applies while both threads exist.
return function()
  -- test_ensure_creates_empty_links_and_unlinked_tables
  do
    local accountState = {}
    local state = ConversationLinks.Ensure(accountState)
    assert(accountState.conversationLinks == state, "the link state is saved on the account")
    assert(type(state.links) == "table" and next(state.links) == nil, "no links yet")
    assert(type(state.unlinked) == "table" and next(state.unlinked) == nil, "no unlinked pairs yet")
  end

  -- test_ensure_keeps_existing_links
  do
    local saved = { links = { [CHAR] = { primaryKey = FRIEND, source = "manual", linkedAt = 1 } }, unlinked = {} }
    local accountState = { conversationLinks = saved }
    assert(ConversationLinks.Ensure(accountState) == saved, "the saved table is reused")
    assert(saved.links[CHAR].primaryKey == FRIEND, "saved links survive")
  end

  -- test_ensure_repairs_missing_subtables
  do
    local accountState = { conversationLinks = { links = "broken" } }
    local state = ConversationLinks.Ensure(accountState)
    assert(type(state.links) == "table" and type(state.unlinked) == "table", "broken parts are replaced")
  end

  -- test_can_link_character_thread_to_battle_net_thread
  do
    assert(ConversationLinks.CanLink(CHAR, FRIEND) == true, "character -> Battle.net is allowed")
  end

  -- test_can_link_rejects_other_pairs
  do
    assert(ConversationLinks.CanLink(CHAR, ALT) == false, "character -> character is not allowed yet")
    assert(ConversationLinks.CanLink(FRIEND, OTHER_FRIEND) == false, "Battle.net -> Battle.net is not allowed")
    assert(ConversationLinks.CanLink(FRIEND, CHAR) == false, "Battle.net -> character is not allowed")
    assert(ConversationLinks.CanLink(CHAR, CHAR) == false, "a thread never links to itself")
    assert(ConversationLinks.CanLink(nil, FRIEND) == false, "a missing key is rejected")
    assert(ConversationLinks.CanLink("guild::stormwind", FRIEND) == false, "group chats never link")
  end

  -- test_link_records_primary_source_and_time
  do
    local state = newState()
    assert(ConversationLinks.Link(state, CHAR, FRIEND, "manual", 100) == true, "link made")
    local entry = state.links[CHAR]
    assert(entry.primaryKey == FRIEND and entry.source == "manual" and entry.linkedAt == 100, "entry saved")
  end

  -- test_link_rejects_pairs_can_link_rejects
  do
    local state = newState()
    assert(ConversationLinks.Link(state, CHAR, ALT, "manual", 100) == false, "character -> character refused")
    assert(next(state.links) == nil, "nothing saved")
  end

  -- test_primary_of_follows_link_while_both_threads_exist
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    local conversations = conversationsFor({ CHAR, FRIEND })
    assert(ConversationLinks.PrimaryOf(state, conversations, CHAR) == FRIEND, "member resolves to its primary")
    assert(ConversationLinks.PrimaryOf(state, conversations, FRIEND) == FRIEND, "a primary resolves to itself")
    assert(ConversationLinks.PrimaryOf(state, conversations, ALT) == ALT, "an unlinked key resolves to itself")
  end

  -- test_primary_of_ignores_link_when_primary_thread_is_gone
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    local conversations = conversationsFor({ CHAR })
    assert(ConversationLinks.PrimaryOf(state, conversations, CHAR) == CHAR, "no primary thread, no grouping")
  end

  -- test_members_of_lists_existing_members_sorted
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    ConversationLinks.Link(state, ALT, FRIEND, "manual", 100)
    ConversationLinks.Link(state, "wow::WOW::gone", FRIEND, "manual", 100)
    local conversations = conversationsFor({ CHAR, ALT, FRIEND })
    local members = ConversationLinks.MembersOf(state, conversations, FRIEND)
    assert(#members == 2, "only members with a thread are listed; got " .. #members)
    assert(members[1] == ALT and members[2] == CHAR, "members are sorted by key")
  end

  -- test_members_of_is_empty_when_primary_thread_is_gone
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    local members = ConversationLinks.MembersOf(state, conversationsFor({ CHAR }), FRIEND)
    assert(#members == 0, "no primary thread, no members")
  end

  -- test_groups_maps_each_primary_to_its_sorted_members
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    ConversationLinks.Link(state, ALT, FRIEND, "manual", 100)
    ConversationLinks.Link(state, "wow::WOW::thrallchar", OTHER_FRIEND, "auto", 100)
    local groups = ConversationLinks.Groups(state, conversationsFor({ CHAR, ALT, FRIEND, "wow::WOW::thrallchar", OTHER_FRIEND }))
    assert(#groups[FRIEND] == 2 and groups[FRIEND][1] == ALT and groups[FRIEND][2] == CHAR, "friend's members, sorted")
    assert(#groups[OTHER_FRIEND] == 1 and groups[OTHER_FRIEND][1] == "wow::WOW::thrallchar", "other friend's member")
  end

  -- test_groups_leave_out_pairs_missing_a_thread
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    ConversationLinks.Link(state, ALT, OTHER_FRIEND, "manual", 100)
    local groups = ConversationLinks.Groups(state, conversationsFor({ CHAR, OTHER_FRIEND }))
    assert(next(groups) == nil, "no group while the primary or the member thread is gone")
  end

  -- test_link_refuses_chains
  do
    local state = { links = { [FRIEND] = { primaryKey = OTHER_FRIEND, source = "manual" } }, unlinked = {} }
    assert(ConversationLinks.Link(state, CHAR, FRIEND, "manual", 100) == false, "a member can't become a primary")
    local state2 = { links = { [OTHER_FRIEND] = { primaryKey = CHAR, source = "manual" } }, unlinked = {} }
    assert(ConversationLinks.Link(state2, CHAR, FRIEND, "manual", 100) == false, "a primary can't become a member")
  end

  -- test_unlink_removes_link_and_remembers_pair
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    assert(ConversationLinks.Unlink(state, CHAR) == FRIEND, "unlink returns the old primary")
    assert(state.links[CHAR] == nil, "link removed")
    assert(state.unlinked[CHAR] == FRIEND, "the split pair is remembered")
    assert(ConversationLinks.Unlink(state, CHAR) == nil, "unlinking twice is a no-op")
  end

  -- test_auto_link_respects_unlinked_pair
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    ConversationLinks.Unlink(state, CHAR)
    assert(ConversationLinks.Link(state, CHAR, FRIEND, "auto", 200) == false, "auto-link never redoes a split pair")
    assert(state.links[CHAR] == nil, "still unlinked")
    assert(ConversationLinks.Link(state, CHAR, OTHER_FRIEND, "auto", 200) == true, "another friend may still auto-link")
  end

  -- test_manual_link_clears_unlinked_pair
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    ConversationLinks.Unlink(state, CHAR)
    assert(ConversationLinks.Link(state, CHAR, FRIEND, "manual", 200) == true, "manual link wins over a split")
    assert(state.unlinked[CHAR] == nil, "the split is forgotten")
  end

  -- test_auto_link_never_moves_an_existing_link
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "manual", 100)
    assert(ConversationLinks.Link(state, CHAR, OTHER_FRIEND, "auto", 200) == false, "auto keeps the existing link")
    assert(state.links[CHAR].primaryKey == FRIEND, "still linked to the first friend")
    assert(ConversationLinks.Link(state, CHAR, FRIEND, "auto", 300) == true, "relinking the same pair is fine")
    assert(state.links[CHAR].source == "manual" and state.links[CHAR].linkedAt == 100, "the manual entry is kept")
  end

  -- test_manual_link_moves_an_existing_link
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    assert(ConversationLinks.Link(state, CHAR, OTHER_FRIEND, "manual", 200) == true, "manual link moves it")
    assert(state.links[CHAR].primaryKey == OTHER_FRIEND, "now linked to the second friend")
  end

  -- test_rekey_moves_primary_and_member_keys
  do
    local state = newState()
    local numericFriend = "bnet::BN::912"
    ConversationLinks.Link(state, CHAR, numericFriend, "auto", 100)
    state.unlinked[ALT] = numericFriend
    ConversationLinks.Rekey(state, { [numericFriend] = FRIEND })
    assert(state.links[CHAR].primaryKey == FRIEND, "links follow a re-keyed primary")
    assert(state.unlinked[ALT] == FRIEND, "split pairs follow a re-keyed primary")

    ConversationLinks.Rekey(state, { [CHAR] = "wow::WOW::jainachar-argentdawn" })
    assert(state.links[CHAR] == nil, "old member key dropped")
    assert(state.links["wow::WOW::jainachar-argentdawn"].primaryKey == FRIEND, "link follows a re-keyed member")
  end

  -- test_rekey_keeps_existing_entry_on_collision
  do
    local state = newState()
    local newKey = "wow::WOW::jainachar-argentdawn"
    ConversationLinks.Link(state, CHAR, OTHER_FRIEND, "auto", 100)
    ConversationLinks.Link(state, newKey, FRIEND, "manual", 100)
    ConversationLinks.Rekey(state, { [CHAR] = newKey })
    assert(state.links[CHAR] == nil, "old member key dropped")
    assert(state.links[newKey].primaryKey == FRIEND, "the entry already on the new key wins")
  end

  -- test_prune_drops_auto_links_whose_threads_are_both_gone
  do
    local state = newState()
    ConversationLinks.Link(state, CHAR, FRIEND, "auto", 100)
    ConversationLinks.Link(state, ALT, FRIEND, "manual", 100)
    ConversationLinks.Link(state, "wow::WOW::kept", OTHER_FRIEND, "auto", 100)
    ConversationLinks.Prune(state, conversationsFor({ "wow::WOW::kept" }))
    assert(state.links[CHAR] == nil, "an auto link with no threads left is dropped (it can be learned again)")
    assert(state.links[ALT] ~= nil, "a manual link is kept: it is the player's choice")
    assert(state.links["wow::WOW::kept"] ~= nil, "an auto link with one thread left is kept")
  end

  -- test_prune_drops_entries_with_wrong_shape
  do
    local state = { links = { [CHAR] = "broken", [ALT] = { source = "auto" } }, unlinked = { [CHAR] = 5 } }
    ConversationLinks.Prune(state, {})
    assert(next(state.links) == nil, "malformed links are dropped")
    assert(next(state.unlinked) == nil, "malformed split pairs are dropped")
  end
end
