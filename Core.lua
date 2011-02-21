EminentDKP = LibStub("AceAddon-3.0"):NewAddon("EminentDKP", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)
local libCH = LibStub:GetLibrary("LibChatHandler-1.0")
local media = LibStub("LibSharedMedia-3.0")
libCH:Embed(EminentDKP)
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

VERSION = '2.1.0'
local newest_version = ''
local needs_update = false

local function Debug(message)
  if false then
    EminentDKP:Print(message)
  end
end

--[[

TODO:

1. Convert permission level checks into hooks
 -- Simplify permissions, and refactor checks for less code overhead
2. Organize meter display code and move to GUI.lua
3. Rip out boss detection code from Skada, use it as default bounty reason
4. Rip out combat detection code from Skada, use it to unhide meter display
5. Convert all static messages into localized messages
6. Rebuild internal whisper functions to support either addon whispers or player whispers
7. Investigate bar recycling (specifically when wiping the window, etc)

]]

-- All the meter windows
local windows = {}

-- All saved sets
local sets = {}

-- Modes (see Modes.lua)
local modes = {}

local auction_active = false

local recent_loots = {}

local eligible_looters = {}

local events_cache = {}

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

function EminentDKP:StdNumber(number)
  return string.format('%.02f', number)
end

local function implode(delim,list)
  local newstr = ""
  if #(list) == 1 then
    return list[1]
  end
  for i,v in ipairs(list) do
    if i ~= #(list) then
      newstr = newstr .. v .. delim
    else
      newstr = newstr .. v
    end
  end
  return newstr
end

local function convertToTimestamp(datetime)
  local t, d = strsplit(' ',datetime)
  local hour, min = strsplit(':',t)
  local month, day, year = strsplit('/',d)
  
  return time({day=day,month=month,year=year,hour=hour,min=min,sec=0})
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
  -- todo: trigger a notification if we need update
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
        order= 21,
      },
      locked = {
        type= "toggle",
        name= L["Lock window"],
        desc= L["Locks the bar window in place."],
        order= 18,
        get= function() return settings.barslocked end,
        set= function(win)
          settings.barslocked = not settings.barslocked
        	EminentDKP:ApplySettings(win[2])
        end,
      }
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
	  if visible then
		  win:Show()
	  else
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
  local sources = { event.source, event.target, event.beneficiary }
  
  for i, field in ipairs(sources) do
    local playerids = {}
    if i < 3 then
      local pid = tostring(tonumber(field) or 0)
      if pid ~= "0" then
        table.insert(playerids,pid)
      end
    else
      if field ~= "" then
        playerids = { strsplit(",",field) }
      end
    end
    if not seen[set.name] then
      seen[set.name] = {}
    end
    for j, pid in ipairs(playerids) do
      -- Seen this player in this set?
      if not seen[set.name][pid] then
        local player = EminentDKP:GetPlayerByID(pid)
        if player.active then
          table.insert(set.players, {id=pid,class=player.class,modedata={}})
          seen[set.name][pid] = true
        end
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
	
	--[[
	  database only changes when incoming events are replicated
	  so search through events and see if the event belongs to any
	  and add it to the event, and mark the set changed
	  
	  we only need to ever worry about "today" and "alltime" when receiving updates
	]]
	
	-- Re-create sets
	sets = self:GetMeterSets() or {}
	if not next(sets) then
	  self:ReloadSets(false)
  else
    -- verify sets (check if Today is actually today)
    local today = GetTodayDate()
    -- check if today has even been used yet...
    if sets.today.date ~= today then
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
  		  sets.today.date = date
		  end
  	end
  end

	-- Re-create windows
	-- As this can be called from a profile change as well as login, re-use windows when possible.
	for i, win in ipairs(self.db.profile.windows) do
		self:CreateWindow(win.name, win)
	end
end

function EminentDKP:ReloadSets(updatedisplays)
  wipe(sets)
  
  local today = GetTodayDate()
  sets.alltime = createSet(L["All-time"])
  sets.alltime.sortnum = 1
  sets.today = createSet(L["Today"])
  sets.today.date = today
  sets.today.sortnum = 2
  
  local eventHash = {}
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
      break
    end
  end
  
  self:VerifyAllSets()
  if updatedisplays then
    self:UpdateAllDisplays()
  end
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
end

