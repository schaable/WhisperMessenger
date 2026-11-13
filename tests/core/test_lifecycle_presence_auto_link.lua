local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar-area52"
local GUID = "Player-1-0000AAAA"

local function makeDeps(friendMap)
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return {
          ScanFriendList = function()
            return friendMap
          end,
        }
      end
      return require(modulePath)
    end,
  }
end

local function friendPlaying(guid)
  return {
    ["Jaina#1234"] = {
      bnetAccountID = 7,
      accountInfo = { bnetAccountID = 7, battleTag = "Jaina#1234", gameAccountInfo = { playerGuid = guid } },
    },
  }
end

-- The window is closed, so the scan rebuilds only the rows it changed.
local function makeBootstrap()
  local refreshes = {}
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      accountState = { settings = {} },
      store = {
        conversations = {
          [FRIEND] = { channel = "BN", battleTag = "Jaina#1234", messages = {} },
          [CHAR] = { channel = "WOW", guid = GUID, messages = {} },
        },
      },
      isWindowVisible = function()
        return false
      end,
      refreshWindow = function(_focusKey, dirtyKeys)
        refreshes[#refreshes + 1] = dirtyKeys or false
      end,
    },
  }
  return Bootstrap, refreshes
end

-- A friend-list scan links the character each friend is playing into that
-- friend's thread.
return function()
  -- test_friend_scan_links_the_character_a_friend_is_playing
  do
    local Bootstrap = makeBootstrap()
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friendPlaying(GUID)))
    local links = Bootstrap.runtime.accountState.conversationLinks
    assert(links and links.links[CHAR] and links.links[CHAR].primaryKey == FRIEND, "character joined the friend's thread")
  end

  -- test_friend_scan_rebuilds_the_rows_a_link_changed
  do
    local Bootstrap, refreshes = makeBootstrap()
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps(friendPlaying(GUID)))
    local dirtyKeys = refreshes[1]
    assert(dirtyKeys and dirtyKeys[CHAR] and dirtyKeys[FRIEND], "the character's and the friend's rows are rebuilt")
  end
end
