-- Fault injection around real orchestration; no network or installation.
local factory = dofile('extensions/hue-shift/src/update.lua')
local function scenario(options)
  options = options or {}
  local files, timers, shells, events = {}, {}, 0, {}
  local now, path, updater = 1000
  os.time = function() return now end
  os.remove = function(p)
    if options.removeDenied then error('remove denied') end
    files[p] = nil
    return true
  end
  io.open = function(p, mode)
    if options.openThrows then error('access denied') end
    if options.openDenied then return nil, 'Permission denied', 13 end
    if mode == 'w' then
      path = p:sub(1, -9)
      files[p] = true
      return {close=function() return true end}
    end
    if not files[p] then return nil, 'No such file', 2 end
    return {read=function()
      if options.readThrows then error('read failed') end
      return files[p]
    end, close=function() return true end}
  end
  os.execute = function()
    shells = shells + 1
    if options.shellThrows then error('execute denied') end
    if options.shellFails then return nil, 'exit', 1 end
    return true, 'exit', 0
  end
  Timer = function(spec)
    if options.timerThrows then error('Timer unavailable') end
    local timer = {ontick=spec.ontick, active=false}
    function timer:start()
      if options.timerStartThrows then error('Timer start failed') end
      self.active = true
    end
    function timer:stop() self.active=false end
    timers[#timers+1] = timer
    return timer
  end
  json = {decode=function(data)
    if data == 'bad' then error('invalid JSON') end
    return data
  end}
  app = {isUIAvailable=true, os={windows=true},
    fs={tempPath='C:/Temp Folder', joinPath=function(...) return table.concat({...}, '/') end,
      isFile=function(p) return files[p] ~= nil end}, alert=function() end,
    command={Options=function(args)
      assert(updater.busy and files[args.installExtension], 'Retain lock and package during installation')
      assert(not updater.checkNow(), 'Nested manual checks must be rejected')
      if options.stopDuringInstall then
        updater.stop()
        assert(files[args.installExtension], 'Plugin exit must retain active package')
      end
      if options.installThrows then error('native error') end
      if options.installFalse then return false end
      if options.installNil then return nil end
      return true
    end}}
  if options.noInstaller then app.command={} end
  updater = factory('extension', '0.1.7')
  local started = updater.checkNow(function(kind)
    events[#events+1]=kind
    assert(updater.busy, 'Callbacks must run before unlocking')
    assert(not updater.checkNow(), 'Callback reentry must be rejected')
  end)
  local function deliver(result)
    files[path]=result
    files[path .. '.aseprite-extension']=true
    timers[#timers].ontick()
  end
  return {u=updater, options=options, files=files, timers=timers, events=events,
    started=started, path=path, deliver=deliver, shells=function() return shells end,
    tick=function(seconds) now=now+seconds; timers[#timers].ontick() end}
end
for _, fault in ipairs({'shellThrows','shellFails','openThrows','openDenied','timerThrows','timerStartThrows'}) do
  local s=scenario({[fault]=true})
  assert(not s.started and not s.u.busy and s.u.state=='error', fault)
  for _, t in ipairs(s.timers) do assert(not t.active) end
  assert(next(s.files)==nil, fault .. ': clean request')
  if fault:find('timer') or fault:find('open') then assert(s.shells()==0) end
end
for _, fault in ipairs({'openThrows','openDenied','readThrows','badJson','timeout'}) do
  local s=scenario()
  if fault=='timeout' then s.tick(141)
  elseif fault=='badJson' then s.deliver('bad')
  else
    s.options[fault]=true
    s.files[s.path]={status='up_to_date'}
    s.tick(1)
  end
  assert(s.u.state=='error' and s.u.busy, fault .. ': uncertain worker must retain lock')
  assert(not s.timers[1].active and not s.u.checkNow())
  assert(next(s.files)==nil)
end
for _, fault in ipairs({'none','installThrows','installFalse','installNil','stopDuringInstall','noInstaller'}) do
  local s=scenario({[fault]=true})
  s.deliver({status='update',version='0.1.8',packagePath=s.path .. '.aseprite-extension'})
  assert(not s.u.busy and next(s.files)==nil, fault)
  local expected=(fault=='installThrows' or fault=='installFalse' or fault=='noInstaller') and 'error' or 'installer_closed'
  assert(s.u.state==expected, fault)
  assert(not s.u.launchStatus:find('success'))
end
local s=scenario()
s.deliver({status='update',version='0.1.8',packagePath='C:/unrelated.aseprite-extension'})
assert(s.u.state=='error' and next(s.files)==nil)
s=scenario()
s.deliver({status='up_to_date',message='Already current'})
assert(s.u.state=='up_to_date' and not s.u.busy and next(s.files)==nil)
assert(s.u.checkNow(), 'Terminal completion permits another check')
s.u.stop()
assert(not s.timers[#s.timers].active and next(s.files)==nil and not s.u.checkNow())
s=scenario({removeDenied=true})
s.deliver({status='error',message='HTTP 403'})
assert(s.u.launchStatus:find('cleanup failed'))
print('OK: updater locks, timeout, permissions, cleanup, native cancel/error and reentrant exit')
