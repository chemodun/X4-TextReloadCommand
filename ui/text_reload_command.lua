local ffi = require("ffi")
local C = ffi.C

local textReloadCommand = {
  configBlackboard = "$TextReloadCommandConfig",
  debugLevel = "none",
  chatReply = true,
  loader = nil,
}

local function write(message, ...)
  if select("#", ...) > 0 then
    message = string.format(message, ...)
  end
  DebugError("TextReloadCommand: " .. message)
end

local function modText(id) return tostring(ReadText(1972092444, id)) end

function textReloadCommand.Error(message, ...) write(message, ...) end
function textReloadCommand.Debug(message, ...) if textReloadCommand.debugLevel ~= "none" then write(message, ...) end end
function textReloadCommand.Trace(message, ...) if textReloadCommand.debugLevel == "trace" then write(message, ...) end end

function textReloadCommand.ReadConfig()
  local playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
  local config = GetNPCBlackboard(playerId, textReloadCommand.configBlackboard)
  if type(config) ~= "table" then return end
  if config.debugLevel then
    textReloadCommand.debugLevel = tostring(config.debugLevel)
  end
  if config.chatReply ~= nil then
    textReloadCommand.chatReply = config.chatReply == 1 or config.chatReply == true
  end
  textReloadCommand.Trace("config read: debug level %s, chat reply %s", textReloadCommand.debugLevel, tostring(textReloadCommand.chatReply))
end

-- Vanilla's announcement buffer is drawn for everyone; the chat window redraws after ExecuteDebugCommand returns.
function textReloadCommand.Print(message, failed)
  local chat = __CORE_CHAT_WINDOW
  if type(chat) ~= "table" or type(chat.announcements) ~= "table" then
    textReloadCommand.Debug("chat window buffer missing, not printed: %s", message)
    return
  end
  local color = ColorText[failed and "text_negative" or "text_positive"]
  table.insert(chat.announcements, {
    -- Vanilla colors every wrapped line itself, so each word carries the color for the line it may start.
    text = (string.gsub(message, "%S+", function(word) return color .. word end)),
    prefix = color .. modText(1) .. ReadText(1001, 120) .. " ",
    timestamp = tostring(C.GetCurrentUTCDataTime() * 1000),
    announcement = true,
    teammessageoftheday = false,
  })
  local menu = Helper and Helper.getMenu and Helper.getMenu("ChatWindow")
  if menu then
    menu.messagesOutdated = true
  end
end

local P = ffi.typeof("uint8_t*")
local function i32(p) return ffi.cast("int32_t*", p)[0] end
local function u32(p) return ffi.cast("uint32_t*", p)[0] end
local function u16(p) return ffi.cast("uint16_t*", p)[0] end
local function hex(n) return string.format("0x%x", n) end
local function match(p, bytes)
  for k = 1, #bytes do
    if p[k - 1] ~= bytes[k] then return false end
  end
  return true
end

