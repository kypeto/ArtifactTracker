--
-- TODO:
--  * auto-update artifact list
--  * whilelist / blacklist
--  * automatic detection of picked up artifacts
--  * detect and group duplicates
--
local addon, data = ...

-- Some arbitrary ArtifactTracker settings
local area          = "Stonefield"        -- default area
local index         = 71                  -- default artifact in area
local ARTIFACTS     = data.artifacts
local ARTIFACT_ICON = "Data\\UI\\item_icons\\scroll6a.dds"
local rgba_gold     = {255/255, 215/255, 0, 2/3}
local rgba_green    = {0, 0.25, 0, 1/2}
local rgba          = rgba_green

area  = "Freemarch"
index = 1

_ARTIFACTTRACKER = {}
local AT = _ARTIFACTTRACKER

local default_settings = {
  mmx        = 200,
  mmy        = 200,
  locked     = false,
  tracked    = {},
  fontsize   = 36,
  num_nodes  = 5,
  fade_time  = 2,
  cfgx       = 500,
  cfgy       = 200,
  trx        = -1,
  try        = -1,
  showcombat = true,
  version    = addon.toc.Version,
  relative   = false
}

local default_settings_node = {
  version = addon.toc.version
}

local SVLOADED = false
local ITEMS    = data.ITEMS
local LANG     = data.SYSLANG

local ICONS     = {}
local AT_ACTIVE = true
local prev_IUD  = false

local MESSAGE_STACK = {
}

local function MergeTable(o, n)
  for k,v in pairs(n) do
    if type(v) == "table" then
      if o[k] == nil then
        o[k] = {}
      end
      if type(o[k]) == 'table' then
        MergeTable(o[k], n[k])
      end
    else
      if o[k] == nil then
        o[k] = v
      end
    end
  end
end

function AT.ShowMessage(m)

  -- If message already exists, update time, then exit
  local tx = Inspect.Time.Real()
  local rq = true
  for k,v in pairs(MESSAGE_STACK) do
    if v.i == m.id then
      MESSAGE_STACK[k].t = nil
      rq = false
      break
    end
  end

  -- If message does not exist, add it on top (wtf?)
  if rq then

    -- TODO: remove
    print("Adding \"m\" to MESSAGE_STACK")
    print(Utility.Serialize.Full(m))

    table.insert(MESSAGE_STACK, 1, {
      i = m.id,
      t = nil,
      x = m.coordX,
      y = m.coordY,
      z = m.coordZ,
      n = m.description,
      d = 10})  -- original: 1000 (meters)
  end

  -- Trim list if it gets too big
  if #MESSAGE_STACK > 10 then
    table.remove(MESSAGE_STACK, 11)
  end

  -- TODO: remove
  print("MESSAGE_STACK:")
  print(Utility.Serialize.Full(MESSAGE_STACK))

end

function AT.Add(m)
  print("AT.Add")
  table.insert(MESSAGE_STACK, 1, {
    i = m.id,
    t = nil,
    x = m.coordX,
    y = m.coordY,
    z = m.coordZ,
    n = m.description,
    d = 10})  -- original: 1000 (meters)
end

function AT.Remove(i)
  print("AT.Remove")
  table.remove(MESSAGE_STACK, i)
end

function AT.Clear()
  print("AT.Clear")
  MESSAGE_STACK = {}
end

function AT.Event_Map_Remove(h, e)
  for ed,ev in pairs(e) do
    for k,v in pairs(MESSAGE_STACK) do
      if v.i == ed then
        if v.d <= 70 then
          MESSAGE_STACK[k].t = Inspect.Time.Real() - 100
        else
          MESSAGE_STACK[k].t = Inspect.Time.Real() +
            ArtifactTracker_Settings.fade_time
        end
        break
      end
    end
  end
end

function AT.Event_Map_Add(h, e)
  --for k,v in pairs(Inspect.Map.Detail(e)) do
  --  if ArtifactTracker_Settings.tracked[v.description] and AT_ACTIVE then
  --    AT.ShowMessage(v)
  --  end
  --  local res = AT.ALLITEMS[v.description]
  --  if res then
  --    local ix = string.format("%d.%d.%d", v.coordX, v.coordZ, v.coordY)
  --    if ArtifactTracker_Nodes[res][LIBZONECHANGE.currentZoneID] == nil then
  --      ArtifactTracker_Nodes[res][LIBZONECHANGE.currentZoneID] = {}
  --    end
  --    if
  --      ArtifactTracker_Nodes[res][LIBZONECHANGE.currentZoneID][ix] == nil
  --    then
  --      ArtifactTracker_Nodes[res][LIBZONECHANGE.currentZoneID][ix] =
  --        {x=v.coordX, z=v.coordZ, y=v.coordY, nodes = {} }
  --    end
  --    local lud = data.LOOKUP[v.description]
  --    ArtifactTracker_Nodes[res][LIBZONECHANGE.currentZoneID][ix].nodes[lud.k]
  --      = true
  --  end
  --end
end

function AT.DumpCurrentMap()
  -- TODO: remove
  print(Utility.Serialize.Full(Inspect.Map.Detail(Inspect.Map.List())))

  --for k,v in pairs(Inspect.Map.Detail(Inspect.Map.List())) do
  --  print(string.format(
  --    "%s %s,%s,%s",
  --    v.description,
  --    v.coordX,
  --    v.coordY,
  --    v.coordZ))
  --end
end

local math_sqrt = math.sqrt
local math_atan = math.atan2
local math_abs  = math.abs
local math_pi   = math.pi

-- XYZ maps to East,Up,South in the game
function AT.Distance(EUS1, EUS2)
  local dx = EUS2[1]-EUS1[1]
  local dy = EUS2[2]-EUS1[2]
  local dz = EUS2[3]-EUS1[3]
  return math_sqrt((dx^2)+(dy^2)+(dz^2))  -- distance
end

