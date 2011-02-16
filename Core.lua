--[[
  Written by Grioja of <Eminent> on Crushridge-US. All rights reserved.
  Modifications may be made freely, however no re-distribution may be made without my express permission.
  
  -- Credits --
  Thanah of <Eminent> on Crushridge-US (for the original mod)
  Ace3 maintainers and contributors (your libraries kick ass)
]]

EminentDKP = LibStub("AceAddon-3.0"):NewAddon("EminentDKP", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
local libCH = LibStub:GetLibrary("LibChatHandler-1.0")
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

VERSION = '2.0.2'
local newest_version = ''
local needs_update = false

local defaults = {
  factionrealm = {
    pools = {
      ["Default"] = {
        players = {},
        playerIDs = {},
        playerCounter = 0,
        events = {},
        eventCounter = 0,
        lastScan = '',
        bounty = {
          size = 1000000,
          available = 1000000
        }
      }
    }
  },
  profile = {
    activepool = "Default",
    raid = {
      disenchanter = "",
      itemRarity = 3,
      expiretime = 30
    }
  }
}

local options = {
  type = "group",
	name = "EminentDKP",
	plugins = {},
  args = {
    d = {
      type = "description",
      name = "DKP used by Eminent of Crushridge-US",
      order = 0,
    },
  	raid = {
  	  type = "group",
  		name = "Raid",
  		order = 1,
      args = {
        disenchanter = {
      		type="input",
      		name="Disenchanter",
      		desc="The name of the designated disenchanter.",
      		get=function() return EminentDKP.db.profile.raid.disenchanter end,
      		set=function(self, val) EminentDKP.db.profile.raid.disenchanter = val end,
      		order=1,
      	},
      	itemrarity = {
      	  type="select",
					name="Item Rarity Threshold",
					desc="The minimum rarity an item must be in order to be auctioned off.",
					values=	{ "Common","Uncommon","Rare","Epic" },
					get=function() return EminentDKP.db.profile.raid.itemRarity end,
					set=function(self, val) EminentDKP.db.profile.raid.itemRarity = val end,
					order=2,
      	},
      	expiretime = {
      	  type="input",
					name="DKP Expiration Time",
					desc="The number of days after a player's last raid that their DKP expires.",
					get=function() return tostring(EminentDKP.db.profile.raid.expiretime) end,
					set=function(self, val) if tonumber(val) > 0 then EminentDKP.db.profile.raid.expiretime = tonumber(val) end end,
					order=3,
      	}
      }
    }
	}

}

libCH:Embed(EminentDKP)

-- todo: convert permission checks into hooks

local officer_cmds = { bounty = true, auction = true, rename = true,
                     reset = true, vanity = true, transfer = true,
                     bid = true }
local ml_cmds = { bid = true, auction = true, transfer = true, rename = true }

local auction_active = false

local recent_loots = {}

local eligible_looters = {}

local events_cache = {}

local lastContainerName = nil

local function GetTodayDateTime()
  local weekday, month, day, year = CalendarGetDate()
  local hour, minutes = GetGameTime()
  return hour .. ":" .. minutes .. " " .. month .. "/" .. day .. "/" .. year
end

local function GetDayNumber(datetime)
  local time, date = strsplit(' ',datetime)
  local month, day, year = strsplit('/',date)
  return ((year-2010)*365.25)+((month-1)*30.4375)+day
end

local function GetDayDifference(date_one,date_two)
  return GetDayNumber(date_one) - GetDayNumber(date_two)
end

local function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

local function numstring(number)
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

-- Setup basic info and get database from saved variables
function EminentDKP:OnInitialize()
  -- DB
	self.db = LibStub("AceDB-3.0"):New("EminentDKPDB", defaults, "Default")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("EminentDKP", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("EminentDKP", "EminentDKP")

	-- Profiles
	LibStub("AceConfig-3.0"):RegisterOptionsTable("EminentDKP-Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
	self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("EminentDKP-Profiles", "Profiles", "EminentDKP")
  
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
  
  if self:GetEventCount() == 0 and Standings then
    GuildRoster()
  end
end

-- DATABASE CONVERSION UPDATE FOR VERSIONS < 2.0.0
function EminentDKP:GUILD_ROSTER_UPDATE()
  if self:GetEventCount() == 0 and Standings then
    if self:AmOfficer() then
      sendchat('Older database found, attempting to convert...',nil,'self')
      classes = {}
      for i = 1, 1000 do
        local name, rank, rankIndex, level, class = GetGuildRosterInfo(i)
        if name == nil then
          break
        elseif Standings[name] then
          classes[name]  = class
        end
      end
  
      for name,data in pairs(Standings) do
        if not classes[name] then
          sendchat('Could not import '..name..' (they do not exist in the guild)',nil,'self')
        else
          sendchat('Importing '..name..'...',nil,'self')
          self:CreateAddPlayerEvent(name,classes[name],data["CurrentDKP"],data["LifetimeDKP"],GetTodayDateTime())
        end
      end
      sendchat('Conversion complete.',nil,'self')
      Standings = nil
    else
      Standings = nil
    end
  end
end

function EminentDKP:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD") -- version broadcast
	self:RegisterChatEvent("CHAT_MSG_WHISPER") -- whisper commands received
	self:RegisterChatEvent("CHAT_MSG_WHISPER_INFORM") -- whispers sent
	self:RegisterEvent("LOOT_OPENED") -- loot listing
	self:RegisterEvent("LOOT_CLOSED") -- auction cancellation
	self:RegisterEvent("PARTY_LOOT_METHOD_CHANGED") -- masterloot change
	self:RegisterEvent("RAID_ROSTER_UPDATE") -- raid member list update
	self:RegisterEvent("PLAYER_REGEN_DISABLED") -- addon announcements
	self:RegisterEvent("GUILD_ROSTER_UPDATE") -- database conversion
	self:RegisterEvent("UNIT_SPELLCAST_SENT") -- loot container tracker
	self:RegisterChatCommand("edkp", "ProcessSlashCmd") -- admin commands
	-- Sync methods
	self:RegisterComm("EminentDKP-Proposal", "ProcessSyncProposal")
	self:RegisterComm("EminentDKP-Fulfill", "ProcessSyncFulfill")
	self:RegisterComm("EminentDKP-Request", "ProcessSyncRequest")
	self:RegisterComm("EminentDKP-Version", "ProcessSyncVersion")
	self:RegisterComm("EminentDKP", "ProcessSyncEvent")
end

function EminentDKP:OnDisable()
end

function EminentDKP:GetVersion()
  return VERSION .. '.' .. self:GetEventCount()
end

function EminentDKP:GetNewestVersion()
  -- todo: reset newest version if our eventcounter increases
  if newest_version ~= '' then
    return newest_version
  end
  return self:GetVersion()
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
    if self.requestCooldown then
      return
    else
      self.requestCooldown = true
      self:ScheduleTimer("ClearRequestCooldown", 10)
    end
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
  if guildRankIndex < 2 then
    return true
  end
  return false
end

function EminentDKP:AmOfficer()
  self.guildName, self.guildRankName, self.guildRankIndex = GetGuildInfo("player")
  return (self.guildRankIndex < 2)
end

function EminentDKP:GetLastScan()
  return self.db.factionrealm.pools[self.db.profile.activepool].lastScan
end

function EminentDKP:GetEvent(eventID)
  return self.db.factionrealm.pools[self.db.profile.activepool].events[eventID]
end

function EminentDKP:GetEventCount()
  return self.db.factionrealm.pools[self.db.profile.activepool].eventCounter
end

-- Return the data for a given player
function EminentDKP:GetPlayer(name)
  local pid = self:GetPlayerID(name)
  if pid then
    return self.db.factionrealm.pools[self.db.profile.activepool].players[pid]
  end
  return nil
end

-- Get a player's ID
function EminentDKP:GetPlayerID(name)
  if self.db.factionrealm.pools[self.db.profile.activepool].playerIDs[name] then
    return self.db.factionrealm.pools[self.db.profile.activepool].playerIDs[name]
  end
  return nil
end

-- Get player name from player ID
function EminentDKP:GetPlayerNameByID(pid)
  for name,id in pairs(self.db.factionrealm.pools[self.db.profile.activepool].playerIDs) do
    if id == pid then
      return name
    end
  end
  return nil
end

-- Check whether or not a player exists in the currently active pool
function EminentDKP:PlayerExistsInPool(player)
  if self:GetPlayerID(player) then
    return true
  end
  return false
end

-- Update a player's last raid day
function EminentDKP:UpdateLastPlayerRaid(pid,datetime)
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].lastRaid = datetime
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].active = true
end

-- Check if a player has a certain amount of DKP
function EminentDKP:PlayerHasDKP(player,amount)
  local pid = self:GetPlayerID(player)
  if self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentDKP >= amount then
    return true
  end
  return false
end

function EminentDKP:GetPlayerPool()
  return self.db.factionrealm.pools[self.db.profile.activepool].players
end

function EminentDKP:GetTotalBounty()
  return self.db.factionrealm.pools[self.db.profile.activepool].bounty.size
end

function EminentDKP:GetAvailableBounty()
  return self.db.factionrealm.pools[self.db.profile.activepool].bounty.available
end

function EminentDKP:GetAvailableBountyPercent()
  return round((self:GetAvailableBounty()/self:GetTotalBounty())*100,2)
end

-- Construct list of players currently in the raid
function EminentDKP:GetCurrentRaidMembers()
  local players = {}
  for spot = 1, 40 do
    local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(spot);
		if name then
		  players[self:GetPlayerID(name)] = self:GetPlayer(name)
		end
  end
  return players
end

-- Construct list of IDs for players currently in the raid
function EminentDKP:GetCurrentRaidMembersIDs()
  local players = {}
  for spot = 1, 40 do
    local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(spot);
		if name then
		  table.insert(players,self:GetPlayerID(name))
		end
  end
  return players
end

---------- START EARNINGS + DEDUCTIONS FUNCTIONS ----------

function EminentDKP:IncreaseAvailableBounty(amount)
  self.db.factionrealm.pools[self.db.profile.activepool].bounty.available = self:GetAvailableBounty() + amount
end

function EminentDKP:DecreaseAvailableBounty(amount)
  self.db.factionrealm.pools[self.db.profile.activepool].bounty.available = self:GetAvailableBounty() - amount
end

function EminentDKP:CreatePlayerVanityDeduction(pid,eventID,amount)
  local vdkp = self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentVanityDKP
  
  -- Set the deduction for the player
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].deductions[eventID] = amount
  
  -- Update current Vanity DKP
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentVanityDKP = vdkp - amount
end