function EminentDKP:ApplySettings(win)
  -- Just incase we're given a window name, not a window
  if type(win) == "string" then
    win = self:GetWindow(win)
  end
	win.display:ApplySettings(win)

	-- Don't show window if we are solo, option.
	-- Don't show window in a PvP instance, option.
	if (self.db.profile.hidesolo and is_solo()) or (self.db.profile.hidepvp and is_in_pvp())then
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
		
		-- View available modes.
		for i, mode in ipairs(modes) do
			local d = win.dataset[i] or {}
			win.dataset[i] = d
			d.id, d.label, d.value = mode:GetName(), mode:GetName() 1
			if mode.GetSetSummary then
				d.valuetext = mode:GetSetSummary(set)
			end
		end
		-- Tell window to sort by our data order.
		win.metadata.ordersort = true
		-- Let window display the data.
		win:UpdateDisplay()
	else
		-- View available sets.
		local nr = 0
    
		for setid, set in pairs(sets) do
			nr = nr + 1
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			d.id, d.label, d.value, d.sortnum, d.starttime = setid, set.name, 1, set.sortnum, set.starttime
			if set.starttime > 0 then
			  d.valuetext = date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
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
	media:Register("font", "Adventure",				[[Interface\Addons\EminentDKP\fonts\Adventure.ttf]])
	media:Register("font", "ABF",					[[Interface\Addons\EminentDKP\fonts\ABF.ttf]])
	media:Register("font", "Vera Serif",			[[Interface\Addons\EminentDKP\fonts\VeraSe.ttf]])
	media:Register("font", "Diablo",				[[Interface\Addons\EminentDKP\fonts\Avqest.ttf]])
	media:Register("font", "Accidental Presidency",	[[Interface\Addons\EminentDKP\fonts\Accidental Presidency.ttf]])
	media:Register("statusbar", "Aluminium",		[[Interface\Addons\EminentDKP\statusbar\Aluminium]])
	media:Register("statusbar", "Armory",			[[Interface\Addons\EminentDKP\statusbar\Armory]])
	media:Register("statusbar", "BantoBar",			[[Interface\Addons\EminentDKP\statusbar\BantoBar]])
	media:Register("statusbar", "Glaze2",			[[Interface\Addons\EminentDKP\statusbar\Glaze2]])
	media:Register("statusbar", "Gloss",			[[Interface\Addons\EminentDKP\statusbar\Gloss]])
	media:Register("statusbar", "Graphite",			[[Interface\Addons\EminentDKP\statusbar\Graphite]])
	media:Register("statusbar", "Grid",				[[Interface\Addons\EminentDKP\statusbar\Grid]])
	media:Register("statusbar", "Healbot",			[[Interface\Addons\EminentDKP\statusbar\Healbot]])
	media:Register("statusbar", "LiteStep",			[[Interface\Addons\EminentDKP\statusbar\LiteStep]])
	media:Register("statusbar", "Minimalist",		[[Interface\Addons\EminentDKP\statusbar\Minimalist]])
	media:Register("statusbar", "Otravi",			[[Interface\Addons\EminentDKP\statusbar\Otravi]])
	media:Register("statusbar", "Outline",			[[Interface\Addons\EminentDKP\statusbar\Outline]])
	media:Register("statusbar", "Perl",				[[Interface\Addons\EminentDKP\statusbar\Perl]])
	media:Register("statusbar", "Smooth",			[[Interface\Addons\EminentDKP\statusbar\Smooth]])
	media:Register("statusbar", "Round",			[[Interface\Addons\EminentDKP\statusbar\Round]])
	media:Register("statusbar", "TukTex",			[[Interface\Addons\EminentDKP\statusbar\normTex]])
  
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
  
  if type(CUSTOM_CLASS_COLORS) == "table" then
		self.classColors = CUSTOM_CLASS_COLORS
	end
  
  self.myName = UnitName("player")
  
  -- Get the current loot info as a basis
  self:PARTY_LOOT_METHOD_CHANGED()
  
  -- Broadcast version every 5 minutes
  self:ScheduleRepeatingTimer("BroadcastVersion", 300)
  
  -- Remember events we have recently sycned
  self.syncRequests = {}
  self.syncProposals = {}
  self.requestedEvents = {}
  self.requestCooldown = false
  
  self:DatabaseUpdate()
  self:ReloadWindows()
  
  -- Since SharedMedia doesn't finish loading until after this executes, we need to re-apply
  -- the settings again to ensure everything is how it should be, an unfortunate work-around...
  self:ScheduleTimer("ApplySettingsAll", 2)
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
      end
      if self.db.factionrealm.pools[name].lastScan ~= 0 then
        self.db.factionrealm.pools[name].lastScan = convertToTimestamp(self.db.factionrealm.pools[name].lastScan)
      end
      pool.revision = 1
    end
  end
end

function EminentDKP:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD") -- version broadcast
	self:RegisterChatEvent("CHAT_MSG_WHISPER") -- whisper commands received
	self:RegisterChatEvent("CHAT_MSG_WHISPER_INFORM") -- whispers sent
	self:RegisterChatEvent("CHAT_MSG_RAID") -- raid messages
	self:RegisterChatEvent("CHAT_MSG_RAID_WARNING") -- raid warnings
	
	self:RegisterEvent("LOOT_OPENED") -- loot listing
	self:RegisterEvent("LOOT_CLOSED") -- auction cancellation
	self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED") -- masterloot change
	self:RegisterEvent("RAID_ROSTER_UPDATE") -- raid member list update
	self:RegisterEvent("PLAYER_REGEN_DISABLED") -- addon announcements
	self:RegisterChatCommand("edkp", "ProcessSlashCmd") -- admin commands
	-- Sync methods
	self:RegisterComm("EminentDKP-Proposal", "ProcessSyncProposal")
	self:RegisterComm("EminentDKP-Fulfill", "ProcessSyncFulfill")
	self:RegisterComm("EminentDKP-Request", "ProcessSyncRequest")
	self:RegisterComm("EminentDKP-Version", "ProcessSyncVersion")
	self:RegisterComm("EminentDKP", "ProcessSyncEvent")
	-- Permission Hooks
	self:RawHook(self,"AdminStartAuction","EnsureMasterlooter")
	self:RawHook(self,"AdminDistributeBounty","EnsureOfficership")
	self:RawHook(self,"AdminVanityReset","EnsureOfficership")
	self:RawHook(self,"AdminVanityRoll","EnsureOfficership")
	self:RawHook(self,"AdminRename","EnsureOfficership")
	
	-- need hook for:
	-- self:Bid(arg1,from)
	-- self:WhisperTransfer(arg1,arg2,from)
	--[[
	if self.lootMethod ~= 'master' then
    sendchat("Master looting must be enabled.", from, 'whisper')
    return
  end
  if self.masterLooterPartyID ~= 0 then
    sendchat("That command must be sent to the master looter.", from, 'whisper')
    return
  end
	]]