function AT.direction(dt)
  if dt >  180 then dt = dt-360 end
  if dt < -180 then dt = dt+360 end

  if     dt >= 169  then  d = "S"
  elseif dt >= 146  then  d = "SSW"
  elseif dt >= 124  then  d = "SW"
  elseif dt >= 101  then  d = "WSW"
  elseif dt >= 79   then  d = "W"
  elseif dt >= 56   then  d = "WNW"
  elseif dt >= 34   then  d = "NW"
  elseif dt >= 11   then  d = "NNW"
  elseif dt >= -11  then  d = "N"
  elseif dt >= -34  then  d = "NNE"
  elseif dt >= -56  then  d = "NE"
  elseif dt >= -79  then  d = "ENE"
  elseif dt >= -101 then  d = "E"
  elseif dt >= -124 then  d = "ESE"
  elseif dt >= -146 then  d = "SE"
  elseif dt >= -169 then  d = "SSE"
  else                    d = "S"
  end

  return {i="", l=d}
end

local CX_IMAGES = {
  ["E"]    = string.format("img/compass-E.png"),
  ["ENE"]  = string.format("img/compass-ENE.png"),
  ["ESE"]  = string.format("img/compass-ESE.png"),
  ["N"]    = string.format("img/compass-N.png"),
  ["NE"]   = string.format("img/compass-NE.png"),
  ["NNE"]  = string.format("img/compass-NNE.png"),
  ["NNW"]  = string.format("img/compass-NNW.png"),
  ["NW"]   = string.format("img/compass-NW.png"),
  ["S"]    = string.format("img/compass-S.png"),
  ["SE"]   = string.format("img/compass-SE.png"),
  ["SSE"]  = string.format("img/compass-SSE.png"),
  ["SSW"]  = string.format("img/compass-SSW.png"),
  ["SW"]   = string.format("img/compass-SW.png"),
  ["W"]    = string.format("img/compass-W.png"),
  ["WNW"]  = string.format("img/compass-WNW.png"),
  ["WSW"]  = string.format("img/compass-WSW.png"),

  ["eE"]   = string.format("img/Ecompass-E.png"),
  ["eENE"] = string.format("img/Ecompass-ENE.png"),
  ["eESE"] = string.format("img/Ecompass-ESE.png"),
  ["eN"]   = string.format("img/Ecompass-N.png"),
  ["eNE"]  = string.format("img/Ecompass-NE.png"),
  ["eNNE"] = string.format("img/Ecompass-NNE.png"),
  ["eNNW"] = string.format("img/Ecompass-NNW.png"),
  ["eNW"]  = string.format("img/Ecompass-NW.png"),
  ["eS"]   = string.format("img/Ecompass-S.png"),
  ["eSE"]  = string.format("img/Ecompass-SE.png"),
  ["eSSE"] = string.format("img/Ecompass-SSE.png"),
  ["eSSW"] = string.format("img/Ecompass-SSW.png"),
  ["eSW"]  = string.format("img/Ecompass-SW.png"),
  ["eW"]   = string.format("img/Ecompass-W.png"),
  ["eWNW"] = string.format("img/Ecompass-WNW.png"),
  ["eWSW"] = string.format("img/Ecompass-WSW.png")
}


local resort_req = false

-- Scans the minimap
function AT.ScanCurrentMap()

  -- TODO: remove
  print("Scanning current map.")

  if SVLOADED then
    for k,v in pairs(MESSAGE_STACK) do
      AT.UI.msgframes[k]:SetVisible(false)
    end
    MESSAGE_STACK = {}

    -- Scans for and adds selected types of items found on minimap
    --for k,v in pairs(Inspect.Map.Detail(Inspect.Map.List())) do
    --  if ArtifactTracker_Settings.tracked[v.description] then
    --    AT.ShowMessage(v)
    --  end
    --end

    -- TODO: remove
    -- Modification, add custom item (artifact)
    local artifact = {}
    artifact.id          = index
    artifact.description = area .. " Artifact " .. index
    artifact.coordX      = ARTIFACTS[area][index][1]      -- east direction
    artifact.coordY      = 1000                           -- up direction
    artifact.coordZ      = ARTIFACTS[area][index][2]      -- south direction
    print(string.format("Selected %q", artifact.description))
    AT.ShowMessage(artifact)

  end
end

local alpha       = 0
local rpt         = 0
local last_update = 0

