local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)

local EminentDKP = EminentDKP

local meter = EminentDKP:NewModule("MeterDisplay", "SpecializedLibBars-1.0")
local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

-- The today set
EminentDKP.todaySet = nil

-- The alltime set
EminentDKP.alltimeSet = nil

-- The last set
EminentDKP.lastSet = nil

-- Our display providers.
EminentDKP.displays = {}

EminentDKP.classColors = RAID_CLASS_COLORS

-- Add to EminentDKP's enormous list of display providers.
meter.name = "Meter display"
EminentDKP.displays["meter"] = meter

--[[
  Display functions for the meter listing
--]]

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
	--window.bargroup.RegisterCallback(meter, "ConfigClicked")
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
	for i, bar in pairs(g:GetBars()) do
		if p.spark then
			bar.spark:Show()
		else
			bar.spark:Hide()
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
			g.bgframe:SetScript("OnMouseDown", function(frame, btn) 
													if IsShiftKeyDown() then
														--EminentDKP:OpenMenu(win)
													elseif btn == "RightButton" then 
														window:RightClick()
													end
												end)
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
	for i, bar in pairs(g:GetBars()) do
		bar:EnableMouse(not p.clickthrough)
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
		EminentDKP:OpenMenu(win)
	elseif win.metadata.click then
		win.metadata.click(win, id, label, button)
	elseif button == "RightButton" then
		win:RightClick()
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
  --[[
	if ttactive then
		GameTooltip:Hide()
		ttactive = false
	end
	]]
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

	-- If we are using "wipestale", we may have removed data
	-- and we need to remove unused bars.
	-- The Threat module uses this.
	-- For each bar, mark bar as unchecked.
	if window.metadata.wipestale then
		local bars = window.bargroup:GetBars()
		if bars then
			for name, bar in pairs(bars) do
				bar.checked = false
			end
		end
	end

	local nr = 1
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
				bar:SetLabel(("%2u. %s"):format(nr, data.label))
			else
				bar:SetLabel(data.label)
			end
			bar:SetTimerLabel(data.valuetext)
			
			if window.metadata.wipestale then
				bar.checked = true
			end
	
			-- Emphathized items - cache a flag saying it is done so it is not done again.
			-- This is a little lame.
			if data.emphathize and bar.emphathize_set ~= true then
				bar:SetFont(nil,nil,"OUTLINE")
				bar.emphathize_set = true
			elseif not data.emphathize and bar.emphathize_set ~= false then
				bar:SetFont(nil,nil,"PLAIN")
				bar.emphathize_set = false
			end
			
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
						
			nr = nr + 1
		end
	end
	
	-- If we are using "wipestale", remove all unchecked bars.
	if window.metadata.wipestale then
		local bars = window.bargroup:GetBars()
		for name, bar in pairs(bars) do
			if not bar.checked then
				window.bargroup:RemoveBar(bar)
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
	elseif direction == -1 and ((getNumberOfBars(win) - window.bargroup:GetMaxBars() - window.bargroup:GetBarOffset()) > 0) then
		window.bargroup:SetBarOffset(window.bargroup:GetBarOffset() + 1)
	end
end

function meter:CreateBar(window, name, label, value, maxvalue, icon, o)
	local bar = window.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(f, d) meter:OnMouseWheel(win, f, d) end)
	return bar
end