function EminentDKP:CreatePlayerDeduction(pid,eventID,amount)
  local cdkp = self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentDKP
  
  -- Set the deduction for the player
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].deductions[eventID] = amount
  
  -- Update current DKP
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentDKP = cdkp - amount
end

function EminentDKP:CreatePlayerEarning(pid,eventID,amount,earnsVanity)
  local cdkp = self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentDKP
  local vdkp = self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentVanityDKP
  local edkp = self.db.factionrealm.pools[self.db.profile.activepool].players[pid].earnedDKP
  local evdkp = self.db.factionrealm.pools[self.db.profile.activepool].players[pid].earnedVanityDKP
  
  -- Set the earning for the player
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].earnings[eventID] = amount
  
  -- Update current DKP (normal and vanity)
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentDKP = cdkp + amount
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].earnedDKP = edkp + amount
  
  -- Transfers do not earn vanity dkp (for obvious reasons)
  if earnsVanity then
    self.db.factionrealm.pools[self.db.profile.activepool].players[pid].currentVanityDKP = vdkp + amount
    self.db.factionrealm.pools[self.db.profile.activepool].players[pid].earnedVanityDKP = evdkp + amount
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
  self:SyncEvent(self:CreateAddPlayerEvent(name,className,0,0,GetTodayDateTime()))