function AT.Event_System_Update_Begin(h)

  -- When there are artifacts
  if #MESSAGE_STACK > 0 then
    local timenow = Inspect.Time.Real()

    -- Every 100ms
    if timenow - last_update > 0.1 then
      last_update = timenow

      -- Location and other information about the player
      local pd = Inspect.Unit.Detail("player")

      -- When relative direction setting is set to true
      if ArtifactTracker_Settings.relative then

        -- Update distance and direction to artifact
        if
          prev_IUD and
          prev_IUD.coordX and
          prev_IUD.coordY and
          prev_IUD.coordZ and
          pd and
          pd.coordX and
          pd.coordY and
          pd.coordZ
        then
          local p_dx      = prev_IUD.coordX - pd.coordX
          local p_dy      = prev_IUD.coordY - pd.coordY
          local p_dz      = prev_IUD.coordZ - pd.coordZ
          local p_heading = math_atan(p_dx, p_dz)*180/math_pi

          -- For each artifact in list
          for x, v in pairs(MESSAGE_STACK) do
            if
              prev_IUD.coordX ~= pd.coordX or
              prev_IUD.coordY ~= pd.coordY or
              prev_IUD.coordZ ~= pd.coordZ
            then
              -- Since height value is missing from the artifact data set we
              -- use the height value of the player instead.
              MESSAGE_STACK[x].y = pd.coordY
              local dx        = pd.coordX - MESSAGE_STACK[x].x
              local dy        = pd.coordY - MESSAGE_STACK[x].y
              local dz        = pd.coordZ - MESSAGE_STACK[x].z
              local d         = math_sqrt((dx^2)+(dy^2)+(dz^2))  -- distance
              local dr        = math_atan(dx, dz)*180/math_pi    -- direction
              local r_heading = dr-p_heading
              if     r_heading < -180 then r_heading = r_heading+360
              elseif r_heading >  360 then r_heading = r_heading-360
              end
              local c = AT.direction(r_heading).l
              -- If below
              if math.abs(pd.coordY - MESSAGE_STACK[x].y) > 10 then
                MESSAGE_STACK[x].ixn = "e"..c
              -- If above
              else
                MESSAGE_STACK[x].ixn = c
              end
              -- Update distance
              MESSAGE_STACK[x].d = d
            end
          end
        end
      -- When relative direction setting is set to false
      else
        -- For each artifact in list
        for x, v in pairs(MESSAGE_STACK) do
          if pd and pd.coordX and pd.coordZ then
            -- Since height value is missing from the artifact data set we
            -- use the height value of the player instead.
            MESSAGE_STACK[x].y = pd.coordY
            local dx = pd.coordX - MESSAGE_STACK[x].x
            local dy = pd.coordY - MESSAGE_STACK[x].y
            local dz = pd.coordZ - MESSAGE_STACK[x].z
            local d  = math_sqrt((dx^2)+(dy^2)+(dz^2))  -- distance
            local dr = math_atan(dx, dz)*180/math_pi    -- direction
            local c  = AT.direction(dr).l
            -- If below
            if math.abs(pd.coordY - MESSAGE_STACK[x].y) > 10 then
              MESSAGE_STACK[x].ixn = "e"..c
            -- If above
            else
              MESSAGE_STACK[x].ixn = c
            end
            -- Update distance
            MESSAGE_STACK[x].d = d
          end
        end
      end

      -- Alphabetical order
      table.sort(MESSAGE_STACK, function(a, b) return a.d < b.d end)

      -- Display in HUD
      local t = Inspect.Time.Real()
      local tf
      for x = ArtifactTracker_Settings.num_nodes, 1, -1 do
        if MESSAGE_STACK[x] then
          if MESSAGE_STACK[x].t ~= nil then
            tf = t-MESSAGE_STACK[x].t
          else
            tf = 0
          end
          if tf > 2 then
            table.remove(MESSAGE_STACK, x)
            AT.UI.msgframes[x]:SetVisible(false)
            resort_req = true
          else
            if tf > 0 then
              alpha = (2-tf)/2
              AT.UI.msgframes[x]:SetAlpha(alpha)
              AT.UI.icons[x]:SetAlpha(alpha)
              AT.UI.dir[x]:SetAlpha(alpha)
            else
              AT.UI.msgframes[x]:SetAlpha(1)
              AT.UI.icons[x]:SetAlpha(1)
              AT.UI.dir[x]:SetAlpha(1)
            end
            if AT.UI.icons[x].ci ~= MESSAGE_STACK[x].n then
              --AT.UI.icons[x]:SetTexture("Rift", ARTIFACT_ICON)  -- ugly
              --AT.UI.icons[x].ci = MESSAGE_STACK[x].n
            end

            if
              AT.UI.dir[x].ci ~= MESSAGE_STACK[x].ixn and
              CX_IMAGES[MESSAGE_STACK[x].ixn]
            then
              AT.UI.dir[x]:SetTexture(
                addon.identifier,
                CX_IMAGES[MESSAGE_STACK[x].ixn])
              AT.UI.dir[x].ci = MESSAGE_STACK[x].ixn
            end

            -- Show distance to artifact if longer than 10m
            if MESSAGE_STACK[x].d > 10 then
              AT.UI.msgframes[x]:SetText(string.format(
                "%s [%dm]",
                MESSAGE_STACK[x].n,
                MESSAGE_STACK[x].d))
            else
              AT.UI.msgframes[x]:SetText(string.format(
                "%s",
                MESSAGE_STACK[x].n))
            end
            AT.UI.msgframes[x]:SetVisible(true)

          end
        else
          AT.UI.msgframes[x]:SetVisible(false)
        end
      end
      if resort_req == true then
        if #MESSAGE_STACK > 0 then
          local newdtls = {}
          local updt = false
          for x = 1, ArtifactTracker_Settings.num_nodes do
            if MESSAGE_STACK[x] then
              table.insert(newdtls, MESSAGE_STACK[x])
              updt = true
            end
          end
          if updt then
            MESSAGE_STACK = newdtls
          end
        end
        resort_req = false
      end
      prev_IUD = pd
    end
  end
end

function AT.CreateConfig(k, v)
  local c = UI.CreateFrame("RiftCheckbox", "cb"..k, AT.UI.config)
  c:SetWidth(24)
  c:SetHeight(24)
  c:SetChecked(false)
  c:SetLayer(15)
  c:EventAttach(Event.UI.Checkbox.Change, function(self, h)
    if c:GetChecked() then
      ArtifactTracker_Settings.tracked[v.name[LANG]] = true
    else
      ArtifactTracker_Settings.tracked[v.name[LANG]] = nil
    end
    AT.ScanCurrentMap()
  end, "Event.UI.Checkbox.Change")
  local i = UI.CreateFrame("Texture", "i"..k, AT.UI.config)
  i:SetWidth(24)
  i:SetHeight(24)
  i:SetTexture("Rift", v.icon)
  i:SetPoint("TOPLEFT", c, "TOPRIGHT", 2, 0)
  i:SetLayer(15)
  local t = UI.CreateFrame("Text", "t"..k, AT.UI.config)
  t:SetFontSize(12)
  t:SetText(v.name[LANG])
  t:SetPoint("CENTERLEFT", i, "CENTERRIGHT", 2, 0)
  t:SetLayer(15)
  return c, i, t
end


