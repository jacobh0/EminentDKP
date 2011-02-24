local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)
local AceGUI = LibStub("AceGUI-3.0")

local EminentDKP = EminentDKP

local meter = EminentDKP:NewModule("MeterDisplay", "SpecializedLibBars-1.0")
local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

-- Our display providers.
EminentDKP.displays = {}

EminentDKP.classColors = RAID_CLASS_COLORS

-- Add to EminentDKP's enormous list of display providers.
meter.name = "Meter display"
EminentDKP.displays["meter"] = meter

--[[-------------------------------------------------------------------
  Meter Window Functions
---------------------------------------------------------------------]]

--[[-------------------------------------------------------------------
  Action Panel Functions
---------------------------------------------------------------------]]

--[[
 Confirmation dialogs:
 
 	StaticPopupDialogs["ResetSkadaDialog"] = {
						text = L["Do you want to reset Skada?"], 
						button1 = ACCEPT, 
						button2 = CANCEL,
						timeout = 30, 
						whileDead = 0, 
						hideOnEscape = 1, 
						OnAccept = function() Skada:Reset() end,
					}
	StaticPopup_Show("ResetSkadaDialog")
]]

-- Show the tab responsible for transfers
local function CreateTransferTab(container)
  local recip = AceGUI:Create("Dropdown")
  recip:SetText("Receipient")
  recip:SetList(EminentDKP:GetOtherPlayersNames())
  container:AddChild(recip)
  
  local amount = AceGUI:Create("Slider")
  amount:SetLabel("Amount")
  amount:SetSliderValues(1,EminentDKP:GetMyCurrentDKP(),1)
  amount:SetValue(1)
  container:AddChild(amount)
  
  local send = AceGUI:Create("Button")
  send:SetText("Send")
  send:SetWidth(200)
  send:SetCallback("OnClick",function(what)
    -- todo: send addon msg to ML (we have the name since we're in a raid)
    EminentDKP:Print(recip:GetValue())
    EminentDKP:Print(amount:GetValue())
  end)
  container:AddChild(send)
end

local function CreateVanityTab(container)
  local resetgrp = AceGUI:Create("InlineGroup")
  resetgrp:SetTitle("Reset Player Vanity DKP")
  resetgrp:SetLayout("Flow")
  resetgrp:SetWidth(200)
  
  local who = AceGUI:Create("Dropdown")
  who:SetText("Player")
  who:SetList(EminentDKP:GetPlayerNames())
  who:SetWidth(150)
  resetgrp:AddChild(who)
  
  local reset = AceGUI:Create("Button")
  reset:SetText("Reset")
  reset:SetWidth(150)
  reset:SetCallback("OnClick",function(what)
    -- todo: hookup functionality
    EminentDKP:Print(who:GetValue())
  end)
  resetgrp:AddChild(reset)
  container:AddChild(resetgrp)
  
  local rollgrp = AceGUI:Create("InlineGroup")
  rollgrp:SetTitle("Vanity DKP Roll")
  rollgrp:SetLayout("Flow")
  
  local roll = AceGUI:Create("Button")
  roll:SetText("Roll")
  roll:SetWidth(150)
  roll:SetCallback("OnClick",function(what)
    -- todo: hookup functionality
  end)
  rollgrp:AddChild(roll)
  container:AddChild(rollgrp)
end

local function CreateRenameTab(container)
  local renamegrp = AceGUI:Create("InlineGroup")
  renamegrp:SetTitle("Rename Player")
  renamegrp:SetLayout("Flow")
  renamegrp:SetWidth(200)
  
  local newname = AceGUI:Create("Dropdown")
  newname:SetLabel("New Name")
  newname:SetWidth(150)
  
  local who = AceGUI:Create("Dropdown")
  who:SetLabel("Player")
  who:SetList(EminentDKP:GetPlayerNames())
  who:SetCallback("OnValueChanged",function(data)
    newname:SetText("")
    newname:SetList(EminentDKP:GetPlayersOfClass(data.value))
  end)
  who:SetWidth(150)
  renamegrp:AddChild(who)
  renamegrp:AddChild(newname)
  
  local rename = AceGUI:Create("Button")
  rename:SetText("Rename")
  rename:SetWidth(150)
  rename:SetCallback("OnClick",function(what)
    -- todo: hookup functionality
    EminentDKP:AdminRename(who:GetValue(),newname:GetValue())
  end)
  renamegrp:AddChild(rename)
  
  container:AddChild(renamegrp)
end

-- Callback function for OnGroupSelected
local function SelectGroup(container, event, group)
  container:ReleaseChildren()
  if group == "transfer" then
    CreateTransferTab(container)
  elseif group == "vanity" then
    CreateVanityTab(container)
  elseif group == "rename" then
    CreateRenameTab(container)
  elseif group == "bounty" then
    CreateBountyTab(container)
  end
  EminentDKP.actionpanel:SetStatusText("")
end

function EminentDKP:CreateActionPanel()
  if self.actionpanel then
    AceGUI:Release(self.actionpanel)
    self.actionpanel = nil
  end
  self.actionpanel = AceGUI:Create("EminentDKPFrame")
  self.actionpanel:SetWidth(450)
  self.actionpanel:SetHeight(400)
  self.actionpanel:SetTitle("EminentDKP Action Panel")
  self.actionpanel:SetCallback("OnClose", function(widget)
    AceGUI:Release(widget)
    EminentDKP.actionpanel = nil
  end)
  self.actionpanel:SetLayout("Fill")
  
  -- Create the TabGroup
  local tab =  AceGUI:Create("TabGroup")
  tab:SetLayout("Flow")
  -- Setup which tabs to show
  tab:SetTabs({
    {text="Transfer", value="transfer"},
    {text="Vanity", value="vanity"},
    {text="Rename", value="rename"}
  })
  -- Register callback
  tab:SetCallback("OnGroupSelected", SelectGroup)
  -- Set initial Tab (this will fire the OnGroupSelected callback)
  tab:SelectTab("transfer")

  -- add to the frame container
  self.actionpanel:AddChild(tab)
end


--[[-------------------------------------------------------------------
  Display functions for the meter listing
---------------------------------------------------------------------]]

-- Called when a EminentDKP window starts using this display provider.
function meter:Create(window)
  -- Re-use bargroup if it exists.
	window.bargroup = meter:GetBarGroup(window.settings.name)
	
	-- Save a reference to window in bar group. Needed for some nasty callbacks.
	if window.bargroup then
		-- Clear callbacks.
		window.bargroup.callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(window.bargroup)
	else
		window.bargroup = meter:NewBarGroup(window.settings.name, nil, window.settings.barwidth, window.settings.barheight, "EminentDKPWindow"..window.settings.name)
	end
	window.bargroup.window = window
	window.bargroup.RegisterCallback(meter, "AnchorMoved")
	window.bargroup.RegisterCallback(meter, "AnchorClicked")
	window.bargroup.RegisterCallback(meter, "ConfigClicked")
	window.bargroup:EnableMouse(true)
	window.bargroup:SetScript("OnMouseDown", function(win, button) if button == "RightButton" then win:RightClick() end end)
	window.bargroup:HideIcon()
	
	-- Register with LibWindow-1.1
	libwindow.RegisterConfig(window.bargroup, window.settings)
	
	-- Restore window position.
	libwindow.RestorePosition(window.bargroup)
end

-- Called by EminentDKP windows when the window is to be destroyed/cleared.
function meter:Destroy(window)
	window.bargroup:Hide()
	window.bargroup.bgframe = nil
	window.bargroup = nil
end

-- Called by EminentDKP windows when the window is to be completely cleared and prepared for new data.
function meter:Wipe(window)
	-- Reset sort function.
	window.bargroup:SetSortFunction(nil)
	
	-- Reset scroll offset.
	window.bargroup:SetBarOffset(0)
	
	-- Remove the bars.
	local bars = window.bargroup:GetBars()
	if bars then
		for i, bar in pairs(bars) do
			bar:Hide()
			window.bargroup:RemoveBar(bar)
		end
	end
	
	-- Clean up.
	window.bargroup:SortBars()
end

function meter:ConfigClicked(cbk, group, button)
	EminentDKP:CreateActionPanel()
end

function meter:AnchorClicked(cbk, group, button)
	if IsShiftKeyDown() then
		--EminentDKP:OpenMenu(group.win)
	elseif button == "RightButton" then
		group.window:RightClick()
	end
end

function meter:AnchorMoved(cbk, group, x, y)
	libwindow.SavePosition(group)
end

function meter:Show(window)
	window.bargroup:Show()
	window.bargroup:SortBars()
end

function meter:Hide(window)
	window.bargroup:Hide()
end

function meter:IsShown(window)
	return window.bargroup:IsShown()
end

local titlebackdrop = {}
local windowbackdrop = {}

function meter:ApplySettings(window)
	local g = window.bargroup
	local p = window.settings
	g:ReverseGrowth(p.reversegrowth)
	g:SetOrientation(p.barorientation)
	g:SetHeight(p.barheight)
	g:SetWidth(p.barwidth)
	g:SetTexture(media:Fetch('statusbar', p.bartexture))
	g:SetFont(media:Fetch('font', p.barfont), p.barfontsize)
	g:SetSpacing(p.barspacing)
	g:UnsetAllColors()
	g:SetColorAt(0,p.barcolor.r,p.barcolor.g,p.barcolor.b, p.barcolor.a)
	g:SetMaxBars(p.barmax)
	if p.barslocked then
		g:Lock()
	else
		g:Unlock()
	end

	-- Header
	local fo = CreateFont("TitleFont"..p.name)
	fo:SetFont(media:Fetch('font', p.title.font), p.title.fontsize)
	g.button:SetNormalFontObject(fo)
	local inset = p.title.margin
	titlebackdrop.bgFile = media:Fetch("statusbar", p.title.texture)
	if p.title.borderthickness > 0 then
		titlebackdrop.edgeFile = media:Fetch("border", p.title.bordertexture)
	else
		titlebackdrop.edgeFile = nil
	end
	titlebackdrop.tile = false
	titlebackdrop.tileSize = 0
	titlebackdrop.edgeSize = p.title.borderthickness
	titlebackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
	g.button:SetBackdrop(titlebackdrop)
	local color = p.title.color
	g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
	
	if p.enabletitle then
		g:ShowAnchor()
	else
		g:HideAnchor()
	end
	
	-- Spark.
	if g:HasAnyBar() then
  	for i, bar in pairs(g:GetBars()) do
  		if p.spark then
  			bar.spark:Show()
  		else
  			bar.spark:Hide()
  		end
  	end
  end
	
	-- Header config button
	g.optbutton:ClearAllPoints()
	g.optbutton:SetPoint("TOPRIGHT", g.button, "TOPRIGHT", -5, 0 - (math.max(g.button:GetHeight() - g.optbutton:GetHeight(), 1) / 2))
	
	-- Menu button - default on.
	if p.title.menubutton == nil or p.title.menubutton then
		g.optbutton:Show()
	else
		g.optbutton:Hide()
	end
	
	-- Window
	if p.enablebackground then
		if g.bgframe == nil then
			g.bgframe = CreateFrame("Frame", p.name.."BG", g)
			g.bgframe:SetFrameStrata("BACKGROUND")
			g.bgframe:EnableMouse()
			g.bgframe:EnableMouseWheel()
			g.bgframe:SetScript("OnMouseDown", function(frame, btn) if btn == "RightButton" then window:RightClick() end end)
			g.bgframe:SetScript("OnMouseWheel", window.OnMouseWheel)
		end

		local inset = p.background.margin
		windowbackdrop.bgFile = media:Fetch("background", p.background.texture)
		if p.background.borderthickness > 0 then
			windowbackdrop.edgeFile = media:Fetch("border", p.background.bordertexture)
		else
			windowbackdrop.edgeFile = nil
		end
		windowbackdrop.tile = false
		windowbackdrop.tileSize = 0
		windowbackdrop.edgeSize = p.background.borderthickness
		windowbackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
		g.bgframe:SetBackdrop(windowbackdrop)
		local color = p.background.color
		g.bgframe:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
		g.bgframe:SetWidth(g:GetWidth() + (p.background.borderthickness * 2))
		g.bgframe:SetHeight(p.background.height)

		g.bgframe:ClearAllPoints()
		if p.reversegrowth then
			g.bgframe:SetPoint("LEFT", g.button, "LEFT", -p.background.borderthickness, 0)
			g.bgframe:SetPoint("RIGHT", g.button, "RIGHT", p.background.borderthickness, 0)
			g.bgframe:SetPoint("BOTTOM", g.button, "TOP", 0, 0)
		else
			g.bgframe:SetPoint("LEFT", g.button, "LEFT", -p.background.borderthickness, 0)
			g.bgframe:SetPoint("RIGHT", g.button, "RIGHT", p.background.borderthickness, 0)
			g.bgframe:SetPoint("TOP", g.button, "BOTTOM", 0, 5)
		end
		g.bgframe:Show()
		
		-- Calculate max number of bars to show if our height is not dynamic.
		if p.background.height > 0 then
			local maxbars = math.floor(p.background.height / math.max(1, p.barheight + p.barspacing))
			g:SetMaxBars(maxbars)
		else
			-- Adjust background height according to current bars.
			self:AdjustBackgroundHeight(window)
		end
		
	elseif g.bgframe then
		g.bgframe:Hide()
	end
	
	-- Clickthrough
	g:EnableMouse(not p.clickthrough)
	if g:HasAnyBar() then
  	for i, bar in pairs(g:GetBars()) do
  		bar:EnableMouse(not p.clickthrough)
  	end
	end
	
	g:SortBars()
end

local function showmode(win, id, label, mode)
	-- Add current mode to window traversal history.
	if win.selectedmode then
		tinsert(win.history, win.selectedmode)
	end
	-- Call the Enter function on the mode.
	if mode.Enter then
		mode:Enter(win, id, label)
	end
	-- Display mode.
	win:DisplayMode(mode)
end

local function BarClick(win, id, label, button)
	local click1 = win.metadata.click1
	local click2 = win.metadata.click2
	local click3 = win.metadata.click3
	
	if button == "RightButton" and IsShiftKeyDown() then
		--EminentDKP:OpenMenu(win)
	elseif button == "RightButton" then
		win:RightClick()
	elseif win.metadata.click then
		win.metadata.click(win, id, label, button)
	elseif click2 and IsShiftKeyDown() then
		showmode(win, id, label, click2)
	elseif click3 and IsControlKeyDown() then
		showmode(win, id, label, click3)
	elseif click1 then
		showmode(win, id, label, click1)
	end
end

local ttactive = false

local function BarEnter(win, id, label)
	local t = GameTooltip
	if EminentDKP.db.profile.tooltips and (win.metadata.click1 or win.metadata.click2 or win.metadata.click3 or win.metadata.tooltip) then
		ttactive = true
		EminentDKP:SetTooltipPosition(t, win.bargroup)
	  t:ClearLines()
	    
	    -- Current mode's own tooltips.
		if win.metadata.tooltip then
			win.metadata.tooltip(win, id, label, t)
			
			-- Spacer
			if win.metadata.click1 or win.metadata.click2 or win.metadata.click3 then
				t:AddLine(" ")
			end
		end
		
		-- Generic informative tooltips.
		if EminentDKP.db.profile.informativetooltips then
			if win.metadata.click1 then
				EminentDKP:AddSubviewToTooltip(t, win, win.metadata.click1, id, label)
			end
			if win.metadata.click2 then
				EminentDKP:AddSubviewToTooltip(t, win, win.metadata.click2, id, label)
			end
			if win.metadata.click3 then
				EminentDKP:AddSubviewToTooltip(t, win, win.metadata.click3, id, label)
			end
		end
	  
		-- Click directions.
		if win.metadata.click1 then
			t:AddLine(L["Click for"].." "..win.metadata.click1:GetName()..".", 0.2, 1, 0.2)
		end
		if win.metadata.click2 then
			t:AddLine(L["Shift-Click for"].." "..win.metadata.click2:GetName()..".", 0.2, 1, 0.2)
		end
		if win.metadata.click3 then
			t:AddLine(L["Control-Click for"].." "..win.metadata.click3:GetName()..".", 0.2, 1, 0.2)
		end
		t:Show()
	end
end

local function BarLeave(win, id, label)
	if ttactive then
		GameTooltip:Hide()
		ttactive = false
	end
end

local function getNumberOfBars(window)
	local bars = window.bargroup:GetBars()
	local n = 0
	for i, bar in pairs(bars) do n = n + 1 end
	return n
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

local function bar_order_sort(a,b)
	return a and b and a.order and b.order and a.order < b.order
end

local function bar_order_reverse_sort(a,b)
	return a and b and a.order and b.order and a.order < b.order
end

-- Called by EminentDKP windows when the display should be updated to match the dataset.
function meter:Update(window)
	-- Set title.
	window.bargroup.button:SetText(window.metadata.title)

	-- Sort if we are showing spots with "showspots".
	if window.metadata.showspots then
		table.sort(window.dataset, value_sort)
	end
	if window.metadata.sortfunc then
	  table.sort(window.dataset, window.metadata.sortfunc)
  end
  
	for i, data in ipairs(window.dataset) do
		if data.id then
			local barid = data.id
			local barlabel = data.label
			
			local bar = window.bargroup:GetBar(barid)
			
			if bar then
				bar:SetMaxValue(window.metadata.maxvalue or 1)
				bar:SetValue(data.value)
			else
				-- Initialization of bars.
				bar = meter:CreateBar(window, barid, barlabel, data.value, window.metadata.maxvalue or 1, data.icon, false)
				if data.icon then
					bar:ShowIcon()
				end
				bar:EnableMouse()
				bar.id = data.id
				bar:SetScript("OnEnter", function(bar) BarEnter(window, barid, barlabel) end)
				bar:SetScript("OnLeave", function(bar) BarLeave(window, barid, barlabel) end)
				bar:SetScript("OnMouseDown", function(bar, button) BarClick(window, barid, barlabel, button) end)
				
				-- Spark.
				if window.settings.spark then
					bar.spark:Show()
				else
					bar.spark:Hide()
				end
						
				if data.color then
					-- Explicit color from dataset.
					bar:SetColorAt(0, data.color.r, data.color.g, data.color.b, data.color.a or 1)
				elseif data.class and window.settings.classcolorbars then
					-- Class color.
					local color = EminentDKP.classColors[data.class]
					if color then
						bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
					end
				else
					-- Default color.
					local color = window.settings.barcolor
					bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
				end
				
				if data.class and window.settings.classcolortext then
					-- Class color text.
					local color = EminentDKP.classColors[data.class]
					if color then
						bar.label:SetTextColor(color.r, color.g, color.b, color.a or 1)
						bar.timerLabel:SetTextColor(color.r, color.g, color.b, color.a or 1)
					end
				else
					-- Default color text.
					bar.label:SetTextColor(1,1,1,1)
					bar.timerLabel:SetTextColor(1,1,1,1)
				end
			end
			
			if window.metadata.ordersort then
				bar.order = i
			end
			
			if window.metadata.showspots and EminentDKP.db.profile.showranks then
				bar:SetLabel(("%2u. %s"):format(i, data.label))
			else
				bar:SetLabel(data.label)
			end
			bar:SetTimerLabel(data.valuetext)
			
			-- Background texture color.
			if data.backgroundcolor then
				bar.bgtexture:SetVertexColor(data.backgroundcolor.r, data.backgroundcolor.g, data.backgroundcolor.b, data.backgroundcolor.a or 1)
			end
			
			-- Background texture size (in percent, as the mode has no idea on actual widths).
			if data.backgroundwidth then
				bar.bgtexture:ClearAllPoints()
				bar.bgtexture:SetPoint("BOTTOMLEFT")
				bar.bgtexture:SetPoint("TOPLEFT")
				bar.bgtexture:SetWidth(data.backgroundwidth * bar:GetLength())
			end
		end
	end
	
	-- Adjust our background frame if background height is dynamic.
	if window.bargroup.bgframe and window.settings.background.height == 0 then
		self:AdjustBackgroundHeight(window)
	end

	-- Sort by the order in the data table if we are using "ordersort".
	if window.metadata.ordersort then
		if window.settings.reversegrowth then
			window.bargroup:SetSortFunction(bar_order_reverse_sort)
		else
			window.bargroup:SetSortFunction(bar_order_sort)
		end
		window.bargroup:SortBars()
	else
		window.bargroup:SetSortFunction(nil)
	  window.bargroup:SortBars()
	end
end

function meter:AdjustBackgroundHeight(window)
	local numbars = 0
	if window.bargroup:GetBars() ~= nil then
		for name, bar in pairs(window.bargroup:GetBars()) do if bar:IsShown() then numbars = numbars + 1 end end
		local height = numbars * (window.settings.barheight + window.settings.barspacing) + window.settings.background.borderthickness
		if window.bargroup.bgframe:GetHeight() ~= height then
			window.bargroup.bgframe:SetHeight(height)
		end
	end
end

function meter:OnMouseWheel(window, frame, direction)
	if direction == 1 and window.bargroup:GetBarOffset() > 0 then
		window.bargroup:SetBarOffset(window.bargroup:GetBarOffset() - 1)
	elseif direction == -1 and ((getNumberOfBars(window) - window.bargroup:GetMaxBars() - window.bargroup:GetBarOffset()) > 0) then
		window.bargroup:SetBarOffset(window.bargroup:GetBarOffset() + 1)
	end
end

function meter:CreateBar(window, name, label, value, maxvalue, icon, o)
	local bar = window.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(f, d) meter:OnMouseWheel(window, f, d) end)
	return bar
