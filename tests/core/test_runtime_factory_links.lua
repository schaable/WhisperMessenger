local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")

local function load(accountState)
  return RuntimeFactory.CreateRuntimeState(accountState, { activeConversationKey = nil }, "testplayer", {
    now = function()
      return 100
    end,
  })
end

-- Loading the runtime gives old saved variables an empty link map and drops
-- automatic links whose threads are both gone.
return function()
  -- test_old_saved_variables_get_an_empty_link_map
  do
    local accountState = { conversations = {} }
    load(accountState)
    local state = accountState.conversationLinks
    assert(type(state) == "table", "link map created")
    assert(type(state.links) == "table" and type(state.unlinked) == "table", "link map has both parts")
  end

  -- test_load_prunes_orphaned_auto_links_and_keeps_manual_ones
  do
    local accountState = {
      conversations = {},
      conversationLinks = {
        links = {
          ["wow::WOW::gone"] = { primaryKey = "bnet::BN::gone#1", source = "auto", linkedAt = 1 },
          ["wow::WOW::chosen"] = { primaryKey = "bnet::BN::gone#1", source = "manual", linkedAt = 1 },
        },
        unlinked = {},
      },
    }
    load(accountState)
    local links = accountState.conversationLinks.links
    assert(links["wow::WOW::gone"] == nil, "auto link without threads is dropped at load")
    assert(links["wow::WOW::chosen"] ~= nil, "manual link is kept at load")
  end
end
