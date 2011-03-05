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

local green = {r = 0, g = 255, b = 0, a = 1}
local red = {r = 255, g = 0, b = 0, a = 1}

local balanceMode = EminentDKP:NewModule(L["Earnings & Deductions"])
local itemMode = EminentDKP:NewModule(L["Items Won"])

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

local function FindPlayer(set, playerid)
  if set.sortnum == 1 then
    -- This is the "all-time" set, so use the actual pool
    return EminentDKP:GetPlayerByID(playerid)
  end
	for i, p in ipairs(set.players) do
		if p.id == playerid then
			return p
		end
	end
	return nil
end

local function GetPlayers(set)
  if set.sortnum == 1 then
	  -- This is the "all-time" set, so use the actual pool
	  return EminentDKP:GetPlayerPool()
  end
  return set.players
end

-- Get relevant events from a set
local function GetEvents(set, typefilter)
  local event_list = {}
  if set.sortnum == 1 then
    -- This is the "all-time" set, so use the actual pool
    local eventcount = 0
    local eventid = EminentDKP:GetEventCount()
    while eventid > 0 and eventcount < EminentDKP.db.profile.maxmodeevents do
      local eid = tostring(eventid)
      local e = EminentDKP:GetEvent(eid)
      if typefilter(e,eid) then
        eventcount = eventcount + 1
        table.insert(event_list,eid)
      end
      eventid = eventid - 1
    end
  else
    for i, eid in ipairs(set.events) do
      local e = EminentDKP:GetEvent(eid)
      if typefilter(e,eid) then
        table.insert(event_list,eid)
      end
    end
  end
  return event_list
end

-- Group events based on a given attribute
local function GetEventGroups(events, groupby)
  local group_list = {}
  for i,eid in ipairs(events) do
    local e = EminentDKP:GetEvent(eid)
    if group_list[e[groupby]] then
      table.insert(group_list[e[groupby]],eid)
    else
      group_list[e[groupby]] = { eid }
    end
  end
  return group_list
end

-- Get relevant player events depending on set
local function GetPlayerEvents(set, playerid, typefilter)
  local player = EminentDKP:GetPlayerByID(playerid)
  local event_list = {}
  if set.sortnum == 1 then
    -- This is the "all-time" set, so use the actual pool
    local eventcount = 0
    local eventid = EminentDKP:GetEventCount()
    while eventid > 0 and eventcount < EminentDKP.db.profile.maxplayerevents do
      local eid = tostring(eventid)
      local e = EminentDKP:GetEvent(eid)
      if typefilter(e,eid,player,playerid) then
        eventcount = eventcount + 1
        table.insert(event_list,eid)
      end
      eventid = eventid - 1
    end
  else
    for i, eid in ipairs(set.events) do
      local e = EminentDKP:GetEvent(eid)
      if typefilter(e,eid,player,playerid) then
        table.insert(event_list,eid)
      end
    end
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

local function event_filter_auction(event,eventid)
  return (event.eventType == "auction")
end

local function custom_filter_auction_source(event,source)
  return (event.eventType == "auction" and event.source == source)
end

