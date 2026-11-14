local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

local FRIEND = "bnet::BN::jaina#1234"
local CHAR_GUID = "Player-60-0ABCDE123"
local SAVED_GLOBALS = {
  "require",
  "CreateFrame",
  "SlashCmdList",
  "SLASH_WHISPERMESSENGER1",
  "SLASH_WHISPERMESSENGER2",
  "C_ChatInfo",
  "C_BattleNet",
  "UnitFullName",
  "GetNormalizedRealmName",
  "InCombatLockdown",
  "time",
  "date",
  "Menu",
  "UnitPopup_OpenMenu",
}

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

local function friendInfo()
  return {
    bnetAccountID = 99,
    accountName = "Jaina",
    battleTag = "Jaina#1234",
    gameAccountInfo = { characterName = "Jainamage", realmName = "Proudmoore", playerGuid = CHAR_GUID },
  }
end

local function newMenuRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = newMenuRoot()
    button.text, button.callback = text, callback
    self.buttons[#self.buttons + 1] = button
    return button
  end
  function root.CreateDivider() end
  function root.CreateTitle() end
  return root
end

local function findButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

-- A Battle.net friend whispers, then whispers from a character: the two
-- threads link on their own and show as one conversation; replies go over
-- Battle.net; unlinking from the menu splits them with every message kept,
-- and linking from the menu joins them again.
return function()
  local saved = {}
  for _, name in ipairs(SAVED_GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local createdFrames, sendCalls = {}, {}
  local clock = 1000

  rawset(_G, "require", nil)
  rawset(_G, "SlashCmdList", {})
  rawset(_G, "time", function()
    return clock
  end)
  rawset(_G, "date", saved.date or os.date)
  rawset(_G, "UnitFullName", function()
    return "Arthas", "Area52"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "C_ChatInfo", {
    SendChatMessage = function(message, chatType, _, target)
      sendCalls[#sendCalls + 1] = { text = message, chatType = chatType, target = target, transport = "WOW" }
    end,
  })
  rawset(_G, "C_BattleNet", {
    SendWhisper = function(bnetAccountID, text)
      sendCalls[#sendCalls + 1] = { bnetAccountID = bnetAccountID, text = text, transport = "BN" }
      return true
    end,
    GetAccountInfoByID = function(bnetAccountID)
      return bnetAccountID == 99 and friendInfo() or nil
    end,
    -- Who plays a character: what automatic linking asks.
    GetAccountInfoByGUID = function(guid)
      return guid == CHAR_GUID and friendInfo() or nil
    end,
  })
  local modifiers, menuContext = {}, nil
  rawset(_G, "Menu", {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  })
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    menuContext = contextData
  end)
  rawset(_G, "CreateFrame", function(frameType, name, parent)
    local frame = factory.CreateFrame(frameType, name, parent)
    createdFrames[#createdFrames + 1] = frame
    -- The addon's event frame records what it listens to.
    rawset(frame, "RegisterEvent", function(self, eventName)
      self.events = self.events or {}
      self.events[eventName] = true
    end)
    rawset(frame, "UnregisterEvent", function(self, eventName)
      if self.events then
        self.events[eventName] = nil
      end
    end)
    return frame
  end)

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  local eventFrame
  for _, frame in ipairs(createdFrames) do
    if eventFrame == nil and frame.scripts and frame.scripts.OnEvent then
      eventFrame = frame
    end
  end
  assert(eventFrame ~= nil, "expected addon load event frame")
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")
  local runtime = ns.Bootstrap.runtime
  runtime.accountState.settings = runtime.accountState.settings or {}
  runtime.accountState.settings.compactLayout = false

  local function bnWhisper(text, lineID)
    eventFrame.scripts.OnEvent(eventFrame, "CHAT_MSG_BN_WHISPER", text, "|Kq1|k", nil, nil, nil, nil, nil, nil, nil, nil, lineID, nil, 99)
  end
  local function characterWhisper(text, lineID)
    eventFrame.scripts.OnEvent(eventFrame, "CHAT_MSG_WHISPER", text, "Jainamage-Proudmoore", "", "", "", "", 0, 0, "", 0, lineID, CHAR_GUID)
  end
  local function rows()
    local list = {}
    for _, row in ipairs(runtime.window.contacts.rows) do
      if row.item ~= nil then
        list[#list + 1] = row
      end
    end
    return list
  end
  local function rowFor(key)
    for _, row in ipairs(rows()) do
      if row.item.conversationKey == key then
        return row
      end
    end
    return nil
  end
  local function rightClick(row)
    row.scripts.OnClick(row, "RightButton")
    local root = newMenuRoot()
    modifiers[row.item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"](row, root, menuContext)
    return root
  end

  -- test_friend_and_character_whispers_link_on_their_own
  bnWhisper("hello from bn", 301)
  clock = 1060
  characterWhisper("hi from my mage", 302)
  clock = 1120
  bnWhisper("back on bn", 303)
  local charKey
  for key, conversation in pairs(runtime.store.conversations) do
    if conversation.channel == "WOW" then
      charKey = key
    end
  end
  assert(charKey ~= nil, "the character's whisper has its own chat")
  local link = runtime.accountState.conversationLinks.links[charKey]
  assert(link and link.primaryKey == FRIEND and link.source == "auto", "linked automatically")

  -- test_the_closed_window_counts_one_contact_with_every_unread_whisper
  local closed = runtime.refreshWindow()
  assert(closed and #closed.contacts == 1 and closed.contacts[1].conversationKey == FRIEND, "only the friend's contact")
  assert(closed.contacts[1].unreadCount == 3, "three unread whispers, got " .. tostring(closed.contacts[1].unreadCount))

  -- test_opening_the_window_shows_one_row_and_reads_both_chats
  _G.SlashCmdList.WHISPERMESSENGER()
  assert(#rows() == 1 and rows()[1].item.conversationKey == FRIEND, "only the friend's row, got " .. #rows())
  rows()[1].scripts.OnClick()
  assert(runtime.activeConversationKey == FRIEND, "the friend's thread is open")
  local shown = runtime.window.conversation.transcript._allMessages
  assert(#shown == 3, "three lines, got " .. #shown)
  assert(shown[1].text == "hello from bn" and shown[2].text == "hi from my mage" and shown[3].text == "back on bn", "in the order they came")
  assert(FindUI.text(runtime.window.frame, "- via Battle.net") ~= nil, "Battle.net lines are tagged")
  assert(FindUI.text(runtime.window.frame, "- via Whisper") ~= nil, "the character's line is tagged")
  assert(runtime.store.conversations[charKey].unreadCount == 0, "the character's chat is read too")

  -- test_a_reply_goes_over_battle_net
  runtime.window.composer.input:SetText("see you there")
  runtime.window.composer.sendButton.scripts.OnClick()
  assert(#sendCalls == 1 and sendCalls[1].transport == "BN" and sendCalls[1].bnetAccountID == 99, "sent as a Battle.net whisper")

  -- test_unlinking_from_the_menu_splits_the_chats_and_keeps_every_message
  local unlinkMenu = findButton(rightClick(rowFor(FRIEND)), "Unlink character")
  assert(unlinkMenu ~= nil and #unlinkMenu.buttons == 1, "the friend's row offers its one character")
  unlinkMenu.buttons[1].callback()
  assert(#rows() == 2 and rowFor(charKey) ~= nil, "the character's row is back")
  assert(#runtime.store.conversations[FRIEND].messages == 2, "the friend's chat kept its lines")
  assert(#runtime.store.conversations[charKey].messages == 1, "the character's chat kept its line")

  -- test_a_split_pair_stays_split_when_the_character_whispers_again
  clock = 1200
  characterWhisper("still here", 304)
  assert(#rows() == 2, "automatic linking leaves a pair the player split")

  -- test_linking_from_the_menu_joins_them_again
  local linkMenu = findButton(rightClick(rowFor(charKey)), "Link to Battle.net friend")
  assert(linkMenu ~= nil and #linkMenu.buttons == 1, "the character's row offers the friend")
  linkMenu.buttons[1].callback()
  assert(#rows() == 1, "one row again")
  assert(_G.WhisperMessengerDB.conversationLinks.links[charKey].source == "manual", "the link is saved for the next session")

  for _, name in ipairs(SAVED_GLOBALS) do
    rawset(_G, name, saved[name])
  end
end
