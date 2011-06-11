local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)

local EminentDKP = EminentDKP

local classFilter = {
  [L["Death Knight"]] = { "DEATHKNIGHT" },
  [L["Druid"]] = { "DRUID" },
  [L["Hunter"]] = { "HUNTER" },
  [L["Mage"]] = { "MAGE" },
  [L["Paladin"]] = { "PALADIN" },
  [L["Priest"]] = { "PRIEST" },
  [L["Rogue"]] = { "ROGUE" },
  [L["Shaman"]] = { "SHAMAN" },
  [L["Warlock"]] = { "WARLOCK" },
  [L["Warrior"]] = { "WARRIOR" },
  [L["Conqueror"]] = { "PALADIN", "PRIEST", "WARLOCK" },
  [L["Vanquisher"]] = { "DEATHKNIGHT", "DRUID", "MAGE", "ROGUE" },
  [L["Protector"]] = { "HUNTER", "SHAMAN", "WARRIOR" },
  [L["Cloth"]] = { "MAGE", "PRIEST", "WARLOCK" },
  [L["Leather"]] = { "DRUID", "ROGUE" },
  [L["Mail"]] = { "HUNTER", "SHAMAN" },
  [L["Plate"]] = { "DEATHKNIGHT", "PALADIN", "WARRIOR" },
  [L["All Classes"]] = { "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN", 
                         "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" },
}

--[[
  bugs:

  - going to item view on a player then back up to
    the mode view causes the bars to not be flush
    (something to do with data wiping)
]]

local function GetDaysAgoTimestamp(days)
  local t = date("*t")
  t.hour = 0
  t.min = 0
  t.sec = 0
  return time(t) - (days * 86400)
end

local function GetDaysBetween(this,that)
  return math.floor((this - that) / 86400)
end

local function GetDaysSince(timestamp)
  return GetDaysBetween(time(),timestamp)
end


local green = {r = 0, g = 255, b = 0, a = 1}
local red = {r = 255, g = 0, b = 0, a = 1}

local function item_tooltip(win, id, label, tooltip)
  tooltip:SetHyperlink(label)
end

local function linkitem(win, id, label, button)
  -- Send itemlink to the editbox
  if button == "LeftButton" and IsShiftKeyDown() then
    local edit_box = _G.ChatEdit_ChooseBoxForSend()
    if edit_box:IsShown() then
      edit_box:Insert(label)
    else
      _G.ChatEdit_ActivateChat(edit_box)
      edit_box:Insert(label)
    end
  end
end

local function FormatValueText(...)
  local textone, showone, texttwo, showtwo, textthree, showthree = ...
  local texts = {}
  if showone then table.insert(texts,textone) end
  if showtwo then table.insert(texts,texttwo) end
  if showthree then table.insert(texts,textthree) end
  if #(texts) == 3 then
    return texts[1].." ("..texts[2]..", "..texts[3]..")"
  elseif #(texts) == 2 then
    return texts[1].." ("..texts[2]..")"
  else
    return texts[1] or ""
  end
end

-- Filter players by class from the player pool
local function FilterPlayers(list)
  local filtered = {}
  for pid, pdata in pairs(EminentDKP:GetPlayerPool()) do
     if tContains(list,pdata.class) and pdata.active then
       filtered[pid] = pdata
     end
  end
  return filtered
end

-- Filter events from the event pool
local function FilterEvents(typefilter,skipcounter)
  local filtered = {}
  local eventcount = 0
  local eventid = EminentDKP:GetEventCount()
  while eventid > 0 and eventcount < EminentDKP:GetSetting('maxmodeevents') do
    local eid = tostring(eventid)
    local e = EminentDKP:GetEvent(eid)
    if typefilter(e,eid) then
      if not skipcounter then
        eventcount = eventcount + 1
      end
      table.insert(filtered,eid)
    end
    eventid = eventid - 1
  end
  return filtered
end

