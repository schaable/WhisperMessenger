local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The one place that decides whether an incoming whisper may alert the
-- player: sound, widget popup, taskbar flash and auto-open all ask here.
-- Group mentions bypass it and alert directly (they break through mute).
local AlertPolicy = {}

local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")

-- settings: account settings; a message request (only while the Requests
-- inbox is on) never alerts. thread: the conversation the message shows in
-- when that is another one (a linked character's friend); its Mute decides,
-- as that is the row the player mutes.
function AlertPolicy.ShouldAlert(conversation, settings, thread)
  if type(conversation) ~= "table" then
    return true
  end
  if MessageRequests.IsRequest(conversation, settings) then
    return false
  end
  if type(thread) ~= "table" then
    thread = conversation
  end
  return thread.muted ~= true
end

ns.AlertPolicy = AlertPolicy
return AlertPolicy
