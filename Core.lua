EminentDKP = LibStub("AceAddon-3.0"):NewAddon("EminentDKP", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)
local libCH = LibStub:GetLibrary("LibChatHandler-1.0")
local media = LibStub("LibSharedMedia-3.0")
libCH:Embed(EminentDKP)
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local VERSION = '2.1.1'
local newest_version = ''
local needs_update = false
local addon_versions = {}

-- All the meter windows
local windows = {}

-- All saved sets
local sets = {}

-- Modes (see Modes.lua)
local modes = {}

local recent_achievements = {}
local recent_deaths = {}

local auction_active = false

local recent_loots = {}
local eligible_looters = {}

local events_cache = {}
local synced_dates = {}
local syncing = false

local lastContainerName = nil

local in_combat = false
--local in_guild_group = false

-- Whether or not officer functionality is allowed to run
local enabled = true

-- When logging in, officer functionality is disabled temporarily
local tempdisabled = true

local function convertToTimestamp(datetime)
  local t, d = strsplit(' ',datetime)
  local hour, min = strsplit(':',t)
  local month, day, year = strsplit('/',d)
  
  return time({day=day,month=month,year=year,hour=hour,min=min,sec=0})
end

local function GetDate(timestamp)
  return date("%x",timestamp)
end

local function GetTodayDate()
  return GetDate(time())
end

local function GetDaysBetween(this,that)
  return math.floor((this - that) / 86400)
end

local function GetDaysSince(timestamp)
  return GetDaysBetween(time(),timestamp)
end

local function IsGroupInCombat()
  if GetNumRaidMembers() > 0 then
    -- We are in a raid.
    for i = 1, GetNumRaidMembers(), 1 do
      if UnitExists("raid"..i) and UnitAffectingCombat("raid"..i) then
        return true
      end
    end
  elseif GetNumPartyMembers() > 0 then
    -- In party.
    for i = 1, GetNumPartyMembers(), 1 do
      if UnitExists("party"..i) and UnitAffectingCombat("party"..i) then
        return true
      end
    end
  end
end

local function MergeTables(source,other,front)
  for i,val in ipairs(other) do
    if front then
      table.insert(source,1,val)
    else
      table.insert(source,val)
    end
  end
end

local function implode(delim,list)
  return table.concat(list,delim)
end

local function sendchat(msg, chan, chantype)
  local prepend = "[EminentDKP] "
  
  if chantype == "self" then
    -- To self.
    EminentDKP:Print(msg)
  elseif chantype == "channel" then
    -- To channel.
    SendChatMessage(prepend .. msg, "CHANNEL", nil, chan)
  elseif chantype == "preset" then
    -- To a preset channel id (say, guild, etc).
    SendChatMessage(prepend .. msg, string.upper(chan))
  elseif chantype == "whisper" then
    -- To player.
    SendChatMessage(prepend .. msg, "WHISPER", nil, chan)
  end
end

-- Compare two version numbers
local function CompareVersions(current,other)
  local a_major, a_minor, a_bug, a_event = strsplit(".",strtrim(current),4)
  local b_major, b_minor, b_bug, b_event = strsplit(".",strtrim(other),4)
  
  local major_diff = tonumber(a_major) - tonumber(b_major)
  local minor_diff = tonumber(a_minor) - tonumber(b_minor)
  local bug_diff = tonumber(a_bug) - tonumber(b_bug)
  local event_diff = tonumber(a_event) - tonumber(b_event)
  
  return { major = major_diff, minor = minor_diff, bug = bug_diff, event = event_diff }
end

local function UpdateNewestVersion(newer)
  local newer_version = strtrim(newer)
  local compare = CompareVersions(EminentDKP:GetNewestVersion(),newer_version)
  
  if compare.major < 0 or compare.minor < 0 then
    -- There is a new addon version
    newest_version = newer_version
    needs_update = true
  elseif compare.major == 0 and compare.minor == 0 then
    if compare.event < 0 or compare.bug < 0 then
      newest_version = newer_version
      if compare.bug < 0 then
        -- There is a new addon version
        needs_update = true
      end
    end
  end
end

local function CheckVersionCompatability(otherversion)
  local compare = CompareVersions(EminentDKP:GetVersion(),otherversion)
  
  UpdateNewestVersion(otherversion)
  if compare.major < 0 or compare.minor < 0 or compare.major > 0 or compare.minor > 0 then
    return false
  else
    return true
  end
end

--[[-------------------------------------------------------------------
  Meter Window Functions
---------------------------------------------------------------------]]

-- Are we in a PVP zone?
local function is_in_pvp()
  return select(2,IsInInstance()) == "pvp" or select(2,IsInInstance()) == "arena"
end

-- Are we solo?
local function is_solo()
  return GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0
end

-- Are we in a party?
local function is_in_party()
  return GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
end

local function find_mode(name)
  for i, mode in ipairs(modes) do
    if mode:GetName() == name then
      return mode
    end
  end
end

-- Our window type.
local Window = {}

local mt = {__index = Window}

function Window:new()
  return setmetatable({
    -- Our dataset.
    dataset = {},
    -- Metadata about our dataset.
    metadata = {},
    -- Our display provider.
    display = nil,
    -- Our mode traversing history.
    history = {},
  }, mt)
end

function Window:AddOptions()
  local settings = self.settings
  
  local options = {
    type = "group",
    name = function() return settings.name end,
    args = {
      rename = {
        type= "input",
        name= L["Rename window"],
        desc= L["Enter the name for the window."],
        get= function() return settings.name end,
        set= function(win, val)
          if val ~= settings.name and val ~= "" and not EminentDKP:GetWindow(val) then
            settings.name = val
          end
        end,
        order= 1,
      },
      display = {
        type= "select",
        name= L["Display system"],
        desc= L["Choose the system to be used for displaying data in this window."],
        values= function()
          local list = {}
          for name, display in pairs(EminentDKP.displays) do
            list[name] = display.name
          end
          return list
        end,
        get= function() return settings.display end,
        set= function(win, display)
          self:SetDisplay(display)
          EminentDKP:ApplySettings(win[2])
        end,
        order= 2,
      },
      locked = {
        type= "toggle",
        name= L["Lock window"],
        desc= L["Locks the bar window in place."],
        get= function() return settings.barslocked end,
        set= function(win)
          settings.barslocked = not settings.barslocked
          EminentDKP:ApplySettings(win[2])
        end,
        order= 3,
      },
      enablestatus = {
        type="toggle",
        name=L["Enable Status Bar"],
        desc=L["Enables the the status bar under the title."],
        get=function() return settings.enablestatus end,
        set=function(win) 
          settings.enablestatus = not settings.enablestatus
          EminentDKP:ApplySettings(win[2])
        end,
        order= 4,
      },
    }
  }
  self.display:AddDisplayOptions(self, options.args)
  EminentDKP.options.args.windows.args[self.settings.name] = options
end

function Window:destroy()
  self.dataset = nil
  self.display:Destroy(self)
end

function Window:SetDisplay(name)
  -- Don't do anything if nothing actually changed.
  if name ~= self.settings.display or self.display == nil then
    if self.display then
      -- Destroy old display.
      self.display:Destroy(self)
    end
    
    -- Set new display.
    self.settings.display = name
    self.display = EminentDKP.displays[self.settings.display]
    
    -- Add options. Replaces old options.
    self:AddOptions()
  end
end

-- Tells window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
  -- Fetch max value if our mode has not done this itself.
  if not self.metadata.maxvalue then
    self.metadata.maxvalue = 0
    for i, data in ipairs(self.dataset) do
      if data.id and data.value > self.metadata.maxvalue then
        self.metadata.maxvalue = data.value
      end
    end
  end
  
  -- Display it.
  self.display:Update(self)
end

function Window:Show()
  self.display:Show(self)
end

function Window:Hide()
  self.display:Hide(self)
end

function Window:IsShown()
  return self.display:IsShown(self)
end

function Window:Wipe()
  -- Clear dataset.
  wipe(self.dataset)
  
  -- Clear display.
  self.display:Wipe(self)
end

-- Sets up the mode view.
function Window:DisplayMode(mode)
  self:Wipe()
  self.selectedmode = mode
  self.metadata = {}
  
  -- Apply mode's metadata.
  if mode.metadata then
    for key, value in pairs(mode.metadata) do
      self.metadata[key] = value
    end
  end
  
  -- Save for remembrance
  self.settings.mode = mode:GetName()
  self.metadata.title = mode.title or mode:GetName()

  EminentDKP:UpdateDisplay(self)
end

local function click_on_mode(win, id, label, button)
  if button == "LeftButton" then
    local mode = find_mode(id)
    if mode then
      win:DisplayMode(mode)
    end
  elseif button == "RightButton" then
    win:RightClick()
  end
end

-- Sets up the mode list.
function Window:DisplayModes(setid)
  self.history = {}
  self:Wipe()

  self.selectedplayer = nil
  self.selectedmode = nil

  self.metadata = {}
  self.metadata.title = L["EminentDKP: Modes"]

  -- Verify the selected set
  if sets[setid] then
    self.selectedset = setid
  else
    self.selectedset = "alltime"
  end
  
  -- Save for remembrance
  self.settings.mode = nil
  self.settings.set = self.selectedset
  
  self.metadata.click = click_on_mode
  self.metadata.maxvalue = 1

  EminentDKP:UpdateDisplay(self)
end

local function click_on_set(win, id, label, button)
  if button == "LeftButton" then
    win:DisplayModes(id)
  elseif button == "RightButton" then
    win:RightClick() 
  end
end

-- Default "right-click" behaviour in case no special click function is defined:
-- 1) If there is a mode traversal history entry, go to the last mode.
-- 2) Go to modes list if we are in a mode.
-- 3) Go to set list.
function Window:RightClick(group, button)
  if self.selectedmode then
    -- If mode traversal history exists, go to last entry, else mode list.
    if #(self.history) > 0 then
      self:DisplayMode(tremove(self.history))
    else
      self:DisplayModes(self.selectedset)
    end
  elseif self.selectedset then
    self:DisplaySets()
  end
end

-- Sets up the set list.
function Window:DisplaySets()
  self.history = {}
  self:Wipe()
  
  self.metadata = {}
  
  self.selectedmode = nil
  self.selectedset = nil
  
  self.settings.mode = nil
  self.settings.set = nil

  self.metadata.title = L["EminentDKP: Days"]

  self.metadata.click = click_on_set
  self.metadata.maxvalue = 1
  self.metadata.sortfunc = function(a,b)
    if a.sortnum < b.sortnum then return true end
    if b.sortnum < a.sortnum then return false end
    return a.starttime > b.starttime
  end
  
  EminentDKP:UpdateDisplay(self)
end

function Window:get_selected_set()
  if sets[self.selectedset] then
    return sets[self.selectedset]
  end
  return sets.alltime
end

-- Ask a mode to verify the contents of a set.
local function verify_set(mode, set)
  for j, player in ipairs(set.players) do
    if mode.AddPlayerAttributes then
      mode:AddPlayerAttributes(player)
    end
  end
  mode:CalculateData(set)
end

-- Create a set with default attributes and have the modes apply their attributes
local function createSet(setname)
  local set = {players = {}, events = {}, name = setname, sortnum = 3,
               starttime = 0, endtime = 0, changed = true, modedata = {}}
  
  -- Tell each mode to apply its needed attributes.
  for i, mode in ipairs(modes) do 
    if mode.AddSetAttributes then
      mode:AddSetAttributes(set)
    end
  end

  return set
end

function EminentDKP:GetWindows()
  return windows
end

-- Toggle visibility of all the meter displays
function EminentDKP:ToggleMeters(visible)
  for i, win in ipairs(windows) do
    if visible and not win:IsShown() then
      win:Show()
    elseif not visible and win:IsShown() then
      win:Hide()
    end
  end
end

-- Table copy function
function EminentDKP:tcopy(to, from)
  for k,v in pairs(from) do
    if type(v) == "table" then
      to[k] = {}
      EminentDKP:tcopy(to[k], v)
    else
      to[k] = v
    end
  end
end

function EminentDKP:GetMeterSets()
  return self:GetActivePool().sets
end

-- Create a window and its db settings
function EminentDKP:CreateWindow(name, settings)
  if not settings then
    settings = {}
    self:tcopy(settings, EminentDKP.windowdefaults)
    table.insert(self.db.profile.windows, settings)
  end

  local window = Window:new()
  window.settings = settings
  window.settings.name = name
  
  window.selectedset = window.settings.set
  if window.settings.mode then
    window.selectedmode = find_mode(window.settings.mode)
  end
  
  -- Set the window's display and call it's Create function.
  window:SetDisplay(window.settings.display or "meter")
  
  window.display:Create(window)
  
  table.insert(windows, window)
  
  self:ApplySettings(window)
  
  -- Display initial view depending on settings
  if window.selectedmode then
    window:DisplayMode(window.selectedmode)
  elseif window.selectedset then
    window:DisplayModes(window.selectedset)
  else
    window:DisplaySets()
  end
end

-- Delete window from our windows table, and also from db.
function EminentDKP:DeleteWindow(name)
  for i, win in ipairs(windows) do
    if win.settings.name == name then
      win:destroy()
      wipe(table.remove(windows, i))
    end
  end
  for i, win in ipairs(self.db.profile.windows) do
    if win.name == name then
      table.remove(self.db.profile.windows, i)
    end
  end
  self.options.args.windows.args[name] = nil
end

-- Builds a unique list of players for a set
local function MarkPlayersSeen(seen, set, event)
  local playerids = { }
  
  local source_id = tostring(tonumber(event.source) or 0)
  local target_id = tostring(tonumber(event.target) or 0)
  if source_id ~= "0" then table.insert(playerids,source_id) end
  if target_id ~= "0" then table.insert(playerids,target_id) end
  if event.beneficiary ~= "" then
    MergeTables(playerids,{ strsplit(",",event.beneficiary) })
  end
  
  if not seen[set.name] then
    seen[set.name] = {}
  end
  
  for i, pid in ipairs(playerids) do
    -- Seen this player in this set?
    if not seen[set.name][pid] then
      local player = EminentDKP:GetPlayerByID(pid)
      if player and player.active then
        table.insert(set.players, {id=pid,modedata={}})
        seen[set.name][pid] = true
      end
    end
  end
