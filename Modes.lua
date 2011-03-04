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
  [L["All Classes"]] = { "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN", 
                         "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" },
}

local balancemode = EminentDKP:NewModule(L["Earnings & Deductions"])
local itemmode = EminentDKP:NewModule(L["Items Won"])

local function Debug(message)
  EminentDKP:Print(message)
end

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

local function find_player(set, playerid)
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

local function get_players(set)
  if set.sortnum == 1 then
	  -- This is the "all-time" set, so use the actual pool
	  return EminentDKP:GetPlayerPool()
  end
  return set.players
end

-- Get relevant events depending on set
local function get_events(set, playerid, typefilter)
  local player = EminentDKP:GetPlayerByID(playerid)
  local event_list = {}
  if set.sortnum == 1 then
    -- This is the "all-time" set, so use the actual pool
    local eventcount = 0
    local eventid = EminentDKP:GetEventCount()
    while eventid > 0 and eventcount < EminentDKP.db.profile.maxevents do
      local eid = tostring(eventid)
      if player.deductions[eid] or player.earnings[eid] then
        local e = EminentDKP:GetEvent(eid)
        if typefilter(e,playerid) then
          eventcount = eventcount + 1
          table.insert(event_list,eid)
        end
      end
      eventid = eventid - 1
    end
  else
    for i, eid in ipairs(set.events) do
      if player.deductions[eid] or player.earnings[eid] then
        local e = EminentDKP:GetEvent(eid)
        if typefilter(e,playerid) then
          table.insert(event_list,eid)
        end
      end
    end
  end
  return event_list
end

local function event_filter_balance(event,pid)
  return (event.eventType ~= "vanityreset" and event.eventType ~= "rename")
end

local function event_filter_auction_won(event,pid)
  return (event.eventType == "auction" and event.target == pid)
end

local classModePrototype = {
  OnEnable = function(self) 
    self.metadata	        = {showspots = true, ordersort = true, click1 = itemmode, click2 = balancemode, columns = { DKP = true, Percent = true }}
  	balancemode.metadata	= {showspots = false, ordersort = true, columns = { DKP = true, Source = true, Time = true }}
  	itemmode.metadata   	= {showspots = false, ordersort = true, tooltip = item_tooltip, click = linkitem, columns = { DKP = true }}
    
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
    
  	for pid, player in pairs(get_players(set)) do
  	  local class = (player.class and player.class or EminentDKP:GetPlayerClassByID(player.id))
  		if tContains(classFilter[self:GetName()],class) and (player.active == nil or player.active) then
  		  local earned = player.earnedDKP or player.modedata.earnedDKP
  		  -- Only show people who have had any activity in the system...
  		  if earned > 0 then
  			  local d = win.dataset[nr] or {}
    			win.dataset[nr] = d
    			d.id = player.id or pid
    			d.label = EminentDKP:GetPlayerNameByID(d.id)
    			d.value = player.currentDKP or player.modedata.currentDKP
    			d.class = class
    			-- Never show percent unless it is the alltime set, the percents are meaningless on individual days
    			local showpercent = self.metadata.columns.Percent
    			if set.sortnum ~= 1 then
    			  showpercent = false
  			  end
    			d.valuetext = FormatValueText(EminentDKP:FormatNumber(d.value), self.metadata.columns.DKP,
    			                              EminentDKP:StdNumber((d.value / set.modedata[self:GetName()].currentDKP) * 100), showpercent)
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
deathknightMode.sortnum = 3
druidMode.sortnum = 3
hunterMode.sortnum = 3
mageMode.sortnum = 3
paladinMode.sortnum = 3
priestMode.sortnum = 3
rogueMode.sortnum = 3
shamanMode.sortnum = 3
warlockMode.sortnum = 3
warriorMode.sortnum = 3

local conqMode = EminentDKP:NewModule(L["Conqueror"],classModePrototype)
local vanqMode = EminentDKP:NewModule(L["Vanquisher"],classModePrototype)
local protMode = EminentDKP:NewModule(L["Protector"],classModePrototype)
conqMode.sortnum, vanqMode.sortnum, protMode.sortnum = 2, 2, 2

local allMode = EminentDKP:NewModule(L["All Classes"],classModePrototype)
allMode.sortnum = 1

function balancemode:Enter(win, id, label)
  self.playerid = id
	self.title = label..L["'s Earnings & Deductions"]
end

function itemmode:Enter(win, id, label)
  self.playerid = id
	self.title = L["Items won by"].." "..label
end

local green = {r = 0, g = 255, b = 0, a = 1}
local red = {r = 255, g = 0, b = 0, a = 1}

function balancemode:PopulateData(win, set) 
  local player = find_player(set,self.playerid)
  local playerData = (player.currentDKP and player or EminentDKP:GetPlayerByID(self.playerid))
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(get_events(set,self.playerid,event_filter_balance)) do
    local event = EminentDKP:GetEvent(eid)
    if event.eventType ~= 'vanityreset' then
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
  end
  win.metadata.maxvalue = max
end

function itemmode:PopulateData(win, set) 
  local player = find_player(set,self.playerid)
  local nr = 1
  local max = 0
  
  for i, eid in ipairs(get_events(set,self.playerid,event_filter_auction_won)) do
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