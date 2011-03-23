local L = LibStub("AceLocale-3.0"):GetLocale("EminentDKP", false)
local AceGUI = LibStub("AceGUI-3.0")

local EminentDKP = EminentDKP

local meter = EminentDKP:NewModule("MeterDisplay", "SpecializedLibBars-1.1")
local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

-- Our display providers.
EminentDKP.displays = {}

EminentDKP.classColors = RAID_CLASS_COLORS

-- Add to EminentDKP's enormous list of display providers.
meter.name = "Meter display"
EminentDKP.displays["meter"] = meter

--[[-------------------------------------------------------------------
  Auction Interface Functions
---------------------------------------------------------------------]]

local auction_frame = nil

local backdrop_default = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  inset = 4,
  edgeSize = 8,
  tile = true,
  insets = {left = 2, right = 2, top = 2, bottom = 2}
}

local bidamt_backdrop_default = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
  tile = true,
  insets = {left = 3, right = 3, top = 3, bottom = 3}
}

-- Handle the auction frame being moved
local function move(self)
  if not self:GetParent().locked then
    self.startX = self:GetParent():GetLeft()
    self.startY = self:GetParent():GetTop()
    self:GetParent():StartMoving()
  end
end
-- Save position for the auction frame
local function stopMove(self)
  if not self:GetParent().locked then
    self:GetParent():StopMovingOrSizing()
    local endX = self:GetParent():GetLeft()
    local endY = self:GetParent():GetTop()
    if self.startX ~= endX or self.startY ~= endY then
      libwindow.SavePosition(self:GetParent())
    end
  end
end

-- Create the base auction frame for items
function EminentDKP:CreateAuctionFrame()
  local settings = self.db.profile.auctionframe
  auction_frame = CreateFrame("Frame", "EminentDKPAuctionFrameWindow", UIParent)
  auction_frame:SetPoint("TOPLEFT", UIParent, "CENTER")
  auction_frame:SetMovable(true)
  auction_frame:SetClampedToScreen(true)
  auction_frame:Hide()

  auction_frame.title = CreateFrame("Button", nil, auction_frame)
  auction_frame.title:SetScript("OnMouseDown", move)
  auction_frame.title:SetScript("OnMouseUp", stopMove)
  auction_frame.title:SetPoint("TOPLEFT", auction_frame, "TOPLEFT")
  auction_frame.title:SetPoint("BOTTOMRIGHT", auction_frame, "BOTTOMRIGHT")
  
  -- Register with LibWindow-1.1
  libwindow.RegisterConfig(auction_frame, settings)

  -- Restore auction anchor position.
  libwindow.RestorePosition(auction_frame)
  
  self:ApplyAuctionFrameSettings()
end

local auction_titlebackdrop = {}
local auction_windowbackdrop = {}

-- Apply profile settings to the auction frame (and item frames)
function EminentDKP:ApplyAuctionFrameSettings()
  local p = self.db.profile.auctionframe
  auction_frame:SetWidth(p.itemwidth)
  auction_frame:SetHeight(p.itemheight * .75)
  
  -- Auction frame title
  local fo = CreateFont("TitleFontEminentDKPAuctionFrame")
  fo:SetFont(media:Fetch('font', p.title.font), p.title.fontsize)
  auction_frame.title:SetNormalFontObject(fo)
  local inset = p.title.margin
  auction_titlebackdrop.bgFile = media:Fetch("statusbar", p.title.texture)
  if p.title.borderthickness > 0 then
    auction_titlebackdrop.edgeFile = media:Fetch("border", p.title.bordertexture)
  else
    auction_titlebackdrop.edgeFile = nil
  end
  auction_titlebackdrop.tile = false
  auction_titlebackdrop.tileSize = 0
  auction_titlebackdrop.edgeSize = p.title.borderthickness
  auction_titlebackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
  auction_frame.title:SetBackdrop(auction_titlebackdrop)
  local color = p.title.color
  auction_frame.title:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
  
  -- Auction frame background
  if p.enablebackground then
    if auction_frame.bgframe == nil then
      auction_frame.bgframe = CreateFrame("Frame", "EminentDKPAuctionFrameBG", auction_frame)
      auction_frame.bgframe:SetFrameStrata("BACKGROUND")
    end

    local inset = p.background.margin
    auction_windowbackdrop.bgFile = media:Fetch("background", p.background.texture)
    if p.background.borderthickness > 0 then
      auction_windowbackdrop.edgeFile = media:Fetch("border", p.background.bordertexture)
    else
      auction_windowbackdrop.edgeFile = nil
    end
    auction_windowbackdrop.tile = false
    auction_windowbackdrop.tileSize = 0
    auction_windowbackdrop.edgeSize = p.background.borderthickness
    auction_windowbackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
    auction_frame.bgframe:SetBackdrop(auction_windowbackdrop)
    local color = p.background.color
    auction_frame.bgframe:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
    auction_frame.bgframe:SetWidth(auction_frame:GetWidth() + (p.background.borderthickness * 2))

    auction_frame.bgframe:ClearAllPoints()
    auction_frame.bgframe:SetPoint("LEFT", auction_frame.title, "LEFT", -p.background.borderthickness, 0)
    auction_frame.bgframe:SetPoint("RIGHT", auction_frame.title, "RIGHT", p.background.borderthickness, 0)
    auction_frame.bgframe:SetPoint("TOP", auction_frame.title, "BOTTOM", 0, 0)
    auction_frame.bgframe:Hide()
    
    self:AdjustAuctionFrameBackgroundHeight()
  elseif auction_frame.bgframe then
    auction_frame.bgframe:Hide()
  end
  
  if auction_frame:IsShown() and p.enabletitle then
    auction_frame.title:Show()
  else
    auction_frame.title:Hide()
  end
  
  auction_frame.locked = p.locked
  
  self:ReApplyItemFrameSettings()
