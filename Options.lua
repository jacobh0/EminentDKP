local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)
local media = LibStub("LibSharedMedia-3.0")

EminentDKP.windowdefaults = {
	name = "EminentDKP",
	
	barmax=10,
	barspacing=0,
	bartexture="BantoBar",
	barfont="Accidental Presidency",
	barfontsize=11,
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
	
	title = {menubutton = true, font="Accidental Presidency", fontsize=11,margin=0, texture="Round", bordertexture="None", borderthickness=2, color = {r=0,g=0,b=0,a=0.6}},
	background = {margin=0, height=150, texture="None", bordertexture="None", borderthickness=0, color = {r=0,g=0,b=0.5,a=0.5}},

	reversegrowth=false,
	modeincombat="",
	returnaftercombat=false,
	
	hidden = false,
	enabletitle = true, 
	enablebackground = false,
	
	set = "current",
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
    },
    windows = { default_window }
  }
}

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