-- Filter grouped events from the event pool
local function FilterGroupedEvents(groupfilter, eventfilter)
  local filtered = {}
  local group_list = {}
  local groupcount = 0
  local eventid = EminentDKP:GetEventCount()
  while eventid > 0 and groupcount < EminentDKP:GetSetting('maxmodeevents') do
    local eid = tostring(eventid)
    local e = EminentDKP:GetEvent(eid)
    if eventfilter(e,eid) then
      local grp = groupfilter(e)
      if not group_list[grp] then
        group_list[grp] = true
        groupcount = groupcount + 1
      end
      table.insert(filtered,eid)
    end
    eventid = eventid - 1
  end
  return filtered
end

-- Group events based on a given attribute
local function GroupEvents(events, groupfilter)
  local group_list = {}
  for i,eid in ipairs(events) do
    local e = EminentDKP:GetEvent(eid)
    local grp = groupfilter(e)
    if group_list[grp] then
      table.insert(group_list[grp],eid)
    else
      group_list[grp] = { eid }
    end
  end
  return group_list
end

-- Get relevant player events depending on set
local function GetPlayerEvents(playerid, filter)
  local player = EminentDKP:GetPlayerByID(playerid)
  local event_list = {}
  local eventcount = 0
  local eventid = EminentDKP:GetEventCount()
  while eventid > 0 and eventcount < EminentDKP:GetSetting('maxplayerevents') do
    local eid = tostring(eventid)
    local e = EminentDKP:GetEvent(eid)
    if filter(e,eid,player,playerid) then
      eventcount = eventcount + 1
      table.insert(event_list,eid)
    end
    eventid = eventid - 1
  end
  return event_list
end

local function player_event_filter_balance(event,eventid,player,playerid)
  if event.eventType ~= "vanityreset" and event.eventType ~= "rename" then
    if player.earnings[eventid] or player.deductions[eventid] then
      return true
    end
  end
  return false
end

local function player_event_filter_auction_target(event,eventid,player,playerid)
  return (event.eventType == "auction" and event.target == playerid)
end

local function event_filter_earnings_period(event,eventid)
  return (event.datetime >= GetDaysAgoTimestamp(EminentDKP:GetSetting('attendancedays')) and 
          (event.eventType == "auction" or event.eventType == "bounty"))
end

local function event_filter_auction(event,eventid)
  return (event.eventType == "auction")
end

local function event_filter_transfer(event,eventid)
  return (event.eventType == "transfer")
end

local function event_filter_bounty(event,eventid)
  return (event.eventType == "bounty")
end

local function group_filter_day(event)
  return date("%x",event.datetime)
end

local function group_filter_source_day(event)
  return event.source .. ":" .. date("%x",event.datetime)
end

local function MergeTables(source,other)
  for i,val in ipairs(other) do
    table.insert(source,val)
  end
end

local function time_sort(a,b)
  return a.time > b.time
end

local function label_sort(a,b)
  return b.label > a.label
end

local function value_and_label_sort(a,b)
  if a.value > b.value then return true end
  if b.value > a.value then return false end
  return b.label > a.label
end

local function getModeData(mode)
  return EminentDKP:GetModeData()[mode]
end

local function setModeData(mode,data)
  EminentDKP:GetModeData()[mode] = data
end

local balanceMode = EminentDKP:NewModule(L["Earnings & Deductions"])
local itemMode = EminentDKP:NewModule(L["Items Won"])