end

function EminentDKP:EnsureOfficership(...)
  -- Check if the command can only be used by an officer
  if not self:AmOfficer() then
    sendchat("That command can only be used by an officer.", nil, 'self')
    return
  end
  self.hooks["EnsureOfficership"](...)
end

function EminentDKP:EnsureMasterlooter(...)
  if not self:AmOfficer() then
    sendchat("That command can only be used by an officer.", nil, 'self')
    return
  end
  if self.lootMethod ~= 'master' then
    sendchat("Master looting must be enabled.", nil, 'self')
    return
  end
  if not self.amMasterLooter then
    sendchat("Only the master looter can use this command.", nil, 'self')
    return
  end
  self.hooks["EnsureMasterlooter"](...)
end

function EminentDKP:OnDisable()
end

function EminentDKP:GetVersion()
  return VERSION .. '.' .. self:GetEventCount()
end

function EminentDKP:GetNewestVersion()
  -- todo: reset newest version if our eventcounter increases
  return (newest_version ~= '' and newest_version or self:GetVersion())
end

---------- START SYNC FUNCTIONS ----------

function EminentDKP:GetNewestEventCount()
  local b = { strsplit(".",self:GetNewestVersion(),4) }
  return tonumber(b[4])
end

function EminentDKP:GetEventCountDifference()
  return self:GetNewestEventCount() - self:GetEventCount()
end

-- Get list of events we need that aren't in the cache
-- But also omit any recently requested events
function EminentDKP:GetMissingEventList()
  local start = self:GetEventCount() + 1
  local missing = {}
  for i = start, self:GetNewestEventCount() do
    local eid = tostring(i)
    if not events_cache[eid] and tContains(self.requestedEvents,eid) ~= 1 then
      table.insert(missing,eid)
    end
  end
  return missing
end

function EminentDKP:ClearRequestedEvents()
  wipe(self.requestedEvents)
end

function EminentDKP:ClearRequestCooldown()
  self.requestCooldown = false
end

-- Request the missing events
function EminentDKP:RequestMissingEvents(cooldown)
  if cooldown then
    if self.requestCooldown then return end
    self.requestCooldown = true
    self:ScheduleTimer("ClearRequestCooldown", 10)
  end
  local mlist = self:GetMissingEventList()
  if #(mlist) > 0 then
    self:SendCommMessage('EminentDKP-Request',self:GetVersion() .. '_' ..implode(',',mlist),'GUILD')
    self:ClearRequestedEvents()
  end
end

-- Broadcast current addon version
function EminentDKP:BroadcastVersion()
  self:SendCommMessage('EminentDKP-Version',self:GetVersion(),'GUILD')
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
    self:SendCommMessage('EminentDKP-Fulfill',self:GetVersion() .. '_' .. who,'GUILD')
    
    -- Then go ahead and sync the events for them
    for i,eid in ipairs(self.syncRequests[who].events) do
      self:SyncEvent(eid)
    end
  end
  self.syncRequests[who] = nil
  self.syncProposals[who] = nil
end

-- Record a proposal to somebody's event request
function EminentDKP:ProcessSyncProposal(prefix, message, distribution, sender)
  if not self:AmOfficer() then return end
  if not self:IsAnOfficer(sender) then return end
  
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
  if not self:IsAnOfficer(sender) then return end
  local version, person = strsplit('_',message)
  if not CheckVersionCompatability(version) then return end
  
  -- The request has been fulfilled, abandon any remaining hope
  if self.syncRequests[person] then
    self:CancelTimer(self.syncRequests[person].timer,true)
    self.syncRequests[person] = nil
    self.syncProposals[person] = nil
  end
end

-- Process an incoming request for missing events
function EminentDKP:ProcessSyncRequest(prefix, message, distribution, sender)
  if sender == self.myName then return end
  local version, events = strsplit('_',message)
  if not CheckVersionCompatability(version) then return end
  local needed_events = { strsplit(',',events) }
  
  if self:AmOfficer() then
    -- If an officer, create a proposal to fulfill this request
    local numbers = { math.random(1000), math.random(1000), math.random(1000) }
    self.syncRequests[sender] = { events = needed_events, timer = nil }
    self.syncProposals[sender] = { }
    
    self:SendCommMessage('EminentDKP-Proposal',self:GetVersion() .. '_' .. sender .. '_' ..implode(',',numbers),'GUILD')
  else
    -- If not an officer, remember which events were requested
    for i,eid in ipairs(needed_events) do
      if tContains(self.requestedEvents,eid) ~= 1 then
        table.insert(self.requestedEvents,1,eid)
      end
    end
  end
end

