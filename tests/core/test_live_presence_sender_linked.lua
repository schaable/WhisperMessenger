local Sender = require("WhisperMessenger.Core.Bootstrap.LivePresenceSender")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local Store = require("WhisperMessenger.Model.ConversationStore")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR = "wow::WOW::jainachar-nagrand"

local function newRuntime(sent, bnSent)
  return {
    now = function()
      return 100
    end,
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    accountState = { settings = {} },
    chatApi = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, channel, target)
        table.insert(sent, { prefix = prefix, payload = payload, channel = channel, target = target })
        return true
      end,
    },
    bnetApi = {
      SendGameData = function(gameAccountID, prefix, payload)
        table.insert(bnSent, { gameAccountID = gameAccountID, prefix = prefix, payload = payload })
        return true
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(index)
        if index ~= 1 then
          return nil
        end
        return { bnetAccountID = 77, battleTag = "Jaina#1234", isOnline = true, gameAccountInfo = { gameAccountID = 9001, isOnline = true } }
      end,
    },
  }
end

local function unread(wireId)
  return { { direction = "in", kind = "user", wireId = wireId, text = "hi", sentAt = 90 } }
end

-- The friend's thread on screen shows their linked characters' lines too, so
-- those get their "Seen" receipt like the friend's own lines.
return function()
  local function linkedThread(sent, bnSent)
    local runtime = newRuntime(sent, bnSent)
    local friend = Store.EnsureConversation(runtime.store, FRIEND)
    friend.channel, friend.battleTag, friend.displayName, friend.bnetAccountID = "BN", "Jaina#1234", "Jaina", 77
    local character = Store.EnsureConversation(runtime.store, CHAR)
    character.channel, character.displayName = "WOW", "Jainachar-Nagrand"
    character.messages = unread("char1")
    LivePresence.RecordPeer(runtime, CHAR)
    local contact = { conversationKey = FRIEND, channel = "BN", bnetAccountID = 77, linkedMembers = { { key = CHAR, conversation = character } } }
    return runtime, contact, friend, character
  end

  -- test_a_linked_characters_line_gets_its_receipt
  do
    local sent, bnSent = {}, {}
    local runtime, contact, _, character = linkedThread(sent, bnSent)
    assert(Sender.SyncReadReceipts(runtime, contact) == true, "a receipt was sent")
    assert(#sent == 1 and sent[1].payload == "1|S|char1" and sent[1].target == "Jainachar-Nagrand", "receipt to the character")
    assert(character.messages[1].receiptSentAt == 100, "recorded on the character's line")
  end

  -- test_the_friend_and_the_character_each_get_theirs
  do
    local sent, bnSent = {}, {}
    local runtime, contact, friend = linkedThread(sent, bnSent)
    friend.messages = unread("bn1")
    LivePresence.RecordPeer(runtime, FRIEND)
    Sender.SyncReadReceipts(runtime, contact)
    assert(#bnSent == 1 and bnSent[1].payload == "1|S|bn1", "the friend's receipt over Battle.net")
    assert(#sent == 1 and sent[1].payload == "1|S|char1", "the character's receipt by whisper")
  end

  -- test_setting_off_sends_no_linked_receipt
  do
    local sent, bnSent = {}, {}
    local runtime, contact = linkedThread(sent, bnSent)
    runtime.accountState.settings.shareReadReceipts = false
    assert(Sender.SyncReadReceipts(runtime, contact) == false and #sent == 0, "no receipt with the setting off")
  end
end
