local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- A character's row offers "Link to Battle.net friend" with one entry per
-- friend it can join; a friend's row with linked characters offers "Unlink
-- character" with one entry per character.

local LINK = "Link to Battle.net friend"
local UNLINK = "Unlink character"
local FRIEND = "bnet::BN::jaina#1234"
local OTHER_FRIEND = "bnet::BN::thrall#5678"
local CHAR = "wow::WOW::jainachar"

local function newDescription(text, callback)
  local description = { text = text, callback = callback, buttons = {} }
  function description:CreateButton(childText, childCallback)
    local child = newDescription(childText, childCallback)
    self.buttons[#self.buttons + 1] = child
    return child
  end
  return description
end

local function findButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

local function labels(description)
  local list = {}
  for _, button in ipairs(description.buttons) do
    list[#list + 1] = button.text
  end
  return table.concat(list, ",")
end

local function characterRow()
  return { channel = "WOW", displayName = "Jainachar", conversationKey = CHAR }
end

local function friendRow()
  return {
    channel = "BN",
    displayName = "Jaina",
    conversationKey = FRIEND,
    linkedMembers = { { key = CHAR, conversation = { displayName = "Jainachar" } } },
  }
end

return function()
  Localization.Configure({ language = "enUS" })
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  local saved = { Menu = _G.Menu, UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu }
  local modifiers = {}
  local openedContext
  _G.Menu = {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  }
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    openedContext = contextData
  end)

  local calls = {}
  local targets = {
    { key = OTHER_FRIEND, conversation = { displayName = "Thrall" } },
    { key = FRIEND, conversation = { displayName = "Jaina" } },
  }
  local linkActions = {
    targetsFor = function()
      return targets
    end,
    link = function(item, primaryKey)
      calls[#calls + 1] = { action = "link", item = item, key = primaryKey }
    end,
    unlink = function(item, memberKey)
      calls[#calls + 1] = { action = "unlink", item = item, key = memberKey }
    end,
  }

  local function menuFor(item, rowActions)
    ContextMenu.Open(item, anchor, function() end, nil, rowActions)
    local root = newDescription()
    local tag = item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"
    modifiers[tag](anchor, root, openedContext)
    return root
  end

  -- test_character_row_lists_the_friends_it_can_join_by_name
  do
    local submenu = findButton(menuFor(characterRow(), { linkActions = linkActions }), LINK)
    assert(submenu ~= nil, "character row offers " .. LINK)
    assert(labels(submenu) == "Jaina,Thrall", "friends sorted by name, got " .. labels(submenu))
  end

  -- test_picking_a_friend_links_the_row_to_it
  do
    calls = {}
    local item = characterRow()
    local submenu = findButton(menuFor(item, { linkActions = linkActions }), LINK)
    findButton(submenu, "Jaina").callback()
    assert(#calls == 1 and calls[1].action == "link", "one link call")
    assert(calls[1].item == item and calls[1].key == FRIEND, "links this row to the picked friend")
  end

  -- test_a_friends_nickname_names_it
  do
    targets = { { key = FRIEND, conversation = { displayName = "Jaina", nickname = "Jay" } } }
    local submenu = findButton(menuFor(characterRow(), { linkActions = linkActions }), LINK)
    assert(labels(submenu) == "Jay", "the nickname wins, got " .. labels(submenu))
  end

  -- test_no_link_entry_without_a_friend_to_join
  do
    targets = {}
    assert(findButton(menuFor(characterRow(), { linkActions = linkActions }), LINK) == nil, "nothing to link to")
  end

  -- test_friend_row_lists_its_linked_characters
  do
    local submenu = findButton(menuFor(friendRow(), { linkActions = linkActions }), UNLINK)
    assert(submenu ~= nil, "friend row offers " .. UNLINK)
    assert(labels(submenu) == "Jainachar", "one entry per character, got " .. labels(submenu))
  end

  -- test_picking_a_character_unlinks_it
  do
    calls = {}
    local item = friendRow()
    local submenu = findButton(menuFor(item, { linkActions = linkActions }), UNLINK)
    findButton(submenu, "Jainachar").callback()
    assert(#calls == 1 and calls[1].action == "unlink", "one unlink call")
    assert(calls[1].item == item and calls[1].key == CHAR, "unlinks the picked character")
  end

  -- test_no_link_entries_without_link_actions
  do
    targets = { { key = FRIEND, conversation = { displayName = "Jaina" } } }
    assert(findButton(menuFor(characterRow(), {}), LINK) == nil, "no link entry")
    assert(findButton(menuFor(friendRow(), {}), UNLINK) == nil, "no unlink entry")
  end

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
end