end

local item_frames = {}
local recycled_item_frames = {}

local function SetItemTip(frame)
  if not frame.link then return end
  GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
  GameTooltip:SetHyperlink(frame.link)
  if IsShiftKeyDown() then GameTooltip_ShowCompareItem() end
  if IsModifiedClick("DRESSUP") then ShowInspectCursor() else ResetCursor() end
end

local function LootClick(frame)
  if IsControlKeyDown() then DressUpItemLink(frame.link)
  elseif IsShiftKeyDown() then ChatEdit_InsertLink(frame.link) end
end

local function ItemOnUpdate(self)
  if IsShiftKeyDown() then GameTooltip_ShowCompareItem() end
  CursorOnUpdate(self)
end

local function HideTip2() GameTooltip:Hide(); ResetCursor() end

-- This is run in the bid amount box everytime they type something
-- It ensures no incorrect bid is sent
local function VerifyBid(frame)
  local value = frame:GetText()
  local num_value = tonumber(value) or 0
  local my_dkp = math.floor(EminentDKP:GetMyCurrentDKP())
  if value == "" or my_dkp < 1 then
    frame:SetText("")
    SetDesaturation(frame:GetParent().bid:GetNormalTexture(), true)
    frame:GetParent().bid:Disable()
    return
  else
    SetDesaturation(frame:GetParent().bid:GetNormalTexture(), false)
    frame:GetParent().bid:Enable()
  end
  if num_value < 1 then
    frame:SetText("1")
  elseif num_value > my_dkp then
    frame:SetText(tostring(my_dkp))
  else
    frame:SetText(string.format("%d",value))
  end
  frame:SetBackdropBorderColor(0.5,0.5,0.5,1)
end

-- This clears the focus of a frame (editbox)
local function ClearFocus(frame)
  frame:ClearFocus()
end

-- This updates the timer bar on an item auction
local function TimerUpdate(frame)
  local left = frame:GetParent().endtime - GetTime()
  if left > 0 then
    local max = select(2,frame:GetMinMaxValues())
    frame.spark:SetPoint("CENTER", frame, "LEFT", (left / max) * frame:GetWidth(), 0)
    frame:SetValue(left)
  else
    frame.spark:Hide()
    frame:Hide()
    frame:GetParent().bid.bidamt:Hide()
    frame:GetParent().bid:Hide()
  end
end

local auction_guid = ""
local last_bid_frame