local classModePrototype = {
  OnEnable = function(self)
    self.metadata	        = {showspots = true, ordersort = true, click1 = itemMode, click2 = balanceMode, columns = { DKP = true, Percent = true }}
  	balanceMode.metadata	= {showspots = false, ordersort = true, columns = { DKP = true, Source = true, Time = true }}
  	balanceMode.parent    = self
  	itemMode.metadata   	= {showspots = false, ordersort = true, tooltip = item_tooltip, click = linkitem, columns = { DKP = true }}
    itemMode.parent       = self
    
  	EminentDKP:AddMode(self)
  end,
  OnDisable = function(self)
  	EminentDKP:RemoveMode(self)
  end,
  GetSetSummary = function(self) 
    return EminentDKP:FormatNumber(getModeData(self:GetName()).currentDKP)
  end,
  CalculateData = function(self)
    -- Reset the totals
    getModeData(self:GetName()).currentDKP = 0
    getModeData(self:GetName()).earnedDKP = 0
	  
	  for pid, player in pairs(FilterPlayers(classFilter[self:GetName()])) do
      -- Iterate through the player's relevant events and sum DKP
      getModeData(self:GetName()).currentDKP = getModeData(self:GetName()).currentDKP + player.currentDKP
      getModeData(self:GetName()).earnedDKP = getModeData(self:GetName()).earnedDKP + player.earnedDKP
    end
  end,
  PopulateData = function(self, win)
  	local max = 0
  	local nr = 1
    
  	for pid, pdata in pairs(FilterPlayers(classFilter[self:GetName()])) do
		  -- Only show people who have had any activity in the system...
		  if not EminentDKP:IsPlayerFresh(pdata) then
			  local d = win.dataset[nr] or {}
  			win.dataset[nr] = d
  			d.id = pid
  			d.label = EminentDKP:GetPlayerNameByID(d.id)
  			d.value = pdata.currentDKP
  			d.class = pdata.class
  			d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP,
  			                              EminentDKP:StdNumber((d.value / getModeData(self:GetName()).currentDKP) * 100).."%", self.metadata.columns.Percent)
  			if d.value > max then
  				max = d.value
  			end
  			nr = nr + 1
  		end
  	end
  	win.metadata.maxvalue = max
  end,
  AddAttributes = function(self)
    -- Called when mode is added
    setModeData(self:GetName(),{ earnedDKP = 0, currentDKP = 0 })
  end
}

-- These are all inherently the same function, just filtering by a different class
local deathknightMode = EminentDKP:NewModule(L["Death Knight"],classModePrototype)
local druidMode = EminentDKP:NewModule(L["Druid"],classModePrototype)
local hunterMode = EminentDKP:NewModule(L["Hunter"],classModePrototype)
local mageMode = EminentDKP:NewModule(L["Mage"],classModePrototype)
local paladinMode = EminentDKP:NewModule(L["Paladin"],classModePrototype)
local priestMode = EminentDKP:NewModule(L["Priest"],classModePrototype)
local rogueMode = EminentDKP:NewModule(L["Rogue"],classModePrototype)
local shamanMode = EminentDKP:NewModule(L["Shaman"],classModePrototype)
local warlockMode = EminentDKP:NewModule(L["Warlock"],classModePrototype)
local warriorMode = EminentDKP:NewModule(L["Warrior"],classModePrototype)
deathknightMode.sortnum = 10
druidMode.sortnum = 10
hunterMode.sortnum = 10
mageMode.sortnum = 10
paladinMode.sortnum = 10
priestMode.sortnum = 10
rogueMode.sortnum = 10
shamanMode.sortnum = 10
warlockMode.sortnum = 10
warriorMode.sortnum = 10

local clothMode = EminentDKP:NewModule(L["Cloth"],classModePrototype)
local leatherMode = EminentDKP:NewModule(L["Leather"],classModePrototype)
local mailMode = EminentDKP:NewModule(L["Mail"],classModePrototype)
local plateMode = EminentDKP:NewModule(L["Plate"],classModePrototype)
clothMode.sortnum, leatherMode.sortnum, mailMode.sortnum, plateMode.sortnum = 5, 5, 5, 5

local conqMode = EminentDKP:NewModule(L["Conqueror"],classModePrototype)
local vanqMode = EminentDKP:NewModule(L["Vanquisher"],classModePrototype)
local protMode = EminentDKP:NewModule(L["Protector"],classModePrototype)
conqMode.sortnum, vanqMode.sortnum, protMode.sortnum = 8, 8, 8

