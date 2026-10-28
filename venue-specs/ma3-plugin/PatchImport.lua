-- Venue Patch Import
-- Reads the "MA3 import" CSV saved from the Sydney Venue Spec Pack site:
-- Fixture ID,Name,Fixture,Mode,Channels,Universe,Address,Generic,X,Y,Z,Position
-- Fixtures already in the show get their stage position set. With "add missing" chosen,
-- fixtures not in the show are patched as generic placeholder types, with the real type
-- noted on each fixture, ready to be changed in the patch.

local pluginName, componentName, signalTable, myHandle = select(1, ...)

-- Placeholder fixture type per site fixture class: library, file, preferred mode names.
local GENERIC = {
  spot   = {lib = "ma3", file = "generic@moving_head.xml"},
  wash   = {lib = "ma3", file = "generic@moving_head.xml"},
  par    = {lib = "ma2", file = "generic@led - irgbw.pxml", modes = {"8 bit"}},
  mate   = {lib = "ma2", file = "generic@led - irgb.pxml", modes = {"8 bit"}},
  fres   = {lib = "ma2", file = "generic@fresnel.pxml"},
  prof   = {lib = "ma2", file = "generic@profile.pxml"},
  blind  = {lib = "ma2", file = "generic@dimmer.pxml", modes = {"8 bit"}},
  strobe = {lib = "ma2", file = "generic@strobe.pxml"},
  haze   = {lib = "ma2", file = "generic@haze.pxml"},
}
local DEFAULT_GENERIC = {lib = "ma2", file = "generic@dimmer.pxml", modes = {"8 bit"}}

local function get(obj, key)
  local ok, v = pcall(function() return obj[key] end)
  if ok then return v end
end