end

-- Reload
function EminentDKP:ReloadWindows()
  -- Delete all existing windows in case of a profile change.
  for i, win in ipairs(windows) do
    win:destroy()
  end
  wipe(windows)
  
  -- Re-create sets
  sets = self:GetMeterSets()
  if not next(sets) then
    self:ReloadSets(false)
  else
    self:VerifyTodaySet()
  end

  -- Re-create windows
  for i, win in ipairs(self.db.profile.windows) do
    self:CreateWindow(win.name, win)
  end
end

-- Reload all the "days" on the meter display
function EminentDKP:ReloadSets(updatedisplays)
  sets = self:GetMeterSets()
  wipe(sets)
  
  local today = GetTodayDate()
  sets.alltime = createSet(L["All-time"])
  sets.alltime.sortnum = 1
  sets.today = createSet(L["Today"])
  sets.today.date = today
  sets.today.sortnum = 2
  
  local eventHash = {}
  -- Start from most recent event and work backwards
  for eventid = self:GetEventCount(), 1, -1 do
    local eid = tostring(eventid)
    local event = self:GetEvent(eid)
    local diff = GetDaysSince(event.datetime)
    if eventid > 0 and diff <= self.db.profile.daystoshow then
      local date = GetDate(event.datetime)
      if sets.today.date == date then
        table.insert(sets.today.events,eid)
        sets.today.starttime = event.datetime
        MarkPlayersSeen(eventHash, sets.today, event)
      elseif sets[date] then
        table.insert(sets[date].events,eid)
        sets[date].starttime = event.datetime
        MarkPlayersSeen(eventHash, sets[date], event)
      else
        local set = createSet(date)
        set.endtime = event.datetime
        table.insert(set.events, eid)
        sets[date] = set
        MarkPlayersSeen(eventHash, set, event)
      end
    else
      -- Stop when we extend beyond our boundary
      break
    end
  end
  
  self:VerifyAllSets()
  if updatedisplays then
    self:UpdateAllDisplays()
  end
end

function EminentDKP:VerifyTodaySet()
  -- Verify the "Today" set is actually today
  local today = GetTodayDate()
  if sets.today.date ~= today then
    -- Has the Today set even been used yet?
    if #(sets.today.players) > 0 then
      local oldtoday = {}
      self:tcopy(oldtoday, sets.today)
      oldtoday.name = oldtoday.date
      oldtoday.sortnum = 3
      sets[oldtoday.date] = oldtoday
      sets.today = createSet(L["Today"])
      sets.today.date = today
      sets.today.sortnum = 2
    
      self:VerifySet(sets.today)
    else
      sets.today.date = today
    end
  end
  -- Prune any sets that extend beyond our given timeframe
  for name, set in pairs(sets) do
    if set.sortnum == 3 then
      if GetDaysSince(set.starttime) > self.db.profile.daystoshow then
        sets[name] = nil
      end
    end
  end
end

