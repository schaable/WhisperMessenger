local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One timeline for a thread (primary) and the threads linked into it
-- (members). members = { { key = memberKey, conversation = record }, ... }.
-- Pure: nothing is copied or written back, the stored records stay as they are.
local LinkedThread = {}

local function numberOr0(value)
  return type(value) == "number" and value or 0
end

local function sentAtOf(message)
  return numberOr0(type(message) == "table" and message.sentAt)
end

-- Message lists in tie-break order: the primary first, then members as given.
-- keys[i] is the member key of lists[i], false for the primary.
local function collectLists(primaryMessages, members)
  local lists = { type(primaryMessages) == "table" and primaryMessages or {} }
  local keys = { false }
  for _, entry in ipairs(members) do
    local conversation = type(entry) == "table" and entry.conversation
    if type(conversation) == "table" and type(conversation.messages) == "table" then
      lists[#lists + 1] = conversation.messages
      keys[#keys + 1] = entry.key
    end
  end
  return lists, keys
end

-- The list whose next line is the oldest; earlier lists win ties.
local function oldestHead(lists, positions)
  local best, bestAt
  for index, list in ipairs(lists) do
    local message = list[positions[index]]
    if message ~= nil and (best == nil or sentAtOf(message) < bestAt) then
      best, bestAt = index, sentAtOf(message)
    end
  end
  return best
end

-- Returns the merged list and { [message] = memberKey } for the member lines.
-- Without members it returns primaryMessages itself and nil. Each thread keeps
-- its own order; lines from different threads interleave by sentAt. The
-- merged list holds the stored message tables: the transcript diffs bubbles by
-- message identity.
function LinkedThread.Merge(primaryMessages, members)
  if type(members) ~= "table" or #members == 0 then
    return primaryMessages, nil
  end
  local lists, keys = collectLists(primaryMessages, members)
  local positions = {}
  for index = 1, #lists do
    positions[index] = 1
  end

  local merged, memberKeyByMessage = {}, {}
  local index = oldestHead(lists, positions)
  while index ~= nil do
    local message = lists[index][positions[index]]
    positions[index] = positions[index] + 1
    merged[#merged + 1] = message
    if keys[index] then
      memberKeyByMessage[message] = keys[index]
    end
    index = oldestHead(lists, positions)
  end
  return merged, memberKeyByMessage
end

-- Contact row values for the whole linked thread: unread counts added up,
-- activity and preview from the newest thread (the primary on a tie), and a
-- mention flag if any thread has an unread mention.
function LinkedThread.Summary(primaryConversation, members)
  local primary = type(primaryConversation) == "table" and primaryConversation or {}
  local newest = primary
  local unreadCount = numberOr0(primary.unreadCount)
  local hasUnreadMention = primary.hasUnreadMention == true

  for _, entry in ipairs(type(members) == "table" and members or {}) do
    local conversation = type(entry) == "table" and entry.conversation
    if type(conversation) == "table" then
      unreadCount = unreadCount + numberOr0(conversation.unreadCount)
      hasUnreadMention = hasUnreadMention or conversation.hasUnreadMention == true
      if numberOr0(conversation.lastActivityAt) > numberOr0(newest.lastActivityAt) then
        newest = conversation
      end
    end
  end

  return {
    unreadCount = unreadCount,
    lastActivityAt = numberOr0(newest.lastActivityAt),
    lastPreview = newest.lastPreview or "",
    hasUnreadMention = hasUnreadMention or nil,
    previewConversation = newest,
  }
end

ns.LinkedThread = LinkedThread
return LinkedThread
