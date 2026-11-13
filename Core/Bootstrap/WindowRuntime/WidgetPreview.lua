local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local AlertPolicy = ns.AlertPolicy or require("WhisperMessenger.Model.AlertPolicy")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local AddonGreetingText = ns.ChatBubbleAddonGreetingText or require("WhisperMessenger.UI.ChatBubble.AddonGreetingText")

local WidgetPreview = {}

function WidgetPreview.Create(options)
  options = options or {}

  local accountState = options.accountState or {}
  local runtimeStore = options.runtimeStore or {}
  local badgeFilter = options.badgeFilter or BadgeFilter

  -- The newer of latest and conversation's last incoming whisper, shown on
  -- item's row. face names and colors it: the row itself, or a linked
  -- character's own record. thread is the row's conversation, whose Mute counts.
  local function newerPreview(latest, item, face, conversation, thread, includeQuiet)
    if type(conversation) ~= "table" or not (includeQuiet or AlertPolicy.ShouldAlert(conversation, accountState.settings, thread)) then
      return latest
    end
    local sentAt = tonumber(conversation.lastIncomingAt)
    local messageText = conversation.lastIncomingPreview
    if not sentAt or type(messageText) ~= "string" or messageText == "" or (latest and sentAt <= latest.sentAt) then
      return latest
    end
    local senderName = DisplayName.Format(conversation.lastIncomingSender or face.displayName or conversation.displayName)
    if type(senderName) ~= "string" or senderName == "" then
      return latest
    end
    return {
      sentAt = sentAt,
      conversationKey = item.conversationKey,
      senderName = senderName,
      messageText = AddonGreetingText.ForIncomingPreview(conversation, messageText),
      classTag = face.classTag or conversation.classTag,
      channel = item.channel,
    }
  end

  -- includeQuiet: also count muted chats and message requests (used to
  -- acknowledge, so unmuting or accepting later never pops a message that
  -- was already on screen).
  local function findLatestIncomingPreview(contacts, includeQuiet)
    local storeConversations = runtimeStore.conversations or {}
    local savedConversations = accountState.conversations or {}
    local latest = nil

    for _, item in ipairs(contacts or {}) do
      local conversation = savedConversations[item.conversationKey] or storeConversations[item.conversationKey]
      -- Group chats never produce a widget preview — per user requirement,
      -- the popup is reserved for whispers. Muted whispers and message requests
      -- never pop it either.
      if not badgeFilter.IsGroupChannel(item.channel) then
        latest = newerPreview(latest, item, item, conversation, conversation, includeQuiet)
        -- A friend's row also shows their linked characters' whispers.
        local members = item.linkedMembers
        if type(members) == "table" then
          for _, member in ipairs(members) do
            latest = newerPreview(latest, item, member.conversation or {}, member.conversation, conversation, includeQuiet)
          end
        end
      end
    end

    return latest
  end

  local function buildLatestIncomingPreview(contacts)
    if accountState.settings and accountState.settings.showWidgetMessagePreview == false then
      return nil
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt)
    local latest = findLatestIncomingPreview(contacts)
    if latest and acknowledgedAt and latest.sentAt <= acknowledgedAt then
      return nil
    end

    return latest
  end

  local function acknowledgeLatestWidgetPreview(contacts)
    local latest = findLatestIncomingPreview(contacts, true)
    if latest == nil then
      return
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt) or 0
    if latest.sentAt > acknowledgedAt then
      accountState.widgetPreviewAcknowledgedAt = latest.sentAt
    end
  end

  -- Acknowledge one whisper (the one being answered) without touching newer ones.
  local function acknowledgeWidgetPreviewThrough(sentAt)
    local stamp = tonumber(sentAt)
    if stamp == nil then
      return
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt) or 0
    if stamp > acknowledgedAt then
      accountState.widgetPreviewAcknowledgedAt = stamp
    end
  end

  return {
    findLatestIncomingPreview = findLatestIncomingPreview,
    buildLatestIncomingPreview = buildLatestIncomingPreview,
    acknowledgeLatestWidgetPreview = acknowledgeLatestWidgetPreview,
    acknowledgeWidgetPreviewThrough = acknowledgeWidgetPreviewThrough,
  }
end

ns.BootstrapWindowRuntimeWidgetPreview = WidgetPreview

return WidgetPreview