end

-- Add a player to the active pool
function EminentDKP:CreateAddPlayerEvent(name,className,dkp,vanitydkp,dtime)
  -- Get a new player ID
  local pc = self.db.factionrealm.pools[self.db.profile.activepool].playerCounter
  pc = pc + 1
  self.db.factionrealm.pools[self.db.profile.activepool].playerCounter = pc
  local pid = tostring(pc)
  self.db.factionrealm.pools[self.db.profile.activepool].playerIDs[name] = pid
  
  -- Create the new player data
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid] = { 
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
      self:CreatePlayerDeduction(pid,cid,round((vanitydkp-dkp),2))
    end
    self:DecreaseAvailableBounty(dkp)
  elseif vanitydkp > 0 and vanitydkp <= dkp then
    self:CreatePlayerEarning(pid,cid,dkp,true)
    if vanitydkp < dkp then
      self:CreatePlayerVanityDeduction(pid,cid,round((dkp-vanitydkp),2))
    end
    self:DecreaseAvailableBounty(vanitydkp)
  elseif vanitydkp == 0 and dkp > 0 then
    self:CreatePlayerEarning(pid,cid,dkp,false)
    self:DecreaseAvailableBounty(dkp)
  end
  
  return cid
end

function EminentDKP:CreateBountySyncEvent(players,amount,srcName)
  self:SyncEvent(self:CreateBountyEvent(players,amount,srcName,GetTodayDateTime()))
end

function EminentDKP:CreateBountyEvent(players,amount,srcName,dtime)
  -- Create the event
  local cid = self:CreateEvent(srcName,"bounty","","",implode(',',players),amount,dtime)
  
  -- Modify the bounty pool
  self:DecreaseAvailableBounty(amount)
  
  -- Then create all the necessary earnings for players
  local dividend = round((amount/#(players)),2)
  for i,pid in ipairs(players) do
    self:CreatePlayerEarning(pid,cid,dividend,true)
    self:UpdateLastPlayerRaid(pid,dtime)
  end
  
  return cid
end

function EminentDKP:CreateAuctionSyncEvent(players,to,amount,srcName,srcExtra)
  self:SyncEvent(self:CreateAuctionEvent(players,to,amount,srcName,srcExtra,GetTodayDateTime()))
end

function EminentDKP:CreateAuctionEvent(players,to,amount,srcName,srcExtra,dtime)
  local pid = self:GetPlayerID(to)
  -- Create the event
  local cid = self:CreateEvent(srcName,"auction",srcExtra,pid,implode(',',players),amount,dtime)
  
  -- Then create the necessary deduction for the receiver
  self:CreatePlayerDeduction(pid,cid,amount)
  
  -- Update receiver's last raid
  self:UpdateLastPlayerRaid(pid,dtime)
  
  -- Then create all the necessary earnings for players
  local dividend = round((amount/#(players)),2)
  for i,rpid in ipairs(players) do
    self:CreatePlayerEarning(rpid,cid,dividend,true)
    self:UpdateLastPlayerRaid(rpid,dtime)
  end
  
  return cid
end

function EminentDKP:CreateTransferSyncEvent(from,to,amount)
  self:SyncEvent(self:CreateTransferEvent(from,to,amount,GetTodayDateTime()))
end

function EminentDKP:CreateTransferEvent(from,to,amount,dtime)
  local pfid = self:GetPlayerID(from)
  local ptid = self:GetPlayerID(to)
  
  -- Create the event
  local cid = self:CreateEvent(pfid,"transfer","",ptid,"",amount,dtime)
  
  -- Then create the necessary deduction and earning for both players
  self:CreatePlayerDeduction(pfid,cid,amount)
  self:CreatePlayerEarning(ptid,cid,amount,false)
  
  -- Update sender's last raid
  self:UpdateLastPlayerRaid(pfid,dtime)
  
  return cid
end

function EminentDKP:CreateExpirationSyncEvent(player)
  self:SyncEvent(self:CreateExpirationEvent(player,GetTodayDateTime()))
end

function EminentDKP:CreateExpirationEvent(player,dtime)
  local pid = self:GetPlayerID(player)
  local pdata = self:GetPlayer(player)
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
  self.db.factionrealm.pools[self.db.profile.activepool].players[pid].active = false
  
  return cid
end

function EminentDKP:CreateVanityResetSyncEvent(player)
  self:SyncEvent(self:CreateVanityResetEvent(player,GetTodayDateTime()))
end

function EminentDKP:CreateVanityResetEvent(player,dtime)
  local pid = self:GetPlayerID(player)
  local pdata = self:GetPlayer(player)
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
  self:SyncEvent(self:CreateRenameEvent(from,to,GetTodayDateTime()))
end

function EminentDKP:CreateRenameEvent(from,to,dtime)
  local pfid = self:GetPlayerID(from)
  
  -- Create the event
  local cid = self:CreateEvent(pfid,"rename",from,"","",to,dtime)
  
  self.db.factionrealm.pools[self.db.profile.activepool].playerIDs[to] = pfid
  self.db.factionrealm.pools[self.db.profile.activepool].playerIDs[from] = nil
  
  return cid
end

-- Creates an event and increments the event counter
function EminentDKP:CreateEvent(src,etype,extra,t,b,amount,dtime)
  local c = self.db.factionrealm.pools[self.db.profile.activepool].eventCounter
  c = c + 1
  self.db.factionrealm.pools[self.db.profile.activepool].eventCounter = c
  local cid = tostring(c)
  self.db.factionrealm.pools[self.db.profile.activepool].events[cid] = {
    source = src,
    eventType = etype,
    extraInfo = extra,
    target = t,
    beneficiary = b,
    value = amount,
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
  if self:AmOfficer() and self.amMasterLooter then
    if self:GetLastScan() == '' or GetDayDifference(self:GetLastScan(),GetTodayDateTime()) < 0 then
      sendchat('Performing database scan...', nil, 'self')
      for pid,data in pairs(self.db.factionrealm.pools[self.db.profile.activepool].players) do
        if data.active then
          local days = math.floor(GetDayDifference(GetTodayDateTime(),data.lastRaid))
          if days >= self.db.profile.raid.expiretime then
            -- If deemed inactive then reset their DKP and vanity DKP
            local name = self:GetPlayerNameByID(pid)
            sendchat('The DKP for '..name..' has expired. Bounty has increased by '..numstring(data.currentDKP)..' DKP.', "raid", "preset")
            self:CreateExpirationSyncEvent(name)
          end
        end
      end
      if self:GetAvailableBountyPercent() > 50 then
        sendchat('There is more than 50% of the bounty available, you should distribute some.', nil, 'self')
      end
      sendchat('Current bounty is '..numstring(self:GetAvailableBounty())..' DKP.', "raid", "preset")
      self.db.factionrealm.pools[self.db.profile.activepool].lastScan = GetTodayDateTime()
      self:PrintStandings()
    end
  end
end

-- Keep track of people in the raid
function EminentDKP:RAID_ROSTER_UPDATE()
  -- This only needs to be run by the masterlooter
  if not self:AmOfficer() then return end
  if not self.amMasterLooter then return end
  
  -- Make sure players exist in the pool
  for d = 1, GetNumRaidMembers() do
		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(d)
		if not self:PlayerExistsInPool(name) then
		  self:CreateAddPlayerSyncEvent(name,class)
		end
	end
end

-- Keep track of the loot method
function EminentDKP:PARTY_LOOT_METHOD_CHANGED()
  self.lootMethod, self.masterLooterPartyID, self.masterLooterRaidID = GetLootMethod()
  self.amMasterLooter = (self.lootMethod == 'master' and self.masterLooterPartyID == 0)
  self.masterLooterName = UnitName("raid"..tostring(self.masterLooterRaidID))
end

-- Keep track of the last container we opened
function EminentDKP:UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
  if not self.amMasterLooter then return end
  if spell == "Opening" and unit == "player" then
    lastContainerName = target
  end
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
  if not self:AmOfficer() then return end
  if not self.amMasterLooter then return end
  
  if UnitInRaid("player") then
    -- Query some info about this unit...
    local unitName = lastContainerName
    local guid = 'container'
    if UnitExists("target") then
      unitName = UnitName("target")
      guid = UnitGUID("target")
    end
    if not recent_loots[guid] and GetNumLootItems() > 0 then
      local eligible_items = {}
      local eligible_slots = {}
      for slot = 1, GetNumLootItems() do 
				local lootIcon, lootName, lootQuantity, rarity = GetLootSlotInfo(slot)
				if lootQuantity > 0 and rarity >= self.db.profile.raid.itemRarity then
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
			recent_loots[guid] = { name=unitName, realm=unitRealm, slots=eligible_slots }
    end
  end
end

-- Place a bid on an active auction
function EminentDKP:Bid(amount, from)
  if auction_active then
    if UnitInRaid(from) then
      if eligible_looters[from] then
        local bid = math.floor(tonumber(amount) or 0)
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
    local b = data.currentDKP
    if stat == 'earnedDKP' then
      b = data.earnedDKP
    else
      b = data.currentDKP
    end
		table.insert(a, { n=self:GetPlayerNameByID(id), dkp=b })
	end
  table.sort(a, function(a,b) return a.dkp>b.dkp end)
  return a
end

function EminentDKP:PrintStandings()
  local a = self:GetStandings('currentDKP')
  
  sendchat('Current DKP standings:', "raid", "preset")
  for rank,data in ipairs(a) do
    sendchat(rank..'. '..data.n..' - '..numstring(data.dkp), "raid", "preset")
  end
end

function EminentDKP:WhisperStandings(to)
  local a = self:GetStandings('currentDKP')
  
  sendchat('Current DKP standings:', to, 'whisper')
  for rank,data in ipairs(a) do
    sendchat(rank..'. '..data.n..' - '..numstring(data.dkp), to, 'whisper')
  end
end

function EminentDKP:WhisperLifetime(to)
  local a = self:GetStandings('earnedDKP')
  
  sendchat('Lifetime Earned DKP standings:', to, 'whisper')
  for rank,data in ipairs(a) do
    sendchat(rank..'. '..data.n..' - '..numstring(data.dkp), to, 'whisper')
  end
end

-- Transfer DKP from one player to another
function EminentDKP:WhisperTransfer(amount, to, from)
  if to ~= from then
    if self:PlayerExistsInPool(from) then
      if self:PlayerExistsInPool(to) then
        if not auction_active then
          local dkp = round(tonumber(amount),2)
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
  sendchat('The current bounty is '..numstring(self:GetAvailableBounty())..' DKP.', to, 'whisper')
end

function EminentDKP:WhisperCheck(who, to)
  if self:PlayerExistsInPool(who) then
    local data = self:GetPlayer(who)
    local days =  math.floor(GetDayDifference(GetTodayDateTime(),data.lastRaid))
    sendchat('Player Report for '..who, to, 'whisper')
    sendchat('Current DKP: '..numstring(data.currentDKP), to, 'whisper')
    sendchat('Lifetime DKP: '..numstring(data.earnedDKP), to, 'whisper')
    sendchat('Vanity DKP: '..numstring(data.currentVanityDKP), to, 'whisper')
    sendchat('Last Raid: '..days..' day(s) ago.', to, 'whisper')
  else
    sendchat(who.." does not exist in the DKP pool.", to, 'whisper')
  end
end

------------- START ADMIN FUNCTIONS -------------

function EminentDKP:AdminStartAuction()
  if self.amMasterLooter then
    if GetNumLootItems() > 0 then
      local guid = 'container'
      if UnitExists("target") then
        guid = UnitGUID("target")
      end
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
    			  srcGUID=guid
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
      sendchat('You must be looting to start an auction.', nil, 'self')
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
      if eligible_looters[self.db.profile.raid.disenchanter] then
        looter = self.db.profile.raid.disenchanter
      else
        sendchat(self.db.profile.raid.disenchanter..' was not eligible to receive loot to disenchant.', nil, 'self')
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
      local dividend = round((secondHighestBid/#(players)),2)
      
      self:CreateAuctionSyncEvent(players,looter,secondHighestBid,recent_loots[guid].name,self.bidItem.itemString)
      sendchat(looter..' has won '..GetLootSlotLink(self.bidItem.slotNum)..' for '..secondHighestBid..' DKP!', "raid", "preset")
      sendchat('Each player has received '..dividend..' DKP.', "raid", "preset")
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
      recent_loots[guid] = nil
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
    local p = tonumber(percent) or 0
    if p <= 100 and p > 0 then
      sendchat('Distributing '.. percent ..'% of the bounty to the raid.', nil, 'self')
      
      -- Construct list of players to receive bounty
      local players = self:GetCurrentRaidMembersIDs()
      
      -- todo: solidify the process by which a "reason" is acquired
      local name = UnitName("target")
      if not name then
        if not reason then
          name = "Default"
        else
          name = reason
        end
      end
      local amount = round((self:GetAvailableBounty() * (p/100)),2)
      local dividend = round((amount/#(players)),2)
      
      self:CreateBountySyncEvent(players,amount,name)
      sendchat('A bounty of '..amount..' ('..tostring(p)..'%) has been awarded to '..#(players)..' players.', "raid", "preset")
      sendchat('Each player has received '..dividend..' DKP.', "raid", "preset")
      sendchat('New bounty is '..numstring(self:GetAvailableBounty())..' DKP.', "raid", "preset")
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
  		  local data = self:GetPlayer(name)
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

-- Handle slash commands (currently accepts only admin commands)
function EminentDKP:ProcessSlashCmd(input)
  local command, arg1, arg2, e = self:GetArgs(input, 3)
  
  -- Check if the command can only be used by an officer
  if officer_cmds[command] and not self:AmOfficer() then
    sendchat("This command can only be used by an officer.", nil, 'self')
    return
  end
  
  -- Check if the command can only be used by the masterlooter
  if ml_cmds[command] then
    if self.lootMethod ~= 'master' then
      sendchat("Master looting must be enabled.", nil, 'self')
      return
    end
    if self.masterLooterPartyID ~= 0 then
      sendchat("Only the master looter can use this command.", nil, 'self')
      return
    end
  end
  
  if command == 'auction' then
    self:AdminStartAuction()
  elseif command == 'bounty' then
    self:AdminDistributeBounty(arg1,arg2)
  elseif command == 'reset' then
    self:AdminReset(arg1)
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
	
	-- Check if the command can only be used by the masterlooter
  if ml_cmds[command] then
    if self.lootMethod ~= 'master' then
      sendchat("Master looting must be enabled.", from, 'whisper')
      return
    end
    if self.masterLooterPartyID ~= 0 then
      sendchat("That command must be sent to the master looter.", from, 'whisper')
      return
    end
  end
  
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