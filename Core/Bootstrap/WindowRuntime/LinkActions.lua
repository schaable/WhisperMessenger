local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationLinks = ns.ConversationLinks or require("WhisperMessenger.Model.ConversationLinks")
local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")

-- The contact menu's link entries (UI/ContactsList/LinkMenuEntry.lua):
--   targetsFor(item)        -> { { key, conversation } } the row can join
--   link(item, primaryKey)  -- links the row's thread into primaryKey's thread
--   unlink(item, memberKey) -- splits memberKey out of the row's thread
-- Links made here are manual: auto-linking never undoes them.
local LinkActions = {}

-- The saved link map, created on first use; nil without a store to link in.
local function linkState(runtime)
  if type(runtime.accountState) ~= "table" or type(runtime.store) ~= "table" or type(runtime.store.conversations) ~= "table" then
    return nil
  end
  return ConversationLinks.Ensure(runtime.accountState)
end

local function currentTime(runtime)
  return type(runtime.now) == "function" and runtime.now() or nil
end

function LinkActions.Create(options)
  local runtime = options.runtime or {}
  local refreshWindow = options.refreshWindow or function() end
  local selectConversation = options.selectConversation or function(_conversationKey) end

  local function targetsFor(item)
    local state = linkState(runtime)
    if state == nil or type(item) ~= "table" then
      return {}
    end
    local conversations = runtime.store.conversations
    local targets = {}
    for _, key in ipairs(ConversationLinks.Targets(state, conversations, item.conversationKey)) do
      targets[#targets + 1] = { key = key, conversation = conversations[key] }
    end
    return targets
  end

  local function link(item, primaryKey)
    local state = linkState(runtime)
    local memberKey = type(item) == "table" and item.conversationKey or nil
    if state == nil or not ConversationLinks.Link(state, memberKey, primaryKey, ConversationLinks.SOURCE_MANUAL, currentTime(runtime)) then
      return
    end
    -- Linking it to a friend says the player knows this character.
    MessageRequests.Accept(runtime.store, memberKey)
    -- Its row is gone now; keep the player in the thread it joined.
    if runtime.activeConversationKey == memberKey then
      selectConversation(primaryKey)
      return
    end
    refreshWindow()
  end

  local function unlink(_item, memberKey)
    local state = linkState(runtime)
    if state == nil or ConversationLinks.Unlink(state, memberKey) == nil then
      return
    end
    refreshWindow()
  end

  return { targetsFor = targetsFor, link = link, unlink = unlink }
end

ns.BootstrapWindowRuntimeLinkActions = LinkActions
return LinkActions
