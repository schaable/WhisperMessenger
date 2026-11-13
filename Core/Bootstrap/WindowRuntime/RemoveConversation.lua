local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local GameWhisperTab = ns.BootstrapWindowRuntimeGameWhisperTab or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GameWhisperTab")
local RuntimeLinks = ns.BootstrapRuntimeLinks or require("WhisperMessenger.Core.Bootstrap.RuntimeLinks")

-- Removing a row removes the thread it shows: its conversation and every
-- conversation linked into it. Links stay, so new chats with both group again.
local RemoveConversation = {}

local function removeOne(runtime, accountState, characterState, key)
  local conversation = Store.Find(runtime.store, key)
  MessageReactions.ClearConversation(runtime, key)
  Store.Remove(runtime.store, key)
  if type(accountState.settings) == "table" and accountState.settings.closeGameWhisperTab == true then
    GameWhisperTab.CloseFor(key, conversation)
  end
  if runtime.activeConversationKey == key then
    runtime.activeConversationKey = nil
    characterState.activeConversationKey = nil
  end
end

function RemoveConversation.Thread(runtime, accountState, characterState, key)
  -- Members group only while the friend's thread exists: list them first.
  local memberKeys = RuntimeLinks.MembersOf(runtime, key)
  removeOne(runtime, accountState, characterState, key)
  for _, memberKey in ipairs(memberKeys) do
    removeOne(runtime, accountState, characterState, memberKey)
  end
end

ns.BootstrapWindowRuntimeRemoveConversation = RemoveConversation
return RemoveConversation