local function parseCSV(text)
  local rows, row, cell, q, i = {}, {}, {}, false, 1
  local n = #text
  while i <= n do
    local c = text:sub(i, i)
    if q then
      if c == '"' then
        if text:sub(i + 1, i + 1) == '"' then cell[#cell + 1] = '"'; i = i + 1 else q = false end
      else cell[#cell + 1] = c end
    elseif c == '"' then q = true
    elseif c == "," then row[#row + 1] = table.concat(cell); cell = {}
    elseif c == "\n" or c == "\r" then
      if c == "\r" and text:sub(i + 1, i + 1) == "\n" then i = i + 1 end
      row[#row + 1] = table.concat(cell); cell = {}
      if #row > 1 or row[1] ~= "" then rows[#rows + 1] = row end
      row = {}
    else cell[#cell + 1] = c end
    i = i + 1
  end
  row[#row + 1] = table.concat(cell)
  if #row > 1 or row[1] ~= "" then rows[#rows + 1] = row end
  return rows
end

-- Depth-first search for a fixture by FID, including grouped sub-fixtures.
local function findFixture(list, fid)
  local hit
  local function walk(f)
    if not f or hit then return end
    if tostring(get(f, "FID")) == fid then hit = f; return end
    local ok, n = pcall(function() return f:Count() end)
    if ok and n then for i = 1, n do walk(f:Ptr(i)) end end
  end
  for i = 1, list:Count() do walk(list:Ptr(i)) end
  return hit
end

local function footprint(f)
  local m = get(f, "ModeDirect")
  local n = m and tonumber(tostring(get(m, "TotalFootprint") or ""))
  return (n and n > 0) and n or 1
end

-- Every DMX address in use, as "u.a" keys, so placeholders never double-patch.
local function usedAddresses(list)
  local used = {}
  local function walk(f)
    if not f then return end
    local u, a = tostring(get(f, "Patch") or ""):match("(%d+)%.(%d+)")
    if u then
      u, a = tonumber(u), tonumber(a)
      for k = 0, footprint(f) - 1 do used[u .. "." .. (a + k)] = true end
      return
    end
    local ok, n = pcall(function() return f:Count() end)
    if ok and n then for i = 1, n do walk(f:Ptr(i)) end end
  end
  for i = 1, list:Count() do walk(list:Ptr(i)) end
  return used
end

local function setPosition(f, x, y, z)
  if not (x and y and z) then return false end
  return pcall(function() f.PosX = x; f.PosY = y; f.PosZ = z end)
end

-- Aim a fixture at its focus point. MA3 composes rotation as Z·Y·X (X applied first), and a fixture
-- at rotation 0 shines straight down (-Z). Positive RotX tips the top downstage, swinging the beam
-- upstage; positive RotZ turns it counter-clockwise seen from above. With no roll (RotY = 0) the beam
-- direction is (-sin Z · sin X, cos Z · sin X, -cos X), which is solved for below.
local function aim(f, x, y, z, tx, ty, tz)
  if not (x and y and z and tx and ty and tz) then return false end
  local dx, dy, dz = tx - x, ty - y, tz - z
  local h = math.sqrt(dx * dx + dy * dy)
  if h < 1e-6 and dz >= 0 then return false end
  local rx = math.deg(math.atan(h, -dz))
  local rz = h < 1e-6 and 0 or math.deg(math.atan(-dx, dy))
  return pcall(function() f.RotX = rx; f.RotY = 0; f.RotZ = rz end)
end

local function main(display, args)
  -- args (optional): "path" or "path|add" / "path|positions", for running without dialogs.
  local path, mode = nil, nil
  if args and args ~= "" then path, mode = args:match("^([^|]+)|?(%a*)$") end
  path = path or ((os.getenv("HOME") or "") .. "/Downloads/")
  if (not args or args == "") and TextInput then
    local answer = TextInput("CSV from the Venue Spec Pack site", path)
    if not answer or answer == "" then return end
    path = answer
  end
  if not mode or mode == "" then
    if MessageBox then
      local r = MessageBox({title = "Venue Patch Import", message = "Set positions for fixtures already in the show, or also patch the missing ones as generic placeholders?",
        commands = {{value = 1, name = "Positions only"}, {value = 2, name = "Positions + add missing"}, {value = 0, name = "Cancel"}}})
      local v = r and r.result
      if v == 1 then mode = "positions" elseif v == 2 then mode = "add" else return end
    else mode = "positions" end
  end

  local f = io.open(path, "r")
  if not f then ErrPrintf("Patch Import: can't open " .. path) return end
  local rows = parseCSV((f:read("*a") or ""):gsub("^\239\187\191", ""))
  f:close()
  if #rows < 2 then ErrPrintf("Patch Import: no fixture rows in " .. path) return end
  local col = {}
  for i, h in ipairs(rows[1]) do col[h:lower():gsub("^%s+", ""):gsub("%s+$", "")] = i end
  if not (col["fixture id"] and col["x"] and col["y"] and col["z"]) then
    ErrPrintf("Patch Import: expected Fixture ID, X, Y and Z columns. Save the file with the site's MA3 button.") return
  end
  local function cell(r, name) local i = col[name]; return i and r[i] and r[i]:gsub("^%s+", ""):gsub("%s+$", "") or "" end

  -- Edits go into the editable patch, which only exists while the command line is inside it;
  -- leaving it (cd Root) applies the changes.
  Cmd('cd Root'); Cmd('cd "ShowData"."Patch"')
  local patch = ShowData().Patch
  local fixtures = patch.Stages:Ptr(1).Fixtures
  local used = usedAddresses(fixtures)
  local moved, added, unpatched, focused, skipped, missing = 0, 0, 0, 0, {}, {}

  for r = 2, #rows do
    local row = rows[r]
    local fid = cell(row, "fixture id")
    if fid ~= "" then
      local fx = findFixture(fixtures, fid)
      local x, y, z = tonumber(cell(row, "x")), tonumber(cell(row, "y")), tonumber(cell(row, "z"))
      local tx, ty, tz = tonumber(cell(row, "focus x")), tonumber(cell(row, "focus y")), tonumber(cell(row, "focus z"))
      if fx then
        if setPosition(fx, x, y, z) then moved = moved + 1 end
        if aim(fx, x, y, z, tx, ty, tz) then focused = focused + 1 end
      elseif mode == "add" and fid:match("^%d+$") then
        missing[#missing + 1] = {row = row, fid = fid, x = x, y = y, z = z, tx = tx, ty = ty, tz = tz}
      else
        skipped[#skipped + 1] = fid
      end
    end
  end

  if #missing > 0 then
    -- Import each placeholder type once, while still at the patch level.
    local libs = {ma2 = GetPath(Enums.PathType.GrandMA2Library) .. GetPathSeparator(), ma3 = GetPath(Enums.PathType.GrandMA3Library) .. GetPathSeparator()}
    local types = {}
    local function placeholderMode(code)
      local g = GENERIC[code] or DEFAULT_GENERIC
      if types[g.file] == nil then
        local ok, ft = pcall(function() local h = patch.FixtureTypes:Acquire(); h:Import(libs[g.lib], g.file); return h end)
        types[g.file] = (ok and ft) or false
      end
      local ft = types[g.file]
      if not ft then return nil end
      local modes = ft.DMXModes
      for _, want in ipairs(g.modes or {}) do
        for j = 1, modes:Count() do local m = modes:Ptr(j); if m and m.name == want then return m end end
      end
      return modes:Ptr(1)
    end
    for _, m in ipairs(missing) do m.mode = placeholderMode(cell(m.row, "generic")) end

    Cmd('cd "Stages"'); Cmd('cd 1'); Cmd('cd "Fixtures"')
    for _, m in ipairs(missing) do
      if m.mode then
        local u, a = tonumber(cell(m.row, "universe")), tonumber(cell(m.row, "address"))
        local free = u and a
        if free then
          local need = footprint({ModeDirect = m.mode})
          for k = 0, need - 1 do if used[u .. "." .. (a + k)] then free = false end end
        end
        local name = cell(m.row, "name"); if name == "" then name = "Fixture " .. m.fid end
        local spec = {mode = m.mode, amount = 1, fid = m.fid, name = name}
        if free then spec.patch = {string.format("%d.%03d", u, a)} end
        local ok = pcall(AddFixtures, spec)
        local fx = ok and findFixture(fixtures, m.fid)
        if fx then
          added = added + 1
          if free then
            for k = 0, footprint(fx) - 1 do used[u .. "." .. (a + k)] = true end
          else unpatched = unpatched + 1 end
          setPosition(fx, m.x, m.y, m.z)
          if aim(fx, m.x, m.y, m.z, m.tx, m.ty, m.tz) then focused = focused + 1 end
          local note = "Placeholder. Change to: " .. cell(m.row, "fixture") .. " · " .. cell(m.row, "mode") .. " (" .. cell(m.row, "channels") .. " ch)"
          if u and a then note = note .. " at " .. string.format("%d.%03d", u, a) end
          if cell(m.row, "focus") ~= "" then note = note .. " · Focus: " .. cell(m.row, "focus") end
          pcall(function() fx.Note = note end)
        else
          skipped[#skipped + 1] = m.fid
        end
      else
        skipped[#skipped + 1] = m.fid
      end
    end
  end
  Cmd('cd Root')

  local msg = string.format("Positions set: %d\nPlaceholders added: %d\nFocused (rotation set): %d", moved, added, focused)
  if unpatched > 0 then msg = msg .. string.format("\nAdded unpatched (address in use): %d", unpatched) end
  if #skipped > 0 then msg = msg .. "\nNot in show, skipped: " .. table.concat(skipped, ", ") end
  Printf("Patch Import: " .. msg:gsub("\n", " · "))
  if MessageBox then MessageBox({title = "Venue Patch Import", message = msg, commands = {{value = 1, name = "OK"}}}) end
end

return main
