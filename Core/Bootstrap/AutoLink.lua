local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationLinks = ns.ConversationLinks or require("WhisperMessenger.Model.ConversationLinks")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- Learns which Battle.net friend plays which character, and links that
-- character's thread into the friend's thread. Only links threads that both
-- exist, never one the player split up (ConversationLinks.Link "auto"), and
-- nothing while the account setting is off.
local AutoLink = {}

local CHARACTER_WHISPERS = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true }
local FRIEND_WHISPERS = { CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true }

local function linkState(runtime)
  local accountState = runtime.accountState
  local settings = type(accountState) == "table" and accountState.settings or nil
  if type(accountState) ~= "table" or (type(settings) == "table" and settings.autoLinkBattleNetCharacters == false) then
    return nil
  end
  return ConversationLinks.Ensure(accountState)
end

-- A secret value raises on any comparison, so check it first.
local function usableGuid(guid)
  return not SecretValue.Is(guid) and type(guid) == "string" and guid ~= ""
end

-- The friend's thread key, from the friend's account info.
local function friendKey(accountInfo)
  local battleTag = type(accountInfo) == "table" and accountInfo.battleTag or nil
  if SecretValue.Is(battleTag) or type(battleTag) ~= "string" or battleTag == "" then
    return nil
  end
  return Identity.BuildConversationKey(nil, Identity.FromBattleNet(accountInfo.bnetAccountID, accountInfo).contactKey)
end

-- The GUID of the character a friend is playing, when usable.
local function playingGuid(accountInfo)
  local gameAccountInfo = type(accountInfo) == "table" and accountInfo.gameAccountInfo or nil
  local guid = type(gameAccountInfo) == "table" and gameAccountInfo.playerGuid or nil
  return usableGuid(guid) and guid or nil
end

-- A thread that joins the open thread opens with it, and its lines are seen.
local function followOpenThread(runtime, memberKey, primaryKey)
  if runtime.activeConversationKey == memberKey then
    runtime.activeConversationKey = primaryKey
    if type(runtime.characterState) == "table" then
      runtime.characterState.activeConversationKey = primaryKey
    end
  end
  if type(runtime.isConversationOpen) == "function" and runtime.isConversationOpen(memberKey) then
    Store.MarkRead(runtime.store, memberKey)
    Store.MarkRead(runtime.store, primaryKey)
  end
end

-- Returns true when the pair is newly linked.
local function linkPair(runtime, state, memberKey, primaryKey)
  local conversations = runtime.store.conversations
  if conversations[memberKey] == nil or conversations[primaryKey] == nil or state.links[memberKey] ~= nil then
    return false
  end
  local now = type(runtime.now) == "function" and runtime.now() or nil
  if not ConversationLinks.Link(state, memberKey, primaryKey, ConversationLinks.SOURCE_AUTO, now) then
    return false
  end
  followOpenThread(runtime, memberKey, primaryKey)
  return true
end

-- { [guid] = thread keys } over every thread with a usable character GUID.
local function threadsByGuid(conversations)
  local index = {}
  for key, conversation in pairs(conversations) do
    local guid = conversation.guid
    if usableGuid(guid) then
      local keys = index[guid] or {}
      index[guid] = keys
      keys[#keys + 1] = key
    end
  end
  return index
end

-- Keys of the threads with this character GUID.
local function threadsWithGuid(conversations, guid)
  local keys = {}
  for key, conversation in pairs(conversations) do
    if usableGuid(conversation.guid) and conversation.guid == guid then
      keys[#keys + 1] = key
    end
  end
  return keys
end

-- Links each thread of the character this friend is playing. Link itself
-- turns down the friend's own thread, which carries the same GUID.
local function linkCharacterThreads(runtime, state, keys, primaryKey, changedKeys)
  for _, key in ipairs(keys or {}) do
    if linkPair(runtime, state, key, primaryKey) and changedKeys then
      changedKeys[key] = true
      changedKeys[primaryKey] = true
    end
  end
end

local function friendPlaying(runtime, guid)
  local bnetApi = runtime.bnetApi
  if type(bnetApi) ~= "table" or type(bnetApi.GetAccountInfoByGUID) ~= "function" then
    return nil
  end
  local ok, accountInfo = pcall(bnetApi.GetAccountInfoByGUID, guid)
  return ok and accountInfo or nil
end

-- After EventRouter stored a whisper. payload is LivePayload's; result is
-- the stored conversation (nil when nothing was stored).
function AutoLink.AfterWhisper(runtime, eventName, payload, result)
  local conversationKey = type(result) == "table" and result.conversationKey or nil
  if conversationKey == nil or type(payload) ~= "table" or not (CHARACTER_WHISPERS[eventName] or FRIEND_WHISPERS[eventName]) then
    return
  end
  local state = type(runtime.store) == "table" and linkState(runtime) or nil
  if state == nil then
    return
  end
  if CHARACTER_WHISPERS[eventName] then
    -- Already linked: auto never re-points it, so there is nothing to learn.
    if state.links[conversationKey] ~= nil then
      return
    end
    local primaryKey = usableGuid(payload.guid) and friendKey(friendPlaying(runtime, payload.guid)) or nil
    if primaryKey then
      linkPair(runtime, state, conversationKey, primaryKey)
    end
    return
  end
  local guid = playingGuid(payload.accountInfo)
  if guid then
    linkCharacterThreads(runtime, state, threadsWithGuid(runtime.store.conversations, guid), conversationKey)
  end
end

-- friendMap: BNetResolver.ScanFriendList's { [battleTag] = { accountInfo } }.
-- Adds the keys of newly linked threads to changedKeys.
function AutoLink.FromFriendScan(runtime, friendMap, changedKeys)
  local state = type(runtime.store) == "table" and type(friendMap) == "table" and linkState(runtime) or nil
  if state == nil then
    return
  end
  local index
  for _, friend in pairs(friendMap) do
    local accountInfo = type(friend) == "table" and friend.accountInfo or nil
    local guid = playingGuid(accountInfo)
    local primaryKey = guid and friendKey(accountInfo)
    if primaryKey and runtime.store.conversations[primaryKey] ~= nil then
      index = index or threadsByGuid(runtime.store.conversations)
      linkCharacterThreads(runtime, state, index[guid], primaryKey, changedKeys)
    end
  end
end

ns.BootstrapAutoLink = AutoLink
return AutoLink