--
-- User interface setup: Diamond widget, Configuration screen, HUD compass list
--
function AT.BuildUI()
  AT.context = UI.CreateContext(addon.identifier)

  AT.UI = {
    msgframes = {},
    icons     = {},
    dir       = {},
    configchk = {},
  }

  -- Diamond widget
  AT.UI.mm = UI.CreateFrame("Texture", "AT.UI.mm", AT.context)
  AT.UI.mm:SetHeight(36)
  AT.UI.mm:SetWidth(36)

  -- Diamond widget, open configuration window (if not locked)
  AT.UI.mm:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
    if ArtifactTracker_Settings.locked or MINIMAPDOCKER ~= nil then
      AT.UI.config:SetVisible(not AT.UI.config:GetVisible())
      AT.UI.anchor:SetVisible(AT.UI.config:GetVisible())
    end
  end, "Event.UI.Input.Mouse.Left.Click")

  -- Diamond widget, drag and drop placement
  AT.UI.mm:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
    if MINIMAPDOCKER == nil and ArtifactTracker_Settings.locked == false then
      self.MouseDown = true
      local mouseData = Inspect.Mouse()
      self.sx = mouseData.x - AT.UI.mm:GetLeft()
      self.sy = mouseData.y - AT.UI.mm:GetTop()
    end
  end, "Event.UI.Input.Mouse.Left.Down")

  if MINIMAPDOCKER == nil then
    -- Configuration window
    AT.UI.mm:EventAttach(Event.UI.Input.Mouse.Left.Up, function(self, h)
      self.MouseDown = false
      if ArtifactTracker_Settings.locked == false then
        ArtifactTracker_Settings.mmx = AT.UI.mm:GetLeft()
        ArtifactTracker_Settings.mmy = AT.UI.mm:GetTop()
      end
    end, "Event.UI.Input.Mouse.Left.Up")

    -- Diamond widget, drag and drop placement
    AT.UI.mm:EventAttach(Event.UI.Input.Mouse.Cursor.Move, function(self, h)
      if ArtifactTracker_Settings.locked == false then
        if self.MouseDown then
          local nx, ny
          local mouseData = Inspect.Mouse()
          nx = mouseData.x - self.sx
          ny = mouseData.y - self.sy
          AT.UI.mm:SetPoint("TOPLEFT", UIParent, "TOPLEFT", nx, ny)
        end
      end
    end, "Event.UI.Input.Mouse.Cursor.Move")

    -- Diamond widget, toggle placeable/clickable state
    AT.UI.mm:EventAttach(Event.UI.Input.Mouse.Right.Click, function(self, h)
      self.MouseDown = false
      ArtifactTracker_Settings.locked = not ArtifactTracker_Settings.locked
      if ArtifactTracker_Settings.locked == false then
        AT.UI.mm:SetTexture(addon.identifier, "img/mm_button_bw.png")
      else
        AT.UI.mm:SetTexture(addon.identifier, "img/mm_button.png")
      end
    end, "Event.UI.Input.Mouse.Right.Click")
  end


  --
  -- Config window
  --

  -- Window decoration bar [ Artifact Tracker Configuration ]
  AT.UI.config = UI.CreateFrame("RiftWindow", "AT.UI.config", AT.context)
  AT.UI.config:SetVisible(false)
  AT.UI.config:SetLayer(1)
  AT.UI.config:SetTitle("Artifact Tracker Configuration")

  -- Window close button (X)
  AT.UI.close = UI.CreateFrame("RiftButton", "AT.UI.close", AT.UI.config)
  AT.UI.close:SetSkin("close")
  AT.UI.close:SetPoint("TOPRIGHT", AT.UI.config, "TOPRIGHT", -8, 16)
  AT.UI.close:SetLayer(3)
  
  local cfgborder = AT.UI.config:GetBorder()

  AT.UI.close:EventAttach(Event.UI.Input.Mouse.Left.Click, function(self, h)
    AT.UI.config:SetVisible(false)
    AT.UI.anchor:SetVisible(false)
  end, "Event.UI.Input.Mouse.Left.Click")

  cfgborder:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
    local mouseData = Inspect.Mouse()
    self.sx = mouseData.x - AT.UI.config:GetLeft()
    self.sy = mouseData.y - AT.UI.config:GetTop()
    self.MouseDown = true
  end, "Event.UI.Input.Mouse.Left.Down")

  cfgborder:EventAttach(Event.UI.Input.Mouse.Left.Up, function(self, h)
    self.MouseDown = false
    ArtifactTracker_Settings.cfgx = AT.UI.config:GetLeft()
    ArtifactTracker_Settings.cfgy = AT.UI.config:GetTop()
  end, "Event.UI.Input.Mouse.Left.Up")

  cfgborder:EventAttach(Event.UI.Input.Mouse.Cursor.Move, function(self, h)
    if self.MouseDown then
      local nx, ny
      local mouseData = Inspect.Mouse()
      nx = mouseData.x - self.sx
      ny = mouseData.y - self.sy
      AT.UI.config:SetPoint("TOPLEFT", UIParent, "TOPLEFT", nx, ny)
    end
  end, "Event.UI.Input.Mouse.Cursor.Move")

  --local frm_metal  = nil
  --local frm_fish   = nil
  local frm_areas = nil

  local frm_p = nil
  local txt_w = 0

  ---- List of minerals
  --for k, v in pairs(ITEMS["MINING"]) do
  --  local c, i, t = AT.CreateConfig(k, v)
  --  AT.UI.configchk[v.name[LANG]] = {c=c, i=i, t=t}
  --  txt_w = math.max(txt_w, t:GetWidth())

  --  if frm_p == nil then
  --    frm_metal = c
  --  else
  --    c:SetPoint("TOPLEFT", frm_p, "BOTTOMLEFT", 0, 0)
  --  end

  --  frm_p = c
  --  ICONS[v.name[LANG]] = v.icon
  --  AT.ALLITEMS[v.name[LANG]] = IDX_ORE
  --end

  ---- List of fish
  --frm_p = nil
  --for k, v in pairs(ITEMS["FISH"]) do
  --  local c, i, t = AT.CreateConfig(k, v)
  --  AT.UI.configchk[v.name[LANG]] = {c=c, i=i, t=t}
  --  txt_w = math.max(txt_w, t:GetWidth())

  --  if frm_p == nil then
  --    frm_fish = c
  --  else
  --    c:SetPoint("TOPLEFT", frm_p, "BOTTOMLEFT", 0, 0)
  --  end

  --  frm_p = c
  --  ICONS[v.name[LANG]] = v.icon
  --  AT.ALLITEMS[v.name[LANG]] = IDX_FISH
  --end

  -- List of areas
  for k,v in pairs(ARTIFACTS) do
    local c, i, t

    c = UI.CreateFrame("RiftCheckbox", "cb"..k, AT.UI.config)
    c:SetWidth(24)
    c:SetHeight(24)
    c:SetChecked(false)
    c:SetLayer(15)
    c:EventAttach(Event.UI.Checkbox.Change, function(self, h)
      AT.ScanCurrentMap()
    end, "Event.UI.Checkbox.Change")

    local i = UI.CreateFrame("Texture", "i"..k, AT.UI.config)
    i:SetWidth(24)
    i:SetHeight(24)
    --i:SetTexture("Rift", ARTIFACT_ICON)  --v.icon)
    i:SetPoint("TOPLEFT", c, "TOPRIGHT", 2, 0)
    i:SetLayer(15)

    local t = UI.CreateFrame("Text", "t"..k, AT.UI.config)
    t:SetFontSize(12)
    t:SetText(k)
    t:SetPoint("CENTERLEFT", i, "CENTERRIGHT", 2, 0)
    t:SetLayer(15)

    txt_w = math.max(txt_w, t:GetWidth())

    if frm_p == nil then
      frm_areas = c
    else
      c:SetPoint("TOPLEFT", frm_p, "BOTTOMLEFT", 0, 0)
    end

    frm_p = c;
  end

  for k, v in pairs(AT.UI.configchk) do
    v.t:SetWidth(txt_w)
  end

  local trl, trr, trt, trb
  trl, trt, trr, trb = AT.UI.config:GetTrimDimensions()

  -- Placement of material lists
  local colwidth = 52 + txt_w
  frm_areas:SetPoint("TOPLEFT", AT.UI.config, "TOPLEFT", trl, trt)

  -- Configuration window height
  AT.UI.config:SetHeight(800)

  local frmht = 0  -- number of items in the list
  for k,v in pairs(ARTIFACTS) do
    frmht = frmht + 1
  end

  -- Configuration window width
  AT.UI.config:SetWidth((colwidth*4) + 10 + trl + trr)

  AT.UI.cfgoptions = UI.CreateFrame("Frame", "AT.UI.cfgoptions", AT.UI.config)
  AT.UI.cfgoptions:SetWidth((colwidth*4) + 10)
  AT.UI.cfgoptions:SetHeight(60+40)  -- MOD +40
  AT.UI.cfgoptions:SetLayer(1)
  AT.UI.cfgoptions:SetPoint(
    "TOPLEFT",
    AT.UI.config,
    "TOPLEFT",
    trl,
    ((24*frmht) + 8 + trt))


  --
  -- Config -> "Number of nodes"
  --

  -- Text
  AT.UI.l_nodes = UI.CreateFrame("Text", "AT.UI.l_nodes", AT.UI.cfgoptions)
  AT.UI.l_nodes:SetPoint("TOPLEFT", AT.UI.cfgoptions, "TOPLEFT", 2, 2)
  AT.UI.l_nodes:SetFontSize(14)
  AT.UI.l_nodes:SetLayer(5)
  AT.UI.l_nodes:SetText("Number of bananas to display: ")

  -- Slider
  AT.UI.s_nodes = UI.CreateFrame(
    "RiftSlider",
    "AT.UI.s_nodes",
    AT.UI.cfgoptions)
  AT.UI.s_nodes:SetLayer(2)
  AT.UI.s_nodes:SetWidth(math.floor(colwidth*1.5))
  AT.UI.s_nodes:SetRange(1, 10)
  AT.UI.s_nodes:SetPoint("TOPLEFT", AT.UI.l_nodes, "BOTTOMLEFT", 16, 0)
  AT.UI.s_nodes:EventAttach(Event.UI.Slider.Change, function(self, h)
    ArtifactTracker_Settings.num_nodes = AT.UI.s_nodes:GetPosition()
    AT.UI.l_nodes:SetText(
      string.format(
        "Number of artifacts to display: %d",
        ArtifactTracker_Settings.num_nodes))
    AT.ScanCurrentMap()
  end, "Event.UI.Slider.Change")


  --
  -- Config -> "Show in combat"
  --

  -- Check box
  AT.UI.c_combat = UI.CreateFrame(
    "RiftCheckbox",
    "AT.UI.c_combat",
    AT.UI.cfgoptions)
  AT.UI.c_combat:SetWidth(24)
  AT.UI.c_combat:SetHeight(24)
  AT.UI.c_combat:SetLayer(5)
  AT.UI.c_combat:SetPoint("TOPLEFT", AT.UI.l_nodes, "BOTTOMLEFT", 0, 14)
  AT.UI.c_combat:EventAttach(Event.UI.Checkbox.Change, function(self, h)
    if AT.UI.c_combat:GetChecked() then
      ArtifactTracker_Settings.showcombat = true
    else
      ArtifactTracker_Settings.showcombat = false
    end
  end, "Event.UI.Checkbox.Change")

  -- Text
  AT.UI.l_combat = UI.CreateFrame("Text", "AT.UI.l_combat", AT.UI.cfgoptions)
  AT.UI.l_combat:SetFontSize(14)
  AT.UI.l_combat:SetLayer(15)
  AT.UI.l_combat:SetText("Show in combat")
  AT.UI.l_combat:SetPoint("CENTERLEFT", AT.UI.c_combat, "CENTERRIGHT", 2, 0)


  --
  -- Config -> "Show relative"
  --

  -- Check box
  AT.UI.c_relative = UI.CreateFrame(
    "RiftCheckbox",
    "AT.UI.c_relative",
    AT.UI.cfgoptions)
  AT.UI.c_relative:SetWidth(24)
  AT.UI.c_relative:SetHeight(24)
  AT.UI.c_relative:SetLayer(5)
  AT.UI.c_relative:SetPoint("TOPLEFT", AT.UI.c_combat, "BOTTOMLEFT", 0, 14)
  AT.UI.c_relative:EventAttach(Event.UI.Checkbox.Change, function(self, h)
    ArtifactTracker_Settings.relative = AT.UI.c_relative:GetChecked()
  end, "Event.UI.Checkbox.Change")

  -- Text
  AT.UI.l_relative = UI.CreateFrame(
    "Text",
    "AT.UI.l_relative",
    AT.UI.cfgoptions)
  AT.UI.l_relative:SetFontSize(14)
  AT.UI.l_relative:SetLayer(15)
  AT.UI.l_relative:SetText("Show relative direction arrows")
  AT.UI.l_relative:SetPoint("CENTERLEFT", AT.UI.c_relative, "CENTERRIGHT", 2, 0)


  --
  -- Config -> Scaling area / Bottom frame with header
  --

  -- Area/Background
  AT.UI.configscale = UI.CreateFrame("Frame", "AT.UI.configscale", AT.UI.config)
  AT.UI.configscale:SetWidth((colwidth*4) + 10)
  AT.UI.configscale:SetHeight(48)
  AT.UI.configscale:SetLayer(1)
  AT.UI.configscale:SetBackgroundColor(rgba[1], rgba[2], rgba[3], rgba[4])
  AT.UI.configscale:SetPoint("TOPLEFT", AT.UI.cfgoptions, "BOTTOMLEFT", 0, 8)
  AT.UI.config:SetHeight((24 * frmht) + 124 +40 + trt + trb)  -- MOD +40

  AT.UI.configscale_ctr = UI.CreateFrame(
    "Frame",
    "AT.UI.configscale_ctr",
    AT.UI.config)
  AT.UI.configscale_ctr:SetPoint("CENTER", AT.UI.configscale, "CENTER", 0, 0)
  AT.UI.configscale_ctr:SetLayer(2)

  -- Mouse wheel scroll up
  AT.UI.configscale:EventAttach(
    Event.UI.Input.Mouse.Wheel.Forward,
    function(self, h)
      if ArtifactTracker_Settings.fontsize <= 128 then
        ArtifactTracker_Settings.fontsize = ArtifactTracker_Settings.fontsize+1
        AT.ResizeElements()
      end
    end,
    "Event.UI.Input.Mouse.Wheel.Forward")

  -- Mouse wheel scrool down
  AT.UI.configscale:EventAttach(
    Event.UI.Input.Mouse.Wheel.Back,
    function(self, h)
      if ArtifactTracker_Settings.fontsize >= 12 then
        ArtifactTracker_Settings.fontsize = ArtifactTracker_Settings.fontsize-1
        AT.ResizeElements()
      end
    end,
    "Event.UI.Input.Mouse.Wheel.Back")

  -- Direction arrow
  --AT.UI.cs_d = UI.CreateFrame("Texture", "AT.UI.cs_d", AT.UI.config)
  --AT.UI.cs_d:SetPoint("TOPLEFT", AT.UI.configscale_ctr, "TOPLEFT", 0, 0)
  --AT.UI.cs_d:SetTexture(addon.identifier, "img/compass-N.png")
  --AT.UI.cs_d:SetLayer(5)

  -- Material icon
  --AT.UI.cs_i = UI.CreateFrame("Texture", "AT.UI.cs_i", AT.UI.config)
  --AT.UI.cs_i:SetPoint("TOPLEFT", AT.UI.cs_d, "TOPRIGHT", 0, 0)
  --AT.UI.cs_i:SetTexture("Rift", "Data\\UI\\item_icons\\ore02.dds")
  --AT.UI.cs_i:SetLayer(5)
  AT.UI.cs_i = UI.CreateFrame("Texture", "AT.UI.cs_i", AT.UI.config)
  AT.UI.cs_i:SetPoint("TOPLEFT", AT.UI.configscale_ctr, "TOPLEFT", 0, 0)
  AT.UI.cs_i:SetTexture("Rift", ARTIFACT_ICON)
  AT.UI.cs_i:SetLayer(5)

  -- Text
  AT.UI.cs_t = UI.CreateFrame("Text", "AT.UI.cs_t", AT.UI.config)
  AT.UI.cs_t:SetPoint("CENTERLEFT", AT.UI.cs_i, "CENTERRIGHT", 0, 0)
  AT.UI.cs_t:SetText("Artifact Tracker")
  AT.UI.cs_t:SetLayer(5)


  local fht = 0

  for x=1,10 do
    AT.UI.msgframes[x] = UI.CreateFrame("Text", "AT.msgframe", AT.context)
    AT.UI.msgframes[x]:SetFontColor(1, 1, 1, 1)
    AT.UI.icons[x] = UI.CreateFrame("Texture", "AT.icon", AT.UI.msgframes[x])
    AT.UI.icons[x]:SetPoint("TOPRIGHT", AT.UI.msgframes[x], "TOPLEFT")
    AT.UI.icons[x].ci = ""
    AT.UI.dir[x] = UI.CreateFrame("Texture", "AT.icon", AT.UI.msgframes[x])
    AT.UI.dir[x]:SetPoint("TOPRIGHT", AT.UI.icons[x], "TOPLEFT")
    AT.UI.dir[x].ci = ""

    if x > 1 then
      AT.UI.msgframes[x]:SetPoint(
        "TOPLEFT",
        AT.UI.msgframes[x-1],
        "BOTTOMLEFT",
        0,
        0)
    end
  end

  AT.UI.FRAMESIZE = UI.CreateFrame("Text", "AT.UI.FRAMESIZE", AT.context)
  AT.UI.FRAMESIZE:SetVisible(false)
  AT.UI.FRAMESIZE:SetText("QQqq")
  AT.UI.FRAMESIZE:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -256, -256)

  -- HUD -> Header (during placement)
  AT.UI.anchor = UI.CreateFrame("Text", "AT.UI.anchor", AT.context)
  AT.UI.anchor:SetVisible(false)
  AT.UI.anchor:SetFontSize(14)
  AT.UI.anchor:SetText("Artifact Tracker")
  AT.UI.anchor:SetBackgroundColor(rgba[1], rgba[2], rgba[3], rgba[4])
  AT.UI.anchor:SetFontColor(1, 1, 1, 1)

  -- HUD size, mouse wheel scroll up
  AT.UI.anchor:EventAttach(Event.UI.Input.Mouse.Wheel.Forward, function(self, h)
    if ArtifactTracker_Settings.fontsize <= 128 then
      ArtifactTracker_Settings.fontsize = ArtifactTracker_Settings.fontsize+1
      AT.ResizeElements()
    end
  end, "Event.UI.Input.Mouse.Wheel.Forward")

  -- HUD size, mouse wheel scrool down
  AT.UI.anchor:EventAttach(Event.UI.Input.Mouse.Wheel.Back, function(self, h)
    if ArtifactTracker_Settings.fontsize >= 12 then
      ArtifactTracker_Settings.fontsize = ArtifactTracker_Settings.fontsize-1
      AT.ResizeElements()
    end
  end, "Event.UI.Input.Mouse.Wheel.Back")

  -- HUD placement, press
  AT.UI.anchor:EventAttach(Event.UI.Input.Mouse.Left.Down, function(self, h)
    self.MouseDown = true
    local mouseData = Inspect.Mouse()
    self.sx = mouseData.x - AT.UI.msgframes[1]:GetLeft()
    self.sy = mouseData.y - AT.UI.msgframes[1]:GetTop()
  end, "Event.UI.Input.Mouse.Left.Down")

  -- HUD placement, move
  AT.UI.anchor:EventAttach(Event.UI.Input.Mouse.Cursor.Move, function(self, h)
    if self.MouseDown then
      local nx, ny
      local mouseData = Inspect.Mouse()
      nx = mouseData.x - self.sx
      ny = mouseData.y - self.sy
      AT.UI.msgframes[1]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", nx, ny)
    end
  end, "Event.UI.Input.Mouse.Cursor.Move")

  -- HUD placement, release
  AT.UI.anchor:EventAttach(Event.UI.Input.Mouse.Left.Up, function(self, h)
    if self.MouseDown then
      self.MouseDown = false
    end
    ArtifactTracker_Settings.trx = AT.UI.msgframes[1]:GetLeft()
    ArtifactTracker_Settings.try = AT.UI.msgframes[1]:GetTop()
  end, "Event.UI.Input.Mouse.Left.Up")

