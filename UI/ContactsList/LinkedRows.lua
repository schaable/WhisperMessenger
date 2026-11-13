local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationLinks = ns.ConversationLinks or require("WhisperMessenger.Model.ConversationLinks")
local LinkedThread = ns.LinkedThread or require("WhisperMessenger.Model.LinkedThread")

-- Contact rows for linked threads: a member's row is hidden and its primary's
-- row stands for the whole thread (summed unread, newest preview and activity).
local LinkedRows = {}

-- Link lookups for one list build, or nil when nothing is linked.
function LinkedRows.Prepare(savedState)
  local state = savedState.conversationLinks
  if type(state) ~= "table" or type(state.links) ~= "table" or next(state.links) == nil then
    return nil
  end
  local conversations = savedState.conversations or {}
  return { state = state, conversations = conversations, groups = ConversationLinks.Groups(state, conversations) }
end

function LinkedRows.IsHidden(linked, conversationKey)
  return linked ~= nil and ConversationLinks.PrimaryOf(linked.state, linked.conversations, conversationKey) ~= conversationKey
end

-- Writes the whole thread's values onto a primary's card. Cards are reset
-- from their cached base on every build, so this runs on every build too.
function LinkedRows.Apply(linked, card)
  local memberKeys = linked and linked.groups[card.conversationKey]
  if memberKeys == nil then
    return
  end
  local members = {}
  for index, memberKey in ipairs(memberKeys) do
    members[index] = { key = memberKey, conversation = linked.conversations[memberKey] }
  end
  local summary = LinkedThread.Summary(card.conversation, members)
  card.unreadCount = summary.unreadCount
  card.lastActivityAt = summary.lastActivityAt
  card.lastPreview = summary.lastPreview
  card.hasUnreadMention = summary.hasUnreadMention
  card.previewConversation = summary.previewConversation
  card.linkedMembers = members
end

ns.ContactsListLinkedRows = LinkedRows
return LinkedRows
