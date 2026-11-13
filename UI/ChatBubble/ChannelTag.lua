local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The gold "- via ..." tag on a sender label: the channel of a channel post
-- ("- via Trade"), and in a linked thread the route of every chat line, so
-- Battle.net and character whispers stay apart in the one timeline.
local ChannelTag = {}

local function via(label)
  return "- " .. Localization.Text("via ") .. Localization.Text(label)
end

-- options.linkedThread: the line is shown in a linked thread. Returns the
-- tag text, or nil when the label needs none.
function ChannelTag.Text(message, options)
  if type(message.channelLabel) == "string" and message.channelLabel ~= "" then
    return via(message.channelLabel)
  end
  if not (options and options.linkedThread) or message.kind ~= "user" then
    return nil
  end
  return via(message.channel == "BN" and "Battle.net" or "Whisper")
end

ns.ChatBubbleChannelTag = ChannelTag
return ChannelTag