function EminentDKP:AdjustAuctionFrameBackgroundHeight()
  if auction_frame.bgframe then
    local settings = self.db.profile.auctionframe
    local height = (#(item_frames) * (settings.itemheight + settings.itemspacing)) + settings.background.borderthickness + settings.itemspacing
    auction_frame.bgframe:SetHeight(height)
    
    if self.db.profile.auctionframe.enablebackground and auction_frame:IsShown() then
      auction_frame.bgframe:Show()
    end
  end
end

-- Apply the profile settings to an item frame
local function ApplyItemFrameSettings(frame)
  local p = EminentDKP.db.profile.auctionframe
  
  frame:SetWidth(p.itemwidth)
  frame:SetHeight(p.itemheight)
  
  frame.button:SetWidth(frame:GetHeight())
  frame.button:SetHeight(frame:GetHeight())
  
  frame.buttonborder:SetWidth(frame.button:GetWidth())
  frame.buttonborder:SetHeight(frame.button:GetHeight())
  
  frame.buttonborder2:SetWidth(frame.button:GetWidth() + 2)
  frame.buttonborder2:SetHeight(frame.button:GetHeight() + 2)
  
  frame.status:SetWidth(frame:GetWidth() - 2 - frame.buttonborder2:GetWidth())
  frame.status:SetHeight(frame:GetHeight() - 2)
  frame.status:SetStatusBarTexture(media:Fetch("statusbar", p.itemtexture))
  
  frame.status.spark:SetHeight(frame.status:GetHeight() + 10)
  
  frame.bid:SetWidth(frame:GetHeight() - 2)
  frame.bid:SetHeight(frame:GetHeight() - 2)
  
  frame.loot:SetHeight(frame:GetHeight() - 4)
  frame.loot:SetWidth(frame:GetWidth() / 2)
  frame.loot:SetFont(media:Fetch('font', p.itemfont), p.itemfontsize, "OUTLINE")
  
  frame.winner:SetHeight(frame:GetHeight() - 2)
  frame.winner:SetWidth(frame:GetWidth() - frame.loot:GetWidth() - frame.button:GetWidth())
  frame.winner:SetFont(media:Fetch('font', p.itemfont), p.itemfontsize - 2, "OUTLINE")
end

-- Create a new item frame absent any settings
local function CreateNewItemFrame()
  local itemframe = CreateFrame("Frame", nil, auction_frame)
  itemframe:SetBackdrop(backdrop_default)
  itemframe:SetBackdropColor(0.1, 0.1, 0.1, 1)
  itemframe:Hide()
  
  local button = CreateFrame("Button", nil, itemframe)
  button:SetPoint("LEFT", 0, 0)
  button:SetScript("OnEnter", SetItemTip)
  button:SetScript("OnLeave", HideTip2)
  button:SetScript("OnUpdate", ItemOnUpdate)
  button:SetScript("OnClick", LootClick)

  itemframe.button = button

  local buttonborder = CreateFrame("Frame", nil, button)
  buttonborder:SetPoint("CENTER", button, "CENTER")
  buttonborder:SetBackdrop(backdrop_default)
  buttonborder:SetBackdropColor(1, 1, 1, 0)
  
  itemframe.buttonborder = buttonborder
  
  local buttonborder2 = CreateFrame("Frame", nil, button)
  buttonborder2:SetFrameLevel(buttonborder:GetFrameLevel()+1)
  buttonborder2:SetPoint("CENTER", button, "CENTER")
  buttonborder2:SetBackdrop(backdrop_default)
  buttonborder2:SetBackdropColor(0, 0, 0, 0)
  buttonborder2:SetBackdropBorderColor(0,0,0,1)
  
  itemframe.buttonborder2 = buttonborder2
  
  local status = CreateFrame("StatusBar", nil, itemframe)
  status:SetPoint("LEFT", buttonborder2, "RIGHT", 0, 0)
  status:SetScript("OnUpdate", TimerUpdate)
  status:SetFrameLevel(status:GetFrameLevel()-1)
  status:SetStatusBarColor(.8, .8, .8, .9)
  status:Hide()
  itemframe.status = status
  
  local spark = status:CreateTexture(nil, "OVERLAY")
  spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  spark:SetPoint("CENTER", status, "RIGHT", 0, 0)
  spark:SetBlendMode("ADD")
  spark:SetWidth(14)
  spark:Hide()
  status.spark = spark
  
  local bid = CreateFrame("Button", nil, itemframe)
  bid:SetPoint("RIGHT", itemframe, "RIGHT", -2, -2)
  bid:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
  bid:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Down")
  bid:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Highlight")
  bid:SetScript("OnClick", function(f)
    last_bid_frame = f:GetParent()
    f.bidamt:ClearFocus()
    EminentDKP:ScheduleBidTimeout()
    EminentDKP:SendCommand("bid",f.bidamt:GetText())
  end)
  bid:SetMotionScriptsWhileDisabled(true)
  SetDesaturation(bid:GetNormalTexture(), true)
  bid:Disable()
  bid:Hide()
  itemframe.bid = bid
  
  local bidamt = CreateFrame("EditBox", nil, itemframe)
  bidamt:SetPoint("RIGHT", bid, "LEFT", -1, 2)
  bidamt:SetWidth(55)
  bidamt:SetHeight(20)
  bidamt:SetTextInsets(5, 5, 5, 3)
  bidamt:SetMaxLetters(6)
  bidamt:SetBackdrop(bidamt_backdrop_default)
  bidamt:SetBackdropColor(0.1,0.1,0.1,1)
  bidamt:SetBackdropBorderColor(0.5,0.5,0.5,1)
  bidamt:SetAutoFocus(false)
  bidamt:SetFontObject(ChatFontNormal)
  bidamt:SetScript("OnTextChanged", VerifyBid)
  bidamt:SetScript("OnEnterPressed", ClearFocus)
  bidamt:SetScript("OnEscapePressed", ClearFocus)
  bidamt:Hide()
  
  bid.bidamt = bidamt
  
  local loot = itemframe:CreateFontString(nil, "ARTWORK")
  loot:SetPoint("LEFT", button, "RIGHT", 4, 0)
  loot:SetJustifyH("LEFT")
  itemframe.loot = loot
  
  local winner = itemframe:CreateFontString(nil, "ARTWORK")
  winner:SetPoint("RIGHT", itemframe, "RIGHT", -1, 0)
  winner:SetJustifyH("RIGHT")
  winner:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  winner:Hide()
  itemframe.winner = winner
  
  ApplyItemFrameSettings(itemframe)
  return itemframe
end

-- Either get a recycled frame or create a new one
local function GetItemFrame()
  local frame
  if #(recycled_item_frames) > 0 then
    frame = tremove(recycled_item_frames)
  else
    frame = CreateNewItemFrame()
  end
  
  frame:SetPoint("TOPLEFT", #(item_frames) > 0 and item_frames[#(item_frames)] or auction_frame.title, "BOTTOMLEFT", 0, -(EminentDKP.db.profile.auctionframe.itemspacing))
  table.insert(item_frames, frame)
  return frame
end

function EminentDKP:CancelBidTimeout()
  if self.bidTimeout then
    self:CancelTimer(self.bidTimeout,true)
    self.bidTimeout = nil
  end
end

-- Incase we never get a response about a bid, just assume it was rejected
function EminentDKP:ScheduleBidTimeout()
  self:CancelBidTimeout()
  self.bidTimeout = self:ScheduleTimer("RejectLastItemBid",3)
end

-- Turn the bid amount box red (signify rejection of bid)
function EminentDKP:RejectLastItemBid()
  self:CancelBidTimeout()
  last_bid_frame.bid.bidamt:SetBackdropBorderColor(235,0,0,1)
end

-- Turn the bid amount box green (signify the acceptance of bid)
function EminentDKP:AcceptLastItemBid()
  self:CancelBidTimeout()
  last_bid_frame.bid.bidamt:SetBackdropBorderColor(0,235,0,1)
end

-- Reapply settings to each item frame (and adjust their positioning if necessary)
function EminentDKP:ReApplyItemFrameSettings()
  for i, frame in ipairs(item_frames) do
    ApplyItemFrameSettings(frame)
    frame:SetPoint("TOPLEFT", i > 1 and item_frames[i-1] or auction_frame.title, "BOTTOMLEFT", 0, -(self.db.profile.auctionframe.itemspacing))
  end
  -- Don't forget about recycled frames
  for i, frame in ipairs(recycled_item_frames) do
    ApplyItemFrameSettings(frame)
  end
end

function EminentDKP:FillOutItemFrame(f)
  local iName, iLink, iQuality, iLevel, iMinLevel, iType, iSubType, iStackCount, iEquipLoc, iTexture, iSellPrice = GetItemInfo(f.item)
  local color
  local success = true
  
  if not iName then
    f.button:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.button.link = nil
    
    color = ITEM_QUALITY_COLORS[1]
    f.loot:SetText("(Querying Item)")
    
    success = false
  else
    f.button:SetNormalTexture(iTexture)
    f.button.link = iLink
    
    color = ITEM_QUALITY_COLORS[iQuality]
    f.loot:SetText(iName)
  end
  
  f.loot:SetVertexColor(color.r, color.g, color.b)
  f:SetBackdropBorderColor(color.r, color.g, color.b, 1)
  f.buttonborder:SetBackdropBorderColor(color.r, color.g, color.b, 1)
  f.status:SetStatusBarColor(color.r, color.g, color.b, .7)
  return success
end

-- Display all the available loot for a given GUID
function EminentDKP:ShowAuctionItems(guid)
  if auction_guid == guid then
    -- If the lootlist has changed, re-list the items
    if self.auctionItems[guid].changed then
      self:RecycleAuctionItems(false)
    else
      return
    end
  else
    self:RecycleAuctionItems(false)
  end
  auction_frame:Show()
  if self.db.profile.auctionframe.enabletitle then
    auction_frame.title:Show()
  end
  auction_frame.title:SetText(L["EminentDKP: %s Items"]:format(self.auctionItems[guid].name))
  local refill = false
  for i, item in ipairs(self.auctionItems[guid].items) do
    local f = GetItemFrame()
    f.item = item.info
    f.slot = item.slot
    
    if not self:FillOutItemFrame(f) then refill = true end
    
    f:Show()
  end
  if refill then self:ScheduleTimer("ReFillItemFrames",1) end
  self.auctionItems[guid].changed = false
  auction_guid = guid
  self:AdjustAuctionFrameBackgroundHeight()
end

local function GetItemFrameBySlot(slot)
  for i, frame in ipairs(item_frames) do
    if frame.slot == slot then
      return frame
    end
  end
  return nil
end

-- Hide bidbox and button for an item frame
local function HideBidApparatus(frame)
  frame.bid:Hide()
  frame.bid.bidamt:Hide()
  frame.status:Hide()
  frame.status.spark:Hide()
end

-- Cancel the auction for a specified slot
function EminentDKP:CancelAuction(slot)
  local frame = GetItemFrameBySlot(slot)
  HideBidApparatus(frame)
  frame.winner:SetText(L["Auction cancelled"])
  frame.winner:Show()
  PlaySound("AuctionWindowClose")
end

-- Start the timer and show bid box/button for an item
function EminentDKP:StartAuction(slot,timeleft,window)
  local frame = GetItemFrameBySlot(slot)
  frame.bid:Show()
  frame.bid.bidamt:SetBackdropBorderColor(0.5,0.5,0.5,1)
  frame.bid.bidamt:Show()
  frame.endtime = GetTime() + timeleft
  frame.status:SetMinMaxValues(0, window)
  frame.status:SetValue(timeleft)
  frame.status:Show()
  frame.status.spark:Show()
  frame.winner:Hide()
  PlaySound("AuctionWindowOpen")
end

-- Label an item disenchanted
function EminentDKP:ShowAuctionDisenchant(slot)
  local frame = GetItemFrameBySlot(slot)
  HideBidApparatus(frame)
  frame.winner:SetText(L["Disenchanted"])
  frame.winner:Show()
end

-- Attempts to fill out the item frames with item data
function EminentDKP:ReFillItemFrames()
  local refill = false
  for i, frame in ipairs(item_frames) do
    if not self:FillOutItemFrame(frame) then refill = true end
  end
  if refill then self:ScheduleTimer("ReFillItemFrames",1) end
end

-- Label an item with a winner
function EminentDKP:ShowAuctionWinner(slot,name,amount,tie)
  local frame = GetItemFrameBySlot(slot)
  HideBidApparatus(frame)
  if tie then
    frame.winner:SetText(L["Tie won by %s (%d)"]:format(name,amount))
  else
    frame.winner:SetText(L["Won by %s (%d)"]:format(name,amount))
  end
  frame.winner:Show()
end

-- Cleanup and recycle all the frames for re-use later (saves memory)
function EminentDKP:RecycleAuctionItems(clear_list)
  if self.auctionRecycleTimer then
    self:CancelTimer(self.auctionRecycleTimer,true)
    self.auctionRecycleTimer = nil
  end
  for i, frame in ipairs(item_frames) do
    frame.item = nil
    frame.slot = nil
    frame.endtime = nil
    frame.bid.bidamt:SetText("")
    frame.winner:SetText("")
    HideBidApparatus(frame)
    frame.winner:Hide()
    table.insert(recycled_item_frames,frame)
    frame:Hide()
  end
  wipe(item_frames)
  auction_frame.title:Hide()
  if auction_frame.bgframe then
    auction_frame.bgframe:Hide()
  end
  auction_frame:Hide()
  -- Clear out the loot list for this GUID, we no longer need it
  if clear_list and self.auctionItems[auction_guid] then
    self.auctionItems[auction_guid] = nil
  end
  auction_guid = ""
end

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

-- Truncate a number to 2 decimals (without rounding)
local function TNum(number)
  decimal = string.find(number, ".", 1, 1)
  if decimal == nil then
    return n
  elseif string.find(number, "e-", 1, 1) ~= nil then
    return 0
  else
    return tonumber(string.sub(number, 1, decimal+2))
  end
end

local function ConfirmAction(name,msg,accept)
  StaticPopupDialogs[name] = {
    text = msg, 
    button1 = ACCEPT, 
    button2 = CANCEL,
    timeout = 15, 
    whileDead = 0, 
    hideOnEscape = 1, 
    OnAccept = accept,
  }
  StaticPopup_Show(name)
end

-- Show the tab responsible for transfers
local function CreateTransferTab(container)
  local transfergrp = AceGUI:Create("InlineGroup")
  transfergrp:SetTitle(L["Transfer DKP"])
  transfergrp:SetLayout("Flow")
  transfergrp:SetWidth(200)
  
  local recip = AceGUI:Create("Dropdown")
  recip:SetLabel(L["Recipient"])
  recip:SetList(EminentDKP:GetOtherPlayersNames(true))
  recip:SetWidth(150)
  
  local amount = AceGUI:Create("Slider")
  amount:SetLabel("Amount")
  if EminentDKP:GetMyCurrentDKP() and EminentDKP:GetMyCurrentDKP() >= 1 then
    amount:SetSliderValues(1,TNum(EminentDKP:GetMyCurrentDKP()),1)
    amount:SetValue(1)
  else
    recip:SetDisabled(true)
  end
  
  local send = AceGUI:Create("Button")
  send:SetText(L["Send"])
  send:SetWidth(200)
  send:SetCallback("OnClick",function(what)
    ConfirmAction("EminentDKPTransfer",
                  L["Are you sure you want to transfer %.02f DKP to %s?"]:format(amount:GetValue(),recip:GetValue()),
                  function() EminentDKP:SendCommand('transfer',amount:GetValue(),recip:GetValue()) end)
  end)
  send:SetDisabled(true)
  
  recip:SetCallback("OnValueChanged",function(i,j,val)
    if val ~= "" and EminentDKP:InQualifiedRaid() then
      send:SetDisabled(false)
    else
      send:SetDisabled(true)
    end
  end)
  
  transfergrp:AddChild(recip)
  transfergrp:AddChild(amount)
  transfergrp:AddChild(send)
  container:AddChild(transfergrp)
end

local function CreateVanityTab(container)
  local resetgrp = AceGUI:Create("InlineGroup")
  resetgrp:SetTitle(L["Reset Vanity DKP"])
  resetgrp:SetLayout("Flow")
  resetgrp:SetWidth(200)
  
  local who = AceGUI:Create("Dropdown")
  who:SetLabel(L["Player"])
  who:SetList(EminentDKP:GetPlayerNames())
  who:SetWidth(150)
  
  local reset = AceGUI:Create("Button")
  reset:SetText(L["Reset"])
  reset:SetWidth(150)
  reset:SetCallback("OnClick",function(what)
    EminentDKP:AdminVanityReset(who:GetValue())
  end)
  reset:SetDisabled(true)
  
  who:SetCallback("OnValueChanged",function(i,j,val)
    if val ~= "" then
      reset:SetDisabled(false)
    else
      reset:SetDisabled(true)
    end
  end)
  
  resetgrp:AddChild(who)
  resetgrp:AddChild(reset)
  container:AddChild(resetgrp)
  
  local rollgrp = AceGUI:Create("InlineGroup")
  rollgrp:SetTitle(L["Vanity DKP Roll"])
  rollgrp:SetLayout("Flow")
  rollgrp:SetWidth(200)
  
  local roll = AceGUI:Create("Button")
  roll:SetText(L["Roll"])
  roll:SetWidth(150)
  roll:SetCallback("OnClick",function(what)
    EminentDKP:AdminVanityRoll()
  end)
  rollgrp:AddChild(roll)
  container:AddChild(rollgrp)
end

local function CreateRenameTab(container)
  local renamegrp = AceGUI:Create("InlineGroup")
  renamegrp:SetTitle(L["Rename Player"])
  renamegrp:SetLayout("Flow")
  renamegrp:SetWidth(200)
  
  local rename = AceGUI:Create("Button")
  rename:SetText(L["Rename"])
  rename:SetWidth(150)
  rename:SetDisabled(true)
  
  local newname = AceGUI:Create("Dropdown")
  newname:SetLabel(L["New Player"])
  newname:SetWidth(150)
  newname:SetCallback("OnValueChanged",function(i,j,value)
    rename:SetDisabled(false)
  end)
  
  local who = AceGUI:Create("Dropdown")
  who:SetLabel(L["Old Player"])
  who:SetList(EminentDKP:GetPlayerNames())
  who:SetCallback("OnValueChanged",function(i,j,value)
    newname:SetList(EminentDKP:GetPlayersOfClass(value,true))
    rename:SetDisabled(true)
  end)
  who:SetWidth(150)
  
  rename:SetCallback("OnClick",function(what)
    EminentDKP:AdminRename(who:GetValue(),newname:GetValue())
  end)
  
  renamegrp:AddChild(who)
  renamegrp:AddChild(newname)
  renamegrp:AddChild(rename)
  container:AddChild(renamegrp)
end

local function CreateBountyTab(container)
  local bountygrp = AceGUI:Create("InlineGroup")
  bountygrp:SetTitle(L["Award Bounty"])
  bountygrp:SetLayout("Flow")
  bountygrp:SetWidth(200)
  
  local reason = AceGUI:Create("Dropdown")
  reason:SetLabel(L["Reason"])
  reason:SetWidth(150)
  reason:SetList(EminentDKP:GetBountyReasons())
  reason:SetValue("Default")
  
  local amount = AceGUI:Create("Slider")
  amount:SetLabel(L["Amount"])
  amount:SetSliderValues(0.5,100,0.5)
  amount:SetValue(0.5)
  
  local percent = AceGUI:Create("CheckBox")
  percent:SetLabel(L["Percent"])
  percent:SetValue(true)
  percent:SetCallback("OnValueChanged",function(i,j,checked)
    if checked then
      amount:SetSliderValues(0.5,100,0.5)
      amount:SetValue(0.5)
    else
      amount:SetSliderValues(1,math.floor(EminentDKP:GetAvailableBounty()),1)
      amount:SetValue(1)
    end
  end)
  
  local award = AceGUI:Create("Button")
  award:SetText(L["Award"])
  award:SetWidth(150)
  award:SetCallback("OnClick",function(what)
    EminentDKP:AdminDistributeBounty(percent:GetValue(),amount:GetValue(),reason:GetValue())
  end)
  
  bountygrp:AddChild(reason)
  bountygrp:AddChild(percent)
  bountygrp:AddChild(amount)
  bountygrp:AddChild(award)
  container:AddChild(bountygrp)
end

local function CreateAdjustmentTab(container)
  local adjustgrp = AceGUI:Create("InlineGroup")
  adjustgrp:SetTitle(L["Issue Adjustment"])
  adjustgrp:SetLayout("Flow")
  adjustgrp:SetWidth(200)
  
  local deduct = AceGUI:Create("CheckBox")
  
  local issue = AceGUI:Create("Button")
  
  local amount = AceGUI:Create("Slider")
  amount:SetLabel(L["Amount"])
  
  local who = AceGUI:Create("Dropdown")
  who:SetLabel(L["Player"])
  who:SetList(EminentDKP:GetPlayerNames(true))
  who:SetWidth(150)
  who:SetCallback("OnValueChanged",function(i,j,value)
    issue:SetDisabled(false)
    if deduct:GetValue() then
      if EminentDKP:GetCurrentDKP(value) < 1 then
        issue:SetDisabled(true)
        amount:SetSliderValues(0,0,0)
      else
        amount:SetSliderValues(1,TNum(EminentDKP:GetCurrentDKP(value)),1)
      end
    else
      amount:SetSliderValues(1,math.floor(EminentDKP:GetAvailableBounty()),1)
    end
    amount:SetValue(1)
  end)
  
  local reason = AceGUI:Create("EditBox")
  reason:SetLabel(L["Reason"])
  reason:SetWidth(150)
  reason:SetMaxLetters(20)
  
  deduct:SetLabel(L["Deduction"])
  deduct:SetValue(true)
  deduct:SetCallback("OnValueChanged",function(i,j,checked)
    if checked and who:GetValue() ~= "" then
      if EminentDKP:GetCurrentDKP(who:GetValue()) < 1 then
        issue:SetDisabled(true)
        amount:SetSliderValues(0,0,0)
      else
        issue:SetDisabled(false)
        amount:SetSliderValues(1,TNum(EminentDKP:GetCurrentDKP(who:GetValue())),1)
      end
    else
      issue:SetDisabled(false)
      amount:SetSliderValues(1,math.floor(EminentDKP:GetAvailableBounty()),1)
    end
    amount:SetValue(1)
  end)
  
  issue:SetText(L["Issue"])
  issue:SetWidth(150)
  issue:SetCallback("OnClick",function(what)
    EminentDKP:AdminIssueAdjustment(who:GetValue(),amount:GetValue(),deduct:GetValue(),reason:GetText())
  end)
  issue:SetDisabled(true)
  
  adjustgrp:AddChild(who)
  adjustgrp:AddChild(reason)
  adjustgrp:AddChild(deduct)
  adjustgrp:AddChild(amount)
  adjustgrp:AddChild(issue)
  container:AddChild(adjustgrp)
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
  elseif group == "adjustment" then
    CreateAdjustmentTab(container)
  end
  EminentDKP.actionpanel:SetStatusText("")
end

function EminentDKP:CreateActionPanel()
  if self.actionpanel then
    AceGUI:Release(self.actionpanel)
    self.actionpanel = nil
  end
  self.actionpanel = AceGUI:Create("EminentDKPFrame")
  self.actionpanel:SetWidth(400)
  self.actionpanel:SetHeight(350)
  self.actionpanel:SetTitle(L["EminentDKP Action Panel"])
  self.actionpanel:SetCallback("OnClose", function(widget)
    AceGUI:Release(widget)
    EminentDKP.actionpanel = nil
  end)
  self.actionpanel:SetLayout("Fill")
  
  -- Create the TabGroup
  local tab = AceGUI:Create("TabGroup")
  tab:SetLayout("Flow")
  -- Setup which tabs to show
  tab:SetTabs({
    {text=L["Transfer"], value="transfer"},
    {text=L["Vanity"], value="vanity", disabled=(not EminentDKP:AmOfficer())},
    {text=L["Rename"], value="rename", disabled=(not EminentDKP:AmOfficer())},
    {text=L["Adjustment"], value="adjustment", disabled=(not EminentDKP:AmOfficer())},
    {text=L["Bounty"], value="bounty", disabled=(not EminentDKP:AmOfficer())},
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

local function lerp(a, b, delta)
  return (a + (b - a) * delta)
end

local color_red = { .9, .10, .10 }
local color_green = { .10, .9, .10 }

local function ColorLerp(color1, color2, delta)
  return lerp(color1[1], color2[1], delta), 
         lerp(color1[2], color2[2], delta), 
         lerp(color1[3], color2[3], delta)
end

function EminentDKP:UpdateStatusBar()
  local color, label, maxvalue, value
  if not self:IsSyncing() then
    if self:NeedSync() then
      -- Show out of date status
      maxvalue = self:GetNewestEventCount()
      value = self:GetEventCount()
      local percent = value / maxvalue
      color = color_red
      label = (L["Out of Date"].." (%d%%)"):format(percent * 100)
    else
      -- Show the bounty status
      local percent = self:GetAvailableBountyPercent()
      color = { ColorLerp(color_green,color_red,(percent / 100)) }
      label = (L["Bounty:"].." %s (%d%%)"):format(self:FormatNumber(self:GetAvailableBounty()),percent)
      maxvalue = 100
      value = percent
    end
  else
    -- Show the sync status
    maxvalue = self:GetNewestEventCount()
    value = self:GetEventCount()
    local percent = value / maxvalue
    color = { ColorLerp(color_red,color_green,percent) }
    label = (L["Syncing..."].." %d/%d (%d%%)"):format(value,maxvalue,(percent * 100))
  end
  -- Update the status bar in all windows
  for i, win in ipairs(self:GetWindows()) do
    win.bargroup.status:UnsetAllColors()
    win.bargroup.status:SetColorAt(0, color[1], color[2], color[3], 1)
    win.bargroup.status:SetLabel(label)
    win.bargroup.status:SetValue(value)
    win.bargroup.status:SetMaxValue(maxvalue)
  end
end

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

function StatusEnter(win, button)
  local t = GameTooltip
  if EminentDKP.db.profile.tooltips then
    ttactive = true
    EminentDKP:SetTooltipPosition(t, win.bargroup)
    t:ClearLines()
    
    t:AddLine(L["Bounty Pool"], 1,1,1)
    t:AddDoubleLine(L["Available:"], EminentDKP:FormatNumber(EminentDKP:GetAvailableBounty()), 1,1,1)
    t:AddDoubleLine(L["Size:"], EminentDKP:FormatNumber(EminentDKP:GetBountySize()), 1,1,1)
    t:AddLine(" ")
    t:AddLine(L["Version Info"], 1,1,1)
    if EminentDKP:NeedUpgrade() then
      t:AddDoubleLine(L["Current:"], EminentDKP:GetVersion(), 1,1,1,unpack(color_red))
      t:AddDoubleLine(L["Newest:"], EminentDKP:GetNewestVersion(), 1,1,1,unpack(color_green))
      t:AddLine(" ")
      t:AddLine(L["Please upgrade to the newest version."], unpack(color_red))
    else
      t:AddDoubleLine(L["Current:"], EminentDKP:GetVersion(), 1,1,1,unpack(color_green))
      t:AddDoubleLine(L["Newest:"], EminentDKP:GetNewestVersion(), 1,1,1,unpack(color_green))
    end
    
    t:Show()
  end
end

function StatusLeave(win, button)
  BarLeave(win,nil,nil)
end

function StatusClick(win, button)
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
  
  -- Status bar
  g.status:ShowLabel()
  g.status:SetScript("OnEnter", function(bar) StatusEnter(window, bar) end)
  g.status:SetScript("OnLeave", function(bar) StatusLeave(window, bar) end)
  g.status:SetScript("OnMouseDown", function(bar) StatusClick(window,bar) end)
  g.status.label:SetJustifyH("MIDDLE")
  
  if p.enablestatus then
    g:ShowStatus()
  else
    g:HideStatus()
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
      if g:IsStatusVisible() then maxbars = maxbars - 1 end
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
    if window.bargroup:IsStatusVisible() then numbars = numbars + 1 end
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
  if icon then 
    if not window.bargroup:IsIconShown() then
      window.bargroup:ShowIcon()
    end
  elseif window.bargroup:IsIconShown() then window.bargroup:HideIcon() end
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
        values= function() return {[1] = L["Left to right"], [3] = L["Right to left"]} end,
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