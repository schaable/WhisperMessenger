local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local WhispersSettings = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings")

-- "Link Battle.net friends' characters": on by default; off stops automatic
-- linking (links already made stay, and the menu still links by hand).

local LABEL = "Link Battle.net friends' characters"
local TOOLTIP =
  "Puts a Battle.net friend's character chats into your chat with that friend on their own. Turning it off keeps the links already made: right-click your friend's chat to unlink a character."

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = WhispersSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_toggle_defaults_on
  do
    local toggle = FindUI.toggle(create({}).frame, LABEL)
    assert(toggle ~= nil, "the Whispers page shows " .. LABEL)
    assert(FindUI.isToggleOn(toggle) == true, "never-saved value shows on")
  end

  -- test_saved_off_starts_off
  do
    local toggle = FindUI.toggle(create({ autoLinkBattleNetCharacters = false }).frame, LABEL)
    assert(FindUI.isToggleOn(toggle) == false, "saved off starts off")
  end

  -- test_clicking_saves_the_setting
  do
    local result, changes = create({})
    FindUI.click(FindUI.toggle(result.frame, LABEL))
    assert(changes.autoLinkBattleNetCharacters == false, "turning it off saves autoLinkBattleNetCharacters = false")
  end

  -- test_reset_turns_it_back_on
  do
    local result, changes = create({ autoLinkBattleNetCharacters = false })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.autoLinkBattleNetCharacters == true, "reset turns automatic linking on")
  end

  -- test_strings_are_translated_everywhere
  do
    for _, code in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
      local catalog = require("WhisperMessenger.Locale." .. code)
      for _, key in ipairs({ LABEL, TOOLTIP }) do
        assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " translates: " .. key)
      end
    end
  end
end
