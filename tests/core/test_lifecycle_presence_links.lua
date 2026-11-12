local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local Identity = require("WhisperMessenger.Model.Identity")

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

-- A Battle.net thread first keyed by the session's numeric account ID moves
-- to its BattleTag key once the friend list loads; its links must follow.
return function()
  -- test_orphan_bnet_rekey_moves_links_to_the_battletag_thread
  do
    local canonicalKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(912, { battleTag = "Friend#1234" }).contactKey)
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(912, nil).contactKey)
    local characterKey = "wow::WOW::friendchar"
    local accountState = {
      conversationLinks = {
        links = { [characterKey] = { primaryKey = numericKey, source = "auto", linkedAt = 1 } },
        unlinked = { ["wow::WOW::friendalt"] = numericKey },
      },
    }
    local Bootstrap = {
      runtime = {
        bnetApi = {},
        accountState = accountState,
        store = {
          conversations = {
            [numericKey] = { channel = "BN", bnetAccountID = 912, displayName = "912", messages = {} },
            [characterKey] = { channel = "WOW", messages = {} },
          },
        },
      },
    }

    Presence.handleBNetFriendEvent(Bootstrap, makeDeps({ ["Friend#1234"] = { bnetAccountID = 912 } }))

    local state = accountState.conversationLinks
    assert(Bootstrap.runtime.store.conversations[canonicalKey] ~= nil, "test precondition: thread re-keyed")
    assert(state.links[characterKey].primaryKey == canonicalKey, "link follows the re-keyed Battle.net thread")
    assert(state.unlinked["wow::WOW::friendalt"] == canonicalKey, "split pair follows the re-keyed Battle.net thread")
  end

  -- test_rekey_without_link_map_does_not_fail
  do
    local numericKey = Identity.BuildConversationKey(nil, Identity.FromBattleNet(913, nil).contactKey)
    local Bootstrap = {
      runtime = {
        bnetApi = {},
        store = { conversations = { [numericKey] = { channel = "BN", bnetAccountID = 913, messages = {} } } },
      },
    }
    Presence.handleBNetFriendEvent(Bootstrap, makeDeps({ ["Other#1"] = { bnetAccountID = 913 } }))
  end
end