local allMode = EminentDKP:NewModule(L["All Classes"],classModePrototype)
allMode.sortnum = 1

local auctionMode = EminentDKP:NewModule(L["Auctions"])
local winnerMode = EminentDKP:NewModule(L["Auction Winners"])
auctionMode.sortnum = 2

local bountyMode = EminentDKP:NewModule(L["Bounties"])
local awardeeMode = EminentDKP:NewModule(L["Awardees"])
bountyMode.sortnum = 2

local activityMode = EminentDKP:NewModule(L["Activity"])
activityMode.sortnum = 2

local vanityMode = EminentDKP:NewModule(L["Vanity"])
vanityMode.sortnum = 2
local vanityRollMode = EminentDKP:NewModule(L["Vanity Rolls"])
vanityRollMode.sortnum = 2

local transferMode = EminentDKP:NewModule(L["Transfers"])
transferMode.sortnum = 2

local attendanceMode = EminentDKP:NewModule(L["Attendance"])
local missedEventMode = EminentDKP:NewModule(L["Missed Events"])
attendanceMode.sortnum = 2

function bountyMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(getModeData(self:GetName()).events) do
    local event = EminentDKP:GetEvent(eid)
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = eid
		d.label = event.source
		d.value = event.value
		d.time = event.datetime
		d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP,
		                              date("%x",event.datetime), self.metadata.columns.Date)
	
		if d.value > max then
			max = d.value
		end
		nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function bountyMode:CalculateData()
  wipe(getModeData(self:GetName()).events)
  MergeTables(getModeData(self:GetName()).events,FilterEvents(event_filter_bounty))
end

function bountyMode:GetSetSummary() 
  return #(getModeData(self:GetName()).events)
end

function bountyMode:OnEnable()
  self.metadata	       = {showspots = false, ordersort = true, sortfunc = time_sort, click1 = awardeeMode, columns = { DKP = true, Date = true }}
  awardeeMode.metadata = {showspots = true, ordersort = true, sortfunc = label_sort, columns = { DKP = true }}
  awardeeMode.parent   = self
  
	EminentDKP:AddMode(self)
end

function bountyMode:AddAttributes()
  -- Called when a new mode is created.
  setModeData(self:GetName(),{ events = {} })
end

function awardeeMode:Enter(win, id, label)
  self.eventid = id
	self.title = label.." "..L["Awardees"]
end

function awardeeMode:PopulateData(win)
  local event = EminentDKP:GetEvent(self.eventid)
  local nr = 1
  
  for i, pid in ipairs({ strsplit(',',event.beneficiary) }) do
    local pdata, name = EminentDKP:GetPlayerByID(pid)
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = pid
		d.label = name
		d.value = pdata.earnings[self.eventid]
		d.class = pdata.class
		d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP)
	  
		nr = nr + 1
		win.metadata.maxvalue = d.value
  end
end

function auctionMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for source, eventlist in pairs(GroupEvents(getModeData(self:GetName()).events,group_filter_source_day)) do
    local event = EminentDKP:GetEvent(eventlist[1])
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = source
		d.label = event.source
		d.value = #(eventlist)
		d.time = event.datetime
		d.valuetext = FormatValueText(d.value, self.metadata.columns.Count,
		                              date("%x",d.time), self.metadata.columns.Date)
	
		if d.value > max then
			max = d.value
		end
		nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function auctionMode:CalculateData()
  wipe(getModeData(self:GetName()).events)
  MergeTables(getModeData(self:GetName()).events,FilterGroupedEvents(group_filter_source_day,event_filter_auction))
end

function auctionMode:GetSetSummary() 
  return #(getModeData(self:GetName()).events)
end

function auctionMode:OnEnable()
  self.metadata	      = {showspots = false, ordersort = true, sortfunc = time_sort, click1 = winnerMode, columns = { Count = true, Date = true }}
  winnerMode.metadata = {showspots = false, ordersort = true, tooltip = item_tooltip, click = linkitem, columns = { DKP = true, Winner = true }}
  winnerMode.parent   = self
  
	EminentDKP:AddMode(self)
