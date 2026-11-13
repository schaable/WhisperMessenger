local RuntimeBindings = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"

-- A whisper from a linked character while the friend's thread is open is on
-- screen, so it is stored as read (the router asks isConversationOpen).
return function()
  -- test_linked_character_counts_as_open_while_the_friend_thread_is
  do
    local runtime = {
      activeConversationKey = FRIEND,
      accountState = {
        conversationLinks = { links = { [CHAR] = { primaryKey = FRIEND, source = "auto", linkedAt = 1 } }, unlinked = {} },
      },
      store = { conversations = { [FRIEND] = {}, [CHAR] = {} } },
    }
    RuntimeBindings.Apply({
      runtime = runtime,
      isWindowVisible = function()
        return true
      end,
    })
    assert(runtime.isConversationOpen(CHAR) == true, "linked character is open with its friend")
    assert(runtime.isConversationOpen("wow::WOW::someone") == false, "anyone else is not")
  end
end
