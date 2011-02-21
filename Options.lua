local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)
local media = LibStub("LibSharedMedia-3.0")

EminentDKP.windowdefaults = {
	name = "EminentDKP",
	
	barmax=10,
	barspacing=0,
	bartexture="BantoBar",
	barfont="Accidental Presidency",
	barfontsize=14,
	barheight=15,
	barwidth=240,
	barorientation=1,
	barcolor = {r = 0.3, g = 0.3, b = 0.8, a=1},
	baraltcolor = {r = 0.45, g = 0.45, b = 0.8, a = 1},
	barslocked=false,
	clickthrough=false,

	classcolorbars = true,
	classcolortext = false,
	
	spark = true,
	
	title = {menubutton = true, font="Accidental Presidency", fontsize=14,margin=0, texture="Armory", bordertexture="None", borderthickness=2, color = {r=0,g=0,b=0,a=0.6}},
	background = {margin=0, height=150, texture="None", bordertexture="None", borderthickness=0, color = {r=0,g=0,b=0.5,a=0.5}},

	reversegrowth=false,
	
	hidden = false,
	enabletitle = true, 
	enablebackground = false,
	
	set = nil,
	mode = nil,
	
	display = "meter",
}

local default_window = {}
EminentDKP:tcopy(default_window, EminentDKP.windowdefaults)

EminentDKP.defaults = {
  factionrealm = {
    pools = {
      ["Default"] = {
        players = {},
        playerIDs = {},
        playerCounter = 0,
        events = {},
        eventCounter = 0,
        lastScan = 0,
        bounty = {
          size = 1000000,
          available = 1000000
        },
        sets = {},
        revision = 0,
      }
    }
  },
  profile = {
    activepool = "Default",
    disenchanter = "",
    itemrarity = 3,
    expiretime = 30,
    hidesolo = false,
    hidepvp = true,
    hidecombat = true,
    maxevents = 40,
    numberformat = 1,
    showranks = true,
    daystoshow = 14,
    hideraidmessages = true,
    windows = { default_window },
    tooltips = true,
    informativetooltips = true,
    tooltiprows = 3,
    tooltippos = "default",
    columns = {},
  }
}

-- Adds column configuration options for a mode.
function EminentDKP:AddColumnOptions(mode)
	local db = self.db.profile.columns
	
	if mode.metadata and mode.metadata.columns then
    local cols = {
      type= "group",
      name= mode:GetName(),
      inline= true,
      args= {},
      order= 0,
    }
		for colname, value in pairs(mode.metadata.columns) do
			local c = mode:GetName().."_"..colname
			
			-- Set initial value from db if available, otherwise use mod default value.
			if db[c] ~= nil then
				mode.metadata.columns[colname] = db[c]
			end
			
			-- Add column option.
			local col = {
        type= "toggle",
        name= L[colname] or colname,
        get= function() return mode.metadata.columns[colname] end,
        set= function() 
          mode.metadata.columns[colname] = not mode.metadata.columns[colname]
          db[c] = mode.metadata.columns[colname]
          EminentDKP:UpdateDisplay(true)
        end,
			}
			cols.args[c] = col
		end
		EminentDKP.options.args.columns.args[mode:GetName()] = cols
	end
end

local deletewindow = nil

