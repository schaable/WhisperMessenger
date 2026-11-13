local LinkedThread = require("WhisperMessenger.Model.LinkedThread")

local CHAR = "wow::WOW::jainachar"
local ALT = "wow::WOW::jainaalt-argentdawn"

local function message(text, sentAt)
  return { text = text, sentAt = sentAt, direction = "in", kind = "user" }
end

local function member(key, conversation)
  return { key = key, conversation = conversation }
end

local function texts(messages)
  local result = {}
  for index, entry in ipairs(messages) do
    result[index] = entry.text
  end
  return table.concat(result, ",")
end

-- A Battle.net friend's thread (primary) shows the whispers of their linked
-- character threads (members) in one timeline. Records never move: the merged
-- list holds the stored message tables, so bubbles keep their identity.
return function()
  -- test_merge_without_members_returns_the_primary_list_itself
  do
    local primary = { message("a", 1) }
    local merged, memberKeyByMessage = LinkedThread.Merge(primary, {})
    assert(merged == primary, "nothing to merge: the stored list is returned")
    assert(memberKeyByMessage == nil, "nothing to merge: no member lines")
  end

  -- test_merge_orders_messages_by_sent_time
  do
    local primary = { message("bn1", 10), message("bn2", 30) }
    local char = { messages = { message("char1", 20), message("char2", 40) } }
    local merged = LinkedThread.Merge(primary, { member(CHAR, char) })
    assert(texts(merged) == "bn1,char1,bn2,char2", "got " .. texts(merged))
  end

  -- test_merge_reuses_the_stored_message_tables
  do
    local bnLine = message("bn", 10)
    local charLine = message("char", 20)
    local merged = LinkedThread.Merge({ bnLine }, { member(CHAR, { messages = { charLine } }) })
    assert(merged[1] == bnLine and merged[2] == charLine, "same tables, not copies")
  end

  -- test_merge_leaves_the_stored_lists_untouched
  do
    local primary = { message("bn", 10) }
    local char = { messages = { message("char", 5) } }
    local merged = LinkedThread.Merge(primary, { member(CHAR, char) })
    assert(merged ~= primary and merged ~= char.messages, "a new list")
    assert(#primary == 1 and #char.messages == 1, "stored lists keep their lines")
  end

  -- test_merge_puts_primary_first_then_members_in_order_on_equal_sent_time
  do
    local primary = { message("bn", 10) }
    local char = { messages = { message("char", 10) } }
    local alt = { messages = { message("alt", 10) } }
    local merged = LinkedThread.Merge(primary, { member(CHAR, char), member(ALT, alt) })
    assert(texts(merged) == "bn,char,alt", "got " .. texts(merged))
  end

  -- test_merge_keeps_each_threads_own_order
  do
    -- A line replayed after a chat lock can be appended after newer lines;
    -- each thread still reads in the order it is shown on its own.
    local primary = { message("bn-late", 30), message("bn-replayed", 5) }
    local char = { messages = { message("char", 20) } }
    local merged = LinkedThread.Merge(primary, { member(CHAR, char) })
    assert(texts(merged) == "char,bn-late,bn-replayed", "got " .. texts(merged))
  end

  -- test_merge_maps_member_lines_to_their_conversation_key
  do
    local bnLine = message("bn", 10)
    local charLine = message("char", 20)
    local altLine = message("alt", 30)
    local _, memberKeyByMessage = LinkedThread.Merge({ bnLine }, {
      member(CHAR, { messages = { charLine } }),
      member(ALT, { messages = { altLine } }),
    })
    assert(memberKeyByMessage, "a linked thread maps its member lines")
    assert(memberKeyByMessage[charLine] == CHAR, "character line belongs to the character thread")
    assert(memberKeyByMessage[altLine] == ALT, "alt line belongs to the alt thread")
    assert(memberKeyByMessage[bnLine] == nil, "the friend's own line is not a member line")
  end

  -- test_merge_skips_members_without_messages
  do
    local primary = { message("bn", 10) }
    local merged, memberKeyByMessage = LinkedThread.Merge(primary, { member(CHAR, {}), member(ALT, nil) })
    assert(texts(merged) == "bn", "got " .. texts(merged))
    assert(type(memberKeyByMessage) == "table", "still a linked thread")
  end

  -- test_merge_treats_missing_sent_time_as_oldest
  do
    local primary = { message("bn", 10) }
    local char = { messages = { message("char", nil) } }
    local merged = LinkedThread.Merge(primary, { member(CHAR, char) })
    assert(texts(merged) == "char,bn", "got " .. texts(merged))
  end

  -- test_summary_without_members_uses_the_primary_values
  do
    local primary = { unreadCount = 2, lastActivityAt = 50, lastPreview = "hi", hasUnreadMention = true }
    local summary = LinkedThread.Summary(primary, {})
    assert(summary.unreadCount == 2, "unread")
    assert(summary.lastActivityAt == 50, "activity")
    assert(summary.lastPreview == "hi", "preview")
    assert(summary.hasUnreadMention == true, "mention")
    assert(summary.previewConversation == primary, "preview source")
  end

  -- test_summary_adds_unread_counts
  do
    local summary = LinkedThread.Summary({ unreadCount = 2 }, {
      member(CHAR, { unreadCount = 3 }),
      member(ALT, {}),
    })
    assert(summary.unreadCount == 5, "got " .. tostring(summary.unreadCount))
  end

  -- test_summary_takes_activity_and_preview_from_the_newest_thread
  do
    local char = { lastActivityAt = 90, lastPreview = "from char" }
    local summary = LinkedThread.Summary({ lastActivityAt = 50, lastPreview = "from bn" }, {
      member(CHAR, char),
      member(ALT, { lastActivityAt = 70, lastPreview = "from alt" }),
    })
    assert(summary.lastActivityAt == 90, "newest activity")
    assert(summary.lastPreview == "from char", "newest preview")
    assert(summary.previewConversation == char, "preview source")
  end

  -- test_summary_prefers_the_primary_on_equal_activity
  do
    local summary = LinkedThread.Summary({ lastActivityAt = 50, lastPreview = "from bn" }, {
      member(CHAR, { lastActivityAt = 50, lastPreview = "from char" }),
    })
    assert(summary.lastPreview == "from bn", "got " .. tostring(summary.lastPreview))
  end

  -- test_summary_flags_a_mention_from_any_thread
  do
    local summary = LinkedThread.Summary({}, { member(CHAR, { hasUnreadMention = true }) })
    assert(summary.hasUnreadMention == true, "mention in a member counts")
    local quiet = LinkedThread.Summary({}, { member(CHAR, {}) })
    assert(quiet.hasUnreadMention == nil, "no mention anywhere")
  end

  -- test_summary_defaults_missing_fields
  do
    local summary = LinkedThread.Summary({}, { member(CHAR, nil) })
    assert(summary.unreadCount == 0, "unread")
    assert(summary.lastActivityAt == 0, "activity")
    assert(summary.lastPreview == "", "preview")
  end
end
