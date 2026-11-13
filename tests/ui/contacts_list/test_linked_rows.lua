local LinkedRows = require("WhisperMessenger.UI.ContactsList.LinkedRows")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"
local ALT = "wow::WOW::jainaalt"

local function savedState(conversations, links)
  return { conversations = conversations, conversationLinks = { links = links or {}, unlinked = {} } }
end

local function linkTo(primaryKey)
  return { primaryKey = primaryKey, source = "manual", linkedAt = 1 }
end

local function linkedState()
  return savedState({
    [FRIEND] = { channel = "BN", unreadCount = 1, lastActivityAt = 10, lastPreview = "bn", messages = {} },
    [CHAR] = { channel = "WOW", unreadCount = 2, lastActivityAt = 30, lastPreview = "char", messages = {} },
    [ALT] = { channel = "WOW", unreadCount = 0, lastActivityAt = 20, lastPreview = "alt", messages = {} },
  }, { [CHAR] = linkTo(FRIEND), [ALT] = linkTo(FRIEND) })
end

-- A Battle.net friend's row stands for the whole linked thread: the linked
-- character rows are hidden and the friend's row sums them up.
return function()
  -- test_prepare_returns_nil_without_links
  do
    assert(LinkedRows.Prepare({ conversations = {} }) == nil, "no link map")
    assert(LinkedRows.Prepare(savedState({ [FRIEND] = {} })) == nil, "empty link map")
  end

  -- test_is_hidden_for_a_linked_character_row
  do
    local linked = LinkedRows.Prepare(linkedState())
    assert(LinkedRows.IsHidden(linked, CHAR) == true, "linked character row is hidden")
    assert(LinkedRows.IsHidden(linked, FRIEND) == false, "the friend's row stays")
  end

  -- test_is_hidden_false_while_the_friend_thread_is_gone
  do
    local state = savedState({ [CHAR] = { messages = {} } }, { [CHAR] = linkTo(FRIEND) })
    assert(LinkedRows.IsHidden(LinkedRows.Prepare(state), CHAR) == false, "no friend thread: the character row shows")
  end

  -- test_is_hidden_false_without_links
  do
    assert(LinkedRows.IsHidden(nil, CHAR) == false, "nothing linked, nothing hidden")
  end

  -- test_apply_sums_the_linked_thread_onto_the_friend_row
  do
    local state = linkedState()
    local card = ConversationSnapshot.Build(FRIEND, state.conversations[FRIEND], {})
    LinkedRows.Apply(LinkedRows.Prepare(state), card)
    assert(card.unreadCount == 3, "unread added up, got " .. tostring(card.unreadCount))
    assert(card.lastActivityAt == 30, "newest activity")
    assert(card.lastPreview == "char", "newest preview")
    assert(card.previewConversation == state.conversations[CHAR], "preview source")
  end

  -- test_apply_lists_the_linked_members_on_the_friend_row
  do
    local state = linkedState()
    local card = ConversationSnapshot.Build(FRIEND, state.conversations[FRIEND], {})
    LinkedRows.Apply(LinkedRows.Prepare(state), card)
    local members = card.linkedMembers
    assert(#members == 2, "two members")
    assert(members[1].key == ALT and members[1].conversation == state.conversations[ALT], "alt first (sorted)")
    assert(members[2].key == CHAR and members[2].conversation == state.conversations[CHAR], "then the character")
  end

  -- test_apply_leaves_an_unlinked_row_alone
  do
    local state = savedState({ [FRIEND] = { unreadCount = 1, messages = {} } })
    local card = ConversationSnapshot.Build(FRIEND, state.conversations[FRIEND], {})
    LinkedRows.Apply(LinkedRows.Prepare(state), card)
    assert(card.unreadCount == 1, "own unread")
    assert(card.linkedMembers == nil, "no members")
    assert(card.previewConversation == nil, "no preview source")
  end
end