local classModePrototype = {
  OnEnable = function(self) 
    self.metadata	        = {showspots = true, ordersort = true, click1 = itemMode, click2 = balanceMode, columns = { DKP = true, Percent = true }}
  	balanceMode.metadata	= {showspots = false, ordersort = true, columns = { DKP = true, Source = true, Time = true }}
  	itemMode.metadata   	= {showspots = false, ordersort = true, tooltip = item_tooltip, click = linkitem, columns = { DKP = true }}
    
  	EminentDKP:AddMode(self)
  end,
  OnDisable = function(self)
  	EminentDKP:RemoveMode(self)
  end,
  GetSetSummary = function(self, set) 
    return EminentDKP:FormatNumber(set.modedata[self:GetName()].currentDKP)
  end,
  CalculateData = function(self, set)
    -- Ensure these calculations are only done once
    if not set.changed then return end
    if set.sortnum == 1 then
  	  -- This is the "all-time" set, so use the actual pool
  	  for pid, player in pairs(EminentDKP:GetPlayerPool()) do
        -- Iterate through the player's relevant events and calculate data!
        if player.active and tContains(classFilter[self:GetName()],player.class) then
          set.modedata[self:GetName()].currentDKP = set.modedata[self:GetName()].currentDKP + player.currentDKP
          set.modedata[self:GetName()].earnedDKP = set.modedata[self:GetName()].earnedDKP + player.earnedDKP
        end
      end
      return
    end
    
    for i, p in pairs(set.players) do
      -- Iterate through the player's relevant events and calculate data!
      local player = EminentDKP:GetPlayerByID(p.id)
      if tContains(classFilter[self:GetName()],player.class) then
        if p.modedata.earnedDKP == 0 then
          for j, eid in ipairs(set.events) do
            local event = EminentDKP:GetEvent(eid)
            -- Vanity resets are of no concern
            if event.eventType ~= 'vanityreset' then
              -- Was there an earning?
              if player.earnings[eid] then
                p.modedata.currentDKP = p.modedata.currentDKP + player.earnings[eid]
                p.modedata.earnedDKP = p.modedata.earnedDKP + player.earnings[eid]
              end
              -- Was there a deduction?
              if player.deductions[eid] then 
                p.modedata.currentDKP = p.modedata.currentDKP - player.deductions[eid]
              end
            end
          end
        end
        set.modedata[self:GetName()].currentDKP = set.modedata[self:GetName()].currentDKP + p.modedata.currentDKP
        set.modedata[self:GetName()].earnedDKP = set.modedata[self:GetName()].earnedDKP + p.modedata.earnedDKP
      end
    end
  end,
  PopulateData = function(self, win, set)
  	local max = 0
  	local nr = 1
    
  	for pid, player in pairs(GetPlayers(set)) do
  	  local hasmodedata = (player.modedata ~= nil)
  	  local pdata = (hasmodedata and EminentDKP:GetPlayerByID(player.id) or player)
  		if tContains(classFilter[self:GetName()],pdata.class) and pdata.active then
  		  -- Only show people who have had any activity in the system...
  		  if not EminentDKP:IsPlayerFresh(pdata) then
  			  local d = win.dataset[nr] or {}
    			win.dataset[nr] = d
    			d.id = (hasmodedata and player.id or pid)
    			d.label = EminentDKP:GetPlayerNameByID(d.id)
    			d.value = (hasmodedata and player.modedata.currentDKP or pdata.currentDKP)
    			d.class = pdata.class
    			-- Never show percent unless it is the alltime set, the percents are meaningless on individual days
    			local showpercent = (set.sortnum ~= 1 and false or self.metadata.columns.Percent)
    			d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP,
    			                              EminentDKP:StdNumber((d.value / set.modedata[self:GetName()].currentDKP) * 100).."%", showpercent)
    			if d.value > max then
    				max = d.value
    			end
    			nr = nr + 1
  			end
  		end
  	end
  	win.metadata.maxvalue = max
  end,
  AddPlayerAttributes = function(self, player)
    -- Called when a new player is added to a set.
    if not player.modedata.currentDKP then
      player.modedata.earnedDKP = 0
      player.modedata.currentDKP = 0
  	end
  end,
  AddSetAttributes = function(self, set)
    -- Called when a new set is created.
    if not set.modedata[self:GetName()] then
      set.modedata[self:GetName()] = { earnedDKP = 0, currentDKP = 0 }
  	end
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
deathknightMode.sortnum = 6
druidMode.sortnum = 6
hunterMode.sortnum = 6
mageMode.sortnum = 6
paladinMode.sortnum = 6
priestMode.sortnum = 6
rogueMode.sortnum = 6
shamanMode.sortnum = 6
warlockMode.sortnum = 6
warriorMode.sortnum = 6

local clothMode = EminentDKP:NewModule(L["Cloth"],classModePrototype)
local leatherMode = EminentDKP:NewModule(L["Leather"],classModePrototype)
local mailMode = EminentDKP:NewModule(L["Mail"],classModePrototype)
local plateMode = EminentDKP:NewModule(L["Plate"],classModePrototype)
clothMode.sortnum, leatherMode.sortnum, mailMode.sortnum, plateMode.sortnum = 3, 3, 3, 3

local conqMode = EminentDKP:NewModule(L["Conqueror"],classModePrototype)
local vanqMode = EminentDKP:NewModule(L["Vanquisher"],classModePrototype)
local protMode = EminentDKP:NewModule(L["Protector"],classModePrototype)
conqMode.sortnum, vanqMode.sortnum, protMode.sortnum = 4, 4, 4

local allMode = EminentDKP:NewModule(L["All Classes"],classModePrototype)
allMode.sortnum = 1

local auctionMode = EminentDKP:NewModule(L["Auctions"])
local winnerMode = EminentDKP:NewModule(L["Auction Winners"])
auctionMode.sortnum = 2

