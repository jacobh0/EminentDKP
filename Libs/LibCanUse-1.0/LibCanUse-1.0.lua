--[[
  LibCanUse is a tooltip scanning library that determines if a class can use
  an item. It was originally created for use inside EminentDKP, but I extracted it
  out incase it could be useful to other addon authors.
  
  The library checks basic things like if the class can use the armor type or weapon type,
  however it goes one step further and also attempts to match up primary stats with what
  the class ideally should be using. There are some exceptions in this, mainly being
  that all tank classes (DK, Paladin, Druid, Warrior) can potentially have overlap into
  agility or strength based items, since they sometimes (rarely) are usable when itemization
  from Blizzard is very poor in a tier.
  
  Since this Library is tooltip scanning library, it is obviously based on the locale of the
  client. Also note this library is not perfect and should not be assumed it will always be 100%
  accurate, so use at your own discretion.
  
  Created by Grioja of Crushridge-US
]]

local MAJOR, MINOR = "LibCanUse", 0
local LibCanUse, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
local L = LibStub("AceLocale-3.0"):GetLocale("LibCanUse-1.0", false)

-- Check if a class can use an item
-- Three steps to check:
-- 1. Armor type / Weapon type
-- 2. Primary stat
-- 3. Class Requirement (i.e. token)

local ENGLISH_CLASSES = {
  [L["Death Knight"]] = "DEATHKNIGHT",
  [L["Druid"]] = "DRUID",
  [L["Hunter"]] = "HUNTER",
  [L["Mage"]] = "MAGE",
  [L["Paladin"]] = "PALADIN",
  [L["Priest"]] = "PRIEST",
  [L["Rogue"]] = "ROGUE",
  [L["Shaman"]] = "SHAMAN",
  [L["Warlock"]] = "WARLOCK",
  [L["Warrior"]] = "WARRIOR",
}

local CLASS_REQUIREMENTS = {
  ["DEATHKNIGHT"] = { [1] => L["Plate"], 
                      [2] => { L["Strength"], L["Agility"] }, 
                      [3] => { L["Axe"], L["Sword"], L["Mace"], L["Pole Arm"], L["Relic"] },
                      [4] => false },
  ["DRUID"] = { [1] => L["Leather"], 
                [2] => { L["Agility"], L["Intellect"] }, 
                [3] => { L["Dagger"], L["Staff"], L["Mace"], L["Pole Arm"], L["Fist"], L["Relic"] }, 
                [4] => false },
  ["HUNTER"] = { [1] => L["Mail"], 
                 [2] => { L["Agility"] }, 
                 [3] => { L["Axe"], L["Sword"], L["Staff"], L["Dagger"], L["Fist"], L["Pole Arm"], L["Bow"], L["Crossbow"], L["Gun"] },
                 [4] => false },
  ["MAGE"] = { [1] => L["Cloth"], 
               [2] => { L["Intellect"] }, 
               [3] => { L["Sword"], L["Staff"], L["Dagger"], L["Wand"] },
               [4] => true },
  ["PALADIN"] = { [1] => L["Plate"], 
                  [2] => { L["Strength"], L["Intellect"], L["Agility"] }, 
                  [3] => { L["Axe"], L["Sword"], L["Mace"], L["Pole Arm"], L["Relic"] },
                  [4] => false },
  ["PRIEST"] = { [1] => L["Cloth"], 
                 [2] => { L["Intellect"] }, 
                 [3] => { L["Mace"], L["Staff"], L["Dagger"], L["Wand"] },
                 [4] => true },
  ["ROGUE"] = { [1] => L["Leather"], 
                [2] => { L["Agility"] }, 
                [3] => { L["Axe"], L["Sword"], L["Mace"], L["Dagger"], L["Fist"], L["Pole Arm"], L["Bow"], L["Crossbow"], L["Gun"], L["Thrown"] },
                [4] => false },
  ["SHAMAN"] = { [1] => L["Mail"], 
                 [2] => { L["Agility"], L["Intellect"] }, 
                 [3] => { L["Axe"], L["Staff"], L["Mace"], L["Pole Arm"], L["Relic"], L["Dagger"], L["Fist"] },
                 [4] => false },
  ["WARLOCK"] = { [1] => L["Cloth"], 
                  [2] => { L["Intellect"] }, 
                  [3] => { L["Sword"], L["Staff"], L["Dagger"], L["Wand"] },
                  [4] => true },
  ["WARRIOR"] = { [1] => L["Plate"], 
                  [2] => { L["Strength"], L["Agility"] }, 
                  [3] => { L["Axe"], L["Sword"], L["Mace"], L["Staff"], L["Dagger"], L["Fist"], L["Pole Arm"], L["Bow"], L["Crossbow"], L["Gun"], L["Thrown"] },
                  [4] => false },
}

