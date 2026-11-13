local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Links between conversations of the same person: a character thread (member)
-- shown inside a Battle.net friend's thread (primary). Saved per account as
--   links    = { [memberKey] = { primaryKey, source = "auto"|"manual", linkedAt } }
--   unlinked = { [memberKey] = primaryKey }  -- pairs the player split up
-- Records never move: a link only groups the two threads for display, so
-- unlinking loses nothing. Grouping applies while both threads exist.
local ConversationLinks = {}

local MEMBER_PREFIX = "wow::"
local PRIMARY_PREFIX = "bnet::"
local SOURCE_MANUAL = "manual"

ConversationLinks.SOURCE_AUTO = "auto"
ConversationLinks.SOURCE_MANUAL = SOURCE_MANUAL

local function startsWith(text, prefix)
  return type(text) == "string" and string.sub(text, 1, #prefix) == prefix
end

local function isKey(value)
  return type(value) == "string" and value ~= ""
end

function ConversationLinks.Ensure(accountState)
  local state = accountState.conversationLinks
  if type(state) ~= "table" then
    state = {}
    accountState.conversationLinks = state
  end
  if type(state.links) ~= "table" then
    state.links = {}
  end
  if type(state.unlinked) ~= "table" then
    state.unlinked = {}
  end
  return state
end

-- The one place that decides which threads may be linked. Everything else
-- asks the link map, so a later kind of link only has to change this.
function ConversationLinks.CanLink(memberKey, primaryKey)
  return memberKey ~= primaryKey and startsWith(memberKey, MEMBER_PREFIX) and startsWith(primaryKey, PRIMARY_PREFIX)
end

local function isPrimary(state, key)
  for _, entry in pairs(state.links) do
    if type(entry) == "table" and entry.primaryKey == key then
      return true
    end
  end
  return false
end

-- A character is linked to one friend at most. "auto" never re-points an
-- already-linked character to another friend and never relinks a pair the
-- player split up; "manual" can do both. Returns true when the pair is linked.
function ConversationLinks.Link(state, memberKey, primaryKey, source, now)
  if not ConversationLinks.CanLink(memberKey, primaryKey) then
    return false
  end
  if state.links[primaryKey] ~= nil or isPrimary(state, memberKey) then
    return false
  end
  local existing = state.links[memberKey]
  local manual = source == SOURCE_MANUAL
  if type(existing) == "table" and existing.primaryKey == primaryKey and not manual then
    return true
  end
  if not manual and (existing ~= nil or state.unlinked[memberKey] == primaryKey) then
    return false
  end
  state.links[memberKey] = { primaryKey = primaryKey, source = source, linkedAt = now }
  if manual then
    state.unlinked[memberKey] = nil
  end
  return true
end

-- Returns the primary the member was linked to, or nil.
function ConversationLinks.Unlink(state, memberKey)
  local entry = state.links[memberKey]
  if type(entry) ~= "table" then
    return nil
  end
  state.links[memberKey] = nil
  state.unlinked[memberKey] = entry.primaryKey
  return entry.primaryKey
end

-- The thread a key is shown in: its primary while both threads exist,
-- otherwise the key itself.
function ConversationLinks.PrimaryOf(state, conversations, key)
  local entry = state.links[key]
  if type(entry) ~= "table" or conversations[key] == nil or conversations[entry.primaryKey] == nil then
    return key
  end
  return entry.primaryKey
end

-- Every grouped thread in one pass: { [primaryKey] = sorted member keys }.
-- Same rule as PrimaryOf: a pair groups only while both threads exist.
function ConversationLinks.Groups(state, conversations)
  local groups = {}
  for memberKey, entry in pairs(state.links) do
    local primaryKey = type(entry) == "table" and entry.primaryKey
    if primaryKey and conversations[memberKey] ~= nil and conversations[primaryKey] ~= nil then
      local members = groups[primaryKey] or {}
      groups[primaryKey] = members
      members[#members + 1] = memberKey
    end
  end
  for _, members in pairs(groups) do
    table.sort(members)
  end
  return groups
end

-- Member keys shown inside primaryKey's thread, sorted.
function ConversationLinks.MembersOf(state, conversations, primaryKey)
  return ConversationLinks.Groups(state, conversations)[primaryKey] or {}
end

-- Moves map[oldKey] to map[newKey]; an entry already on newKey wins.
local function moveMemberKeys(map, mappings)
  local moves = {}
  for oldKey, value in pairs(map) do
    if mappings[oldKey] ~= nil then
      moves[oldKey] = value
    end
  end
  for oldKey in pairs(moves) do
    map[oldKey] = nil
  end
  for oldKey, value in pairs(moves) do
    local newKey = mappings[oldKey]
    if map[newKey] == nil then
      map[newKey] = value
    end
  end
end

-- mappings: { [oldKey] = newKey } from a conversation re-key.
function ConversationLinks.Rekey(state, mappings)
  if type(mappings) ~= "table" then
    return
  end
  moveMemberKeys(state.links, mappings)
  moveMemberKeys(state.unlinked, mappings)
  for _, entry in pairs(state.links) do
    if type(entry) == "table" and mappings[entry.primaryKey] ~= nil then
      entry.primaryKey = mappings[entry.primaryKey]
    end
  end
  for memberKey, primaryKey in pairs(state.unlinked) do
    if mappings[primaryKey] ~= nil then
      state.unlinked[memberKey] = mappings[primaryKey]
    end
  end
end

-- Load-time cleanup. A manual link is the player's choice and outlives its
-- threads (they expire quickly by default); an auto link can be learned
-- again, so it goes once neither thread is left.
function ConversationLinks.Prune(state, conversations)
  for memberKey, entry in pairs(state.links) do
    local valid = type(entry) == "table" and isKey(entry.primaryKey)
    local orphanedAuto = valid and entry.source ~= SOURCE_MANUAL and conversations[memberKey] == nil and conversations[entry.primaryKey] == nil
    if not valid or orphanedAuto then
      state.links[memberKey] = nil
    end
  end
  for memberKey, primaryKey in pairs(state.unlinked) do
    if not isKey(primaryKey) then
      state.unlinked[memberKey] = nil
    end
  end
end

ns.ConversationLinks = ConversationLinks
return ConversationLinks
