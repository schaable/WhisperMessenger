local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelContextMerger = ns.ConversationPaneChannelContextMerger or require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")
local LinkedThread = ns.LinkedThread or require("WhisperMessenger.Model.LinkedThread")

-- The lines the conversation pane shows: the open conversation's own lines,
-- the sender's latest channel post, and the lines of linked threads
-- (selectedContact.linkedMembers) in one timeline.
local PaneMessages = {}

function PaneMessages.IsLinked(selectedContact)
  return type(selectedContact) == "table" and type(selectedContact.linkedMembers) == "table" and #selectedContact.linkedMembers > 0
end

-- Returns the message list and marks the transcript as a linked thread (its
-- labels then carry a route tag). Remembers which lines came from a linked
-- thread for IsMemberLine.
function PaneMessages.Build(view, selectedContact, conversation)
  -- Channel context first: it is saved into the conversation only when handed
  -- that conversation's own list. view.isChannelContextShown is the "Show
  -- their last channel message" option.
  local isContextShown = view.isChannelContextShown == nil or view.isChannelContextShown() == true
  local messages = ChannelContextMerger.ForPane(conversation and conversation.messages or {}, selectedContact, conversation, isContextShown)
  local members = PaneMessages.IsLinked(selectedContact) and selectedContact.linkedMembers or nil
  local merged, memberKeyByMessage = LinkedThread.Merge(messages, members)
  view._memberKeyByMessage = memberKeyByMessage
  view.transcript.linkedThread = memberKeyByMessage ~= nil
  return merged
end

-- True for a line that belongs to a linked thread, not the open one. Reacting
-- or replying to it would need that thread's own route.
function PaneMessages.IsMemberLine(view, message)
  local memberKeyByMessage = view._memberKeyByMessage
  return memberKeyByMessage ~= nil and memberKeyByMessage[message] ~= nil
end

ns.ConversationPaneMessages = PaneMessages
return PaneMessages
