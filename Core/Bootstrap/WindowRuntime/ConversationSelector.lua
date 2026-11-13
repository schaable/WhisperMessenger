local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")
local RuntimeLinks = ns.BootstrapRuntimeLinks or require("WhisperMessenger.Core.Bootstrap.RuntimeLinks")

local ConversationSelector = {}

-- The oldest of the last `unreadCount` incoming user messages; when fewer are
-- stored, the oldest stored one. nil when there is none.
local function firstUnreadMessage(conversation)
  local remaining = conversation.unreadCount or 0
  if remaining <= 0 or type(conversation.messages) ~= "table" then
    return nil
  end
  local found
  for index = #conversation.messages, 1, -1 do
    local message = conversation.messages[index]
    if message.kind == "user" and message.direction == "in" then
      found = message
      remaining = remaining - 1
      if remaining == 0 then
        break
      end
    end
  end
  return found
end

-- A linked thread's first unread line: the oldest of each thread's own first
-- unread line (the opened thread wins a tie).
local function firstUnreadInThread(runtime, conversation, memberKeys)
  local first = conversation and firstUnreadMessage(conversation) or nil
  for _, memberKey in ipairs(memberKeys) do
    local candidate = firstUnreadMessage(runtime.store.conversations[memberKey])
    if candidate ~= nil and (first == nil or (candidate.sentAt or 0) < (first.sentAt or 0)) then
      first = candidate
    end
  end
  return first
end

-- "New messages" divider (session only, never saved): set when a conversation
-- opens with unread messages, kept while it stays selected, dropped when
-- another conversation opens.
local function updateUnreadDivider(runtime, conversationKey, conversation, memberKeys)
  local message = firstUnreadInThread(runtime, conversation, memberKeys)
  if message ~= nil then
    runtime.unreadDivider = { conversationKey = conversationKey, message = message }
  elseif runtime.unreadDivider and runtime.unreadDivider.conversationKey ~= conversationKey then
    runtime.unreadDivider = nil
  end
end

-- Callers that open a whisper force the Whispers tab first; a message
-- request lives in the Requests tab, so switch there instead. Runs before
-- the selection is stored: the tab swap restores that tab's own selection.
local function showRequestsTab(runtime, conversation)
  local window = runtime.window
  if window == nil or type(window.getTabMode) ~= "function" or type(window.setTabMode) ~= "function" then
    return
  end
  local settings = runtime.accountState and runtime.accountState.settings
  if window.getTabMode() ~= "requests" and MessageRequests.IsRequest(conversation, settings) then
    window.setTabMode("requests")
  end
end

function ConversationSelector.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local characterState = options.characterState or {}
  local markConversationRead = options.markConversationRead
  local presenceCache = options.presenceCache or {}
  local requestAvailability = options.requestAvailability
  local refreshWindow = options.refreshWindow or function()
    return nil
  end

  local selector = {}

  function selector.selectConversation(conversationKey)
    local store = runtime.store
    -- A linked character's thread is shown inside its friend's thread.
    conversationKey = RuntimeLinks.PrimaryOf(runtime, conversationKey)
    local memberKeys = RuntimeLinks.MembersOf(runtime, conversationKey)
    local conversation = conversationKey ~= nil and store.conversations[conversationKey] or nil
    showRequestsTab(runtime, conversation)

    runtime.activeConversationKey = conversationKey
    characterState.activeConversationKey = conversationKey
    updateUnreadDivider(runtime, conversationKey, conversation, memberKeys)

    if conversation ~= nil then
      markConversationRead(store, conversationKey)
      for _, memberKey in ipairs(memberKeys) do
        markConversationRead(store, memberKey)
      end

      if conversation.guid then
        presenceCache.RefreshPresence(conversation.guid)
      end
      if conversation.channel == "WOW" and conversation.guid then
        requestAvailability(runtime.chatApi, conversation.guid)
      end
    end

    return refreshWindow()
  end

  return selector
end

ns.BootstrapWindowRuntimeConversationSelector = ConversationSelector

return ConversationSelector