end

function meter:AddDisplayOptions(win, options)
	local db = win.settings

	options.baroptions = {
		type = "group",
		name = L["Bars"],
		order=1,
		args = {
      barfont = {
        type = 'select',
        dialogControl = 'LSM30_Font',
        name = L["Bar font"],
        desc = L["The font used by all bars."],
        values = AceGUIWidgetLSMlists.font,
        get = function() return db.barfont end,
        set = function(win,key)
      		db.barfont = key
      		EminentDKP:ApplySettings(win[2])
        end,
        order=10,
      },
			barfontsize = {
				type="range",
				name=L["Bar font size"],
				desc=L["The font size of all bars."],
				min=7,
				max=40,
				step=1,
				get= function() return db.barfontsize end,
				set= function(win, size)
          db.barfontsize = size
          EminentDKP:ApplySettings(win[2])
        end,
				order=11,
			},
	    bartexture = {
        type = 'select',
        dialogControl = 'LSM30_Statusbar',
        name = L["Bar texture"],
        desc = L["The texture used by all bars."],
        values = AceGUIWidgetLSMlists.statusbar,
        get = function() return db.bartexture end,
        set = function(win,key)
          db.bartexture = key
          EminentDKP:ApplySettings(win[2])
        end,
        order=12,
	    },
			barspacing = {
        type="range",
        name=L["Bar spacing"],
        desc=L["Distance between bars."],
        min=0,
        max=10,
        step=1,
        get=function() return db.barspacing end,
        set=function(win, spacing)
          db.barspacing = spacing
          EminentDKP:ApplySettings(win[2])
        end,
        order=13,
			},
			barheight = {
        type="range",
        name=L["Bar height"],
        desc=L["The height of the bars."],
        min=10,
        max=40,
        step=1,
        get=function() return db.barheight end,
        set=function(win, height)
          db.barheight = height
          EminentDKP:ApplySettings(win[2])
        end,
        order=14,
			},
			barwidth = {
        type="range",
        name=L["Bar width"],
        desc=L["The width of the bars."],
        min=80,
        max=400,
        step=1,
        get=function() return db.barwidth end,
        set=function(win, width)
          db.barwidth = width
          EminentDKP:ApplySettings(win[2])
        end,
        order=15,
			},
			barmax = {
        type="range",
        name=L["Max bars"],
        desc=L["The maximum number of bars shown."],
        min=0,
        max=100,
        step=1,
        get=function() return db.barmax end,
        set=function(win, max)
          db.barmax = max
          EminentDKP:ApplySettings(win[2])
        end,
        order=16,
			},
			barorientation = {
        type="select",
        name=L["Bar orientation"],
        desc=L["The direction the bars are drawn in."],
        values=	function() return {[1] = L["Left to right"], [3] = L["Right to left"]} end,
        get=function() return db.barorientation end,
        set=function(win, orientation)
          db.barorientation = orientation
          EminentDKP:ApplySettings(win[2])
        end,
        order=17,
			},
			reversegrowth = {
        type="toggle",
        name=L["Reverse bar growth"],
        desc=L["Bars will grow up instead of down."],
        get=function() return db.reversegrowth end,
        set=function(win) 
          db.reversegrowth = not db.reversegrowth
          EminentDKP:ApplySettings(win[2])
        end,
        order=18,
			},
			color = {
        type="color",
        name=L["Bar color"],
        desc=L["Choose the default color of the bars."],
        hasAlpha=true,
        get=function(i) 
          local c = db.barcolor
          return c.r, c.g, c.b, c.a
        end,
        set=function(win, r,g,b,a) 
          db.barcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
          EminentDKP:ApplySettings(win[2])
        end,
        order=19,
			},
			altcolor = {
        type="color",
        name=L["Alternate color"],
        desc=L["Choose the alternate color of the bars."],
        hasAlpha=true,
        get=function(i) 
          local c = db.baraltcolor
          return c.r, c.g, c.b, c.a
        end,
        set=function(win, r,g,b,a) 
          db.baraltcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
          EminentDKP:ApplySettings(win[2])
        end,
        order=20,
			},
			classcolorbars = {
        type="toggle",
        name=L["Class color bars"],
        desc=L["When possible, bars will be colored according to player class."],
        get=function() return db.classcolorbars end,
        set=function(win) 
          db.classcolorbars = not db.classcolorbars
          EminentDKP:ApplySettings(win[2])
        end,
        order=21,
			},
			classcolortext = {
        type="toggle",
        name=L["Class color text"],
        desc=L["When possible, bar text will be colored according to player class."],
        get=function() return db.classcolortext end,
        set=function(win) 
          db.classcolortext = not db.classcolortext
          EminentDKP:ApplySettings(win[2])
        end,
        order=22,
			},
			spark = {
        type="toggle",
        name=L["Show spark effect"],
        get=function() return db.spark end,
        set=function(win) 
          db.spark = not db.spark
          EminentDKP:ApplySettings(win[2])
        end,
        order=23,
			},
			clickthrough = {
        type="toggle",
        name=L["Clickthrough"],
        desc=L["Disables mouse clicks on bars."],
        order=20,
        get=function() return db.clickthrough end,
        set=function(win) 
          db.clickthrough = not db.clickthrough
          EminentDKP:ApplySettings(win[2])
        end,
			},
		}
	}
   	
  options.titleoptions = {
    type = "group",
    name = L["Title bar"],
    order=2,
    args = {
      enable = {
        type="toggle",
        name=L["Enable"],
        desc=L["Enables the title bar."],
        get=function() return db.enabletitle end,
        set=function(win) 
          db.enabletitle = not db.enabletitle
          EminentDKP:ApplySettings(win[2])
        end,
        order=0,
      },
      font = {
        type = 'select',
        dialogControl = 'LSM30_Font',
        name = L["Bar font"],
        desc = L["The font used by all bars."],
        values = AceGUIWidgetLSMlists.font,
        get = function() return db.title.font end,
        set = function(win,key) 
          db.title.font = key
          EminentDKP:ApplySettings(win[2])
        end,
        order=1,
      },
        fontsize = {
        type="range",
        name=L["Bar font size"],
        desc=L["The font size of all bars."],
        min=7,
        max=40,
        step=1,
        get=function() return db.title.fontsize end,
        set=function(win, size)
          db.title.fontsize = size
          EminentDKP:ApplySettings(win[2])
        end,
        order=2,
      },
      texture = {
        type = 'select',
        dialogControl = 'LSM30_Statusbar',
        name = L["Background texture"],
        desc = L["The texture used as the background of the title."],
        values = AceGUIWidgetLSMlists.statusbar,
        get = function() return db.title.texture end,
        set = function(win,key)
          db.title.texture = key
          EminentDKP:ApplySettings(win[2])
        end,
        order=3,
      },						    
        bordertexture = {
        type = 'select',
        dialogControl = 'LSM30_Border',
        name = L["Border texture"],
        desc = L["The texture used for the border of the title."],
        values = AceGUIWidgetLSMlists.border,
        get = function() return db.title.bordertexture end,
        set = function(win,key)
          db.title.bordertexture = key
          EminentDKP:ApplySettings(win[2])
        end,
        order=4,
      },
      thickness = {
        type="range",
        name=L["Border thickness"],
        desc=L["The thickness of the borders."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.title.borderthickness end,
        set=function(win, val)
          db.title.borderthickness = val
          EminentDKP:ApplySettings(win[2])
        end,
        order=5,
      },
      margin = {
        type="range",
        name=L["Margin"],
        desc=L["The margin between the outer edge and the background texture."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.title.margin end,
        set=function(win, val)
          db.title.margin = val
          EminentDKP:ApplySettings(win[2])
        end,
        order=6,
      },
      color = {
        type="color",
        name=L["Background color"],
        desc=L["The background color of the title."],
        hasAlpha=true,
        get=function(i) 
          local c = db.title.color
          return c.r, c.g, c.b, c.a
        end,
        set=function(win, r,g,b,a) 
          db.title.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
          EminentDKP:ApplySettings(win[2])
        end,
        order=7,
      },
      menubutton = {
        type="toggle",
        name=L["Show menu button"],
        desc=L["Shows a button for opening the menu in the window title bar."],
        get=function() return db.title.menubutton == nil or db.title.menubutton end,
        set=function(win)
          db.title.menubutton = not db.title.menubutton
          EminentDKP:ApplySettings(win[2])
        end,
        order=8,
      },
    }
  }
  
	options.windowoptions = {
    type = "group",
    name = L["Background"],
    order=2,
    args = {
      enablebackground = {
        type="toggle",
        name=L["Enable"],
        desc=L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."],
        get=function() return db.enablebackground end,
        set=function(win) 
          db.enablebackground = not db.enablebackground
          EminentDKP:ApplySettings(win[2])
        end,
        order=0,
      },
      texture = {
        type = 'select',
        dialogControl = 'LSM30_Background',
        name = L["Background texture"],
        desc = L["The texture used as the background."],
        values = AceGUIWidgetLSMlists.background,
        get = function() return db.background.texture end,
        set = function(win,key)
          db.background.texture = key
          EminentDKP:ApplySettings(win[2])
        end,
        order=1,
      },
      bordertexture = {
        type = 'select',
        dialogControl = 'LSM30_Border',
        name = L["Border texture"],
        desc = L["The texture used for the borders."],
        values = AceGUIWidgetLSMlists.border,
        get = function() return db.background.bordertexture end,
        set = function(win,key)
          db.background.bordertexture = key
          EminentDKP:ApplySettings(win[2])
        end,
        order=2,
      },
      thickness = {
        type="range",
        name=L["Border thickness"],
        desc=L["The thickness of the borders."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.background.borderthickness end,
        set=function(win, val)
          db.background.borderthickness = val
          EminentDKP:ApplySettings(win[2])
        end,
        order=3,
      },
      margin = {
        type="range",
        name=L["Margin"],
        desc=L["The margin between the outer edge and the background texture."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.background.margin end,
        set=function(win, val)
          db.background.margin = val
          EminentDKP:ApplySettings(win[2])
        end,
        order=4,
      },
      height = {
        type="range",
        name=L["Window height"],
        desc=L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."],
        min=0,
        max=600,
        step=1,
        get=function() return db.background.height end,
        set=function(win, height)
          db.background.height = height
          EminentDKP:ApplySettings(win[2])
        end,
        order=5,
      },
      color = {
        type="color",
        name=L["Background color"],
        desc=L["The color of the background."],
        hasAlpha=true,
        get=function(i) 
          local c = db.background.color
          return c.r, c.g, c.b, c.a
        end,
        set=function(win, r,g,b,a)
          db.background.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
          EminentDKP:ApplySettings(win[2])
        end,
        order=6,
      },
    }
	}
end