EminentDKP.options = {
  type = "group",
	name = "EminentDKP",
	plugins = {},
  args = {
    d = {
      type = "description",
      name = "DKP used by Eminent of Crushridge-US",
      order = 0,
    },
    windows = {
      type= "group",
      name= L["Windows"],
      order= 0,
      args = {
        create = {
          type= "input",
          name= L["Create window"],
          desc= L["Enter the name for the new window."],
          set= function(self, val)
            if val and val ~= "" and not EminentDKP:GetWindow(val) then
              EminentDKP:CreateWindow(val)
            end
          end,
          order= 1,
        },
        delete = {
          type= "select",
          name= L["Delete window"],
          desc= L["Choose the window to be deleted."],
          values=	function()
            local windows = {}
            for i, win in ipairs(EminentDKP:GetWindows()) do
              windows[win.settings.name] = win.settings.name
            end
            return windows
          end,
          get= function() return deletewindow end,
          set= function(self, val) deletewindow = val end,
          order= 2,
        },
        deleteexecute = {
          type= "execute",
          name= L["Delete window"],
          desc= L["Deletes the chosen window."],
          func= function(self) if deletewindow then EminentDKP:DeleteWindow(deletewindow) end end,
          order= 3,
        },
      },
    },
  	generaloptions = {
  	  type = "group",
  		name = L["General Options"],
  		order = 1,
      args = {
      	hidesolo = {
          type= "toggle",
          name= L["Hide when solo"],
          desc= L["Hides EminentDKP's window when not in a party or raid."],
          get= function() return EminentDKP.db.profile.hidesolo end,
          set= function()
            EminentDKP.db.profile.hidesolo = not EminentDKP.db.profile.hidesolo
            EminentDKP:ApplySettingsAll()
          end,
          order= 4,
				},
				hidepvp = {
          type= "toggle",
          name= L["Hide in PvP"],
          desc= L["Hides EminentDKP's window when in Battlegrounds/Arenas."],
          get= function() return EminentDKP.db.profile.hidepvp end,
          set= function()
            EminentDKP.db.profile.hidepvp = not EminentDKP.db.profile.hidepvp
            EminentDKP:ApplySettingsAll()
          end,
          order= 5,
				},
				hidecombat = {
          type= "toggle",
          name= L["Hide in combat"],
          desc= L["Hides EminentDKP's window when in combat."],
          get= function() return EminentDKP.db.profile.hidecombat end,
          set= function()
            EminentDKP.db.profile.hidecombat = not EminentDKP.db.profile.hidecombat
            EminentDKP:ApplySettingsAll()
          end,
          order= 6,
				},
				showranks = {
          type= "toggle",
          name= L["Show rank numbers"],
          desc= L["Shows numbers for relative ranks for modes where it is applicable."],
          get= function() return EminentDKP.db.profile.showranks end,
          set= function()
            EminentDKP.db.profile.showranks = not EminentDKP.db.profile.showranks
            EminentDKP:ApplySettingsAll()
          end,
          order= 7,
				},
				numberformat = {
          type= "select",
          name= L["Number format"],
          desc= L["Controls the way large numbers are displayed."],
          values=	{ L["Condensed"], L["Detailed"] },
          get= function() return EminentDKP.db.profile.numberformat end,
          set= function(self, opt) EminentDKP.db.profile.numberformat = opt end,
          order= 8,
				},
				daystoshow = {
          type= "range",
          name= L["Days to show"],
          desc= L["The number of days prior to today to show in the day listing."],
          min= 5,
          max= 30,
          step= 1,
          get= function() return EminentDKP.db.profile.daystoshow end,
          set= function(self, val)
            EminentDKP.db.profile.daystoshow = val
            EminentDKP:CancelTimer(EminentDKP.setHistoryTimer, true)
            EminentDKP.setHistoryTimer = EminentDKP:ScheduleTimer("ReloadSets",1,true)
          end,
          order= 9,
				},
				maxevents = {
          type= "range",
          name= L["Maximum Events"],
          desc= L["The maximum number of events to show for a specific player."],
          min= 10,
          max= 60,
          step= 1,
          get= function() return EminentDKP.db.profile.maxevents end,
          set= function(self, val) EminentDKP.db.profile.maxevents = val end,
          order= 10,
				},
				hideraidmessages = {
          type= "toggle",
          name= L["Hide Raid Messages"],
          desc= L["Prevents raid messages sent by EminentDKP from being shown."],
          get= function() return EminentDKP.db.profile.hideraidmessages end,
          set= function()
            EminentDKP.db.profile.hideraidmessages = not EminentDKP.db.profile.hideraidmessages
          end,
          order= 11,
				},
      },
    },
    masterlooter = {
  	  type = "group",
  		name = L["Masterlooter Options"],
  		order = 2,
      args = {
        disenchanter = {
      		type= "input",
      		name= L["Disenchanter"],
      		desc= L["The name of the person who will disenchant."],
      		get= function() return EminentDKP.db.profile.disenchanter end,
      		set= function(self, val) EminentDKP.db.profile.disenchanter = val end,
      		order= 1,
      	},
      	itemrarity = {
      	  type= "select",
					name= L["Auction Threshold"],
					desc= L["The minimum rarity an item must be in order to be auctioned off."],
					values=	{ [2] = "Uncommon", [3] = "Rare", [4] = "Epic" },
					get= function() return EminentDKP.db.profile.itemrarity end,
					set= function(self, val) EminentDKP.db.profile.itemrarity = val end,
					order= 2,
      	},
      	expiretime = {
      	  type= "range",
					name= L["DKP Expiration Time"],
					desc= L["The number of days after a player's last raid that their DKP expires."],
					min= 10,
          max= 60,
          step= 10,
					get= function() return EminentDKP.db.profile.expiretime end,
					set= function(self, val) EminentDKP.db.profile.expiretime = val end,
					order= 3,
      	},
      },
    },
    tooltips = {
      type= "group",
      name= L["Tooltips"],
      order= 3,
      args= {
        tooltips = {
          type= "toggle",
          name= L["Show tooltips"],
          desc= L["Shows tooltips with extra information in some modes."],
          get= function() return EminentDKP.db.profile.tooltips end,
          set= function() EminentDKP.db.profile.tooltips = not EminentDKP.db.profile.tooltips end,
          order= 1,
        },
        informative = {
          type= "toggle",
          name= L["Informative tooltips"],
          desc= L["Shows subview summaries in the tooltips."],
          get= function() return EminentDKP.db.profile.informativetooltips end,
          set= function() EminentDKP.db.profile.informativetooltips = not EminentDKP.db.profile.informativetooltips end,
          order= 2,
        },
        rows = {
          type= "range",
          name= L["Subview rows"],
          desc= L["The number of rows from each subview to show when using informative tooltips."],
          min= 1,
          max= 10,
          step= 1,
          get= function() return EminentDKP.db.profile.tooltiprows end,
          set= function(self, val) EminentDKP.db.profile.tooltiprows = val end,
          order= 3,
        },
        tooltippos = {
          type= "select",
          name= L["Tooltip position"],
          desc= L["Position of the tooltips."],
          values=	{["default"] = L["Default"], ["topright"] = L["Top right"], ["topleft"] = L["Top left"]},
          get= function() return EminentDKP.db.profile.tooltippos end,
          set= function(self, opt) EminentDKP.db.profile.tooltippos = opt end,
          order= 4,
        },
      },
		},
    columns = {
      type= "group",
      name= L["Columns"],
      order= 4,
      args= {},
    },
	}
}