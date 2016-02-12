function PrecacheHeroItems( name, path, context )
  print("----------------------------------------Precache Hero Start----------------------------------------") --для консоли

  local wearablesList = {} --"переменная для надеваемых шмоток(для всех героев)"
  local precacheWearables = {} --"переменная только для шмоток нужного героя"
  local precacheParticle = {}
  for k, v in pairs(path) do --лезем в файл, достаем шмоточки
    if k == 'items' then
      wearablesList = v
    end
  end
  local counter = 0 -- всякие счетчики
  local counter_particle = 0
  local value
  for k, v in pairs(wearablesList) do -- "выбираем из списка предметов только предметы на нужных героев"
    if IsForHero(name, wearablesList[k]) then
      if wearablesList[k]["model_player"] then
        value = wearablesList[k]["model_player"] 
        precacheWearables[value] = true
      end
      if wearablesList[k]["particle_file"] then -- "прекешируем еще и частицы, куда ж без них!"
        value = wearablesList[k]["particle_file"] 
        precacheParticle[value] = true
      end
    end
  end

--"собственно само прекеширование всех занесенных в список шмоток"
  for wearable,_ in pairs( precacheWearables ) do
    print("Precache model: " .. wearable)
    PrecacheResource( "model", wearable, context )
    counter = counter + 1
  end

--"и прекеширование частиц"
  for wearable,_ in pairs( precacheParticle ) do
    print("Precache particle: " .. wearable)
    PrecacheResource( "particle", wearable, context )
    counter_particle = counter_particle + 1
  end

 -- "прекешируем саму модель героя! иначе будут бегать шмотки без тела"
  -- PrecacheUnitByNameSync(name, context)
  PrecacheUnitByNameAsync(name, function(...) end)
    
    print('[Precache]' .. counter .. " models loaded and " .. counter_particle .." particles loaded")
    print('[Precache] End')

end

-- "привет от вашего друга, индийского быдлокодера работающего за еду"
function IsForHero(str, tbl)
  if type(tbl["used_by_heroes"]) ~= type(1) and tbl["used_by_heroes"] then 
    if tbl["used_by_heroes"][str] then
      return true
    end
  end
  return false
end

function HasAbilities( hero, abilities_table )
  for _, ab in pairs( abilities_table ) do
    if hero:HasAbility( ab ) then
      return true
    end
  end
  return false
end

function GetLength( array )
  local arrayLength = 0
  for k,v in pairs(array) do
    arrayLength = arrayLength + 1
  end
  return arrayLength
end

--[[CustomNetTables
  Use for quick access to 2nd lvl KVs
]]
function GetFromCustomNetTables(tableName, pID, key)
  local innerTable = CustomNetTables:GetTableValue(tableName, tostring(pID))
  return innerTable[tostring(key)]
end

function AddToCustomNetTables(tableName, pID, key, value)
  local newTable = CustomNetTables:GetTableValue(tableName, tostring(pID))
  if newTable then
    newTable[tostring(key)] = value
    CustomNetTables:SetTableValue(tableName, tostring(pID), newTable);
  end
end
--

function DebugPrint(...)
  -- local spew = Convars:GetInt('barebones_spew') or -1
  -- if spew == -1 and BAREBONES_DEBUG_SPEW then
  --   spew = 1
  -- end

  -- if spew == 1 then
  if BAREBONES_DEBUG_SPEW then
    print(...)
  end
  -- end
end

function DebugPrintTable(...)
  -- local spew = Convars:GetInt('barebones_spew') or -1
  -- if spew == -1 and BAREBONES_DEBUG_SPEW then
  --   spew = 1
  -- end

  -- if spew == 1 then
  if BAREBONES_DEBUG_SPEW then
    PrintTable(...)
  end
  -- end
end

function PrintTable(t, indent, done)
  --print ( string.format ('PrintTable type %s', type(keys)) )
  if type(t) ~= "table" then return end

  done = done or {}
  done[t] = true
  indent = indent or 0

  local l = {}
  for k, v in pairs(t) do
    table.insert(l, k)
  end

  table.sort(l)
  for k, v in ipairs(l) do
    -- Ignore FDesc
    if v ~= 'FDesc' then
      local value = t[v]

      if type(value) == "table" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..":")
        PrintTable (value, indent + 2, done)
      elseif type(value) == "userdata" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        PrintTable ((getmetatable(value) and getmetatable(value).__index) or getmetatable(value), indent + 2, done)
      else
        if t.FDesc and t.FDesc[v] then
          print(string.rep ("\t", indent)..tostring(t.FDesc[v]))
        else
          print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        end
      end
    end
  end
end

-- Colors
COLOR_NONE = '\x06'
COLOR_GRAY = '\x06'
COLOR_GREY = '\x06'
COLOR_GREEN = '\x0C'
COLOR_DPURPLE = '\x0D'
COLOR_SPINK = '\x0E'
COLOR_DYELLOW = '\x10'
COLOR_PINK = '\x11'
COLOR_RED = '\x12'
COLOR_LGREEN = '\x15'
COLOR_BLUE = '\x16'
COLOR_DGREEN = '\x18'
COLOR_SBLUE = '\x19'
COLOR_PURPLE = '\x1A'
COLOR_ORANGE = '\x1B'
COLOR_LRED = '\x1C'
COLOR_GOLD = '\x1D'


--[[Author: Noya
  Date: 09.08.2015.
  Hides all dem hats
]]
function HideWearables( event )
  local hero = event.caster
  local ability = event.ability

  hero.hiddenWearables = {} -- Keep every wearable handle in a table to show them later
    local model = hero:FirstMoveChild()
    while model ~= nil do
        if model:GetClassname() == "dota_item_wearable" then
            model:AddEffects(EF_NODRAW) -- Set model hidden
            table.insert(hero.hiddenWearables, model)
        end
        model = model:NextMovePeer()
    end
end

function ShowWearables( event )
  local hero = event.caster

  for i,v in pairs(hero.hiddenWearables) do
    v:RemoveEffects(EF_NODRAW)
  end
end