end

function AT.Event_Addon_SavedVariables_Load_End(h, a)
  if a == addon.identifier then
    if ArtifactTracker_Settings == nil then
      ArtifactTracker_Settings = {}
    end

    MergeTable(ArtifactTracker_Settings, default_settings)

    if MINIMAPDOCKER then
      MINIMAPDOCKER.Register(addon.identifier, AT.UI.mm)
      AT.UI.mm:SetTexture(addon.identifier, "img/mm_button.png")
    else
      AT.UI.mm:SetPoint(
        "TOPLEFT",
        UIParent,
        "TOPLEFT",
        ArtifactTracker_Settings.mmx,
        ArtifactTracker_Settings.mmy)
      if ArtifactTracker_Settings.locked then
        AT.UI.mm:SetTexture(addon.identifier, "img/mm_button.png")
      else
        AT.UI.mm:SetTexture(addon.identifier, "img/mm_button_bw.png")
      end
    end

    AT.ResizeElements()

    if ArtifactTracker_Settings.trx == -1 then
      AT.UI.msgframes[1]:SetPoint("TOPLEFT", UIParent, "CENTER", 0, -100)
      ArtifactTracker_Settings.trx = AT.UI.msgframes[1]:GetLeft()
      ArtifactTracker_Settings.try = AT.UI.msgframes[1]:GetTop()
    else
      AT.UI.msgframes[1]:SetPoint(
        "TOPLEFT",
        UIParent,
        "TOPLEFT",
        ArtifactTracker_Settings.trx,
        ArtifactTracker_Settings.try)
    end

    for k, v in pairs(ArtifactTracker_Settings.tracked) do
      if AT.UI.configchk[k] then
        AT.UI.configchk[k].c:SetChecked(true)
      end
    end

    AT.UI.config:SetPoint(
      "TOPLEFT",
      UIParent,
      "TOPLEFT",
      ArtifactTracker_Settings.cfgx,
      ArtifactTracker_Settings.cfgy)

    local nn = ArtifactTracker_Settings.num_nodes
    AT.UI.s_nodes:SetPosition(2)
    AT.UI.s_nodes:SetPosition(nn)
    local ft = ArtifactTracker_Settings.fade_time
    --AT.UI.s_duration:SetPosition(2)
    --AT.UI.s_duration:SetPosition(ft)
    AT.UI.c_combat:SetChecked(ArtifactTracker_Settings.showcombat)
    AT.UI.c_relative:SetChecked(ArtifactTracker_Settings.relative)
    SVLOADED = true

    AT.ScanCurrentMap()

    Command.Event.Attach(Event.Map.Add, AT.Event_Map_Add, "Event.Map.Add")

    Command.Event.Attach(
      Event.Map.Remove,
      AT.Event_Map_Remove,
      "Event.Map.Remove")
    
    LibVersionCheck.register(addon.toc.Identifier, addon.toc.Version)
  end
