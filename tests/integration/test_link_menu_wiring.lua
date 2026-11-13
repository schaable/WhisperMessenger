local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

-- The window's link actions reach the contact row menu, which offers
-- "Link to Battle.net friend" and "Unlink character" through them.
return function()
  local conversations = {
    ["wow::WOW::jainachar"] = { displayName = "Jainachar", channel = "WOW", lastActivityAt = 1, messages = {} },
  }
  local linkActions = {
    targetsFor = function()
      return {}
    end,
    link = function() end,
    unlink = function() end,
  }
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = ContactsList.BuildItems(conversations),
    initialTabMode = "whispers",
    onSelectConversation = function(conversationKey, item)
      return { selectedContact = item, conversation = conversations[conversationKey] }
    end,
    linkActions = linkActions,
  })

  -- test_row_menu_receives_the_link_actions
  local rowActions
  local originalOpen = ContextMenu.Open
  rawset(ContextMenu, "Open", function(_item, _anchor, _onMarkUnread, _onUpdatePrefs, actions)
    rowActions = actions
    return true
  end)
  local row = window.contacts.rows[1]
  row.scripts.OnClick(row, "RightButton")
  rawset(ContextMenu, "Open", originalOpen)
  assert(rowActions ~= nil, "row menu opened")
  assert(rowActions.linkActions == linkActions, "row menu gets the window's link actions")
end