local ITEM_SLOTS = { L["Head"], L["Neck"], L["Shoulder"], L["Back"],
                     L["Chest"], L["Shirt"], L["Tabard"], L["Wrists"],
                     L["Hands"], L["Waist"], L["Legs"], L["Feet"],
                     L["Finger"], L["Trinket"], L["Relic"], L["Wand"],
                     L["Two-Hand"], L["One-Hand"], L["Main-Hand"],
                     L["Held in Off-Hand"] }

local scan_tip
local enable_stat_check = true

-- Disable the primary stat check
function LibCanUse:UseStatCheck(bool)
  enable_stat_check = (bool and true or false)
end

-- Convert localized class name to english class name
function LibCanUse:GetEnglishClass(name)
  return ENGLISH_CLASSES[name]
end

-- classname : The ENGLISH classname i.e. "DEATHKNIGHT"
-- link : the itemlink for an item
-- Returns true or false depending on if the item can be used by the class
function LibCanUse:CanUseItem(classname,link)
  -- If passed localized class name, convert to english class name
  if ENGLISH_CLASSES[classname] ~= nil then
    classname = ENGLISH_CLASSES[classname]
  end
  
  -- Scanning tooltip created yet?
  if not scan_tip then
    scan_tip = CreateFrame('GameTooltip', 'LibCanUseScanTip', UIParent, 'GameTooltipTemplate')
    scan_tip:SetOwner(UIParent, 'ANCHOR_NONE')
    scan_tip:AddFontStrings(
      scan_tip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
      scan_tip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
  end
  LibCanUseScanTip:ClearLines()
  LibCanUseScanTip:SetHyperlink(link)
  
  local is_weapon = false
  local item_slot
  local item_type
  local primary_attrib
  local class_restrictions
  
  for i = 1, math.min(6,EminentDKPST:NumLines()) do
    -- Right text is only ever the item type
    local right_text = getglobal("LibCanUseScanTipTextRight" .. i)
    if right_text:GetText() then
      if not item_type then
        item_type = right_text:GetText()
      else
        -- We found a 2nd right text, this must be a weapon of some sort
        is_weapon = true
      end
    end
    
    -- Scan the left text
    local left_text = getglobal("LibCanUseScanTipTextLeft" .. i)
    if string.find(left_text:GetText(), L["Classes"], 1, true) then
      -- There is a class restriction line (this is a token)
      class_restrictions = { strsplit(", ",string.sub(left_text:GetText(), strlen(L["Classes"]) + 1)) }
      -- Convert the localized class names into general english class names
      for i,name in ipairs(class_restrictions) do
        class_restrictions[i] = self:GetEnglishClass(name)
      end
    elseif tContains(ITEM_SLOTS,left_text:GetText()) then
      -- We found the slot type
      item_slot = left_text:GetText()
    else
      -- Search for a primary stat
      local stat = string.match(left_text:GetText(), "["..L["Intellect"].."|"..L["Agility"].."|"..L["Strength"].."]+") then
      if stat then
        primary_attrib = stat
      end
    end  
  end
  
  -- If class restrictions and not any of the classes, can't use the item
  if class_restrictions ~= nil and not tContains(class_restrictions,classname) then
    return false
  end
  
  if item_type then
    if is_weapon then
      if tContains(CLASS_REQUIREMENTS[classname][3],item_type) then
        -- Can we use only 1h?
        if CLASS_REQUIREMENTS[classname][4] and item_type ~= L["Staff"] and item_slot ~= L["One-Hand"] then
          -- If not a Staff (which are always 2h), and is not a 1h, can't use
          return false
        end
      else
        -- Cannot equip this weapon
        return false
      end
    elseif item_slot ~= L["Back"] and item_type ~= CLASS_REQUIREMENTS[classname][1] then
      -- Should not (or cannot) equip this armor type
      return false
    end
  end
  
  -- If primary stats don't match, shouldn't use the item
  if enable_stat_check and primary_attrib and not tContains(CLASS_REQUIREMENTS[classname][2],primary_attrib) then
    return false
  end
  
  return true
end