end

function AT.ResizeElements()
  AT.UI.FRAMESIZE:SetFontSize(ArtifactTracker_Settings.fontsize)
  AT.UI.fht = AT.UI.FRAMESIZE:GetHeight()

  for x=1,10 do
    AT.UI.msgframes[x]:SetFontSize(ArtifactTracker_Settings.fontsize)
    AT.UI.icons[x]:SetWidth(AT.UI.fht)
    AT.UI.icons[x]:SetHeight(AT.UI.fht)
    AT.UI.dir[x]:SetWidth(AT.UI.fht)
    AT.UI.dir[x]:SetHeight(AT.UI.fht)
  end

  AT.UI.anchor:SetPoint(
    "BOTTOMLEFT",
    AT.UI.msgframes[1],
    "TOPLEFT",
    -(AT.UI.fht*2),
    0)
  AT.UI.anchor:SetWidth(AT.UI.fht * 8)

  -- Direction
  --AT.UI.cs_d:SetWidth(AT.UI.fht)
  --AT.UI.cs_d:SetHeight(AT.UI.fht)
  -- Icon
  AT.UI.cs_i:SetWidth(AT.UI.fht)
  AT.UI.cs_i:SetHeight(AT.UI.fht)
  -- Text
  AT.UI.cs_t:SetFontSize(ArtifactTracker_Settings.fontsize)
  AT.UI.configscale_ctr:SetHeight(AT.UI.fht)
  AT.UI.configscale_ctr:SetWidth(AT.UI.fht*10)