-- Compare the version against our version, and note any newer version
function EminentDKP:ProcessSyncVersion(prefix, message, distribution, sender)
  if sender == self.myName then return end
  local compare = CompareVersions(self:GetVersion(),message)
  
  UpdateNewestVersion(message)
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
        -- Randomize a time in the next 1-5 seconds that requests events
        -- This staggers event requests to cut down on addon channel traffic and spamming
        self:ScheduleTimer("RequestMissingEvents", math.random(5), true)
      end
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
  	sendchat('Error occured while decoding a sync event: '..message,nil,'self')
  	return
  end
  
  local version, eventID, data = strsplit('_',two,3)
  -- Ignore events from incompatible versions
  if not CheckVersionCompatability(version) then return end
  
  -- Deserialize the decompressed data
  local success, event = libS:Deserialize(data)
  if not success then
    sendchat('Error occured while deserializing a sync event.',nil,'self')
  	return
  end
  
  -- We will only act on the next chronological event and cache future events
  local currentEventID = self:GetEventCount()
  if tonumber(eventID) == (currentEventID + 1) then
    -- Effectively delay any event requests since we're processing another event
    if self.syncTimer then
      self:CancelTimer(self.syncTimer,true)
      self.syncTimer = nil
    end
    self:ReplicateSyncEvent(eventID,event)
  elseif tonumber(eventID) > currentEventID then
    -- This is an event in the future, so cache it
    events_cache[eventID] = event
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
  elseif event.eventType == 'vanityreset' then
    local sname = self:GetPlayerNameByID(event.source)
    self:CreateVanityResetEvent(sname,event.datetime)
  elseif event.eventType == 'rename' then
    self:CreateRenameEvent(event.extraInfo,event.value,event.datetime)
  end
  
  local next_eventID = tostring(tonumber(eventID) + 1)
  events_cache[eventID] = nil
  
  if events_cache[next_eventID] then
    -- We have the next event we need to proceed with updating...
    self:ReplicateSyncEvent(next_eventID,events_cache[next_eventID])
  elseif self:GetEventCountDifference() > 0 then
    -- We lack what we need to continue onward...
    -- Give 3 seconds before we request missing events
    -- This gives time to receive more events that are already being synced
    self.syncTimer = self:ScheduleTimer("RequestMissingEvents", 3, false)
  end
end

---------- END SYNC FUNCTIONS ----------

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
  return self:GetActivePool().players[pid]
end

function EminentDKP:GetPlayerByName(name)
  local pid = self:GetPlayerIDByName(name)
  return (pid ~= nil and self:GetPlayerByID(pid) or nil)
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

-- Check whether or not a player exists in the currently active pool
function EminentDKP:PlayerExistsInPool(name)
  return (self:GetPlayerIDByName(name) ~= nil)
end

-- Update a player's last raid day
function EminentDKP:UpdateLastPlayerRaid(pid,datetime)
  local player = self:GetPlayerByID(pid)
  player.lastRaid = datetime
  player.active = true
end

-- Check if a player has a certain amount of DKP
function EminentDKP:PlayerHasDKP(name,amount)
  local player = self:GetPlayerByName(name)
  return (player ~= nil and player.currentDKP >= amount)
end

-- Get the your current DKP
function EminentDKP:GetMyCurrentDKP()
  local player = self:GetPlayerByName(self.myName)
  return (player ~= nil and player.currentDKP or nil)
end

-- Get the names of everybody else in the pool
function EminentDKP:GetOtherPlayersNames()
  local list = {}
  for name,id in pairs(self:GetActivePool().playerIDs) do
    if name ~= self.myName then
      list[name] = name
    end
  end
  return list
end

function EminentDKP:GetPlayerPool()
  return self:GetActivePool().players
end

function EminentDKP:GetTotalBounty()
  return self:GetActivePool().bounty.size
end

function EminentDKP:GetAvailableBounty()
  return self:GetActivePool().bounty.available
end

function EminentDKP:GetAvailableBountyPercent()
  return self:StdNumber((self:GetAvailableBounty()/self:GetTotalBounty())*100)
end

-- Construct list of players currently in the raid
function EminentDKP:GetCurrentRaidMembers()
  local players = {}
  for spot = 1, 40 do
    local name = select(1,GetRaidRosterInfo(spot))
		if name then
		  players[self:GetPlayerIDByName(name)] = self:GetPlayerByName(name)
		end
  end
  return players
end

