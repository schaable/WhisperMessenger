local ChannelTag = require("WhisperMessenger.UI.ChatBubble.ChannelTag")
local Localization = require("WhisperMessenger.Locale.Localization")

local function line(direction, channel)
  return { direction = direction, kind = "user", channel = channel, playerName = "Jaina" }
end

local LINKED = { linkedThread = true }

-- The gold tag after a sender name: "- via Trade" on a channel post, and in a
-- linked thread the route of every line ("- via Battle.net" / "- via Whisper").
return function()
  Localization.Configure({ language = "enUS" })

  -- test_channel_post_names_its_channel
  do
    local post = { direction = "in", kind = "channel_context", channelLabel = "Trade" }
    assert(ChannelTag.Text(post, nil) == "- via Trade", "got " .. tostring(ChannelTag.Text(post, nil)))
  end

  -- test_plain_whisper_has_no_tag
  do
    assert(ChannelTag.Text(line("in", "BN"), nil) == nil, "a single thread needs no route tag")
  end

  -- test_linked_battle_net_line_says_battle_net
  do
    assert(ChannelTag.Text(line("in", "BN"), LINKED) == "- via Battle.net", "incoming Battle.net line")
    assert(ChannelTag.Text(line("out", "BN"), LINKED) == "- via Battle.net", "outgoing Battle.net line")
  end

  -- test_linked_character_line_says_whisper
  do
    assert(ChannelTag.Text(line("in", "WOW"), LINKED) == "- via Whisper", "incoming character line")
    assert(ChannelTag.Text(line("out", "WOW"), LINKED) == "- via Whisper", "outgoing character line")
  end

  -- test_linked_non_user_line_has_no_route_tag
  do
    local notice = { direction = "in", kind = "system", channel = "BN" }
    assert(ChannelTag.Text(notice, LINKED) == nil, "only chat lines carry a route")
  end
end