end

function auctionMode:AddAttributes()
  -- Called when a new mode is created.
  setModeData(self:GetName(),{ events = {} })
end

function winnerMode:Enter(win, id, label)
  self.events = GroupEvents(getModeData(self.parent:GetName()).events,group_filter_source_day)[id]
	self.title = label..L["'s Auctions"]
end

function winnerMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(self.events) do
    local event = EminentDKP:GetEvent(eid)
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = eid
		-- Because Blizzard is slow and doesn't always return the itemlink in time
		d.label = select(2, GetItemInfo(event.extraInfo)) or "(Querying Item)"
		d.value = event.value
		d.valuetext = FormatValueText(EminentDKP:FormatNumber(event.value), self.metadata.columns.DKP,
		                              EminentDKP:GetPlayerNameByID(event.target), self.metadata.columns.Winner)
		d.icon = select(10, GetItemInfo(event.extraInfo))
	
		if d.value > max then
			max = d.value
		end
		nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function balanceMode:Enter(win, id, label)
  self.playerid = id
	self.title = label..L["'s Earnings & Deductions"]
end

function balanceMode:PopulateData(win)
  local pdata = EminentDKP:GetPlayerByID(self.playerid)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(GetPlayerEvents(self.playerid,player_event_filter_balance)) do
    local event = EminentDKP:GetEvent(eid)
    local debits = {}
    debits.e = pdata.earnings[eid]
    debits.d = pdata.deductions[eid]
    for debitType, amount in pairs(debits) do
      local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			d.id = debitType..":"..eid
			d.label = event.eventType:gsub("^%l", string.upper)
			d.value = amount
			if event.eventType == 'transfer' or event.eventType == 'addplayer' then
			  local source = (debitType == 'd' and event.target or event.source)
			  d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP, 
			                                EminentDKP:GetPlayerNameByID(source), self.metadata.columns.Source)
		  else
			  d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP, 
			                                event.source, self.metadata.columns.Source)
	    end
	    if debitType == 'e' then
	      d.color = green
	      d.icon = select(3,GetSpellInfo(28059)) -- positive charge icon
	    elseif debitType == 'd' then
	      d.color = red
	      d.icon = select(3,GetSpellInfo(28084)) -- negative charge icon
      end
      
      if d.value > max then
				max = d.value
			end
			nr = nr + 1
    end
  end
  win.metadata.maxvalue = max
end

function itemMode:Enter(win, id, label)
  self.playerid = id
	self.title = L["Items won by"].." "..label
end

function itemMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(GetPlayerEvents(self.playerid,player_event_filter_auction_target)) do
    local event = EminentDKP:GetEvent(eid)
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = eid
		-- Because Blizzard is slow and doesn't always return the itemlink in time
		d.label = select(2, GetItemInfo(event.extraInfo)) or "(Querying Item)"
		d.value = event.value
		d.valuetext = FormatValueText(EminentDKP:FormatNumber(event.value), self.metadata.columns.DKP)
		d.icon = select(10, GetItemInfo(event.extraInfo))
		
		if d.value > max then
			max = d.value
		end
		nr = nr + 1
  end
  win.metadata.maxvalue = max
end

------------------- Activity Mode -------------------

function activityMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for pid, pdata in pairs(FilterPlayers(classFilter[L["All Classes"]])) do
    -- Only show people who have had any activity in the system...
    if not EminentDKP:IsPlayerFresh(pdata) then
      local d = win.dataset[nr] or {}
      win.dataset[nr] = d
      d.id = pid
      d.label = EminentDKP:GetPlayerNameByID(d.id)
      d.value = GetDaysSince(pdata.lastRaid)
      d.class = pdata.class
      d.valuetext = FormatValueText(d.value, self.metadata.columns.Count,
                                    date("%x",pdata.lastRaid), self.metadata.columns.Date)
    
      if d.value > max then
        max = d.value
      end
      nr = nr + 1
    end
  end
  win.metadata.maxvalue = max