-- Only update the sets that have changed in the last sync
function EminentDKP:UpdateSyncedDays()
  -- Ensure the today set is proper
  self:VerifyTodaySet()
  
  local seen = {}
  for date,events in pairs(synced_dates) do
    local set
    if sets[date] then
      set = sets[date]
    elseif sets.today.date == date then
      set = sets.today
    else
      -- Set doesn't exist, so make it
      if GetDaysSince(self:GetEvent(events[1]).datetime) <= self.db.profile.daystoshow then
        set = createSet(date)
        sets[date] = set
      end
    end
    if set then
      MergeTables(set.events,events,true)
      set.endtime = self:GetEvent(set.events[1]).datetime
      set.starttime = self:GetEvent(set.events[#(set.events)]).datetime
      wipe(set.players)
      for i, eid in ipairs(set.events) do
        MarkPlayersSeen(seen, set, self:GetEvent(eid))
      end
      set.changed = true
    end
  end
  wipe(sets.alltime.events)
  sets.alltime.changed = true
  wipe(synced_dates)
  self:VerifyAllSets()
  self:UpdateAllDisplays()
end

-- For a set, give each mode a chance to calculate the data they need
function EminentDKP:VerifySet(set)
  for j, mode in ipairs(modes) do
    verify_set(mode, set)
  end
  set.changed = false
end

-- For every set, have each mode verify their data
function EminentDKP:VerifyAllSets()
  for setid, set in pairs(sets) do
    self:VerifySet(set)
  end
end

function EminentDKP:ApplySettingsAll()
  for i, win in ipairs(windows) do
    self:ApplySettings(win)
  end
  self:UpdateStatusBar()
end

function EminentDKP:ApplySettings(win)
  -- Just incase we're given a window name, not a window
  if type(win) == "string" then
    win = self:GetWindow(win)
  end
  win.display:ApplySettings(win)

  -- Don't show window if we are solo, option.
  -- Don't show window in a PvP instance, option.
  if (self.db.profile.hidesolo and is_solo()) or 
     (self.db.profile.hidepvp and is_in_pvp()) or 
     (self.db.profile.hideparty and is_in_party()) or 
     (self.db.profile.hidecombat and in_combat) then
    win:Hide()
  else
    win:Show()
    
    -- Hide specific windows if window is marked as hidden (ie, if user manually hid the window, keep hiding it).
    if win.settings.hidden and win:IsShown() then
      win:Hide()
    end
  end
  
  self:UpdateDisplay(win)
end

-- Called before dataset is updated.
function Window:UpdateInProgress()
  for i, data in ipairs(self.dataset) do
    data.id = nil
  end
end

-- Loop through and update each window's display
function EminentDKP:UpdateAllDisplays()
  for i, win in ipairs(windows) do
    self:UpdateDisplay(win)
  end
end

-- Update a given window's display
function EminentDKP:UpdateDisplay(win)
  if win.selectedmode then
    local set = win:get_selected_set()
    
    -- Inform window that a data update will take place.
    win:UpdateInProgress()
  
    -- Let mode update data.
    if win.selectedmode.PopulateData then
      win.selectedmode:PopulateData(win, set)
    else
      self:Print("Mode "..win.selectedmode:GetName().." does not have a PopulateData function!")
    end
    -- Let window display the data.
    win:UpdateDisplay()
  elseif win.selectedset then
    local set = win:get_selected_set()
    
    win:Wipe()
    
    -- View available modes.
    for i, mode in ipairs(modes) do
      local d = win.dataset[i] or {}
      win.dataset[i] = d
      d.id, d.label, d.value = mode:GetName(), mode:GetName(), 1
      if mode.GetSetSummary then
        d.valuetext = mode:GetSetSummary(set)
      end
    end
    -- Tell window to sort by our data order.
    win.metadata.ordersort = true
    -- Let window display the data.
    win:UpdateDisplay()
  else
    win:Wipe()
    
    -- View available sets.
    local nr = 0
    
    for setid, set in pairs(sets) do
      nr = nr + 1
      local d = win.dataset[nr] or {}
      win.dataset[nr] = d
      d.id, d.label, d.value, d.sortnum, d.starttime = setid, set.name, 1, set.sortnum, set.starttime
      if set.starttime > 0 then
        d.valuetext = date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
      else
        d.valuetext = nil
      end
    end
    -- Tell window to sort by our data order.
    win.metadata.ordersort = true
    -- Let window display the data.
    win:UpdateDisplay()
  end
end

local function scan_for_columns(mode)
  -- Only process if not already scanned.
  if not mode.scanned then
    mode.scanned = true
  
    -- Add options for this mode if available.
    if mode.metadata and mode.metadata.columns then
      EminentDKP:AddColumnOptions(mode)
    end
    
    -- Scan any linked modes.
    if mode.metadata then
      if mode.metadata.click1 then
        scan_for_columns(mode.metadata.click1)
      end
      if mode.metadata.click2 then
        scan_for_columns(mode.metadata.click2)
      end
      if mode.metadata.click3 then
        scan_for_columns(mode.metadata.click3)
      end
    end
  end
end

function EminentDKP:GetWindow(name)
  for i, win in ipairs(windows) do
    if win.settings.name == name then
      return win
    end
  end
  return nil
end

-- Register a mode.
function EminentDKP:AddMode(mode)
  table.insert(modes, mode)
  
  -- Add column configuration if available.
  if mode.metadata then
    scan_for_columns(mode)
  end
  
  -- Sort modes.
  table.sort(modes, function(a, b) return a.sortnum < b.sortnum or (not (b.sortnum < a.sortnum) and a.name < b.name) end)
end

-- Unregister a mode.
function EminentDKP:RemoveMode(mode)
  table.remove(modes, mode)
end

function EminentDKP:SetTooltipPosition(tooltip, frame)
  local p = self.db.profile.tooltippos
  if p == "default" then
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40)
  elseif p == "topleft" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
  elseif p == "topright" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
   end
end

local function value_sort(a,b)
  if not a or a.value == nil then
    return false
  elseif not b or b.value == nil then
    return true
  else
    return a.value > b.value
  end
end

-- Tooltip display. Shows subview data for a specific row.
-- Using a fake window, the subviews are asked to populate the window's dataset normally.
local ttwin = Window:new()
function EminentDKP:AddSubviewToTooltip(tooltip, win, mode, id, label)
  -- Clean dataset.
  wipe(ttwin.dataset)
  
  -- Tell mode we are entering our real window.
  mode:Enter(win, id, label)
  
  -- Ask mode to populate dataset in our fake window.
  mode:PopulateData(ttwin, win:get_selected_set())
  
  -- Sort dataset unless we are using ordersort.
  if not mode.metadata or not mode.metadata.ordersort then
    table.sort(ttwin.dataset, value_sort)
  end
  if mode.metadata and mode.metadata.sortfunc then
    table.sort(ttwin.dataset, mode.metadata.sortfunc)
  end

  -- Show title and data if we have data.
  if #ttwin.dataset > 0 then
    tooltip:AddLine(mode.title or mode:GetName(), 1,1,1)

    -- Display the top X, default 3, rows.
    local nr = 0
    for i, data in ipairs(ttwin.dataset) do
      if data.id and nr < EminentDKP.db.profile.tooltiprows then
        nr = nr + 1
        
        local color = {r = 1, g = 1, b = 1}
        if data.color then
          -- Explicit color from dataset.
          color = data.color
        elseif data.class then
          -- Class color.
          local color = EminentDKP.classColors[data.class]
        end
        
        tooltip:AddDoubleLine(nr..". "..data.label, data.valuetext, color.r, color.g, color.b)
      end
    end
    
    -- Add an empty line.
    tooltip:AddLine(" ")
  end
end

--[[-------------------------------------------------------------------
  END Meter Window Functions
---------------------------------------------------------------------]]

-- Setup basic info and get database from saved variables
function EminentDKP:OnInitialize()
  -- Register the SharedMedia
  media:Register("font", "Adventure",       [[Interface\Addons\EminentDKP\fonts\Adventure.ttf]])
  media:Register("font", "ABF",         [[Interface\Addons\EminentDKP\fonts\ABF.ttf]])
  media:Register("font", "Vera Serif",      [[Interface\Addons\EminentDKP\fonts\VeraSe.ttf]])
  media:Register("font", "Diablo",        [[Interface\Addons\EminentDKP\fonts\Avqest.ttf]])
  media:Register("font", "Accidental Presidency", [[Interface\Addons\EminentDKP\fonts\Accidental Presidency.ttf]])
  media:Register("statusbar", "Aluminium",    [[Interface\Addons\EminentDKP\statusbar\Aluminium]])
  media:Register("statusbar", "Armory",     [[Interface\Addons\EminentDKP\statusbar\Armory]])
  media:Register("statusbar", "BantoBar",     [[Interface\Addons\EminentDKP\statusbar\BantoBar]])
  media:Register("statusbar", "Glaze2",     [[Interface\Addons\EminentDKP\statusbar\Glaze2]])
  media:Register("statusbar", "Gloss",      [[Interface\Addons\EminentDKP\statusbar\Gloss]])
  media:Register("statusbar", "Graphite",     [[Interface\Addons\EminentDKP\statusbar\Graphite]])
  media:Register("statusbar", "Grid",       [[Interface\Addons\EminentDKP\statusbar\Grid]])
  media:Register("statusbar", "Healbot",      [[Interface\Addons\EminentDKP\statusbar\Healbot]])
  media:Register("statusbar", "LiteStep",     [[Interface\Addons\EminentDKP\statusbar\LiteStep]])
  media:Register("statusbar", "Minimalist",   [[Interface\Addons\EminentDKP\statusbar\Minimalist]])
  media:Register("statusbar", "Otravi",     [[Interface\Addons\EminentDKP\statusbar\Otravi]])
  media:Register("statusbar", "Outline",      [[Interface\Addons\EminentDKP\statusbar\Outline]])
  media:Register("statusbar", "Perl",       [[Interface\Addons\EminentDKP\statusbar\Perl]])
  media:Register("statusbar", "Smooth",     [[Interface\Addons\EminentDKP\statusbar\Smooth]])
  media:Register("statusbar", "Round",      [[Interface\Addons\EminentDKP\statusbar\Round]])
  media:Register("statusbar", "TukTex",     [[Interface\Addons\EminentDKP\statusbar\normTex]])
  
  -- DB
  self.db = LibStub("AceDB-3.0"):New("EminentDKPDB", self.defaults, "Default")
  LibStub("AceConfig-3.0"):RegisterOptionsTable("EminentDKP", self.options)
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("EminentDKP", "EminentDKP")

  -- Profiles
  LibStub("AceConfig-3.0"):RegisterOptionsTable("EminentDKP-Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
  self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("EminentDKP-Profiles", "Profiles", "EminentDKP")
  
  self.db.RegisterCallback(self, "OnProfileChanged", "ReloadWindows")
  self.db.RegisterCallback(self, "OnProfileCopied", "ReloadWindows")
  self.db.RegisterCallback(self, "OnProfileReset", "ReloadWindows")
  
  -- Modes
  for name, mode in EminentDKP:IterateModules() do
    if mode.OnEnable then
      mode:Enable()
    end
  end
  
  self.myName = UnitName("player")
  
  self.auctionItems = {}
  
  -- Remember sync stuff
  self.syncRequests = {}
  self.syncProposals = {}
  self.requestedRanges = {}
  self.requestCooldown = false
  self.broadcastCooldown = false
  
  self:CreateAuctionFrame()
  self:ReloadWindows()
  
  -- Since SharedMedia doesn't finish loading until after this executes, we need to re-apply
  -- the settings again to ensure everything is how it should be, an unfortunate work-around...
  self:ScheduleTimer("GlobalApplySettings", 2)
  
  -- Temporarily disable officer functionality for the first 8 seconds, ensures no accidental database recreation
  self:ScheduleTimer("UndoTempDisable", 8)
  
  DEFAULT_CHAT_FRAME:AddMessage("|rYou are using |cFFEBAA32EminentDKP |cFFAAEB32v"..VERSION.."|r")
  DEFAULT_CHAT_FRAME:AddMessage("|rVisit |cFFD2691Ehttp://eminent.enjin.com|r for feedback and support.")
end

-- Restore officer functionality, we should know sync status by now
function EminentDKP:UndoTempDisable()
  tempdisabled = false
  self:PARTY_LOOT_METHOD_CHANGED()
end

function EminentDKP:GlobalApplySettings()
  self:ApplySettingsAll()
  self:ApplyAuctionFrameSettings()
  self:PARTY_LOOT_METHOD_CHANGED()
  self:DatabaseUpdate()
  
  -- Broadcast version
  self:SendCommMessage("EminentDKP-SV",self:GetVersion()..":Hello",'GUILD')
end

-- DATABASE UPDATES
function EminentDKP:DatabaseUpdate()
  for name, pool in pairs(self.db.factionrealm.pools) do
    if not pool.revision or pool.revision < 1 then
      self:Print("Applying database revision 1 to pool: "..name)
      -- Convert player classes to English classes
      -- Convert all datetimes to timestamps
      for pid, playerdata in pairs(pool.players) do
        self.db.factionrealm.pools[name].players[pid].class = select(2,UnitClass(self:GetPlayerNameByID(pid))) or string.upper(string.gsub(playerdata.class,"%s*",""))
        self.db.factionrealm.pools[name].players[pid].lastRaid = convertToTimestamp(playerdata.lastRaid)
      end
      for eid, eventdata in pairs(pool.events) do
        self.db.factionrealm.pools[name].events[eid].datetime = convertToTimestamp(eventdata.datetime)
        if eventdata.eventType == 'bounty' and (not eventdata.source or eventdata.source == "") then
          self.db.factionrealm.pools[name].events[eid].source = "Default"
        end
        if eventdata.eventType == 'addplayer' then
          local ei = { strsplit(",",eventdata.extraInfo) }
          ei[1] = select(2,UnitClass(eventdata.value)) or string.upper(string.gsub(ei[1],"%s*",""))
          self.db.factionrealm.pools[name].events[eid].extraInfo = implode(",",ei)
        end
      end
      if self.db.factionrealm.pools[name].lastScan ~= 0 then
        self.db.factionrealm.pools[name].lastScan = convertToTimestamp(self.db.factionrealm.pools[name].lastScan)
      end
      if self.db.profile.raid then
        self.db.profile.raid = nil
      end
      pool.revision = 1
    end
    if pool.revision < 2 then
      self:Print("Applying database revision 2 to pool: "..name)
      -- Rebuild database to fix rename bug found in 2.1.0
      self:RebuildDatabase()
      pool.revision = 2
    end
  end
end

function EminentDKP:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD") -- version broadcast
  self:RegisterChatEvent("CHAT_MSG_WHISPER") -- whisper commands received
  self:RegisterChatEvent("CHAT_MSG_WHISPER_INFORM") -- whispers sent
  self:RegisterChatEvent("CHAT_MSG_PARTY") -- party messages
  self:RegisterChatEvent("CHAT_MSG_PARTY_LEADER") -- party messages
  self:RegisterChatEvent("CHAT_MSG_RAID") -- raid messages
  self:RegisterChatEvent("CHAT_MSG_RAID_LEADER") -- raid messages
  self:RegisterChatEvent("CHAT_MSG_RAID_WARNING") -- raid warnings
  self:RegisterEvent("ACHIEVEMENT_EARNED") -- achievement tracking
  self:RegisterEvent("LOOT_OPENED") -- loot listing
  self:RegisterEvent("LOOT_CLOSED") -- auction cancellation
  self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED") -- masterloot change
  self:RegisterEvent("RAID_ROSTER_UPDATE") -- raid member list update
  self:RegisterEvent("PARTY_MEMBERS_CHANGED") -- party member list update
  self:RegisterEvent("PLAYER_REGEN_DISABLED") -- addon announcements
  self:RegisterEvent("PLAYER_REGEN_ENABLED") -- combat checking
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") -- death tracking
  self:RegisterEvent("UNIT_SPELLCAST_SENT") -- loot container tracking
  --self:RegisterEvent("GUILD_PARTY_STATE_UPDATED") -- guild group tracking
  self:RegisterChatCommand("edkp", "ProcessSlashCmd") -- admin commands
  -- Addon messages
  self:RegisterComm("EminentDKP-SPP", "ProcessSyncProposal")
  self:RegisterComm("EminentDKP-SFF", "ProcessSyncFulfill")
  self:RegisterComm("EminentDKP-SRQ", "ProcessSyncRequest")
  self:RegisterComm("EminentDKP-SV", "ProcessSyncVersion")
  self:RegisterComm("EminentDKP-SE", "ProcessSyncEvent")
  self:RegisterComm("EminentDKP-CMD", "ProcessCommand")
  self:RegisterComm("EminentDKP-INF", "ProcessInformation")
  -- Custom event notifications
  self:RawHookScript(LevelUpDisplay, "OnShow", "LevelUpDisplayShow")
  self:RawHookScript(LevelUpDisplay, "OnHide", "LevelUpDisplayHide")
  self:RawHookScript(RaidWarningFrame, "OnEvent", "HideRaidWarning")
  self:RawHook("LevelUpDisplay_AnimStep", "LevelUpDisplayFinished", true)
  
  if type(CUSTOM_CLASS_COLORS) == "table" then
    self.classColors = CUSTOM_CLASS_COLORS
  end
  
  -- Broadcast version every 5 minutes
  self:ScheduleRepeatingTimer("BroadcastVersion", 300)
end

local notify_types = { "BOUNTY_RECEIVED", "TRANSFER_RECEIVED", "AUCTION_WON", 
                       "TRANSFER_MADE", "ADJUSTMENT_RECEIVED", "ADJUSTMENT_MADE" }

-- Hook the animation step function to change the font size of the flavor text
function EminentDKP:LevelUpDisplayFinished(frame)
  if tContains(notify_types,frame.type) then
    frame.spellFrame.flavorText:SetFontObject("GameFontNormalLarge")
  end
  self.hooks["LevelUpDisplay_AnimStep"](frame)
end

-- Hook the levelUpDisplay OnHide to execute any cached notifications
function EminentDKP:LevelUpDisplayHide(frame)
  self:ExecuteNextNotification()
  self.hooks[frame].OnHide(frame)
end

-- Overriding the default level up display to show custom messages
-- todo: add sound notification option in settings
function EminentDKP:LevelUpDisplayShow(frame)
  local texcoords = {
    dot = { 0.64257813, 0.68359375, 0.18750000, 0.23046875 },
    goldBG = { 0.56054688, 0.99609375, 0.24218750, 0.46679688 },
    gLine = { 0.00195313, 0.81835938, 0.01953125, 0.03320313 },
    textTint = { 0.67, 0.93, 0.45 },
  }
  if tContains(notify_types,frame.type) then
    frame.currSpell = 2 -- currSpell > #(unlockList)
    frame.unlockList = { }
    frame.levelFrame.levelText:SetFontObject("GameFont_Gigantic")
    frame:SetHeight(72)
    frame.levelFrame:SetHeight(72)
    if frame.type == "BOUNTY_RECEIVED" then
      frame.levelFrame.reachedText:SetFormattedText(L["You have received a bounty of"])
      frame.levelFrame.levelText:SetFormattedText("%.02f DKP",self.notifyDetails.desc)
    elseif frame.type == "ADJUSTMENT_RECEIVED" then
      if self.notifyDetails.extra then
        -- This is a deduction
        frame.levelFrame.reachedText:SetFormattedText(L["You have been deducted"])
        texcoords.textTint = { 0.92, 0.49, 0.04 }
      else
        frame.levelFrame.reachedText:SetFormattedText(L["You have been awarded"])
      end
      frame.levelFrame.levelText:SetFormattedText("%.02f DKP",self.notifyDetails.desc)
    elseif frame.type == "ADJUSTMENT_MADE" then
      frame:SetHeight(50)
      frame.levelFrame:SetHeight(50)
      if self.notifyDetails.extra then
        -- This is a deduction
        frame.levelFrame.reachedText:SetFormattedText(L["%s has been deducted"],self.notifyDetails.src)
        texcoords.textTint = { 0.92, 0.49, 0.04 }
      else
        frame.levelFrame.reachedText:SetFormattedText(L["%s has been awarded"],self.notifyDetails.src)
      end
      frame.levelFrame.levelText:SetFontObject("GameFontNormalLarge")
      frame.levelFrame.levelText:SetFormattedText("%.02f DKP",self.notifyDetails.desc)
    elseif frame.type == "TRANSFER_RECEIVED" then
      frame.levelFrame.reachedText:SetFormattedText(L["%s has transferred you"],self.notifyDetails.src)
      frame.levelFrame.levelText:SetFormattedText("%.02f DKP",self.notifyDetails.desc)
    elseif frame.type == "TRANSFER_MADE" then
      frame:SetHeight(50)
      frame.levelFrame:SetHeight(50)
      frame.levelFrame.reachedText:SetFormattedText(L["%s has transferred %s"],self.notifyDetails.src,self.notifyDetails.extra)
      frame.levelFrame.levelText:SetFontObject("GameFontNormalLarge")
      frame.levelFrame.levelText:SetFormattedText("%.02f DKP",self.notifyDetails.desc)
      texcoords.textTint = { 0.92, 0.49, 0.04 }
    elseif frame.type == "AUCTION_WON" then
      table.insert(frame.unlockList,{ icon=select(10,GetItemInfo(self.notifyDetails.desc)),
                                      subIcon=SUBICON_TEXCOOR_ARROW,
                                      text=string.format(L["has been acquired for %d DKP"],self.notifyDetails.src),
                                      subText=select(2,GetItemInfo(self.notifyDetails.desc)),
                                      })
      frame.currSpell = 1
      frame.levelFrame.reachedText:SetFormattedText(L["You Have Just"])
      frame.levelFrame.levelText:SetFormattedText(L["Won An Auction"])
      texcoords.textTint = nil
    end
    frame.gLine:SetTexCoord(unpack(texcoords.gLine))
    frame.gLine2:SetTexCoord(unpack(texcoords.gLine))
    if (texcoords.tint) then
        frame.gLine:SetVertexColor(unpack(texcoords.tint))
        frame.gLine2:SetVertexColor(unpack(texcoords.tint))
    else
        frame.gLine:SetVertexColor(1, 1, 1);
        frame.gLine2:SetVertexColor(1, 1, 1);
    end
    if (texcoords.textTint) then
        frame.levelFrame.levelText:SetTextColor(unpack(texcoords.textTint))
    else
        frame.levelFrame.levelText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
    frame.levelFrame.levelUp:Play()
  else
    self.hooks[frame].OnShow(frame)
  end
end

local animating = false
local queued_notifications = {}

-- Execute cached on-screen notifications
function EminentDKP:ExecuteNextNotification()
  if #(queued_notifications) > 0 then
    local n = tremove(queued_notifications)
    LevelUpDisplay.type = n.type
    self.notifyDetails = n.data
    LevelUpDisplay:Show()
    LevelUpDisplaySide:Hide()
  else
    animating = false
  end
end

-- Play a notification (or cache it)
function EminentDKP:NotifyOnScreen(...)
  local eventType, received, source, extra = ...
  local data = { src = source, desc = received, extra = extra }
  
  if animating then
    table.insert(queued_notifications,1,{ type=eventType, data=data })
  else
    LevelUpDisplay.type = eventType
    self.notifyDetails = data
    animating = true
    LevelUpDisplay:Show()
    LevelUpDisplaySide:Hide()
  end
end

-- Permission check for a command *sent* to a masterlooter
function EminentDKP:EnsureToMasterlooter(addon,method,from)
  if not self.amMasterLooter then
    self:WhisperPlayer(addon,method,L["That command must be sent to the master looter."],from)
    return false
  end
  if not self:AmOfficer() then
    self:WhisperPlayer(addon,method,L["The master looter must be an officer."],from)
    return false
  end
  if not UnitExists(from) then
    self:WhisperPlayer(addon,method,L["You are not in the current group."],from)
    return false
  end
  if not self:IsEnabled() then
    self:WhisperPlayer(addon,method,L["EminentDKP is currently disabled."],from)
    return false
  end
  return true
end

-- Check if the command can only be used by an officer
function EminentDKP:EnsureOfficership()
  if not self:AmOfficer() then
    self:DisplayActionResult(L["That command can only be used by an officer."])
    return false
  end
  if self:NeedSync() then
    self:DisplayActionResult(L["Your database must be up to date first."])
    return false
  end
  if not self:IsEnabled() then
    self:DisplayActionResult(L["EminentDKP is currently disabled."])
    return false
  end
  return true
end

-- Check if the command can only be used by masterlooter (and officer)
function EminentDKP:EnsureMasterlooter()
  if not self:EnsureOfficership() then return false end
  if self.lootMethod ~= 'master' then
    self:DisplayActionResult(L["Master looting must be enabled."])
    return false
  end
  if not self.amMasterLooter then
    self:DisplayActionResult(L["Only the master looter can use that command."])
    return false
  end
  return true
end

function EminentDKP:OnDisable()
end

function EminentDKP:GetVersion()
  return VERSION .. '.' .. self:GetEventCount()
end

function EminentDKP:GetNewestVersion()
  return (newest_version ~= '' and newest_version or self:GetVersion())
end

function EminentDKP:GetAddonVersions()
  return addon_versions
end

function EminentDKP:NeedUpgrade()
  return needs_update
end

---------- START SYNC FUNCTIONS ----------

function EminentDKP:GetNewestEventCount()
  local b = { strsplit(".",self:GetNewestVersion(),4) }
  return tonumber(b[4])
end

function EminentDKP:GetEventCountDifference()
  return self:GetNewestEventCount() - self:GetEventCount()
end

function EminentDKP:IsSyncing()
  return syncing
end

function EminentDKP:NeedSync()
  return (self:GetEventCountDifference() > 0)
end

local function GetRange(string)
  local range = { strsplit("-",string) }
  return tonumber(range[1]), tonumber(range[2])
end

-- Record a requested event range
function EminentDKP:LogRequestedEventRange(newrange)
  local new_start, new_finish = GetRange(newrange)
  -- We don't care about ranges below our current eventCounter
  if new_finish <= self:GetEventCount() then return end
  
  local found = false
  for i, range in ipairs(self.requestedRanges) do
    local cur_start, cur_finish = GetRange(range)
    if new_finish > cur_finish and new_start < cur_start then
      -- New range is bigger than the current range
      self.requestedRanges[i] = newrange
      found = true
      break
    elseif new_finish <= cur_finish and new_start >= cur_start then
      -- New range is within current range, do nothing
      found = true
      break
    elseif new_start <= cur_finish then
      -- New range clips the end of the current, so extend current
      self.requestedRanges[i] = cur_start.."-"..new_finish
      found = true
      break
    elseif new_finish >= cur_start then
      -- New range clips the front of the current, so extend current
      self.requestedRanges[i] = new_start.."-"..cur_finish
      found = true
      break
    end
  end
  if not found then
    table.insert(self.requestedRanges,newrange)
  end
end

-- Get range of events we need that aren't in the cache
-- But also omit any recently requested ranges
function EminentDKP:GetMissingEventList()
  local start = self:GetEventCount() + 1
  local finish = self:GetNewestEventCount()
  
  -- Build the ranges available in the events cache
  local event_cache_ranges = {}
  local last_cache_start
  local last_eid
  for eid = start, finish do
    if events_cache[tostring(eid)] then
      if not last_cache_start then
        last_cache_start = eid
      end
    elseif last_cache_start then
      table.insert(event_cache_ranges,last_cache_start.."-"..last_eid)
      last_cache_start = nil
    end
    last_eid = eid
  end
  
  -- Consolidate all the ranges
  local all_ranges = {}
  MergeTables(all_ranges,event_cache_ranges)
  MergeTables(all_ranges,self.requestedRanges)
  
  -- Sort by range start
  if #(all_ranges) > 1 then
    table.sort(all_ranges,function(a,b)
      local a_s = GetRange(a)
      local b_s = GetRange(b)
      return a_s < b_s
    end)
  end
  
  -- Combine any overlapping ranges
  local merged = true
  while merged ~= false and #(all_ranges) > 1 do
    for i = 1, #(all_ranges) do
      local cur_start, cur_finish = GetRange(all_ranges[i])
      local next_start, next_finish
      if all_ranges[i+1] then
        next_start, next_finish = GetRange(all_ranges[i+1])
        if cur_finish >= next_start then
          all_ranges[i] = cur_start.."-"..next_finish
          merged = true
          break
        end
      else
        merged = false
      end
    end
  end
  
  -- Build the ranges of events we need
  -- Assuming there are no overlapping ranges, and they are ordered
  local missing_ranges = {}
  if #(all_ranges) > 1 then
    for i, range in ipairs(all_ranges) do
      local cur_start, cur_finish = GetRange(all_ranges[i])
      if i == 1 then
        if cur_start > start then
          table.insert(missing_ranges,start.."-"..(cur_start-1))
        end
      else
        local last_start, last_finish = GetRange(all_ranges[i-1])
        table.insert(missing_ranges,(last_finish+1).."-"..(cur_start-1))
        if i == #(all_ranges) then
          if cur_finish < finish then
            table.insert(missing_ranges,(cur_finish+1).."-"..finish)
          end
        end
      end
    end
  elseif #(all_ranges) == 1 then
    local r_s, r_f = GetRange(all_ranges[1])
    if r_s > start then
      table.insert(missing_ranges,start.."-"..(r_s-1))
    end
    if r_f < finish then
      table.insert(missing_ranges,(r_f+1).."-"..finish)
    end
  else
    table.insert(missing_ranges,start.."-"..finish)
  end
  
  return missing_ranges
end

function EminentDKP:ScheduleEventsRequest(time)
  self:CancelEventsRequest()
  if not self.requestCooldown then
    self.requestTimer = self:ScheduleTimer("RequestMissingEvents", (time ~= nil and time or 3))
  end
end

function EminentDKP:CancelEventsRequest()
  if self.requestTimer then
    self:CancelTimer(self.requestTimer,true)
    self.requestTimer = nil
  end
end

function EminentDKP:ClearRequestCooldown()
  self.requestCooldown = false
end

-- Request the missing events
function EminentDKP:RequestMissingEvents()
  -- No longer syncing at this point...
  syncing = false
  self:UpdateStatusBar()
  
  local mlist = self:GetMissingEventList()
  if #(mlist) > 0 then
    self.requestCooldown = true
    self:SendCommMessage("EminentDKP-SRQ",self:GetVersion() .. '_' ..implode(',',mlist),'GUILD')
    -- 10 second cooldown on doing an event requests, gives time for stuff to start syncing
    self:ScheduleTimer("ClearRequestCooldown", 10)
  end
  wipe(self.requestedRanges)
end

function EminentDKP:ClearBroadcastCooldown()
  self.broadcastCooldown = false
end

-- Broadcast current addon version
function EminentDKP:BroadcastVersion()
  if not self.broadcastCooldown then
    self.broadcastCooldown = true
    self:SendCommMessage("EminentDKP-SV",self:GetVersion(),'GUILD')
    -- 15 second cooldown on broadcasting version, reduces spam
    self:ScheduleTimer("ClearBroadcastCooldown", 15)
  end
end

-- Determine if we are the proposal winner, and if so do the syncing
function EminentDKP:ProcessRequestProposals(who)
  if not self:AmOfficer() then return end
  if not self.syncProposals[who] then return end
  
  -- First determine who has the latest event version
  local highestEventCount = 0
  local winners = {}
  local rolls = {}
  for i,data in ipairs(self.syncProposals[who]) do
    local major,minor,bug,ec = strsplit('.',data.v)
    local ecount = tonumber(ec)
    if ecount > highestEventCount then
      highestEventCount = ecount
      wipe(winners)
      table.insert(winners,1,data.name)
    elseif ecount == highestEventCount then
      table.insert(winners,1,data.name)
    end
    rolls[data.name] = data.rolls
  end
  
  -- Then determine from the latest versions, who has the best roll
  if #(winners) > 1 then
    local highestRoll = 0
    local rollwinners = {}
    for i=1, 3 do
      for j,name in ipairs(winners) do
        local roll = tonumber(rolls[name][i])
        if roll > highestRoll then
          highestRoll = roll
          wipe(rollwinners)
          table.insert(rollwinners,1,name)
        elseif roll == highestRoll then
          table.insert(rollwinners,1,name)
        end
      end
      if #(rollwinners) == 1 then break end
    end
    winners = rollwinners
  end
  
  -- It is "theoretically" possible that winners may contain more than 1 person
  -- However we will simply compare the first value against ourself, so ultimately
  -- Only one unique person will fulfill the request no matter what
  
  if winners[1] == self.myName then
    -- We have won the proposal, announce that we are fulfilling their request
    self:SendCommMessage("EminentDKP-SFF",self:GetVersion() .. '_' .. who,'GUILD')
    
    -- Then go ahead and sync the events for them
    for i,range in ipairs(self.syncRequests[who].ranges) do
      local start, finish = GetRange(range)
      for eid = start, finish do
        self:SyncEvent(tostring(eid))
      end
    end
  end
  self.syncRequests[who] = nil
  self.syncProposals[who] = nil
end

-- Record a proposal to somebody's event request
function EminentDKP:ProcessSyncProposal(prefix, message, distribution, sender)
  if not self:AmOfficer() or not self:IsAnOfficer(sender) then return end
  
  local version, person, numbers = strsplit('_',message)
  if not CheckVersionCompatability(version) then return end
  
  -- We only care about proposals in which we are competing against
  if self.syncRequests[person] then
    local numberlist = { strsplit(',',numbers) }
    table.insert(self.syncProposals[person],1,{ name = sender, rolls = numberlist, v = version })
    self:CancelTimer(self.syncRequests[person].timer,true)
    -- Wait 3 seconds for anymore proposals (to compensate for any addon or latency lag)
    self.syncRequests[person].timer = self:ScheduleTimer("ProcessRequestProposals", 3, person)
  end
end

-- Acknowledge an event request fulfillment for a person
function EminentDKP:ProcessSyncFulfill(prefix, message, distribution, sender)
  if sender == self.myName then return end
  if not self:AmOfficer() or not self:IsAnOfficer(sender) then return end
  local version, person = strsplit('_',message)
  if not CheckVersionCompatability(version) then return end
  
  -- The request has been fulfilled, abandon any remaining hope
  if self.syncRequests[person] then
    self:CancelTimer(self.syncRequests[person].timer,true)
    self.syncRequests[person] = nil
    self.syncProposals[person] = nil
  end
end

-- Determine if we can fulfill the needed ranges of events
function EminentDKP:CanFulfillRanges(range_list)
  local can = true
  for i,range in ipairs(range_list) do
    local start, finish = GetRange(range)
    if finish > self:GetEventCount() then
      can = false
      break
    end
  end
  return can
end

-- Process an incoming request for missing events
function EminentDKP:ProcessSyncRequest(prefix, message, distribution, sender)
  if sender == self.myName then return end
  local version, ranges = strsplit('_',message)
  if not CheckVersionCompatability(version) then return end
  local needed_ranges = { strsplit(',',ranges) }
  
  -- If an officer and can fulfill the needed ranges...
  if self:AmOfficer() and self:CanFulfillRanges(needed_ranges) then
    -- Create a proposal to fulfill this request
    local numbers = { math.random(1000), math.random(1000), math.random(1000) }
    self.syncRequests[sender] = { ranges = needed_ranges, timer = nil }
    self.syncProposals[sender] = { }
  
    self:SendCommMessage("EminentDKP-SPP",self:GetVersion() .. '_' .. sender .. '_' ..implode(',',numbers),'GUILD')
  end
  
  -- Remember which ranges were requested
  for i,range in ipairs(needed_ranges) do
    self:LogRequestedEventRange(range)
  end
end

-- Compare the version against our version, and note any newer version
function EminentDKP:ProcessSyncVersion(prefix, message, distribution, sender)
  if sender == self.myName then return end
  local version, welcome = strsplit(':',message,2)
  local compare = CompareVersions(self:GetVersion(),version)
  
  -- Keep track of their version
  addon_versions[sender] = version
  
  UpdateNewestVersion(version)
  self:UpdateStatusBar()
  if compare.major > 0 or compare.minor > 0 then
    -- Broadcast our newer version
    self:BroadcastVersion()
  elseif compare.major == 0 and compare.minor == 0 then
    if compare.bug > 0 or compare.event > 0 then
      -- Broadcast our newer version
      self:BroadcastVersion()
    end
    if compare.event < 0 or compare.bug < 0 then
      if compare.event < 0 then
        -- Event data is out of date
        self:ScheduleEventsRequest(math.random(3,8))
      end
    end
  end
  
  -- If they load during an auction, and are eligible, notify them appropriately
  if welcome and welcome == "Hello" then
    if self:AmMasterLooter() and auction_active and eligible_looters[sender] then
      -- Start the auction for them
      self:InformPlayer("auction",{ 
        guid=self.bidItem.srcGUID, 
        slot=self.bidItem.slotNum, 
        timeleft=(self.bidItem.ending - GetTime()),
        window=self.bidItem.window,
      },sender)
    end
  end
end

-- Process an incoming synced event
function EminentDKP:ProcessSyncEvent(prefix, message, distribution, sender)
  if sender == self.myName then return end
  if not self:IsAnOfficer(sender) then return end
  
  -- Decode the compressed data
  local one = libCE:Decode(message)

  -- Decompress the decoded data
  local two, message = libC:Decompress(one)
  if not two then
    self:Print("Error occured while decoding a sync event:" .. message)
    return
  end
  
  local version, eventID, data = strsplit('_',two,3)
  -- Ignore events from incompatible versions
  if not CheckVersionCompatability(version) then return end
  
  -- Deserialize the decompressed data
  local success, event = libS:Deserialize(data)
  if not success then
    self:Print("Error occured while deserializing a sync event.")
    return
  end
  
  -- We will only act on the next chronological event and cache future events
  local currentEventID = self:GetEventCount()
  if tonumber(eventID) > currentEventID then
    syncing = true
    if tonumber(eventID) == (currentEventID + 1) then
      -- Effectively delay any event requests since we're processing another event
      self:CancelEventsRequest()
      self:ReplicateSyncEvent(eventID,event)
    else
      -- This is an event in the future, so cache it
      events_cache[eventID] = event
      -- Keep scheduling an events request, as eventually
      -- we'll stop caching events and need to fill in the holes
      self:ScheduleEventsRequest()
    end
    self:UpdateStatusBar()
  end
end

-- Replicate a synced event
function EminentDKP:ReplicateSyncEvent(eventID,event)
  -- Determine which event creation function to use
  if event.eventType == 'auction' then
    local tname = self:GetPlayerNameByID(event.target)
    self:CreateAuctionEvent({ strsplit(',',event.beneficiary) },tname,event.value,event.source,event.extraInfo,event.datetime)
  elseif event.eventType == 'bounty' then
    self:CreateBountyEvent({ strsplit(',',event.beneficiary) },event.value,event.source,event.datetime)
  elseif event.eventType == 'addplayer' then
    local classname, dkp, vanitydkp = strsplit(',',event.extraInfo)
    self:CreateAddPlayerEvent(event.value,classname,tonumber(dkp),tonumber(vanitydkp),event.datetime)
  elseif event.eventType == 'transfer' then
    local sname = self:GetPlayerNameByID(event.source)
    local tname = self:GetPlayerNameByID(event.target)
    self:CreateTransferEvent(sname,tname,event.value,event.datetime)
  elseif event.eventType == 'expiration' then
    local sname = self:GetPlayerNameByID(event.source)
    self:CreateExpirationEvent(sname,event.datetime)
  elseif event.eventType == 'purge' then
    local sname = self:GetPlayerNameByID(event.source)
    self:CreatePurgeEvent(sname,event.datetime)
  elseif event.eventType == 'vanityreset' then
    local sname = self:GetPlayerNameByID(event.source)
    self:CreateVanityResetEvent(sname,event.datetime)
  elseif event.eventType == 'adjustment' then
    local tname = self:GetPlayerNameByID(event.target)
    self:CreateAdjustmentEvent(tname,math.abs(event.value),(event.value < 0),event.source,event.datetime)
  elseif event.eventType == 'rename' then
    self:CreateRenameEvent(event.extraInfo,event.value,event.datetime)
  else
    -- This is an unknown event type
    return
  end
  
  local next_eventID = tostring(tonumber(eventID) + 1)
  events_cache[eventID] = nil
  local event_date = GetDate(event.datetime)
  if synced_dates[event_date] then
    table.insert(synced_dates[event_date],eventID)
  else
    synced_dates[event_date] = { eventID }
  end
  
  if self:GetEventCountDifference() > 0 then
    if events_cache[next_eventID] then
      -- We have the next event we need to proceed with updating...
      self:ReplicateSyncEvent(next_eventID,events_cache[next_eventID])
    else
      -- We lack what we need to continue onward...
      self:ScheduleEventsRequest(math.random(3,8))
    end
  else
    -- We're up to date!
    wipe(events_cache)
    syncing = false
    self:UpdateSyncedDays()
  end
end

---------- END SYNC FUNCTIONS ----------

-- Formats a number into human readable form.
function EminentDKP:FormatNumber(number)
  if number then
    if self.db.profile.numberformat == 1 then
      if number > 1000000 then
        return ("%02.2fM"):format(number / 1000000)
      else
        return ("%02.1fK"):format(number / 1000)
      end
    else
      return self:StdNumber(number)
    end
  end
end

function EminentDKP:MessageGroup(what)
  sendchat(what,(is_in_party() and "party" or "raid"),"preset")
end

function EminentDKP:AuctionActive()
  return auction_active
end

function EminentDKP:StdNumber(number)
  return string.format('%.02f', number)
end

function EminentDKP:IsAnOfficer(who)
  local guildName, guildRankName, guildRankIndex = GetGuildInfo(who)
  return (guildRankIndex < 2)
end

function EminentDKP:AmOfficer()
  return self:IsAnOfficer("player")
end

function EminentDKP:GetActivePool()
  return self.db.factionrealm.pools[self.db.profile.activepool]
end

function EminentDKP:GetLastScan()
  return self:GetActivePool().lastScan
end

function EminentDKP:GetEventPool()
  return self:GetActivePool().events
end

function EminentDKP:GetEvent(eventID)
  return self:GetActivePool().events[eventID]
end

function EminentDKP:GetEventCount()
  return self:GetActivePool().eventCounter
end

function EminentDKP:IsPlayerFresh(name)
  local player = (type(name) == "string" and self:GetPlayerByName(name) or name)
  if player then
    return (not next(player.earnings) and not next(player.deductions))
  end
  return nil
end

function EminentDKP:GetPlayerByID(pid)
  return self:GetActivePool().players[pid], self:GetPlayerNameByID(pid)
end

function EminentDKP:GetPlayerByName(name)
  local pid = self:GetPlayerIDByName(name)
  if pid ~= nil then
    return self:GetPlayerByID(pid), pid
  end
  return nil
end

-- Get a player's ID
function EminentDKP:GetPlayerIDByName(name)
  return self:GetActivePool().playerIDs[name]
end

-- Get player name from player ID
function EminentDKP:GetPlayerNameByID(pid)
  for name,id in pairs(self:GetActivePool().playerIDs) do
    if id == pid then
      return name
    end
  end
  return nil
end

function EminentDKP:GetPlayerClassByID(pid)
  if self:GetActivePool().players[pid] then
    return self:GetActivePool().players[pid].class
  end
  return nil
end

-- Check whether or not a player exists in the currently active pool
function EminentDKP:PlayerExistsInPool(name)
  return (self:GetPlayerIDByName(name) ~= nil)
end

-- Update a player's last raid day
function EminentDKP:UpdatePlayerLastRaid(pid,datetime)
  local player = self:GetPlayerByID(pid)
  player.lastRaid = datetime
  player.active = true
end

-- Check if a player has a certain amount of DKP
function EminentDKP:PlayerHasDKP(name,amount)
  local player = self:GetPlayerByName(name)
  return (player ~= nil and player.currentDKP >= amount)
end

-- Get current DKP for a player
function EminentDKP:GetCurrentDKP(name)
  local player = self:GetPlayerByName(name)
  return (player ~= nil and player.currentDKP or nil)
end

-- Get the your current DKP
function EminentDKP:GetMyCurrentDKP()
  return self:GetCurrentDKP(self.myName)
end

-- Get the names of everybody in the pool
function EminentDKP:GetPlayerNames(active)
  local list = {}
  for name,pid in pairs(self:GetActivePool().playerIDs) do
    local player = self:GetPlayerByID(pid)
    if not active or (active and player.active) then
      list[name] = name
    end
  end
  return list
end

-- Get the names of everybody else in the pool
function EminentDKP:GetOtherPlayersNames(active)
  local list = self:GetPlayerNames(active)
  list[self.myName] = nil
  return list
end

function EminentDKP:GetPlayersOfClass(name,fresh)
  local player, playerid = self:GetPlayerByName(name)
  local list = {}
  for pid,data in pairs(self:GetActivePool().players) do
    if playerid ~= pid and data.class == player.class then
      if not fresh or (fresh and self:IsPlayerFresh(data)) then
        local name = self:GetPlayerNameByID(pid)
        list[name] = name
      end
    end
  end
  return list
end

function EminentDKP:GetPlayerPool()
  return self:GetActivePool().players
end

function EminentDKP:GetBountySize()
  return self:GetActivePool().bounty.size
end

function EminentDKP:GetAvailableBounty()
  return self:GetActivePool().bounty.available
end

function EminentDKP:GetAvailableBountyPercent()
  return (self:GetAvailableBounty()/self:GetBountySize())*100
end

-- Construct list of names for players currently in the group
function EminentDKP:GetCurrentGroupMembersNames()
  local players = {}
  if is_in_party() then
    for spot = 1, 5 do
      local name = UnitName("party"..spot)
      if name then
        table.insert(players,name)
      end
    end
  else
    for spot = 1, 40 do
      local name = UnitName("raid"..spot)
      if name then
        table.insert(players,name)
      end
    end
  end
  return players
end

-- Construct list of IDs for players currently in the group
function EminentDKP:GetCurrentGroupMembersIDs()
  local players = {}
  if is_in_party() then
    for spot = 1, 5 do
      local name = UnitName("party"..spot)
      if name then
        table.insert(players,self:GetPlayerIDByName(name))
      end
    end
  else
    for spot = 1, 40 do
      local name = UnitName("raid"..spot)
      if name then
        table.insert(players,self:GetPlayerIDByName(name))
      end
    end
  end
  return players
end

-- Construct list of players currently in the group
function EminentDKP:GetCurrentGroupMembers()
  local players = {}
  for i, pid in ipairs(self:GetCurrentGroupMembersIDs()) do
    local pdata = self:GetPlayerByID(pid)
    players[pid] = pdata
  end
  return players
end

---------- START EARNINGS + DEDUCTIONS FUNCTIONS ----------

function EminentDKP:IncreaseAvailableBounty(amount)
  self:GetActivePool().bounty.available = self:GetAvailableBounty() + amount
end

function EminentDKP:DecreaseAvailableBounty(amount)
  self:GetActivePool().bounty.available = self:GetAvailableBounty() - amount
end

function EminentDKP:CreatePlayerVanityDeduction(pid,eventID,amount)
  local player = self:GetPlayerByID(pid)
  
  -- Set the deduction for the player
  player.deductions[eventID] = amount
  
  -- Update current Vanity DKP
  player.currentVanityDKP = player.currentVanityDKP - amount
end

function EminentDKP:CreatePlayerDeduction(pid,eventID,amount)
  local player = self:GetPlayerByID(pid)
  
  -- Set the deduction for the player
  player.deductions[eventID] = amount
  
  -- Update current DKP
  player.currentDKP = player.currentDKP - amount
end

function EminentDKP:CreatePlayerEarning(pid,eventID,amount,earnsVanity)
  local player = self:GetPlayerByID(pid)
  
  -- Set the earning for the player
  player.earnings[eventID] = amount
  
  -- Update current DKP (normal and vanity)
  player.currentDKP = player.currentDKP + amount
  player.earnedDKP = player.earnedDKP + amount
  
  -- Transfers do not earn vanity dkp (for obvious reasons)
  if earnsVanity then
    player.currentVanityDKP = player.currentVanityDKP + amount
    player.earnedVanityDKP = player.earnedVanityDKP + amount
  end
end

---------- END EARNINGS + DEDUCTIONS FUNCTIONS ----------

---------- START EVENT FUNCTIONS ----------
function EminentDKP:SyncEvent(eventID)
  -- Serialize and compress the data
  local data = self:GetEvent(eventID)
  local one = self:GetVersion() .. '_' .. eventID .. '_'.. libS:Serialize(data)
  local two = libC:CompressHuffman(one)
  local final = libCE:Encode(two)
  
  self:SendCommMessage("EminentDKP-SE",final,'GUILD',nil,'BULK')
end

function EminentDKP:CreateAddPlayerSyncEvent(name,className)
  self:SyncEvent(self:CreateAddPlayerEvent(name,className,0,0,time()))
end

-- Add a player to the active pool
function EminentDKP:CreateAddPlayerEvent(name,className,dkp,vanitydkp,dtime)
  -- Get a new player ID
  local pc = self:GetActivePool().playerCounter
  pc = pc + 1
  self:GetActivePool().playerCounter = pc
  local pid = tostring(pc)
  self:GetActivePool().playerIDs[name] = pid
  
  -- Create the new player data
  self:GetActivePool().players[pid] = { 
    class=className, 
    lastRaid=dtime,
    currentDKP=0,
    currentVanityDKP=0,
    earnedDKP=0,
    earnedVanityDKP=0,
    earnings={},
    deductions={},
    active=true
  }
  
  -- Remember the initial info
  local info = className .. ',' .. tostring(dkp) .. ',' .. tostring(vanitydkp)
  
  -- Create the event
  local cid = self:CreateEvent(pid,"addplayer",info,"","",name,dtime)
  
  -- Reflect the default dkps
  if vanitydkp > 0 and vanitydkp > dkp then
    self:CreatePlayerEarning(pid,cid,vanitydkp,true)
    if dkp > 0 then
      self:CreatePlayerDeduction(pid,cid,(vanitydkp-dkp))
    end
    self:DecreaseAvailableBounty(dkp)
  elseif vanitydkp > 0 and vanitydkp <= dkp then
    self:CreatePlayerEarning(pid,cid,dkp,true)
    if vanitydkp < dkp then
      self:CreatePlayerVanityDeduction(pid,cid,(dkp-vanitydkp))
    end
    self:DecreaseAvailableBounty(dkp)
  elseif vanitydkp == 0 and dkp > 0 then
    self:CreatePlayerEarning(pid,cid,dkp,false)
    self:DecreaseAvailableBounty(dkp)
  end
  
  return cid
end

function EminentDKP:CreateBountySyncEvent(players,amount,srcName)
  self:SyncEvent(self:CreateBountyEvent(players,amount,srcName,time()))
end

function EminentDKP:CreateBountyEvent(players,amount,srcName,dtime)
  -- Create the event
  local cid = self:CreateEvent(srcName,"bounty","","",implode(',',players),amount,dtime)
  
  -- Modify the bounty pool
  self:DecreaseAvailableBounty(amount)
  
  -- Then create all the necessary earnings for players
  local dividend = (amount/#(players))
  for i,pid in ipairs(players) do
    self:CreatePlayerEarning(pid,cid,dividend,true)
    self:UpdatePlayerLastRaid(pid,dtime)
  end
  
  return cid
end

function EminentDKP:CreateAuctionSyncEvent(players,to,amount,srcName,srcExtra)
  self:SyncEvent(self:CreateAuctionEvent(players,to,amount,srcName,srcExtra,time()))
end

function EminentDKP:CreateAuctionEvent(players,to,amount,srcName,srcExtra,dtime)
  local pid = self:GetPlayerIDByName(to)
  -- Create the event
  local cid = self:CreateEvent(srcName,"auction",srcExtra,pid,implode(',',players),amount,dtime)
  
  -- Then create the necessary deduction for the receiver
  self:CreatePlayerDeduction(pid,cid,amount)
  
  -- Update receiver's last raid
  self:UpdatePlayerLastRaid(pid,dtime)
  
  -- Then create all the necessary earnings for players
  local dividend = (amount/#(players))
  for i,rpid in ipairs(players) do
    self:CreatePlayerEarning(rpid,cid,dividend,true)
    self:UpdatePlayerLastRaid(rpid,dtime)
  end
  
  return cid
end

function EminentDKP:CreateTransferSyncEvent(from,to,amount)
  self:SyncEvent(self:CreateTransferEvent(from,to,amount,time()))
end

function EminentDKP:CreateTransferEvent(from,to,amount,dtime)
  local pfid = self:GetPlayerIDByName(from)
  local ptid = self:GetPlayerIDByName(to)
  
  -- Create the event
  local cid = self:CreateEvent(pfid,"transfer","",ptid,"",amount,dtime)
  
  -- Then create the necessary deduction and earning for both players
  self:CreatePlayerDeduction(pfid,cid,amount)
  self:CreatePlayerEarning(ptid,cid,amount,false)
  
  -- Update sender's last raid
  self:UpdatePlayerLastRaid(pfid,dtime)
  
  return cid
end

function EminentDKP:CreatePurgeSyncEvent(name)
  self:SyncEvent(self:CreatePurgeEvent(name,time()))
end

-- This assumes the player is fresh
function EminentDKP:CreatePurgeEvent(name,dtime)
  local pid = self:GetPlayerIDByName(name)
  
  -- Create the event
  local cid = self:CreateEvent(pid,"purge",name,"","",0,dtime)
  
  self:GetActivePool().playerIDs[name] = nil
  self:GetActivePool().players[pid] = nil
  
  return cid
end

function EminentDKP:CreateAdjustmentSyncEvent(name,amount,deduction,reason)
  self:SyncEvent(self:CreateAdjustmentEvent(name,amount,deduction,reason,time()))
end

function EminentDKP:CreateAdjustmentEvent(name,amount,deduction,reason,dtime)
  local pdata, pid = self:GetPlayerByName(name)
  
  if deduction then amount = amount * -1 end
  
  -- Create the event
  local cid = self:CreateEvent(reason,"adjustment","",pid,"",amount,dtime)
  
  if deduction then
    -- If deducting: subtract DKP and add it back to the bounty pool
    self:CreatePlayerDeduction(pid,cid,math.abs(amount))
    self:IncreaseAvailableBounty(math.abs(amount))
  else
    -- If earning: add DKP and subtract it from the bounty pool
    self:CreatePlayerEarning(pid,cid,amount)
    self:DecreaseAvailableBounty(amount)
  end
  
  return cid
end

function EminentDKP:CreateExpirationSyncEvent(name)
  self:SyncEvent(self:CreateExpirationEvent(name,time()))
end

function EminentDKP:CreateExpirationEvent(name,dtime)
  local pdata, pid = self:GetPlayerByName(name)
  local dkpAmt = pdata.currentDKP
  local vanityAmt = pdata.currentVanityDKP
  
  -- Create the event
  local cid = self:CreateEvent(pid,"expiration","","","",0,dtime)
  
  -- Then create the necessary deductions for the player
  self:CreatePlayerVanityDeduction(pid,cid,vanityAmt)
  self:CreatePlayerDeduction(pid,cid,dkpAmt)
  
  -- Modify the bounty pool
  self:IncreaseAvailableBounty(dkpAmt)
  
  -- Mark the player as inactive (to bypass future expiration checks)
  pdata.active = false
  
  return cid
end

function EminentDKP:CreateVanityResetSyncEvent(name)
  self:SyncEvent(self:CreateVanityResetEvent(name,time()))
end

function EminentDKP:CreateVanityResetEvent(name,dtime)
  local pdata, pid = self:GetPlayerByName(name)
  local amount = pdata.currentVanityDKP
  
  -- Create the event
  local cid = self:CreateEvent(pid,"vanityreset","","","",amount,dtime)
  
  -- Update player's last raid
  self:UpdatePlayerLastRaid(pid,dtime)
  
  -- Then create the necessary deduction for the player
  self:CreatePlayerVanityDeduction(pid,cid,amount)
  
  return cid
end

function EminentDKP:CreateRenameSyncEvent(from,to)
  self:SyncEvent(self:CreateRenameEvent(from,to,time()))
end

function EminentDKP:CreateRenameEvent(from,to,dtime)
  -- This event assumes that the "to" player is fresh
  local pfid = self:GetPlayerIDByName(from)
  local ptid = self:GetPlayerIDByName(to)
  
  -- Create the event
  local cid = self:CreateEvent(pfid,"rename",from,"","",to,dtime)
  
  -- Delete the "to" person
  self:GetActivePool().players[ptid] = nil
  -- Delete the name for the "from" person
  self:GetActivePool().playerIDs[from] = nil
  -- Re-route the "to" person to the "from" person
  self:GetActivePool().playerIDs[to] = pfid
  
  return cid
end

-- Creates an event and increments the event counter
function EminentDKP:CreateEvent(src,etype,extra,t,b,val,dtime)
  local c = self:GetActivePool().eventCounter
  c = c + 1
  self:GetActivePool().eventCounter = c
  local cid = tostring(c)
  self:GetActivePool().events[cid] = {
    source = src,
    eventType = etype,
    extraInfo = extra,
    target = t,
    beneficiary = b,
    value = val,
    datetime = dtime
  }
  
  -- Update newest_version (since it may be out of date now)
  if newest_version ~= "" then
    local old_newest_version = self:GetNewestVersion()
    newest_version = ""
    UpdateNewestVersion(old_newest_version)
  end
  
  return cid
end

---------- END EVENT FUNCTIONS ----------

-- Iterate over the group and determine loot eligibility
function EminentDKP:UpdateLootEligibility()
  wipe(eligible_looters)
  local count = (is_in_party() and GetNumPartyMembers() or GetNumRaidMembers())
  for d = 1, count do
    if GetMasterLootCandidate(d) then
      eligible_looters[GetMasterLootCandidate(d)] = d
    end
  end
end

function EminentDKP:IsEnabled()
  return enabled and not self:NeedSync() and not tempdisabled
end

--[[
function EminentDKP:GUILD_PARTY_STATE_UPDATED(event, is_guild)
  in_guild_group = is_guild
  self:DisableCheck()
end
]]

-- Keep track of any creature deaths
function EminentDKP:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  if not self:AmOfficer() then return end
  if eventtype == "UNIT_DIED" and bit.band(dstFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then
    table.insert(recent_deaths,1,dstName)
    if #(recent_deaths) > 10 then
      tremove(recent_deaths)
    end
  end
end

-- Keep track of any earned achievements
function EminentDKP:ACHIEVEMENT_EARNED(event, achievementID)
  if not self:AmOfficer() then return end
  local achiev_id, achiev_name = GetAchievementInfo(tonumber(achievementID))
  table.insert(recent_achievements,1,achiev_name)
  if #(recent_achievements) > 10 then
    tremove(recent_achievements)
  end
end

-- Keep track of being in PVP
function EminentDKP:PLAYER_ENTERING_WORLD()
  -- Hide the meters if we're PVPing and we want it hidden
  self:HideMeterCheck()
  self:DisableCheck()
end

-- Check if we're not dead and group is not in combat, then we're out of combat
function EminentDKP:CheckCombatStatus()
  if not UnitIsDead("player") and not IsGroupInCombat() then
    self:CancelTimer(self.combatCheckTimer,true)
    in_combat = false
    self:HideMeterCheck()
  end
end

-- Possibility we are out of combat
function EminentDKP:PLAYER_REGEN_ENABLED()
  if self.db.profile.hidecombat then
    self.combatCheckTimer = self:ScheduleRepeatingTimer("CheckCombatStatus",1)
  end
end

-- Announcements, prunes, and expirations occur at the first entry of combat
function EminentDKP:PLAYER_REGEN_DISABLED()
  -- Hide meters if we're in combat and want it hidden
  if self.db.profile.hidecombat then
    in_combat = true
    self:CancelTimer(self.combatCheckTimer,true)
    self:HideMeterCheck()
  end
  if not self:AmMasterLooter() or not self:IsEnabled() then return end
  
  if self:GetLastScan() == 0 or GetDaysSince(self:GetLastScan()) > 0 then
    self:Print(L["Performing database scan..."])
    for pid,data in pairs(self:GetActivePool().players) do
      if GetDaysSince(data.lastRaid) >= self.db.profile.expiretime then
        local name = self:GetPlayerNameByID(pid)
        if self:IsPlayerFresh(name) then
          -- The player has been inactive for a while, purge them if they're fresh
          self:CreatePurgeSyncEvent(name)
        elseif data.active then
          -- If deemed inactive then reset their DKP and vanity DKP
          self:CreateExpirationSyncEvent(name)
        end
      end
    end
    if self:GetAvailableBountyPercent() > 50 then
      self:Print(L["There is more than 50% of the bounty available. You should distribute some."])
    end
    self:MessageGroup(L["Current bounty is %.02f DKP."]:format(self:GetAvailableBounty()))
    self:GetActivePool().lastScan = time()
    self:InformPlayer("scan",{ time=self:GetLastScan() })
  end
end

-- Make sure players exist in the pool
function EminentDKP:CheckGroupPlayers()
  -- This only needs to be run by the masterlooter
  if not self:AmMasterLooter() or not self:IsEnabled() then return end
  
  if GetNumRaidMembers() > 0 then
    for d = 1, GetNumRaidMembers() do
      local name = UnitName("raid"..d)
      if name and UnitExists(name) and not self:PlayerExistsInPool(name) then
        local classname = select(2,UnitClass(name))
        if classname then
          self:CreateAddPlayerSyncEvent(name,classname)
        end
      end
    end
  elseif GetNumPartyMembers() > 0 then
    for d = 1, GetNumPartyMembers() do
      local name = UnitName("party"..d)
      if name and UnitExists(name) and not self:PlayerExistsInPool(name) then
        local classname = select(2,UnitClass(name))
        if classname then
          self:CreateAddPlayerSyncEvent(name,classname)
        end
      end
    end
  end
end

-- Player names aren't always immediately available, so we have to schedule
-- the group check so it gives time for the UI to update
function EminentDKP:ScheduleGroupCheck()
  -- This only needs to be run by the masterlooter
  if not self:AmMasterLooter() or not self:IsEnabled() then return end
  
  self:CancelTimer(self.groupCheckTimer,true)
  self.groupCheckTimer = self:ScheduleTimer("CheckGroupPlayers",2)
end

function EminentDKP:HideMeterCheck()
  if (self.db.profile.hideparty and is_in_party()) or 
     (self.db.profile.hidepvp and is_in_pvp()) or 
     (self.db.profile.hidesolo and is_solo()) or 
     (self.db.profile.hidecombat and in_combat) then
    self:ToggleMeters(false)
    return
  end
  self:ToggleMeters(true)
end

function EminentDKP:DisableCheck()
  --[[
  (self.db.profile.guildgroup and not in_guild_group)
  ]]
  if (self.db.profile.disableparty and is_in_party()) or
     (self.db.profile.disablepvp and is_in_pvp()) then
    enabled = false
    return
  end
  enabled = true
end

-- Tracking for parties
function EminentDKP:PARTY_MEMBERS_CHANGED()
  self:HideMeterCheck()
  self:DisableCheck()
  self:ScheduleGroupCheck()
end

-- Tracking for raids
function EminentDKP:RAID_ROSTER_UPDATE()
  self:HideMeterCheck()
  self:ScheduleGroupCheck()
end

-- Keep track of the loot method
function EminentDKP:PARTY_LOOT_METHOD_CHANGED()
  self.lootMethod, self.masterLooterPartyID, self.masterLooterRaidID = GetLootMethod()
  self.amMasterLooter = (self.lootMethod == 'master' and self.masterLooterPartyID == 0)
  if not self.amMasterLooter then
    if is_in_party() then 
      self.masterLooterName = UnitName("party"..tostring(self.masterLooterPartyID))
    else
      self.masterLooterName = UnitName("raid"..tostring(self.masterLooterRaidID))
    end
  else
    self.masterLooterName = self.myName
  end
  
  self:ScheduleGroupCheck()
end

-- Keep track of the last container we opened
function EminentDKP:UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
  if not self:AmMasterLooter() then return end
  if spell == "Opening" and unit == "player" then
    lastContainerName = target
  end
end

function EminentDKP:AmMasterLooter()
  return (self.amMasterLooter and self:AmOfficer())
end

function EminentDKP:GetMasterLooterName()
  if self.lootMethod == 'master' then
    if not UnitExists(self.masterLooterName) then
      self:PARTY_LOOT_METHOD_CHANGED()
    end
    return self.masterLooterName
  end
  return nil
end

-- Loot window closing means cancel auction
function EminentDKP:LOOT_CLOSED()
  if self:AmMasterLooter() and auction_active then
    auction_active = false
    self:CancelTimer(self.bidTimer,true)
    self:MessageGroup(L["Auction cancelled. All bids have been voided."])
    self:InformPlayer("auctioncancel",{
      guid = self.bidItem.srcGUID,
      slot = (recent_loots[self.bidItem.srcGUID].slotoffset + self.bidItem.slotNum),
    })
    self.bidItem = nil
  end
end

-- Prints out the loot to the group when looting a corpse
function EminentDKP:LOOT_OPENED()
  -- This only needs to be run by the masterlooter
  if not self:AmMasterLooter() then return end
  
  -- Query some info about this unit...
  local unitName = lastContainerName
  local guid = 'container'
  if UnitExists("target") then
    unitName = UnitName("target")
    guid = UnitGUID("target")
  end
  if GetNumLootItems() > 0 then
    local eligible_items = {}
    local slotlist = {}
    local itemlist = {}
    for slot = 1, GetNumLootItems() do 
      local lootIcon, lootName, lootQuantity, rarity = GetLootSlotInfo(slot)
      if lootQuantity > 0 and rarity >= self.db.profile.itemrarity then
        local link = GetLootSlotLink(slot)
        table.insert(eligible_items,link)
        table.insert(itemlist,{ info=string.match(link, "item[%-?%d:]+"), slot=slot })
        table.insert(slotlist,1,slot)
      end
    end
    
    if #(eligible_items) > 0 then
      if not recent_loots[guid] then
        self:MessageGroup(L["Loot from %s:"]:format(unitName))
        for i,loot in ipairs(eligible_items) do
          self:MessageGroup(loot)
        end
        
        -- Share loot list with group
        self:InformPlayer("lootlist",{ guid=guid, name=unitName, items=itemlist })
        -- Ensure that we only print once by keeping track of the GUID
        recent_loots[guid] = {
          name=unitName,
          slots=slotlist,
          items=itemlist,
          auctioncount=0,
          slotoffset=0
        }
      else
        -- Update slot list
        recent_loots[guid].slots = slotlist
        -- Snapshot our offset, it is the basis for the slot position in the GUI
        recent_loots[guid].slotoffset = recent_loots[guid].auctioncount
      end
    end
  end
end

function EminentDKP:WhisperPlayer(addon, method, msg, who, accept)
  if addon then
    local nt = (accept and "accept" or "reject")
    self:InformPlayer(nt,{ from=method, message=msg },who)
  else
    sendchat(msg, who, 'whisper')
  end
end

-- Place a bid on an active auction
function EminentDKP:Bid(addon,from,amount)
  if not self:EnsureToMasterlooter(addon,"bid",from) then return end
  if auction_active then
    if eligible_looters[from] then
      local bid = math.floor(tonumber(amount) or 0)
      if bid >= 1 then
        if self:PlayerHasDKP(from,bid) then
          self.bidItem.bids[from] = bid
          self:WhisperPlayer(addon,"bid",L["Your bid of %d has been accepted."]:format(bid), from, true)
        else
          self:WhisperPlayer(addon,"bid",L["The DKP amount must not exceed your current DKP."], from)
        end
      else
        self:WhisperPlayer(addon,"bid",L["DKP amount must be atleast 1."], from)
      end
    else
      self:WhisperPlayer(addon,"bid",L["You are not eligible to receive loot."], from)
    end
  else
    self:WhisperPlayer(addon,"bid",L["There is currently no auction active."], from)
  end
end

-- Transfer DKP from one player to another
function EminentDKP:Transfer(addon,from,amount,to)
  if not self:EnsureToMasterlooter(addon,"transfer",from) then return end
  if not auction_active then
    if to ~= from then
      if self:PlayerExistsInPool(from) then
        if self:PlayerExistsInPool(to) then
          local dkp = tonumber(amount) or 0
          if dkp >= 1 then
            if self:PlayerHasDKP(from,dkp) then
              self:CreateTransferSyncEvent(from,to,dkp)
              
              self:InformPlayer("transfer",{ amount = dkp, sender=from, receiver=to })
              if addon then
                self:WhisperPlayer(addon,"transfer",L["Succesfully transferred %.02f DKP to %s."]:format(dkp,to), from, true)
              else
                sendchat(L["Succesfully transferred %.02f DKP to %s."]:format(dkp,to), from, 'whisper')
              end
              sendchat(L["%s just transferred %.02f DKP to you."]:format(from,dkp), to, 'whisper')
              self:MessageGroup(L["%s has transferred %.02f DKP to %s."]:format(from,dkp,to))
            else
              self:WhisperPlayer(addon,"transfer",L["The DKP amount must not exceed your current DKP."], from)
            end
          else
            self:WhisperPlayer(addon,"transfer",L["DKP amount must be atleast 1."], from)
          end
        else
          self:WhisperPlayer(addon,"transfer",L["%s does not exist in the DKP pool."]:format(to), from)
        end
      else
        self:WhisperPlayer(addon,"transfer",L["You do not exist in the DKP pool."], from)
      end
    else
      self:WhisperPlayer(addon,"transfer",L["You cannot transfer DKP to yourself."], from)
    end
  else
    self:WhisperPlayer(addon,"transfer",L["You cannot transfer DKP during an auction."], from)
  end
end

function EminentDKP:WhisperBalance(to)
  self:WhisperCheck(to, to)
end

function EminentDKP:GetStandings(stat)
  local a = {}
  local players = self:GetCurrentGroupMembers()
  if next(players) == nil then
    players = self:GetPlayerPool()
  end
  for id,data in pairs(players) do
    local b = (data[stat] ~= nil and data[stat] or data.currentDKP)
    table.insert(a, { n=self:GetPlayerNameByID(id), dkp=b })
  end
  table.sort(a, function(a,b) return a.dkp>b.dkp end)
  return a
end

function EminentDKP:WhisperStandings(to)
  local a = self:GetStandings('currentDKP')
  
  sendchat(L["Current DKP standings:"], to, 'whisper')
  for rank,data in ipairs(a) do
    sendchat(("%d. %s - %.02f"):format(rank,data.n,data.dkp), to, 'whisper')
  end
end

function EminentDKP:WhisperLifetime(to)
  local a = self:GetStandings('earnedDKP')
  
  sendchat(L["Lifetime Earned DKP standings:"], to, 'whisper')
  for rank,data in ipairs(a) do
    sendchat(("%d. %s - %.02f"):format(rank,data.n,data.dkp), to, 'whisper')
  end
end

function EminentDKP:WhisperBounty(to)
  sendchat(L["Current bounty is %.02f DKP."]:format(self:GetAvailableBounty()), to, 'whisper')
end

function EminentDKP:WhisperCheck(who, to)
  if self:PlayerExistsInPool(who) then
    local data = self:GetPlayerByName(who)
    sendchat(L["Player Report for %s:"]:format(who), to, 'whisper')
    sendchat(L["Current DKP:"].. ' '..self:StdNumber(data.currentDKP), to, 'whisper')
    sendchat(L["Lifetime DKP:"].. ' '..self:StdNumber(data.earnedDKP), to, 'whisper')
    sendchat(L["Vanity DKP:"].. ' '..self:StdNumber(data.currentVanityDKP), to, 'whisper')
    sendchat(L["Last Seen: %d day(s) ago."]:format(GetDaysSince(data.lastRaid)), to, 'whisper')
  else
    sendchat(L["%s does not exist in the DKP pool."]:format(who), to, 'whisper')
  end
end

------------- START ADMIN FUNCTIONS -------------

function EminentDKP:AdminStartAuction()
  if not self:EnsureMasterlooter() then return end
  if GetNumLootItems() > 0 then
    local guid = UnitExists("target") and UnitGUID("target") or 'container'
    if #(recent_loots[guid].slots) > 0 then
      if not auction_active then
        -- Fast forward to next eligible slot
        local slot
        local itemLink
        
        while not itemLink and #(recent_loots[guid].slots) > 0 do
          slot = tremove(recent_loots[guid].slots)
          itemLink = GetLootSlotLink(slot)
        end
        
        if not itemLink then
          self:DisplayActionResult(L["There is no loot available to auction."])
          return
        end
        
        -- Gather some info about this item
        local lootIcon, lootName, lootQuantity, rarity = GetLootSlotInfo(slot)
        local gui_slot = (recent_loots[guid].slotoffset + slot)
        
        -- Update eligibility list
        self:UpdateLootEligibility()
        
        auction_active = true
        self.bidItem = {
          itemString=string.match(itemLink, "item[%-?%d:]+"), 
          remaining=self.db.profile.auctionlength, 
          bids={}, 
          slotNum=slot,
          srcGUID=guid,
          ending=(GetTime() + self.db.profile.auctionlength),
          window=self.db.profile.auctionlength,
        }
        self.bidTimer = self:ScheduleRepeatingTimer("AuctionBidTimer", 5)
        self:InformPlayer("auction",{
          guid = self.bidItem.srcGUID,
          slot = gui_slot,
          timeleft = self.bidItem.window,
          window = self.bidItem.window,
        })
        
        if not is_in_party() then
          sendchat(L["Bids for %s"]:format(itemLink), "raid_warning", "preset")
        end
        self:MessageGroup(L["%s now up for auction! Auction ends in 30 seconds."]:format(itemLink))
      else
        self:DisplayActionResult(L["An auction is already active."])
      end
    else
      self:DisplayActionResult(L["There is no loot available to auction."])
    end
  else
    self:DisplayActionResult(L["You must be looting a corpse to start an auction."])
  end
end

function EminentDKP:AuctionBidTimer()
  -- Subtract 5 seconds from the remaining time
  self.bidItem.remaining = self.bidItem.remaining - 5
  
  -- If no more time remaining: close it
  if self.bidItem.remaining == 0 then
    auction_active = false
    self:CancelTimer(self.bidTimer)
    self:MessageGroup(L["Auction has closed. Determining winner..."])
    
    local looter = self.myName
    local guid = self.bidItem.srcGUID
    local gui_slot = (recent_loots[guid].slotoffset + self.bidItem.slotNum)
    
    -- Update eligibility list
    self:UpdateLootEligibility()
    
    if next(self.bidItem.bids) == nil then
      -- No bids received, so disenchant
      self:MessageGroup(L["No bids received. Disenchanting."])
      if self.db.profile.disenchanter ~= "" then
        if eligible_looters[self.db.profile.disenchanter] then
          looter = self.db.profile.disenchanter
        else
          self:Print(L["%s was not eligible to receive loot to disenchant."]:format(self.db.profile.disenchanter))
        end
      else
        self:Print(L["There is no disenchanter assigned."])
      end
      self:InformPlayer("auctiondisenchant",{ guid = self.bidItem.srcGUID, slot = gui_slot })
    else
      local secondHighestBid = 0
      local winningBid = 0
      local winners = {}
      
      -- Run through the bids and determine the winner(s)
      for name,bid in pairs(self.bidItem.bids) do
        if bid > winningBid then
          secondHighestBid = winningBid
          winners = {}
          table.insert(winners,name)
          winningBid = bid
        elseif bid == winningBid then
          table.insert(winners,name)
        elseif bid > secondHighestBid then
          secondHighestBid = bid
        end
      end
      
      if #(winners) == 1 then
        -- We have a sole winner
        looter = winners[1]
      else
        -- We have a tie to break
        looter = winners[math.random(#(winners))]
        secondHighestBid = winningBid
        self:MessageGroup(L["A tie was broken with a random roll."])
      end
      
      -- Construct list of players to receive dkp
      local players = self:GetCurrentGroupMembersIDs()
      local dividend = (secondHighestBid/#(players))
      
      self:CreateAuctionSyncEvent(players,looter,secondHighestBid,recent_loots[guid].name,self.bidItem.itemString)
      self:MessageGroup(L["%s has won %s for %d DKP!"]:format(looter,GetLootSlotLink(self.bidItem.slotNum),secondHighestBid))
      self:MessageGroup(L["Each player has received %.02f DKP."]:format(dividend))
      self:InformPlayer("auctionwon",{
        guid = self.bidItem.srcGUID, 
        amount = secondHighestBid, 
        receiver = looter, 
        item = self.bidItem.itemString, 
        slot = gui_slot,
        tie = (#(winners) > 1)
      })
    end
    
    recent_loots[guid].auctioncount = recent_loots[guid].auctioncount + 1
    
    -- Distribute the loot
    GiveMasterLoot(self.bidItem.slotNum, eligible_looters[looter])
    
    -- Re-run the auction routine...
    if #(recent_loots[guid].slots) > 0 then
      self.bidItem = nil
      self:AdminStartAuction()
    else
      self:MessageGroup(L["No more loot found."])
      self:InformPlayer("lootdone",{ guid = self.bidItem.srcGUID })
      self.bidItem = nil
    end
  else
    self:MessageGroup(("%d..."):format(self.bidItem.remaining))
  end
end

function EminentDKP:GetBountyReasons()
  local reasons = { ["Default"] = "Default" }
  for i,mob in pairs(recent_deaths) do
    reasons[mob] = L["Kill: %s"]:format(mob)
  end
  for i,achiev in pairs(recent_achievements) do
    reasons[achiev] = L["Achievement: %s"]:format(achiev)
  end
  return reasons
end

function EminentDKP:AdminIssueAdjustment(who,amount,deduction,reason)
  if not self:EnsureOfficership() then return end
  if not auction_active then
    local p = tonumber(amount) or 0
    if (deduction and p <= self:GetCurrentDKP(who) and p >= 1) or (not deduction and p <= self:GetAvailableBounty() and p >= 1) then      
      self:CreateAdjustmentSyncEvent(who,p,deduction,reason)
      
      -- Announce adjustment to the other addons
      self:InformPlayer("adjustment",{ amount = p, receiver = who, deduct = deduction })
      
      if deduction then
         self:MessageGroup(L["%s has received a deduction of %.02f DKP."]:format(who,p))
      else
        self:MessageGroup(L["%s has been awarded %.02f DKP."]:format(who,p))
      end
    else
      self:DisplayActionResult(L["ERROR: Invalid adjustment amount given."])
    end
  else
    self:DisplayActionResult(L["ERROR: An auction must not be active."])
  end
end

function EminentDKP:AdminDistributeBounty(percent,value,reason)
  if not self:EnsureOfficership() then return end
  if not auction_active then
    local p = tonumber(value) or 0
    if (percent and p <= 100 and p > 0) or (not percent and p <= self:GetAvailableBounty() and p > 0) then
      -- Construct list of players to receive bounty
      local players = self:GetCurrentGroupMembersIDs()
      
      local amount = (percent and (self:GetAvailableBounty() * (p/100)) or p)
      local dividend = (amount/#(players))
      
      self:CreateBountySyncEvent(players,amount,reason)
      
      -- Announce bounty to the other addons
      self:InformPlayer("bounty",{ amount = dividend })
      
      self:MessageGroup(L["A bounty of %.02f has been awarded to %d players."]:format(amount,#(players)))
      self:MessageGroup(L["Each player has received %.02f DKP."]:format(dividend))
      self:MessageGroup(L["The bounty pool is now %.02f DKP."]:format(self:GetAvailableBounty()))
    else
      self:DisplayActionResult(L["ERROR: Invalid bounty amount given."])
    end
  else
    self:DisplayActionResult(L["ERROR: An auction must not be active."])
  end
end

-- Perform a vanity roll weighted by current vanity DKP
function EminentDKP:AdminVanityRoll()
  if not self:EnsureOfficership() then return end
  if not auction_active then
    local ranks = {}
    for pid, data in pairs(self:GetCurrentGroupMembers()) do
      local name = self:GetPlayerNameByID(pid)
      if data.currentVanityDKP > 0 then
        local roll = math.random(math.floor(data.currentVanityDKP))/1000
        table.insert(ranks, { n=name, v=data.currentVanityDKP, r=roll })
      end
    end
    table.sort(ranks, function(a,b) return a.r>b.r end)
    
    self:MessageGroup(L["Vanity item rolls weighted by current vanity DKP:"])
    for rank,data in ipairs(ranks) do
      self:MessageGroup(("%d. %s (%.02f) - %.02f"):format(rank,data.n,data.v,data.r))
    end
  else
    self:DisplayActionResult(L["ERROR: An auction must not be active."])
  end
end

function EminentDKP:AdminVanityReset(who)
  if not self:EnsureOfficership() then return end
  if self:PlayerExistsInPool(who) then
    self:CreateVanityResetSyncEvent(who)
    self:DisplayActionResult(L["Successfully reset vanity DKP for %s."]:format(who))
  else
    self:DisplayActionResult(L["ERROR: %s does not exist in the DKP pool."]:format(who))
  end
end

function EminentDKP:AdminRename(from,to)
  if not self:EnsureOfficership() then return end
  if self:PlayerExistsInPool(from) then
    if self:PlayerExistsInPool(to) then
      if self:IsPlayerFresh(to) then
        self:CreateRenameSyncEvent(from,to)
        self:DisplayActionResult(L["Successfully renamed %s to %s."]:format(from,to))
      else
        self:DisplayActionResult(L["ERROR: %s is not a fresh player."]:format(to))
      end
    else
      self:DisplayActionResult(L["ERROR: %s does not exist in the DKP pool."]:format(to))
    end
  else
    self:DisplayActionResult(L["ERROR: %s does not exist in the DKP pool."]:format(from))
  end
end

function EminentDKP:DisplayActionResult(status)
  if self.actionpanel then
    self.actionpanel:SetStatusText(status)
  else
    self:Print(status)
  end
end

------------- END ADMIN FUNCTIONS -------------

function EminentDKP:FILTER_EMINENTDKP_MESSAGES(eventController, message)
  -- Ensure all correspondence from the addon is hidden (option)
  if self.db.profile.hideraidmessages and string.find(message, "[EminentDKP]", 1, true) then
    eventController:BlockFromChatFrame()
  end
end

function EminentDKP:CHAT_MSG_PARTY_CONTROLLER(eventController, message, from, ...)
  self:FILTER_EMINENTDKP_MESSAGES(eventController, message)
end

function EminentDKP:CHAT_MSG_PARTY_LEADER_CONTROLLER(eventController, message, from, ...)
  self:FILTER_EMINENTDKP_MESSAGES(eventController, message)
end

function EminentDKP:CHAT_MSG_RAID_CONTROLLER(eventController, message, from, ...)
  self:FILTER_EMINENTDKP_MESSAGES(eventController, message)
end

function EminentDKP:CHAT_MSG_RAID_LEADER_CONTROLLER(eventController, message, from, ...)
  self:FILTER_EMINENTDKP_MESSAGES(eventController, message)
end

function EminentDKP:CHAT_MSG_RAID_WARNING_CONTROLLER(eventController, message, from, ...)
  self:FILTER_EMINENTDKP_MESSAGES(eventController, message)
end

function EminentDKP:HideRaidWarning(frame, event, message)
  -- Ensure all correspondence from the addon is hidden (option)
  if self.db.profile.hideraidmessages and string.find(message, "[EminentDKP]", 1, true) then
    return
  end
  self.hooks[frame].OnEvent(frame, event, message)
end

function EminentDKP:CHAT_MSG_WHISPER_INFORM_CONTROLLER(eventController, message, from, ...)
  -- Ensure all correspondence from the addon is hidden (since we're running the addon)
  if string.find(message, "[EminentDKP]", 1, true) then
    eventController:BlockFromChatFrame()
  end
end

function EminentDKP:CHAT_MSG_WHISPER_CONTROLLER(eventController, message, from, ...)
  -- Ensure all commands received are hidden
  if string.match(message, "^$ %a+") then
    eventController:BlockFromChatFrame()
  end
end

function EminentDKP:InformPlayer(...)
  local notifyType, rawdata, target, channel = ...
  local data = notifyType .. "_" .. libS:Serialize(rawdata)
  local tosync = libCE:Encode(libC:CompressHuffman(data))
  if not target then
    if not channel then
      channel = (is_in_party() and "PARTY" or "RAID")
    end
    self:SendCommMessage('EminentDKP-INF',tosync,channel)
  else
    self:SendCommMessage('EminentDKP-INF',tosync,'WHISPER',target)
  end
end

local cached_notifications = {}

function EminentDKP:ProcessInformation(prefix, message, distribution, sender)
  if not self:IsAnOfficer(sender) then return end
  -- Decode the compressed data
  local one = libCE:Decode(message)

  -- Decompress the decoded data
  local two, message = libC:Decompress(one)
  if not two then
    self:Print('Error occured while decoding a notification: '..message)
    return
  end
  
  local notifyType, rawdata = strsplit('_',two,2)
  
  -- Deserialize the decompressed data
  local success, data = libS:Deserialize(rawdata)
  if not success then
    self:Print('Error occured while deserializing notification data.')
    return
  end
  
  self:ActuateNotification(notifyType,data)
end

local cache_start

function EminentDKP:RunCachedNotifications()
  while #(cached_notifications) > 0 do
    local n = tremove(cached_notifications)
    if n.d.timeleft then
      -- Adjust timeleft to account for the delay in processing
      n.d.timeleft = n.d.timeleft - (GetTime() - cache_start)
    end
    self:ActuateNotification(n.t,n.d)
  end
end

function EminentDKP:ActuateNotification(notifyType,data)
  -- We don't have a lootlist, so request it before we run this
  if notifyType ~= "lootlist" and data.guid then
    if not self.auctionItems[data.guid] then
      cache_start = GetTime()
      table.insert(cached_notifications,1,{t=notifyType,d=data})
      self:SendCommand("lootlist",data.guid)
      return
    end
  end
  
  if notifyType == "accept" or notifyType == "reject" then
    -- A transfer or bid was made, and a response was given
    if data.from == "transfer" then
      self:DisplayActionResult(data.message)
    elseif data.from == "bid" then
      -- Accept or reject the last bid
      if notifyType == "accept" then
        self:AcceptLastItemBid()
      else
        self:RejectLastItemBid()
      end
    end
  elseif notifyType == "lootlist" then
    local guid = data.guid
    data.guid = nil
    self.auctionItems[guid] = data
    self.auctionItems[guid].changed = true
    -- Ensures the items showup properly when reported in the auction frame
    for i,item in ipairs(data.items) do
      GetItemInfo(item.info)
    end
    -- Wait a second to ensure the items are in the itemcache
    self:ScheduleTimer("RunCachedNotifications",1)
  elseif notifyType == "adjustment" then
    if data.receiver == self.myName then
      -- We received an adjustment
      self:NotifyOnScreen("ADJUSTMENT_RECEIVED",data.amount,data.receiver,data.deduct)
    else
      -- Somebody else got adjusted
      self:NotifyOnScreen("ADJUSTMENT_MADE",data.amount,data.receiver,data.deduct)
    end
  elseif notifyType == "bounty" then
    -- Bounty received
    self:NotifyOnScreen("BOUNTY_RECEIVED",data.amount)
  elseif notifyType == "transfer" then
    if data.receiver == self.myName then
      -- We received a transfer
      self:NotifyOnScreen("TRANSFER_RECEIVED",data.amount,data.sender)
    else
      -- Somebody else made a transfer
      self:NotifyOnScreen("TRANSFER_MADE",data.amount,data.sender,data.receiver)
    end
  elseif notifyType == "auction" then
    -- Start an auction
    if not self:AmMasterLooter() then auction_active = true end
    self:ShowAuctionItems(data.guid)
    self:StartAuction(data.slot,data.timeleft,data.window)
  elseif notifyType == "auctioncancel" then
    -- Cancel an auction
    if not self:AmMasterLooter() then auction_active = false end
    self:ShowAuctionItems(data.guid)
    self:CancelAuction(data.slot)
  elseif notifyType == "auctionwon" then
    -- Label the winner of an auction
    if not self:AmMasterLooter() then auction_active = false end
    self:ShowAuctionItems(data.guid)
    self:ShowAuctionWinner(data.slot,data.receiver,data.amount,data.tie)
    if data.receiver == self.myName then
      self:NotifyOnScreen("AUCTION_WON",data.item,data.amount)
    end
  elseif notifyType == "auctiondisenchant" then
    -- Label an auction disenchanted
    if not self:AmMasterLooter() then auction_active = false end
    self:ShowAuctionItems(data.guid)
    self:ShowAuctionDisenchant(data.slot)
  elseif notifyType == "lootdone" then
    -- Hide the auction frame
    self.auctionRecycleTimer = self:ScheduleTimer("RecycleAuctionItems",6,true)
  elseif notifyType == "scan" then
    -- A scan was done, so update the last scan time
    self:GetActivePool().lastScan = data.time
  elseif notifyType == "reset" then
    -- A reset notification was given, so we must reset as well
    if self:AmOfficer() then
      -- If an officer, give the option of complying, for security purposes
      -- todo: freeze any syncing or version broadcasting until the decision has been made
      EminentDKP:ConfirmAction("EminentDKPReset",
                               L["%s has requested a database reset. Do you wish to comply? This cannot be undone."]:format(data.sender),
                               function()
                                 EminentDKP:ResetDatabase()
                               end)
    else
      -- If a regular user, just go ahead and reset
      self:Print(L["%s has requested a database reset."]:format(data.sender))
      EminentDKP:ResetDatabase()
    end
  end
end

function EminentDKP:InQualifiedRaid()
  return (self:GetMasterLooterName() and self:IsAnOfficer(self:GetMasterLooterName()))
end

-- Send a command to the ML
function EminentDKP:SendCommand(...)
  if not self:GetMasterLooterName() then return end
  local cmd, arg1, arg2 = ...
  local tbl = {}
  table.insert(tbl,cmd)
  table.insert(tbl,arg1)
  table.insert(tbl,arg2)
  self:SendCommMessage("EminentDKP-CMD",implode(",",tbl),'WHISPER',self:GetMasterLooterName())
end

-- Process a command sent to the ML
function EminentDKP:ProcessCommand(prefix, message, distribution, sender)
  if not self:AmMasterLooter() then return end
  local command, arg1, arg2 = strsplit(",", message, 3)
  
  if command == 'bid' then
    self:Bid(true,sender,arg1)
  elseif command == 'transfer' then
    self:Transfer(true,sender,arg1,arg2)
  elseif command == 'lootlist' then
    -- Send them the loot
    if recent_loots[arg1] then
      self:InformPlayer("lootlist",{ 
        guid=arg1, 
        name=recent_loots[arg1].name,
        items=recent_loots[arg1].items
      },sender)
    end
  end
end

-- This function will reprocess all events and re-build the database
-- This is useful when computations need to be re-done (due to a bug, etc)
-- So the user won't be forced to re-sync, they can just do a rebuild
function EminentDKP:RebuildDatabase()
  -- Copy all events into the cache
  wipe(events_cache)
  for eid,event in pairs(self:GetEventPool()) do
    local temp = {}
    self:tcopy(temp,event)
    events_cache[eid] = temp
  end
  
  -- Restore the database to default
  local old_ver = self:GetVersion()
  self:ResetDatabase()
  newest_version = old_ver
  
  -- Start replicating cached events
  self:ReplicateSyncEvent("1",events_cache["1"])
  
  self:Print(L["Database has been rebuilt."])
end

-- This function resets the database to default
function EminentDKP:ResetDatabase()
  local db = self:GetActivePool()
  local rev = db.revision
  wipe(db)
  self:tcopy(db,self.defaults.factionrealm.pools["Default"])
  db.revision = rev
  
  newest_version = ""
  
  -- Force reload the meter display
  self:ReloadSets(true)
  self:UpdateStatusBar()
  
  self:Print(L["Database has been reset."])
end

-- Handle slash commands
function EminentDKP:ProcessSlashCmd(input)
  local command, arg1, arg2, e = self:GetArgs(input, 3)
  
  if command == 'auction' then
    self:AdminStartAuction()
  elseif command == 'rebuild' then
    self:RebuildDatabase()
  elseif command == 'reset' then
    if arg1 == "all" then
      -- Reset the database for everybody online
      EminentDKP:ConfirmAction("EminentDKPReset",
                               L["Are you sure you want to reset the database for ALL users? This cannot be undone."],
                               function()
                                 EminentDKP:InformPlayer("reset",{ sender = EminentDKP.myName },"","GUILD")
                                 EminentDKP:ResetDatabase()
                               end)
    else
      -- Reset the database just for yourself
      EminentDKP:ConfirmAction("EminentDKPReset",
                               L["Are you sure you want to reset the database? This cannot be undone."],
                               function()
                                 EminentDKP:ResetDatabase()
                               end)
    end
  elseif command == 'options' then
    InterfaceOptionsFrame_OpenToCategory("EminentDKP")
  elseif command == 'action' then
    self:CreateActionPanel()
  elseif command == 'version' then
    local say_what = "Current version is "..self:GetVersion()
    if self:GetNewestVersion() ~= self:GetVersion() then
      say_what = say_what .. " (latest is "..self:GetNewestVersion()..")"
    end
    self:Print(say_what)
  end
end

function EminentDKP:CHAT_MSG_WHISPER(message, from)
  -- Only interpret messages starting with $
  local a, command, arg1, arg2 = strsplit(" ", message, 4)
  if a ~= "$" then return end
  
  if command == 'bid' then
    self:Bid(false,from,arg1)
  elseif command == 'balance' then
    self:WhisperBalance(from)
  elseif command == 'check' then
    if arg1 == 'bounty' then
      self:WhisperBounty(from)
    else
      self:WhisperCheck(arg1,from)
    end
  elseif command == 'standings' then
    self:WhisperStandings(from)
  elseif command == 'lifetime' then
    self:WhisperLifetime(from)
  elseif command == 'transfer' then
    self:Transfer(false,from,arg1,arg2)
  elseif command == 'help' then
    sendchat(L["Available Commands:"], from, 'whisper')
    sendchat("$ balance -- " .. L["Check your current balance"], from, 'whisper')
    sendchat("$ check X -- " .. L["Check the current balance of player X"], from, 'whisper')            
    sendchat("$ standings -- " .. L["Display the current dkp standings"], from, 'whisper')
    sendchat("$ lifetime -- " .. L["Display the lifetime earned dkp standings"], from, 'whisper')
    sendchat("$ bid X -- " .. L["Place a bid of X DKP on the active auction"] .. " **", from, 'whisper')
    sendchat("$ transfer X Y -- " .. L["Transfer X DKP to player Y"] .. " **", from, 'whisper')           
    sendchat("** " .. L["These commands can only be sent to the master looter while in a group"], from, 'whisper')
  else
    sendchat(L["Unrecognized command. Whisper %s for a list of valid commands."]:format("'$ help'"), from, 'whisper')
  end
end