local ContactSearch = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

local function friendRow()
  return {
    conversationKey = "bnet::BN::jaina#1234",
    displayName = "Jaina#1234",
    conversation = { messages = { { kind = "user", direction = "in", text = "hello there", playerName = "Jaina#1234" } } },
    linkedMembers = {
      {
        key = "wow::WOW::frostmage-area52",
        conversation = {
          displayName = "Frostmage-Area52",
          messages = { { kind = "user", direction = "in", text = "dungeon tonight?", playerName = "Frostmage-Area52" } },
        },
      },
    },
  }
end

local function finds(query)
  return #ContactSearch.BuildVisibleContacts({ friendRow() }, ContactSearch.NormalizeSearchQuery(query)) == 1
end

-- A friend's row shows their linked characters' chats too, so searching for
-- a character's name or lines finds the friend's row.
return function()
  -- test_a_linked_characters_name_finds_the_friends_row
  assert(finds("frostmage"), "the character's name finds the row")

  -- test_a_linked_characters_line_finds_the_friends_row
  assert(finds("dungeon"), "the character's line finds the row")

  -- test_terms_can_match_across_the_friend_and_the_character
  assert(finds("hello dungeon"), "one term from each thread")

  -- test_a_term_found_nowhere_still_hides_the_row
  assert(not finds("raid"), "no match, no row")
end
