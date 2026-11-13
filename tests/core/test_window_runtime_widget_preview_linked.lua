local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar"

local function setup(friendAt, characterAt)
  local friend = { displayName = "Jaina#1234", channel = "BN", lastIncomingPreview = "over bnet", lastIncomingAt = friendAt }
  local character = {
    displayName = "Jainachar",
    channel = "WOW",
    classTag = "MAGE",
    lastIncomingPreview = "from my mage",
    lastIncomingAt = characterAt,
    lastIncomingSender = "Jainachar",
  }
  local accountState = { conversations = { [FRIEND] = friend, [CHAR] = character } }
  local preview = WidgetPreview.Create({ accountState = accountState, runtimeStore = { conversations = {} } })
  local contacts = {
    { conversationKey = FRIEND, displayName = "Jaina#1234", channel = "BN", linkedMembers = { { key = CHAR, conversation = character } } },
  }
  return preview, contacts, friend
end

-- A friend's row also shows their linked characters' whispers, so those pop
-- the message preview too, under the friend's mute.
return function()
  -- test_a_linked_characters_newer_whisper_pops_the_preview
  do
    local preview, contacts = setup(10, 30)
    local latest = preview.buildLatestIncomingPreview(contacts)
    assert(latest ~= nil and latest.messageText == "from my mage", "the character's whisper shows")
    assert(latest.senderName == "Jainachar" and latest.classTag == "MAGE", "named and colored as the character")
    assert(latest.conversationKey == FRIEND, "clicking it opens the friend's thread")
  end

  -- test_the_friends_newer_whisper_still_wins
  do
    local preview, contacts = setup(40, 30)
    assert(preview.buildLatestIncomingPreview(contacts).messageText == "over bnet", "newest whisper of the thread")
  end

  -- test_a_muted_friend_hides_the_characters_whisper
  do
    local preview, contacts, friend = setup(10, 30)
    friend.muted = true
    assert(preview.buildLatestIncomingPreview(contacts) == nil, "the friend's mute covers their characters")
  end

  -- test_opening_the_window_acknowledges_the_characters_whisper
  do
    local preview, contacts = setup(10, 30)
    preview.acknowledgeLatestWidgetPreview(contacts)
    assert(preview.buildLatestIncomingPreview(contacts) == nil, "already seen, so no pop-up")
  end
end
