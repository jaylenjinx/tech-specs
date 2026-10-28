-- Venue Patch Export
-- Writes the show's patch to a CSV that the Sydney Venue Spec Pack site can import:
-- Fixture ID,Fixture,Mode,Universe,Address,End,Location

local pluginName, componentName, signalTable, myHandle = select(1, ...)

local function get(obj, key)
  local ok, v = pcall(function() return obj[key] end)
  if ok then return v end
end

local function nameOf(h)
  local t = type(h)
  if t == "userdata" or t == "table" then return get(h, "name") or get(h, "Name") or "" end
  return h and tostring(h) or ""
end

-- The mode's TotalFootprint is the DMX width. Fallback: the highest Coarse/Fine/Ultra/Uber
-- channel number, which counts 16-bit channels as 2 and skips virtual channels.
local function footprint(mode)
  if type(mode) ~= "userdata" and type(mode) ~= "table" then return nil end
  local total = tonumber(tostring(get(mode, "TotalFootprint") or ""))
  if total and total > 0 then return total end
  local chans = get(mode, "DMXChannels")
  local ok, n = pcall(function() return chans:Count() end)
  if not ok or not n then return nil end
  local top = 0
  for i = 1, n do
    local c = chans:Ptr(i)
    if c then
      for _, k in ipairs({"Coarse", "Fine", "Ultra", "Uber"}) do
        top = math.max(top, tonumber(tostring(get(c, k) or "")) or 0)
      end
    end
  end
  return top > 0 and top or nil
end

-- 2.5 returns Mode as text like "2 6 channel" (index in the fixture type, then name)
-- and the mode object itself as ModeDirect.
local function resolveMode(fx)
  local m = get(fx, "Mode")
  local direct = get(fx, "ModeDirect")
  if type(m) ~= "string" then return direct or m, nameOf(m) end
  local idx, name = m:match("^(%d+)%s+(.*)$")
  local handle = type(direct) ~= "string" and direct or nil
  local modes = get(get(fx, "FixtureType") or {}, "DMXModes")
  if not handle and modes and idx then
    local ok, h = pcall(function() return modes:Ptr(tonumber(idx)) end)
    if ok then handle = h end
  end
  return handle, name or m
end

local function splitPatch(p)
  p = tostring(p or "")
  local u, a = p:match("(%d+)%.(%d+)")
  if u then return tonumber(u), tonumber(a) end
  local abs = tonumber(p:match("%d+") or "")
  if abs and abs > 0 then return math.floor((abs - 1) / 512) + 1, (abs - 1) % 512 + 1 end
end

local function csv(v)
  v = tostring(v == nil and "" or v)
  if v:find('[,"\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
  return v
end

local function collect(list, fx, stageName)
  if not fx then return end
  local u, a = splitPatch(get(fx, "Patch"))
  local fid = get(fx, "FID") or get(fx, "fid")
  if u and fid and tostring(fid) ~= "" and tostring(fid) ~= "None" then
    local mode, modeName = resolveMode(fx)
    local ch = footprint(mode)
    local loc = nameOf(get(fx, "Layer"))
    if loc == "" then loc = nameOf(get(fx, "Name")) end
    if stageName ~= "" and stageName ~= "Stage 1" then loc = (loc ~= "" and loc .. " · " or "") .. stageName end
    list[#list + 1] = {
      fid = tostring(fid), sort = tonumber(fid) or math.huge,
      ftype = nameOf(get(fx, "FixtureType")), mode = modeName,
      u = u, a = a, e = ch and (a + ch - 1) or "", loc = loc,
    }
    return
  end
  -- Grouped fixtures carry their patch on the children.
  local ok, n = pcall(function() return fx:Count() end)
  if ok and n then for i = 1, n do collect(list, fx:Ptr(i), stageName) end end
end

local function defaultPath()
  local base
  local ok, p = pcall(function() return GetPath(Enums.PathType.Library) end)
  if ok and p then base = p end
  if not base then ok, p = pcall(GetPath, "library"); if ok and p then base = p end end
  if not base then base = os.getenv("HOME") or "." end
  return base .. "/patch_export_" .. os.date("%Y%m%d_%H%M") .. ".csv"
end

local function main(display, args)
  local list = {}
  local stages = get(Patch(), "Stages")
  if not stages then ErrPrintf("Patch Export: couldn't find the patch stages.") return end
  for s = 1, stages:Count() do
    local st = stages:Ptr(s)
    local fixtures = st and get(st, "Fixtures")
    if fixtures then
      for i = 1, fixtures:Count() do collect(list, fixtures:Ptr(i), nameOf(st)) end
    end
  end
  if #list == 0 then ErrPrintf("Patch Export: no patched fixtures found.") return end
  table.sort(list, function(x, y) if x.sort ~= y.sort then return x.sort < y.sort end return x.fid < y.fid end)

  local path = (args and args ~= "") and args or defaultPath()
  if TextInput then
    local answer = TextInput("Export patch to", path)
    if answer == nil then return end
    if answer ~= "" then path = answer end
  end

  local f, err = io.open(path, "w")
  if not f then ErrPrintf("Patch Export: can't write " .. path .. " (" .. tostring(err) .. ")") return end
  f:write("Fixture ID,Fixture,Mode,Universe,Address,End,Location\n")
  for _, r in ipairs(list) do
    f:write(table.concat({csv(r.fid), csv(r.ftype), csv(r.mode), r.u, r.a, r.e, csv(r.loc)}, ","), "\n")
  end
  f:close()
  Printf("Patch Export: wrote %d fixtures to %s", #list, path)
  if MessageBox then
    MessageBox({title = "Patch Export", message = #list .. " fixtures written to\n" .. path, commands = {{value = 1, name = "OK"}}})
  end
end

return main
