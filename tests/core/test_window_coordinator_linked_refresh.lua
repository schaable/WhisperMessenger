local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"

local function makeWindow()
  local shown = false
  local window = { frame = {}, selectionRefreshes = 0, contactRefreshes = 0 }
  function window.frame:IsShown()
    return shown
  end
  function window.frame:Show()
    shown = true
  end
  window.refreshSelection = function()
    window.selectionRefreshes = window.selectionRefreshes + 1
  end
  window.refreshContacts = function()
    window.contactRefreshes = window.contactRefreshes + 1
  end
  return window
end

-- A new line in a linked character thread changes what the open friend
-- thread shows, so the open pane refreshes, not just the contact rows.
return function()
  -- test_linked_character_line_refreshes_the_open_friend_thread
  do
    local window = makeWindow()
    local runtime = {
      availabilityByGUID = {},
      availabilityRequestedAt = {},
      sendStatusByConversation = {},
      now = function()
        return 1000
      end,
      chatApi = {},
      activeConversationKey = FRIEND,
      accountState = {
        conversationLinks = { links = { [CHAR] = { primaryKey = FRIEND, source = "auto", linkedAt = 1 } }, unlinked = {} },
      },
      store = { conversations = { [FRIEND] = { channel = "BN" }, [CHAR] = { channel = "WOW" } } },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return { { channel = "BN", conversationKey = FRIEND } }
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return true
      end,
      requestAvailability = function() end,
    })

    window.frame:Show()
    coord.refreshWindow(CHAR)
    assert(window.selectionRefreshes == 1, "the open friend thread is refreshed")
    assert(window.contactRefreshes == 0, "not just the contact rows")
  end
end
