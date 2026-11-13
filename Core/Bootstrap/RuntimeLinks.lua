local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationLinks = ns.ConversationLinks or require("WhisperMessenger.Model.ConversationLinks")

-- Link lookups against the live runtime: the account's saved link map and the
-- conversation store. A runtime without either behaves as if nothing is linked.
local RuntimeLinks = {}

local function sources(runtime)
  if type(runtime) ~= "table" then
    return nil
  end
  local state = runtime.accountState and runtime.accountState.conversationLinks
  local conversations = runtime.store and runtime.store.conversations
  if type(state) ~= "table" or type(state.links) ~= "table" or type(conversations) ~= "table" then
    return nil
  end
  return state, conversations
end

-- The thread a key is shown in (the key itself when it is not linked).
function RuntimeLinks.PrimaryOf(runtime, conversationKey)
  local state, conversations = sources(runtime)
  if state == nil or conversationKey == nil then
    return conversationKey
  end
  return ConversationLinks.PrimaryOf(state, conversations, conversationKey)
end

-- The record of the thread a key is shown in; nil without one.
function RuntimeLinks.PrimaryConversation(runtime, conversationKey)
  local primaryKey = RuntimeLinks.PrimaryOf(runtime, conversationKey)
  local conversations = primaryKey ~= nil and type(runtime) == "table" and runtime.store and runtime.store.conversations
  return type(conversations) == "table" and conversations[primaryKey] or nil
end

-- Sorted keys of the threads shown inside primaryKey's thread.
function RuntimeLinks.MembersOf(runtime, primaryKey)
  local state, conversations = sources(runtime)
  if state == nil or primaryKey == nil then
    return {}
  end
  return ConversationLinks.MembersOf(state, conversations, primaryKey)
end

-- True when both keys are shown in the same thread.
function RuntimeLinks.SameThread(runtime, leftKey, rightKey)
  return RuntimeLinks.PrimaryOf(runtime, leftKey) == RuntimeLinks.PrimaryOf(runtime, rightKey)
end

ns.BootstrapRuntimeLinks = RuntimeLinks
return RuntimeLinks
