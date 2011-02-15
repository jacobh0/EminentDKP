local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)

local EminentDKP = EminentDKP

local balancemode = EminentDKP:NewModule(L["Earnings & Deductions"])
local itemmode = EminentDKP:NewModule(L["Items Won"])

local classModePrototype = { 
  OnEnable = function(self) 
    self.metadata	        = {showspots = true, click1 = balancemode, click2 = itemmode, columns = {DKP = true, Percent = true}}
  	balancemode.metadata	= {columns = {DKP = true, Percent = true}}
  	itemmode.metadata   	= {tooltip = item_tooltip, columns = {DKP = true, Percent = true}}
    
  	EminentDKP:AddMode(self)
  end,
  OnDisable = function(self)
  	EminentDKP:RemoveMode(self)
  end,
  GetSetSummary = function(set) return EminentDKP:FormatNumber(set.currentDKP) end,
  Update = function(win, set) playerUpdate(win, set) end,
  AddPlayerAttributes = function(player)
    -- Called when a new player is added to a set.
    if not player.earnedDKP then
  		player.earnedDKP = 0
  		player.currentDKP = 0
  	end
  end,
  AddSetAttributes = function(set)
    -- Called when a new set is created.
    if not set.earnedDKP then
  		set.earnedDKP = 0
  		set.currentDKP = 0
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
EminentDKP:EnableModule(L["Death Knight"])
EminentDKP:EnableModule(L["Druid"])
EminentDKP:EnableModule(L["Hunter"])
EminentDKP:EnableModule(L["Mage"])
EminentDKP:EnableModule(L["Paladin"])
EminentDKP:EnableModule(L["Priest"])
EminentDKP:EnableModule(L["Rogue"])
EminentDKP:EnableModule(L["Shaman"])
EminentDKP:EnableModule(L["Warlock"])
EminentDKP:EnableModule(L["Warrior"])

local function item_tooltip(win, id, label, tooltip)
  tooltip:SetHyperlink(label)
end

local function playerUpdate(win, set)
  local nr = 1
	local max = 0
  
	for i, pid in ipairs(set.players) do
	  local player = EminentDKP:GetPlayerByID(pid)
		if player.currentDKP > 0 then
			
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			
			d.id = player.id
			d.label = player.name
			d.value = player.currentDKP
			
			d.valuetext = Skada:FormatValueText(
											Skada:FormatNumber(player.healing), self.metadata.columns.Healing,
											string.format("%02.1f", getHPS(set, player)), self.metadata.columns.HPS,
											string.format("%02.1f%%", player.healing / set.healing * 100), self.metadata.columns.Percent
										)
			d.class = player.class
			
			if player.currentDKP > max then
				max = player.currentDKP
			end
			
			nr = nr + 1
		end
	end
	
	win.metadata.maxvalue = max
end