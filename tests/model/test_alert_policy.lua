local AlertPolicy = require("WhisperMessenger.Model.AlertPolicy")

return function()
  -- test_regular_conversation_alerts
  assert(AlertPolicy.ShouldAlert({ channel = "WOW" }) == true, "an unmuted whisper alerts")

  -- test_unknown_conversation_alerts
  assert(AlertPolicy.ShouldAlert(nil) == true, "a message with no record yet still alerts")

  -- test_muted_conversation_is_silent
  assert(AlertPolicy.ShouldAlert({ channel = "BN", muted = true }) == false, "a muted conversation never alerts")

  -- test_message_request_is_silent_only_while_inbox_is_on
  local request = { channel = "WOW", request = true }
  assert(AlertPolicy.ShouldAlert(request, { requestsInbox = true }) == false, "a message request never alerts")
  assert(AlertPolicy.ShouldAlert(request, { requestsInbox = false }) == true, "inbox off: the flag is ignored")
  assert(AlertPolicy.ShouldAlert(request) == true, "no settings: the flag is ignored")

  -- test_a_linked_character_follows_its_friends_mute
  local friend, character = { channel = "BN", muted = true }, { channel = "WOW" }
  assert(AlertPolicy.ShouldAlert(character, nil, friend) == false, "muting the friend silences their characters")
  assert(AlertPolicy.ShouldAlert({ channel = "WOW", muted = true }, nil, { channel = "BN" }) == true, "the friend's thread decides")

  -- test_a_linked_request_stays_silent
  assert(AlertPolicy.ShouldAlert(request, { requestsInbox = true }, { channel = "BN" }) == false, "a request never alerts")
end