end

function AT.Event_System_Secure_Enter(h)
  if ArtifactTracker_Settings.showcombat == false then
    AT_ACTIVE = false
    for k,v in pairs(MESSAGE_STACK) do
      MESSAGE_STACK[k].t = 0
    end
  end
end

function AT.Event_System_Secure_Leave(h)
  if ArtifactTracker_Settings.showcombat == false then
    AT_ACTIVE = true
    AT.ScanCurrentMap()
  end
end


--
-- "Command line"
--
function AT.Command_Slash_Register(h, args)
  local r = {}

  for token in string.gmatch(args, "[^%s]+") do
    table.insert(r, token)
  end

  if r[1] == nil then
    print("Welcome to Artifact Tracker, an addon that will help you complete"..
    " the game 100% or make you rich. Try /at help for further instructions.");

  elseif r[1] == "help" then
    print("Valid commands are:")
    print("/at dump artifact\tCurrent artifact information.")
    print("/at dump database\tArtifact count per area.")
    print("/at dump map     \tCurrent minimap information.")
    print("/at dump player  \tPlayer information.")
    print("/at area <\"\">  \tSelect area to track artifacts in.")
    print("/at scan           \tScan and select the nearest artifact.")
    print("/at set <#>      \tSelect which artifact to track.")
    print("/at add <#>      \tSelect an additional artifact to track.")
    print("/at remove <#>   \tRemove one artifact from the list.")
    print("/at clear          \tClear all tracking entries.")
    print("/at reset         \tReset addon to default settings.")
    print("")

  elseif r[1] == "area" then
    if ARTIFACTS[r[2]] == nil then
      print("Error: Invalid area selected. Try \"/at dump database\"")
    else
      area = r[2]
      print("Area sucessfully set to:", area)
    end

  elseif r[1] == "dump" then
    if r[2] == nil then
      print("Error: No second argument provided. Try \"/at help\".")
    elseif r[2] == "artifact" or r[2] == "a" then
      print("Current artifact:")
      print(Utility.Serialize.Full(artifact))
    elseif r[2] == "database" or r[2] == "db" or r[2] == "d" then
      print("Current artifact database:")
      for k,v in pairs(ARTIFACTS) do
        --print("AreaName,NumArtifacts:", k, "\t", #v)
        print(string.format("Count,Area:  %3d \t%-18s", #v, k))
      end
      print("")
      --print(Utility.Serialize.Full(artifact))
    elseif r[2] == "map" or r[2] == "m" then
      print("Current map:")
      AT.DumpCurrentMap()
    elseif r[2] == "player" or r[2] == "p" then
      local pd = Inspect.Unit.Detail("player")
      print("Player:")
      print(Utility.Serialize.Full(pd))
    end

  elseif r[1] == "scan" then
    -- TODO: reimplement and simplify
    local pd          = Inspect.Unit.Detail("player")
    local closest     = 999999
    local close       = 999999
    local distance    = nil
    local cur_index   = 0
    local best_index  = 0
    local close_index = 0
    for k,v in pairs(ARTIFACTS[area]) do
      cur_index = cur_index + 1
      distance  = AT.Distance(
        {v[1], pd.coordY, v[2]},
        {pd.coordX, pd.coordY, pd.coordZ})
      print("k,v,d:", k, Utility.Serialize.Inline(v), distance)
      if distance == nil then
        print("Error: could not calculate distance.")
        print(Utility.Serialize.Inline(pd))
        print(Utility.Serialize.Inline(v))
        break
      end
      if distance > 50 and distance < close then
        close = distance
        close_index = cur_index
      end
      if distance < closest then
        print("closer")
        closest    = distance
        best_index = cur_index
      end
    end
    if close_index == 0 then
      print("Scanning done. No close artifact found.")
    else
      index = close_index
      AT.ScanCurrentMap()
      print("Scanning done. Close artifact: ", close_index)
    end
    if best_index == 0 then
      print("Scanning done. No closest artifact found.")
    else
      --index = best_index
      --AT.ScanCurrentMap()
      print("Scanning done. Closest artifact: ", best_index)
    end

  elseif r[1] == "set" then
    if r[2] == nil then
      print("Error: No second argument provided. Try /at help.")
    end
    index = tonumber(r[2])
    if index == nil then
      print("Error: Invalid argument to \"set\".")
    else
      print("Artifact index sucessfully set to:", index)
      AT.ScanCurrentMap()
    end

  elseif r[1] == "add" then
    local index = tonumber(r[2])
    if index == nil then
      print("Error: Invalid argument to \"add\".")
    else
      local artifact = {}
      artifact.id          = index
      artifact.description = area .. " Artifact " .. index
      artifact.coordX      = ARTIFACTS[area][index][1]      -- east direction
      artifact.coordY      = 1000                           -- up direction
      artifact.coordZ      = ARTIFACTS[area][index][2]      -- south direction
      print(string.format("Added %q", artifact.description))
      AT.Add(artifact)
    end

  elseif r[1] == "remove" then
    local index = tonumber(r[2])
    if index == nil then
      print("Error: Invalid argument to \"remove\".")
    else
      AT.Remove(i)
    end

  elseif r[1] == "clear" then
    AT.Clear()

  elseif r[1] == "reset" then
    if MINIMAPDOCKER then
      print("Not resetting button position. Location manged by Docker.")
    else
      ArtifactTracker_Settings.mmx = 100
      ArtifactTracker_Settings.mmy = 100

      print("Resetting location of control button to 100,100")
      AT.UI.mm:SetPoint(
        "TOPLEFT",
        UIParent,
        "TOPLEFT",
        ArtifactTracker_Settings.mmx,
        ArtifactTracker_Settings.mmy)
    end

    print("Resetting location of tracker listing to 200,100")
    ArtifactTracker_Settings.trx = 200
    ArtifactTracker_Settings.try = 100
    AT.UI.msgframes[1]:SetPoint(
      "TOPLEFT",
      UIParent,
      "TOPLEFT",
      ArtifactTracker_Settings.trx,
      ArtifactTracker_Settings.try)

    print("Resetting location of config screen to 300,300")
    ArtifactTracker_Settings.cfgx = 300
    ArtifactTracker_Settings.cfgy = 300
    AT.UI.config:SetPoint(
      "TOPLEFT",
      UIParent,
      "TOPLEFT",
      ArtifactTracker_Settings.cfgx,
      ArtifactTracker_Settings.cfgy)

  else
    print("Unrecognized command.")

  end
end


--
-- "Main"
--

AT.BuildUI()

Command.Event.Attach(
  Event.System.Update.Begin,
  AT.Event_System_Update_Begin,
  "Event.System.Update.Begin")

Command.Event.Attach(
  Event.Addon.SavedVariables.Load.End,
  AT.Event_Addon_SavedVariables_Load_End,
  "Event.Addon.SavedVariables.Load.End")

Command.Event.Attach(
  Event.System.Secure.Leave,
  AT.Event_System_Secure_Leave,
  "Event.System.Secure.Leave")

Command.Event.Attach(
  Event.System.Secure.Enter,
  AT.Event_System_Secure_Enter,
  "Event.System.Secure.Enter")

Command.Event.Attach(
  Command.Slash.Register("artifacttracker"),
  AT.Command_Slash_Register,
  "Command.Slash.Register")

Command.Event.Attach(
  Command.Slash.Register("at"),
  AT.Command_Slash_Register,
  "Command.Slash.Register")

print(string.format("v%s loaded.", addon.toc.Version))
