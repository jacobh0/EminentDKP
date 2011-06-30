--[[
  LibCanUse is a tooltip scanning library that determines if a class can use
  an item. It was originally created for use inside EminentDKP, but I extracted it
  out incase it could be useful to other addon authors.
  
  The library checks basic things like if the class can use the armor type or weapon type,
  however it goes one step further and also attempts to match up primary stats with what
  the class ideally should be using.
  
  Since this Library is a tooltip scanning library, it is obviously based on the locale of the
  client. Also note this library is not perfect and should not be assumed it will always be 100%
  accurate, so use at your own discretion.
  
  Created by Grioja of Crushridge-US
]]

local MAJOR, MINOR = "LibCanUse-1.0", 1
local LibCanUse, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
local L = LibStub("AceLocale-3.0"):GetLocale("LibCanUse-1.0", false)

if not LibCanUse then return end

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

--[[
  1: Armor type
  2: Primary stats
  3: Weapons
  4: Only 1h weapons
  5: Relics, shields, etc
]]

local CLASS_REQUIREMENTS = {
  ["DEATHKNIGHT"] = { [1] = L["Plate"], 
                      [2] = { L["Strength"] }, 
                      [3] = { L["Axe"], L["Sword"], L["Mace"], L["Pole Arm"] },
                      [4] = false,
                      [5] = { L["Relic"] } },
  ["DRUID"] = { [1] = L["Leather"], 
                [2] = { L["Agility"], L["Intellect"] }, 
                [3] = { L["Dagger"], L["Staff"], L["Mace"], L["Pole Arm"], L["Fist"] }, 
                [4] = false,
                [5] = { L["Relic"] } },
  ["HUNTER"] = { [1] = L["Mail"], 
                 [2] = { L["Agility"] }, 
                 [3] = { L["Axe"], L["Sword"], L["Staff"], L["Dagger"], L["Fist"], L["Pole Arm"], L["Bow"], L["Crossbow"], L["Gun"] },
                 [4] = false,
                 [5] = {} },
  ["MAGE"] = { [1] = L["Cloth"], 
               [2] = { L["Intellect"] }, 
               [3] = { L["Sword"], L["Staff"], L["Dagger"], L["Wand"] },
               [4] = true,
               [5] = {} },
  ["PALADIN"] = { [1] = L["Plate"], 
                  [2] = { L["Strength"], L["Intellect"] }, 
                  [3] = { L["Axe"], L["Sword"], L["Mace"], L["Pole Arm"] },
                  [4] = false,
                  [5] = { L["Relic"], L["Shield"] } },
  ["PRIEST"] = { [1] = L["Cloth"], 
                 [2] = { L["Intellect"] }, 
                 [3] = { L["Mace"], L["Staff"], L["Dagger"], L["Wand"] },
                 [4] = true,
                 [5] = {} },
  ["ROGUE"] = { [1] = L["Leather"], 
                [2] = { L["Agility"] }, 
                [3] = { L["Axe"], L["Sword"], L["Mace"], L["Dagger"], L["Fist"], L["Pole Arm"], L["Bow"], L["Crossbow"], L["Gun"], L["Thrown"] },
                [4] = false,
                [5] = {} },
  ["SHAMAN"] = { [1] = L["Mail"], 
                 [2] = { L["Agility"], L["Intellect"] }, 
                 [3] = { L["Axe"], L["Staff"], L["Mace"], L["Pole Arm"], L["Dagger"], L["Fist"] },
                 [4] = false,
                 [5] = { L["Relic"], L["Shield"] } },
  ["WARLOCK"] = { [1] = L["Cloth"], 
                  [2] = { L["Intellect"] }, 
                  [3] = { L["Sword"], L["Staff"], L["Dagger"], L["Wand"] },
                  [4] = true,
                  [5] = {} },
  ["WARRIOR"] = { [1] = L["Plate"], 
                  [2] = { L["Strength"] }, 
                  [3] = { L["Axe"], L["Sword"], L["Mace"], L["Staff"], L["Dagger"], L["Fist"], L["Pole Arm"], L["Bow"], L["Crossbow"], L["Gun"], L["Thrown"] },
                  [4] = false,
                  [5] = { L["Shield"] } },
}

local ITEM_SLOTS = { L["Head"], L["Neck"], L["Shoulder"], L["Back"],
                     L["Chest"], L["Shirt"], L["Tabard"], L["Wrists"],
                     L["Hands"], L["Waist"], L["Legs"], L["Feet"],
                     L["Finger"], L["Trinket"], L["Relic"], L["Wand"],
                     L["Two-Hand"], L["One-Hand"], L["Main Hand"],
                     L["Held In Off-hand"], L["Off Hand"] }

local scan_tip
local enable_stat_check = true

-- Strip any color codes from a string
local function removeColor(str)
  if not str then return nil end
  return string.gsub(string.gsub(str,"|c%a%a%a%a%a%a%a%a",""),"|%a","")
end

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
  
  for i = 1, math.min(8,LibCanUseScanTip:NumLines()) do
    -- Grab the left text
    local left_text_obj = getglobal("LibCanUseScanTipTextLeft" .. i)
    local left_text = removeColor(left_text_obj:GetText())

    -- Stop when we reach a gap
    if string.find(left_text, "\n") then break end

    -- Grab the right text
    local right_text_obj = getglobal("LibCanUseScanTipTextRight" .. i)
    local right_text = removeColor(right_text_obj:GetText())

    -- Right text is only ever the item type
    if right_text then
      if not item_type then
        item_type = right_text
      else
        -- We found a 2nd right text, this must be a weapon of some sort
        is_weapon = true
      end
    end

    if string.find(left_text, L["Classes"], 1, true) then
      -- There is a class restriction line (this is a token)
      class_restrictions = { strsplit(",",string.sub(left_text, strlen(L["Classes"]) + 2)) }
      -- Convert the localized class names into general english class names
      for i,name in ipairs(class_restrictions) do
        class_restrictions[i] = self:GetEnglishClass(strtrim(name))
      end
    elseif tContains(ITEM_SLOTS,left_text) then
      -- We found the slot type
      item_slot = left_text
    else
      -- Search for a primary stat
      local stat = string.gsub(left_text,"%s*+%d*%s*","")
      if stat == L["Strength"] or stat == L["Agility"] or stat == L["Intellect"] then
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
      -- Weapon we can use?
      if tContains(CLASS_REQUIREMENTS[classname][3],item_type) then
        -- Can we use only 1h?
        if item_slot == L["Two-Hand"] and CLASS_REQUIREMENTS[classname][4] and item_type ~= L["Staff"] then
          -- If not a Staff (which are always 2h), can't use
          return false
        end
      else
        -- Cannot equip this weapon
        return false
      end
    else
      -- This a special slot (Shield, Relic)?
      if not tContains(CLASS_REQUIREMENTS[classname][5],item_type) then
        -- Must be some type of armor then
        if item_slot ~= L["Back"] and item_type ~= CLASS_REQUIREMENTS[classname][1] then
          -- Should not (or cannot) equip this armor type
          return false
        end
      end
    end
  end
  
  -- If primary stats don't match, shouldn't use the item
  if enable_stat_check and primary_attrib ~= nil and not tContains(CLASS_REQUIREMENTS[classname][2],primary_attrib) then
    return false
  end
  
  return true
end