local function cString(p, s)
  for k = 1, #s do
    if p[k - 1] ~= string.byte(s, k) then return false end
  end
  return p[#s] == 0
end

-- The exception table (.pdata) lists every function start, sorted.
local function isFunctionStart(base, rva)
  local directory = base + i32(base + 0x3c) + 24 + 112 + 3 * 8
  local entries = u32(directory)
  local lo, hi = 0, math.floor(u32(directory + 4) / 12) - 1
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local start = u32(base + entries + mid * 12)
    if start == rva then return true end
    if start < rva then lo = mid + 1 else hi = mid - 1 end
  end
  return false
end

-- Build-independent: a real function, called with the two flags zeroed, and called again for the "t/0000" fallback.
-- Returns nil when the target is the loader, else the reason.
local function checkLoader(base, rdata, site, call, loader)
  if not isFunctionStart(base, loader) then return "call target " .. hex(loader) .. " is not a function start" end
  local zeroR8, zeroR9
  for k = site + 7, call - 1 do
    if match(base + k, { 0x45, 0x33, 0xc0 }) then zeroR8 = true end
    if match(base + k, { 0x45, 0x33, 0xc9 }) then zeroR9 = true end
  end
  if not (zeroR8 and zeroR9) then return "flags not zeroed before the call at " .. hex(call) end
  local fallback
  for k = call + 5, call + 0x65 do
    if match(base + k, { 0x48, 0x8d, 0x15 }) then
      local target = k + 7 + i32(base + k + 3)
      if target >= rdata.rva and target < rdata.rva + rdata.size - 8 and cString(base + target, "t/0000") then
        fallback = true
      end
    end
    if fallback and base[k] == 0xe8 and k + 5 + i32(base + k + 1) == loader then return nil end
  end
  return "no t/0000 call to the same target after " .. hex(call)
end

-- The engine's startup text import is found at its call site: mov rbx,[db]; lea rdx,"t/0001"; ...; mov rcx,rbx; call loader.
function textReloadCommand.Locate()
  -- The walk below the image would read unmapped memory in the native Linux build; Proton/Wine report Windows.
  if ffi.os ~= "Windows" then return nil, "only the Windows build of the game is supported, found " .. tostring(ffi.os) end
  -- ffi.load and unlisted ffi.C symbols are blocked, so the image base comes from a whitelisted export's address.
  local address = ffi.cast("uintptr_t", C.GetPlayerID)
  address = address - address % 0x10000
  local base
  for _ = 1, 4096 do
    local p = ffi.cast(P, address)
    if p[0] == 0x4d and p[1] == 0x5a and u32(p + i32(p + 0x3c)) == 0x4550 then
      base = p
      break
    end
    address = address - 0x10000
  end
  if not base then return nil, "image base not found" end

  local pe = base + i32(base + 0x3c)
  local sections, header = {}, pe + 24 + u16(pe + 20)
  for i = 0, u16(pe + 6) - 1 do
    local h = header + i * 40
    local name = {}
    for k = 0, 7 do
      if h[k] ~= 0 then name[#name + 1] = string.char(h[k]) end
    end
    sections[table.concat(name)] = { rva = u32(h + 12), size = u32(h + 8) }
  end
  local rdata, text = sections[".rdata"], sections[".text"]
  if not (rdata and text) then return nil, ".rdata or .text section missing" end
  textReloadCommand.Trace("sections .rdata %s +%s, .text %s +%s", hex(rdata.rva), hex(rdata.size), hex(text.rva), hex(text.size))

  -- ffi.string stops at the first NUL whatever the length, so binary memory is scanned byte by byte.
  local pathRva
  for o = rdata.rva, rdata.rva + rdata.size - 8 do
    if base[o + 1] == 0x74 and match(base + o, { 0, 0x74, 0x2f, 0x30, 0x30, 0x30, 0x31, 0 }) then
      pathRva = o + 1
      break
    end
  end
  if not pathRva then return nil, "string t/0001 not found" end

  for o = text.rva + 7, text.rva + text.size - 7 do
    if base[o] == 0x48 and base[o + 1] == 0x8d and base[o + 2] == 0x15 and o + 7 + i32(base + o + 3) == pathRva
        and match(base + o - 7, { 0x48, 0x8b, 0x1d }) then
      for j = o + 7, o + 0x30 do
        if match(base + j, { 0x48, 0x8b, 0xcb, 0xe8 }) then
          local loader = j + 8 + i32(base + j + 4)
          local mismatch = checkLoader(base, rdata, o, j + 3, loader)
          if mismatch then return nil, mismatch end
          local db = o + i32(base + o - 4)
          textReloadCommand.Debug("loader found: call site %s, text database %s, loader %s", hex(o), hex(db), hex(loader))
          return {
            db = ffi.cast("void**", base + db),
            load = ffi.cast("bool(*)(void*, void*, uint8_t, uint8_t)", base + loader),
          }
        end
      end
      return nil, "loader call not found after the t/0001 reference at " .. hex(o)
    end
  end
  return nil, "no reference to t/0001 with the expected call site"
end

-- Returns nil on success, else the reason.
function textReloadCommand.Reload()
  if not textReloadCommand.loader then
    local found, err = textReloadCommand.Locate()
    if not found then return err end
    textReloadCommand.loader = found
  end
  local loader = textReloadCommand.loader
  if loader.db[0] == nil then return "text database pointer is null" end

  -- MSVC std::string in its short form: 16-byte inline buffer, size, capacity.
  local path = ffi.new("struct { char buf[16]; uint64_t size; uint64_t cap; }")
  ffi.copy(path.buf, "t/0001")
  path.size, path.cap = 6, 15
  if not loader.load(loader.db[0], path, 0, 0) then return "the engine reported a failed import" end

  -- Vanilla's ReadText wrapper (ego_detailmonitorhelper) caches every result, misses included.
  local cleared = 0
  if Helper and Helper.texts then
    for _ in pairs(Helper.texts) do cleared = cleared + 1 end
    Helper.texts = {}
  end
  textReloadCommand.Debug("%d cached ReadText results cleared", cleared)
  return nil
end

function textReloadCommand.OnReload()
  local reason
  local called, raised = pcall(function() reason = textReloadCommand.Reload() end)
  if not called then
    reason = tostring(raised)
  end
  if reason == nil then
    write("texts reloaded")
    if textReloadCommand.chatReply then
      textReloadCommand.Print(modText(1000))
    end
  else
    textReloadCommand.Error("text reload failed: %s", reason)
    textReloadCommand.Print(string.format(modText(1001), reason), true)
  end
end

local debugLevels = { none = 90911, debug = 90912, trace = 90913 }
local switches = { on = 1, off = 0 }

-- Settings changed from chat are stored by MD in the config blackboard.
function textReloadCommand.OnCommand(parameter)
  local words = {}
  for word in string.lower(tostring(parameter or "")):gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then
    textReloadCommand.OnReload()
  elseif #words == 1 and debugLevels[words[1]] then
    textReloadCommand.debugLevel = words[1]
    AddUITriggeredEvent("TextReloadCommand", "config", { key = "debugLevel", value = words[1] })
    write("debug level set to %s", words[1])
    textReloadCommand.Print(string.format(modText(1002), modText(debugLevels[words[1]])))
  elseif #words == 2 and words[1] == "reply" and switches[words[2]] then
    textReloadCommand.chatReply = switches[words[2]] == 1
    AddUITriggeredEvent("TextReloadCommand", "config", { key = "chatReply", value = switches[words[2]] })
    write("chat reply set to %s", words[2])
    textReloadCommand.Print(modText(textReloadCommand.chatReply and 1004 or 1005))
  else
    textReloadCommand.Print(modText(1003))
  end
end

local commands = { reloadtext = true, rtx = true }

-- The chat window redraws right after the command returns; this flag makes that redraw refocus the input.
local function keepChatOpen()
  local menu = Helper and Helper.getMenu and Helper.getMenu("ChatWindow")
  if menu then
    menu.activateeditbox = true
    menu.lastInteraction = getElapsedTime()
  end
end

-- The chat window calls the global ExecuteDebugCommand; the engine logs an error for a command it does not know,
-- so ours are handled here and never passed on (sn_mod_support_apis wraps the same global, in either order).
local function wrapExecuteDebugCommand()
  local original = ExecuteDebugCommand
  ExecuteDebugCommand = function(command, parameter)
    local name = string.lower(tostring(command or ""))
    if commands[name] then
      textReloadCommand.Debug("/%s %s entered", name, tostring(parameter or ""))
      textReloadCommand.OnCommand(parameter)
      keepChatOpen()
      return
    end
    return original(command, parameter)
  end
end

-- A failure here is retried by the first reload, which reports the reason in the chat.
local function locateLoader()
  local found, reason
  local called, raised = pcall(function() found, reason = textReloadCommand.Locate() end)
  if found then
    textReloadCommand.loader = found
  else
    textReloadCommand.Error("loader not located at start: %s", tostring(called and reason or raised))
  end
end

local function init()
  RegisterEvent("TextReloadCommand.Reload", textReloadCommand.OnReload)
  RegisterEvent("TextReloadCommand.ConfigChanged", textReloadCommand.ReadConfig)
  textReloadCommand.ReadConfig()
  wrapExecuteDebugCommand()
  locateLoader()
end

init()
