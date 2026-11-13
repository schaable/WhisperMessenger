local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")

-- "Link to Battle.net friend" on a row that can join a friend's thread, and
-- "Unlink character" on a friend's row that has linked characters; each lists
-- one entry per thread, by name. rowActions.linkActions: { targetsFor(item),
-- link(item, primaryKey), unlink(item, memberKey) }. targetsFor and
-- item.linkedMembers both give { key, conversation } entries.
local LinkMenuEntry = {}

local function nameOf(entry)
  local conversation = type(entry.conversation) == "table" and entry.conversation or {}
  return conversation.nickname or DisplayName.Format(conversation.displayName) or entry.key
end

local function byName(left, right)
  local leftName, rightName = string.lower(left.label), string.lower(right.label)
  if leftName ~= rightName then
    return leftName < rightName
  end
  return left.key < right.key
end

local function choicesFor(entries)
  local choices = {}
  for _, entry in ipairs(entries) do
    choices[#choices + 1] = { key = entry.key, label = nameOf(entry) }
  end
  table.sort(choices, byName)
  return choices
end

local function addSubmenu(rootDescription, title, entries, onPick)
  if type(entries) ~= "table" or #entries == 0 then
    return
  end
  local submenu = rootDescription:CreateButton(Localization.Text(title))
  if submenu == nil or type(submenu.CreateButton) ~= "function" then
    return
  end
  for _, choice in ipairs(choicesFor(entries)) do
    local key = choice.key
    submenu:CreateButton(choice.label, function()
      onPick(key)
    end)
  end
end

function LinkMenuEntry.Add(rootDescription, item, rowActions)
  local actions = type(rowActions) == "table" and rowActions.linkActions
  if type(actions) ~= "table" then
    return
  end
  addSubmenu(rootDescription, "Link to Battle.net friend", actions.targetsFor(item), function(primaryKey)
    actions.link(item, primaryKey)
  end)
  addSubmenu(rootDescription, "Unlink character", item.linkedMembers, function(memberKey)
    actions.unlink(item, memberKey)
  end)
end

ns.ContactsListLinkMenuEntry = LinkMenuEntry
return LinkMenuEntry