-- Construct list of IDs for players currently in the raid
function EminentDKP:GetCurrentRaidMembersIDs()
  local players = {}
  for spot = 1, 40 do
    local name = select(1,GetRaidRosterInfo(spot))
		if name then
		  table.insert(players,self:GetPlayerIDByName(name))
		end
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
  
  self:SendCommMessage('EminentDKP',final,'GUILD',nil,'BULK')
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
    self:DecreaseAvailableBounty(vanitydkp)
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
    self:UpdateLastPlayerRaid(pid,dtime)
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
  self:UpdateLastPlayerRaid(pid,dtime)
  
  -- Then create all the necessary earnings for players
  local dividend = (amount/#(players))
  for i,rpid in ipairs(players) do
    self:CreatePlayerEarning(rpid,cid,dividend,true)
    self:UpdateLastPlayerRaid(rpid,dtime)
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
  self:UpdateLastPlayerRaid(pfid,dtime)
  
  return cid
end

function EminentDKP:CreateExpirationSyncEvent(name)
  self:SyncEvent(self:CreateExpirationEvent(name,time()))
end

function EminentDKP:CreateExpirationEvent(name,dtime)
  local pid = self:GetPlayerIDByName(name)
  local pdata = self:GetPlayerByName(name)
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
  local pid = self:GetPlayerIDByName(name)
  local pdata = self:GetPlayerByName(name)
  local amount = pdata.currentVanityDKP
  
  -- Create the event
  local cid = self:CreateEvent(pid,"vanityreset","","","",amount,dtime)
  
  -- Update player's last raid
  self:UpdateLastPlayerRaid(pid,dtime)
  
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
  self:GetPlayerByID(ptid) = nil
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
  
  return cid
end

---------- END EVENT FUNCTIONS ----------

-- Iterate over the raid and determine loot eligibility
function EminentDKP:UpdateLootEligibility()
  wipe(eligible_looters)
  for d = 1, GetNumRaidMembers() do
		if GetMasterLootCandidate(d) then
			eligible_looters[GetMasterLootCandidate(d)] = d
		end
	end
end

-- Broadcast version
function EminentDKP:PLAYER_ENTERING_WORLD()
  self:BroadcastVersion()
end

-- Announcements (and expirations) occur at the first entry of combat
-- This ensures nobody is accidently expired and everybody sees the announcements
function EminentDKP:PLAYER_REGEN_DISABLED()
  if self.db.profile.hidecombat then self:ToggleMeters(false) end
  if not self:AmOfficer() and not self.amMasterLooter then return end
  
  if self:GetLastScan() == 0 or GetDaysSince(self:GetLastScan()) < 0 then
    sendchat('Performing database scan...', nil, 'self')
    for pid,data in pairs(self:GetActivePool().players) do
      if data.active then
        local days = math.floor(GetDaysSince(data.lastRaid))
        if days >= self.db.profile.expiretime then
          -- If deemed inactive then reset their DKP and vanity DKP
          local name = self:GetPlayerNameByID(pid)
          sendchat('The DKP for '..name..' has expired. Bounty has increased by '..self:StdNumber(data.currentDKP)..' DKP.', "raid", "preset")
          self:CreateExpirationSyncEvent(name)
        end
      end
    end
    if self:GetAvailableBountyPercent() > 50 then
      sendchat('There is more than 50% of the bounty available, you should distribute some.', nil, 'self')
    end
    sendchat('Current bounty is '..self:StdNumber(self:GetAvailableBounty())..' DKP.', "raid", "preset")
    self:GetActivePool().lastScan = time()
    self:PrintStandings()
  end
end

-- Keep track of people in the raid
function EminentDKP:RAID_ROSTER_UPDATE()
  -- This only needs to be run by the masterlooter
  if not self:AmOfficer() and not self.amMasterLooter then return end
  
  -- Make sure players exist in the pool
  for d = 1, GetNumRaidMembers() do
		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(d)
		if not self:PlayerExistsInPool(name) then
		  self:CreateAddPlayerSyncEvent(name,select(2,UnitClass(name)))
		end
	end
end

-- Keep track of the loot method
function EminentDKP:PARTY_LOOT_METHOD_CHANGED()
  self.lootMethod, self.masterLooterPartyID, self.masterLooterRaidID = GetLootMethod()
  self.amMasterLooter = (self.lootMethod == 'master' and self.masterLooterPartyID == 0)
  self.masterLooterName = UnitName("raid"..tostring(self.masterLooterRaidID))
end

-- Loot window closing means cancel auction
function EminentDKP:LOOT_CLOSED()
  if UnitInRaid("player") and self.amMasterLooter and auction_active then
    sendchat('Auction cancelled. All bids have been voided.', "raid", "preset")
    auction_active = false
    self:CancelTimer(self.bidTimer)
    self.bidItem = nil
  end
end

-- Prints out the loot to the raid when looting a corpse
function EminentDKP:LOOT_OPENED()
  -- This only needs to be run by the masterlooter
  if not self:AmOfficer() and not self.amMasterLooter then return end
  
  if UnitInRaid("player") then
    -- Query some info about this unit...
    local guid = UnitGUID("target")
    local unitName = select(1,UnitName("target"))
    if not recent_loots[guid] and GetNumLootItems() > 0 then
      local eligible_items = {}
      local eligible_slots = {}
      for slot = 1, GetNumLootItems() do 
				local lootIcon, lootName, lootQuantity, rarity = GetLootSlotInfo(slot)
				if lootQuantity > 0 and rarity >= self.db.profile.itemrarity then
				  table.insert(eligible_items,GetLootSlotLink(slot))
				  table.insert(eligible_slots,slot)
				end
			end
			
			if #(eligible_items) > 0 then
  			sendchat('Loot from '.. unitName ..':',"raid", "preset")
			  for i,loot in ipairs(eligible_items) do
			    sendchat(loot,"raid", "preset")
		    end
			end
			-- Ensure that we only print once by keeping track of the GUID
			recent_loots[guid] = { name=unitName, slots=eligible_slots }
    end
  end
end

-- Place a bid on an active auction
function EminentDKP:Bid(amount, from)
  if auction_active then
    if UnitInRaid(from) then
      if eligible_looters[from] then
        local bid = math.floor(tonumber(amount))
        if bid > 0 then
          if self:PlayerHasDKP(from,bid) then
            self.bidItem.bids[from] = bid
            sendchat('Your bid of '.. bid .. ' has been accepted.', from, 'whisper')
          else
            sendchat('The bid amount must not exceed your current DKP.', from, 'whisper')
          end
        else
          sendchat('Bid must be a number greater than 0.', from, 'whisper')
        end
      else
        sendchat('You are not eligible to receive loot.', from, 'whisper')
      end
    else
      sendchat('You must be present in the raid.', from, 'whisper')
    end
  else
    sendchat("There is currently no auction active.", from, 'whisper')
  end
end

function EminentDKP:WhisperBalance(to)
  self:WhisperCheck(to, to)
end

function EminentDKP:GetStandings(stat)
  local a = {}
  local players = self:GetCurrentRaidMembers()
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

function EminentDKP:PrintStandings()
  local a = self:GetStandings('currentDKP')
  
  sendchat('Current DKP standings:', "raid", "preset")
  for rank,data in ipairs(a) do
    sendchat(rank..'. '..data.n..' - '..self:StdNumber(data.dkp), "raid", "preset")
  end
end

function EminentDKP:WhisperStandings(to)
  local a = self:GetStandings('currentDKP')
  
  sendchat('Current DKP standings:', to, 'whisper')
  for rank,data in ipairs(a) do
    sendchat(rank..'. '..data.n..' - '..self:StdNumber(data.dkp), to, 'whisper')
  end
end

function EminentDKP:WhisperLifetime(to)
  local a = self:GetStandings('earnedDKP')
  
  sendchat('Lifetime Earned DKP standings:', to, 'whisper')
  for rank,data in ipairs(a) do
    sendchat(rank..'. '..data.n..' - '..self:StdNumber(data.dkp), to, 'whisper')
  end
end

-- Transfer DKP from one player to another
function EminentDKP:WhisperTransfer(amount, to, from)
  if to ~= from then
    if self:PlayerExistsInPool(from) then
      if self:PlayerExistsInPool(to) then
        if not auction_active then
          local dkp = tonumber(amount)
          if dkp > 0 then
            if self:PlayerHasDKP(from,dkp) then
              self:CreateTransferSyncEvent(from,to,dkp)
              sendchat('Succesfully transferred '.. dkp ..' DKP to ' .. to .. '.', from, 'whisper')
              sendchat(from .. ' just transferred '.. dkp .. ' DKP to you.', to, 'whisper')
              sendchat(from .. " has transferred " .. dkp .. " DKP to " .. to .. ".", "raid", "preset")
            else
              sendchat('The DKP amount must not exceed your current DKP.', from, 'whisper')
            end
          else
            sendchat('DKP amount must be a number greater than 0.', from, 'whisper')
          end
        else
          sendchat("You cannot transfer DKP during an auction.", from, 'whisper')
        end
      else
        sendchat(to.." does not exist in the DKP pool.", from, 'whisper')
      end
    else
      sendchat("You do not exist in the DKP pool.", from, 'whisper')
    end
  else
    sendchat("You cannot transfer DKP to yourself.", from, 'whisper')
  end
end

function EminentDKP:WhisperBounty(to)
  sendchat('The current bounty is '..self:StdNumber(self:GetAvailableBounty())..' DKP.', to, 'whisper')
end

function EminentDKP:WhisperCheck(who, to)
  if self:PlayerExistsInPool(who) then
    local data = self:GetPlayerByName(who)
    sendchat('Player Report for '..who, to, 'whisper')
    sendchat('Current DKP: '..self:StdNumber(data.currentDKP), to, 'whisper')
    sendchat('Lifetime DKP: '..self:StdNumber(data.earnedDKP), to, 'whisper')
    sendchat('Vanity DKP: '..self:StdNumber(data.currentVanityDKP), to, 'whisper')
    sendchat('Last Raid: '..GetDaysSince(data.lastRaid)..' day(s) ago.', to, 'whisper')
  else
    sendchat(who.." does not exist in the DKP pool.", to, 'whisper')
  end
end

------------- START ADMIN FUNCTIONS -------------

function EminentDKP:AdminStartAuction()
  if self.amMasterLooter then
    if GetNumLootItems() > 0 then
      local guid = UnitGUID("target")
      if #(recent_loots[guid].slots) > 0 then
        if not auction_active then
          -- Update eligibility list
          self:UpdateLootEligibility()
  		
      		-- Fast forward to next eligible slot
      		local slot = recent_loots[guid].slots[1]
      		local itemLink = GetLootSlotLink(slot)
      		
      		while itemLink == nil do
      		  table.remove(recent_loots[guid].slots,1)
      		  slot = recent_loots[guid].slots[1]
      		  itemLink = GetLootSlotLink(slot)
    		  end
    		  
      		-- Gather some info about this item
      		local lootIcon, lootName, lootQuantity, rarity = GetLootSlotInfo(slot)
			
    			auction_active = true
    			self.bidItem = { 
    			  name=lootName, 
    			  itemString=string.match(itemLink, "item[%-?%d:]+"), 
    			  elapsed=0, 
    			  bids={}, 
    			  slotNum=slot,
    			  srcGUID=UnitGUID("target")
    			}
    			self.bidTimer = self:ScheduleRepeatingTimer("AuctionBidTimer", 5)
			
    			sendchat(itemLink .. ' bid now!', "raid_warning", "preset")
    			sendchat(itemLink .. ' now up for auction! Auction ends in 30 seconds.', "raid", "preset")
      		--local itemString = string.match(itemLink, "item[%-?%d:]+")
        else
          sendchat('An auction is already active.', nil, 'self')
        end
      else
        sendchat('There is no loot available to auction.', nil, 'self')
      end
    else
      sendchat('You must be looting a corpse to start an auction.', nil, 'self')
    end
  else
    sendchat('You must be the master looter to initiate an auction.', nil, 'self')
  end
end

function EminentDKP:AuctionBidTimer()
  -- Add 5 seconds to the elapsed time
  self.bidItem.elapsed = self.bidItem.elapsed + 5
  
  -- If 30 seconds has elapsed, then close it
  if self.bidItem.elapsed == 30 then
    sendchat('Auction has closed. Determining winner...', "raid", "preset")
    auction_active = false
    self:CancelTimer(self.bidTimer)
    
    local looter = self.myName
		local guid = self.bidItem.srcGUID
		
		-- Update eligibility list
    self:UpdateLootEligibility()
    
    if next(self.bidItem.bids) == nil then
      -- No bids received, so disenchant
      sendchat('No bids received. Disenchanting.', "raid", "preset")
      if eligible_looters[self.db.profile.disenchanter] then
        looter = self.db.profile.disenchanter
      else
        sendchat(self.db.profile.disenchanter..' was not eligible to receive loot to disenchant.', nil, 'self')
      end
    else
      local bids = 0
      local secondHighestBid = 0
      local winningBid = 0
      local winners = {}
      
      -- Run through the bids and determine the winner(s)
      for name,bid in pairs(self.bidItem.bids) do
        bids = bids + 1
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
        local tiebreak = math.random(#(winners))
        looter = winners[tiebreak]
        secondHighestBid = winningBid
        sendchat('A tie was broken with a random roll.', "raid", "preset")
      end
      
      -- Construct list of players to receive dkp
      local players = self:GetCurrentRaidMembersIDs()
      local dividend = (secondHighestBid/#(players))
      
      self:CreateAuctionSyncEvent(players,looter,secondHighestBid,recent_loots[guid].name,self.bidItem.itemString)
      sendchat(looter..' has won '..GetLootSlotLink(self.bidItem.slotNum)..' for '..secondHighestBid..' DKP!', "raid", "preset")
      sendchat('Each player has received '..self:StdNumber(dividend)..' DKP.', "raid", "preset")
    end
    
    -- Distribute the loot
    table.remove(recent_loots[guid].slots,1)
    GiveMasterLoot(self.bidItem.slotNum, eligible_looters[looter])
    self.bidItem = nil
    
    -- Re-run the auction routine...
    if #(recent_loots[guid].slots) > 0 then
      sendchat('The next auction will begin in 3 seconds.', "raid", "preset")
      self:ScheduleTimer("AdminStartAuction", 3)
    else
      sendchat('No more loot found.', "raid", "preset")
    end
  else
    local timeLeft = (30 - self.bidItem.elapsed)
    sendchat(timeLeft .. '...', "raid", "preset")
  end
end

function EminentDKP:AdminDistributeBounty(percent,reason)
  -- todo: maybe offer a config option to automatically run this after a boss death?
  if not auction_active then
    local p = math.floor(tonumber(percent))
    if p <= 100 and p > 0 then
      sendchat('Distributing '.. percent ..'% of the bounty to the raid.', nil, 'self')
      
      -- Construct list of players to receive bounty
      local players = self:GetCurrentRaidMembersIDs()
      
      -- todo: solidify the process by which a "reason" is acquired
      local name = UnitName("target")
      if name ~= nil then
        if reason ~= nil then
          name = "Default"
        else
          name = reason
        end
      end
      local amount = (self:GetAvailableBounty() * (p/100))
      local dividend = (amount/#(players))
      
      self:CreateBountySyncEvent(players,amount,name)
      sendchat('A bounty of '..self:StdNumber(amount)..' ('..tostring(p)..'%) has been awarded to '..#(players)..' players.', "raid", "preset")
      sendchat('Each player has received '..self:StdNumber(dividend)..' DKP.', "raid", "preset")
      sendchat('New bounty is '..self:StdNumber(self:GetAvailableBounty())..' DKP.', "raid", "preset")
    else
      sendchat('You must enter a percent between 0 and 100.', nil, 'self')
    end
  else
    sendchat('An auction must not be active.', nil, 'self')
  end
  
end

-- Perform a vanity roll weighted by current vanity DKP
function EminentDKP:AdminVanityRoll()
  if not auction_active then
    local ranks = {}
    for r = 1, GetNumRaidMembers() do
  		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(r)
  		if name then
  		  local data = self:GetPlayerByName(name)
  			if data.currentVanityDKP > 0 then
  			  local roll = math.random(math.floor(data.currentVanityDKP))/1000
  			  table.insert(ranks, { n=name, v=data.currentVanityDKP, r=roll })
			  end
		  end
	  end
	  table.sort(ranks, function(a,b) return a.r>b.r end)
	  
	  sendchat('Vanity item rolls weighted by current vanity DKP:', "raid", "preset")
	  for rank,data in ipairs(ranks) do
	    sendchat(rank..'. '..data.n..' ('..tostring(data.v)..') - '..tostring(data.r)..'.', "raid", "preset")
    end
  else
    sendchat('An auction must not be active.', nil, 'self')
  end
end

function EminentDKP:AdminVanityReset(who)
  if self:PlayerExistsInPool(who) then
    self:CreateVanityResetSyncEvent(who)
    sendchat('Reseting current vanity DKP for '.. who ..'.', nil, 'self')
  else
    sendchat('The player '..who..' does not exist in the DKP pool.', nil, 'self')
  end
end

function EminentDKP:AdminRename(from,to)
  if self:PlayerExistsInPool(from) then
    if not self:PlayerExistsInPool(to) then
      self:CreateRenameSyncEvent(from,to)
      sendchat('Succesfully renamed '..from..' -> '..to..'!', nil, 'self')
    else
      sendchat('The player '..to..' already exists in the DKP pool.', nil, 'self')
    end
  else
    sendchat('The player '..from..' does not exist in the DKP pool.', nil, 'self')
  end
end

------------- END ADMIN FUNCTIONS -------------

-- Handle slash commands
function EminentDKP:ProcessSlashCmd(input)
  local command, arg1, arg2, e = self:GetArgs(input, 3)
  
  if command == 'auction' then
    self:AdminStartAuction()
  elseif command == 'bounty' then
    self:AdminDistributeBounty(arg1,arg2)
  elseif command == 'vanity' then
    if arg1 then
      self:AdminVanityReset(arg1)
    else
      self:AdminVanityRoll()
    end
  elseif command == 'rename' then
    self:AdminRename(arg1,arg2)
  elseif command == 'version' then
    local say_what = "Current version is "..self:GetVersion()
    if self:GetNewestVersion() ~= self:GetVersion() then
      say_what = say_what .. " (latest is "..self:GetNewestVersion()..")"
    end
    sendchat(say_what, nil, 'self')
  elseif command == 'admin' then
    sendchat("Admin Commands:", nil, 'self')
		sendchat("'/edkp auction' to begin an auction (must be looting)", nil, 'self')
		sendchat("'/edkp bounty X Y' to distribute X% of the bounty pool to the raid for a given reason Y", nil, 'self')
		sendchat("'/edkp vanity X' to clear the vanity DKP for player X. If X is not given, a vanity roll is performed instead. Each roll is weighted by that player's current vanity dkp.", nil, 'self')
	  sendchat("'/edkp rename X Y' to rename a player from X to Y (Y must not already exist)", nil, 'self')
	else
	  sendchat("Unrecognized command. Type '/edkp admin' for a list of valid commands.", nil, 'self')
  end
end

function EminentDKP:CHAT_MSG_RAID_CONTROLLER(eventController, message, from, ...)
  -- Ensure all correspondence from the addon is hidden (option)
  if self.db.profile.hideraidmessages and string.find(message, "[EminentDKP]", 1, true) then
    eventController:BlockFromChatFrame()
  end
end

function EminentDKP:CHAT_MSG_RAID_WARNING_CONTROLLER(eventController, message, from, ...)
  -- Ensure all correspondence from the addon is hidden (option)
  if self.db.profile.hideraidmessages and string.find(message, "[EminentDKP]", 1, true) then
    eventController:BlockFromChatFrame()
  end
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

function EminentDKP:CHAT_MSG_WHISPER(message, from)
  -- Only interpret messages starting with $
  local a, command, arg1, arg2 = strsplit(" ", message, 4)
	if a ~= "$" then return end
	
  if command == 'bid' then
    self:Bid(arg1,from)
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
    self:WhisperTransfer(arg1,arg2,from)
  elseif command == 'help' then
	  sendchat("Available Commands:", from, 'whisper')
		sendchat("'$ balance' to check your current balance", from, 'whisper')
		sendchat("'$ check X' to check the current balance of player X", from, 'whisper')						
		sendchat("'$ standings' to display the current dkp standings", from, 'whisper')
		sendchat("'$ lifetime' to display the lifetime earned dkp standings", from, 'whisper')
		sendchat("'$ bid X' (*) to enter a bid of X on the active auction", from, 'whisper')
		sendchat("'$ transfer X Y' (*) to transfer X dkp to player Y", from, 'whisper')						
		sendchat("* - these commands can only be sent to the master looter and only during a raid", from, 'whisper')
  elseif command == 'tutorial' then
    sendchat("I have many jobs here. I keep track of the raiders and their dkp. I announce loot to the raid and conduct auctions. When an auction ends, I award loot to the winner and distribute dkp to the raid.", from, 'whisper')
		sendchat("Most of my functionality is automated, but users (like you) can interact with me by whispering commands to the master looter. If you are a new user, there are two commands that you should learn right away: '$ balance' and '$ bid X'.", from, 'whisper')
		sendchat("'$ balance' will show you how much dkp you have available to spend. You can whisper this command to the master looter at any time. '$ bid X' will enter your bid of X dkp on the active auction.", from, 'whisper')
		sendchat("Once I announce an auction to the raid, you have 30 seconds to enter your bid. If you make the highest bid, you will win the auction and pay whatever the second highest bid was. This is the Vickrey auction model.", from, 'whisper')
		sendchat("You will start earning dkp immediately and, as far as I am concerned, you are free to start bidding on auctions right away. You can view a list of the other commands by whispering '$ help'.", from, 'whisper')
  else
    sendchat("Unrecognized command. Whisper '$ help' for a list of valid commands.", from, 'whisper')
  end
end