function auctionMode:PopulateData(win, set)
  local nr = 1
  local max = 0
  local eligible_events = GetEvents(set,event_filter_auction)
  
  for source, eventlist in pairs(GetEventGroups(eligible_events,"source")) do
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = source
		d.label = source
		d.value = #(eventlist)
		d.valuetext = FormatValueText(d.value, self.metadata.columns.Count)
	
		if d.value > max then
			max = d.value
		end
		nr = nr + 1
  end
  win.metadata.maxvalue = max
end

function auctionMode:CalculateData(set)
  -- Ensure these calculations are only done once
  if not set.changed then return end
  if set.sortnum == 1 then
    -- This is the alltime set, so go find events that are auctions
    -- todo: this is sort of dirty since we store events only for this mode...
    set.events = GetEvents(set,event_filter_auction)
    set.modedata[self:GetName()].sourceCount = #(set.events)
  else
    set.modedata[self:GetName()].sourceCount = #(GetEvents(set,event_filter_auction))
  end
end

function auctionMode:GetSetSummary(set) 
  return set.modedata[self:GetName()].sourceCount
end

local function label_sort(a,b)
  return a.label < b.label
end

function auctionMode:OnEnable()
  self.metadata	      = {showspots = false, ordersort = true, sortfunc = label_sort, click1 = winnerMode, columns = { Count = true }}
  winnerMode.metadata = {showspots = false, ordersort = true, tooltip = item_tooltip, click = linkitem, columns = { DKP = true, Winner = true }}
  
	EminentDKP:AddMode(self)
end

function auctionMode:AddPlayerAttributes(player)
end

function auctionMode:AddSetAttributes(set)
  -- Called when a new set is created.
  if not set.modedata[self:GetName()] then
    set.modedata[self:GetName()] = { sourceCount = 0 }
	end
end

function winnerMode:Enter(win, id, label)
  self.creaturesource = id
	self.title = label..L["'s Auctions"]
end

function winnerMode:PopulateData(win, set)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(set.events) do
    local event = EminentDKP:GetEvent(eid)
    if custom_filter_auction_source(event,self.creaturesource) then
      local d = win.dataset[nr] or {}
  		win.dataset[nr] = d
  		d.id = eid
  		-- Because Blizzard is slow and doesn't always return the itemlink in time
  		d.label = select(2, GetItemInfo(event.extraInfo)) or "(Querying Item)"
  		d.value = event.value
  		d.valuetext = FormatValueText(event.value, self.metadata.columns.DKP,
  		                              EminentDKP:GetPlayerNameByID(event.target), self.metadata.columns.Winner)
  		d.icon = select(10, GetItemInfo(event.extraInfo))
		
  		if d.value > max then
  			max = d.value
  		end
  		nr = nr + 1
		end
  end
  win.metadata.maxvalue = max
end

function balanceMode:Enter(win, id, label)
  self.playerid = id
	self.title = label..L["'s Earnings & Deductions"]
end

function balanceMode:PopulateData(win, set) 
  local player = FindPlayer(set,self.playerid)
  local playerData = (player.currentDKP and player or EminentDKP:GetPlayerByID(self.playerid))
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(GetPlayerEvents(set,self.playerid,player_event_filter_balance)) do
    local event = EminentDKP:GetEvent(eid)
    local debits = {}
    debits.e = playerData.earnings[eid]
    debits.d = playerData.deductions[eid]
    for debitType, amount in pairs(debits) do
      local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			d.id = debitType..":"..eid
			d.label = event.eventType:gsub("^%l", string.upper)
			d.value = amount
			if event.eventType == 'transfer' or event.eventType == 'addplayer' then
			  local source = (debitType == 'd' and event.target or event.source)
			  d.valuetext = FormatValueText(d.value, self.metadata.columns.DKP, 
			                                EminentDKP:GetPlayerNameByID(source), self.metadata.columns.Source)
		  else
			  d.valuetext = FormatValueText(d.value, self.metadata.columns.DKP, 
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

function itemMode:PopulateData(win, set) 
  local player = FindPlayer(set,self.playerid)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(GetPlayerEvents(set,self.playerid,player_event_filter_auction_target)) do
    local event = EminentDKP:GetEvent(eid)
    local d = win.dataset[nr] or {}
		win.dataset[nr] = d
		d.id = eid
		-- Because Blizzard is slow and doesn't always return the itemlink in time
		d.label = select(2, GetItemInfo(event.extraInfo)) or "(Querying Item)"
		d.value = event.value
		d.valuetext = FormatValueText(event.value, self.metadata.columns.DKP)
		d.icon = select(10, GetItemInfo(event.extraInfo))
		
		if d.value > max then
			max = d.value
		end
		nr = nr + 1
  end
  win.metadata.maxvalue = max
end