end

function activityMode:CalculateData()
end

function activityMode:GetSetSummary() 
  return ""
end

function activityMode:OnEnable()
  self.metadata       = {showspots = true, ordersort = true, sortfunc = value_and_label_sort, columns = { Count = true, Date = true }}
  
  EminentDKP:AddMode(self)
end

function activityMode:AddAttributes()
end

------------------- Vanity Mode -------------------

function vanityMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for pid, pdata in pairs(FilterPlayers(classFilter[L["All Classes"]])) do
    -- Only show people who have had any activity in the system...
    if not EminentDKP:IsPlayerFresh(pdata) then
      local d = win.dataset[nr] or {}
      win.dataset[nr] = d
      d.id = pid
      d.label = EminentDKP:GetPlayerNameByID(d.id)
      d.value = pdata.currentVanityDKP
      d.class = pdata.class
      d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP,
                                    EminentDKP:StdNumber((d.value / getModeData(self:GetName()).currentVanityDKP) * 100).."%", self.metadata.columns.Percent)

      if d.value > max then
        max = d.value
      end
      nr = nr + 1
    end
  end
  win.metadata.maxvalue = max
end

function vanityMode:CalculateData()
  -- Reset the totals
  getModeData(self:GetName()).currentVanityDKP = 0

  for pid, player in pairs(FilterPlayers(classFilter[L["All Classes"]])) do
    -- Iterate through the player's relevant events and sum DKP
    getModeData(self:GetName()).currentVanityDKP = getModeData(self:GetName()).currentVanityDKP + player.currentVanityDKP
  end
end

function vanityMode:GetSetSummary() 
  return EminentDKP:FormatNumber(getModeData(self:GetName()).currentVanityDKP)
end

function vanityMode:OnEnable()
  self.metadata       = {showspots = true, ordersort = true, columns = { DKP = true, Percent = true }}
  
  EminentDKP:AddMode(self)
end

function vanityMode:AddAttributes()
  -- Called when mode is added
  setModeData(self:GetName(),{ currentVanityDKP = 0 })
end

------------------- Vanity Roll Mode -------------------

function vanityRollMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for pid, roll in pairs(getModeData(self:GetName()).rolls) do
    local pdata = EminentDKP:GetPlayerByID(pid)
    local d = win.dataset[nr] or {}
    win.dataset[nr] = d
    d.id = pid
    d.label = EminentDKP:GetPlayerNameByID(d.id)
    d.value = tonumber(roll)
    d.class = pdata.class
    d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.Roll)

    if d.value > max then
      max = d.value
    end
    nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function vanityRollMode:CalculateData()
end

function vanityRollMode:InjectData(data)
  getModeData(self:GetName()).rolls = data
end

function vanityRollMode:GetSetSummary() 
  return ""
end

function vanityRollMode:OnEnable()
  self.metadata       = {showspots = true, ordersort = true, columns = { Roll = true }}
  
  EminentDKP:AddMode(self)
end

function vanityRollMode:AddAttributes()
  -- Called when mode is added
  setModeData(self:GetName(),{ rolls = {} })
end

------------------- Transfer Mode -------------------

function transferMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(getModeData(self:GetName()).events) do
    local event = EminentDKP:GetEvent(eid)
    local d = win.dataset[nr] or {}
    win.dataset[nr] = d
    d.id = eid
    d.label = EminentDKP:GetPlayerNameByID(event.target)
    d.value = event.value
    d.time = event.datetime
    d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP,
                                  EminentDKP:GetPlayerNameByID(event.source), self.metadata.columns.Source,
                                  date("%x",event.datetime), self.metadata.columns.Date)
  
    if d.value > max then
      max = d.value
    end
    nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function transferMode:CalculateData()
  wipe(getModeData(self:GetName()).events)
  MergeTables(getModeData(self:GetName()).events,FilterEvents(event_filter_transfer))
end

function transferMode:GetSetSummary() 
  return #(getModeData(self:GetName()).events)
end

function transferMode:OnEnable()
  self.metadata        = {showspots = false, ordersort = true, sortfunc = time_sort, columns = { Source = true, DKP = true, Date = true }}
  
  EminentDKP:AddMode(self)
end

function transferMode:AddAttributes()
  -- Called when a new mode is created.
  setModeData(self:GetName(),{ events = {} })
end

------------------- Attendance Mode -------------------

function attendanceMode:PopulateData(win)
  local nr = 1
  local max = 0
  
  for pid, count in pairs(getModeData(self:GetName()).totals) do
    local event = EminentDKP:GetEvent(eid)
    local d = win.dataset[nr] or {}
    win.dataset[nr] = d
    d.id = pid
    d.label = EminentDKP:GetPlayerNameByID(pid)
    d.value = count
    d.class = EminentDKP:GetPlayerClassByID(pid)
    d.valuetext = FormatValueText(d.value, self.metadata.columns.Count,
                                   EminentDKP:StdNumber((d.value / getModeData(self:GetName()).count) * 100).."%", self.metadata.columns.Percent)
  
    if d.value > max then
      max = d.value
    end
    nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function attendanceMode:CalculateData()
  local events = FilterEvents(event_filter_earnings_period,true)
  local event_count = #(events)
  local a = {}

  for pid, pdata in pairs(FilterPlayers(classFilter[L["All Classes"]])) do
    -- Only show people who have had any activity in the system...
    if not EminentDKP:IsPlayerFresh(pdata) then
      a[pid] = 0
    end
  end

  for i, eid in ipairs(events) do
    local event = EminentDKP:GetEvent(eid)
    for j, pid in ipairs({ strsplit(',',event.beneficiary) }) do
      if a[pid] then
        a[pid] = a[pid] + 1
      end
    end
  end
  wipe(getModeData(self:GetName()).events)
  MergeTables(getModeData(self:GetName()).events,events)
  getModeData(self:GetName()).count = event_count
  getModeData(self:GetName()).totals = a
end

function attendanceMode:GetSetSummary() 
  return ""
end

function attendanceMode:OnEnable()
  self.metadata            = {showspots = false, ordersort = true, sortfunc = value_and_label_sort, click1 = missedEventMode, columns = { Count = true, Percent = true }}
  missedEventMode.metadata = {showspots = false, ordersort = true, sortfunc = time_sort, columns = { Count = true, Percent = true }}
  missedEventMode.parent   = self

  EminentDKP:AddMode(self)
end

function attendanceMode:AddAttributes()
  -- Called when a new mode is created.
  setModeData(self:GetName(),{ events = {}, count = {}, totals = {} })
end

function missedEventMode:Enter(win, id, label)
  self.playerid = id
  self.title = L["Events missed by"].." "..label
end

function missedEventMode:PopulateData(win)
  local nr = 1
  local max = 0
  local days = GroupEvents(getModeData(self.parent:GetName()).events,group_filter_day)

  for day, events in pairs(days) do
    local missed = 0
    local day_total = 0
    local time
    for j, eid in ipairs(events) do
      local event = EminentDKP:GetEvent(eid)
      if not tContains({ strsplit(',',event.beneficiary) },self.playerid) then
        missed = missed + 1
      end
      day_total = day_total + 1
      time = event.datetime
    end
    if missed > 0 then
      local d = win.dataset[nr] or {}
      win.dataset[nr] = d
      d.id = day
      d.label = day
      d.value = missed
      d.time = time
      d.valuetext = FormatValueText(d.value, self.metadata.columns.Count,
                                    EminentDKP:StdNumber((missed / day_total) * 100).."%", self.metadata.columns.Percent)
      
      if d.value > max then
        max = d.value
      end
      nr = nr + 1
    end
  end
  win.metadata.maxvalue = max
end