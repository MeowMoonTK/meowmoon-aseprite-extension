-- Sequential updater: fake only the external tool boundary, use native JSON/Version when available.
local nativeJSON,nativeVersion=json,Version
local originalPopen,originalRemove,originalExecute=io.popen,os.remove,os.execute
local realApp=app
local factory=dofile('extensions/hue-shift/src/update.lua')
if realApp and realApp.params.live=='1' then
  app={isUIAvailable=true,os=realApp.os,fs=realApp.fs,command={Options=function() error('No install expected') end}}
  local u=factory(nil,'999.0.0')
  local ok,message=u.checkNow()
  assert(ok and u.state=='up_to_date',message)
  print('OK: real curl + native JSON/Version, no-update result, no temporary files')
  return
end
if not Version then
  Version=function(text)
    local a,b,c=text:match('^(%d+)%.(%d+)%.(%d+)$')
    assert(a,'Invalid version')
    return setmetatable({n=tonumber(a)*1000000+tonumber(b)*1000+tonumber(c)},
      {__lt=function(x,y) return x.n<y.n end,__le=function(x,y) return x.n<=y.n end})
  end
end
local function scenario(options)
  options=options or {}
  local files,commands,states={}, {}, {}
  local u,path,installed= nil,nil,0
  local hash=string.rep('a',64)
  local releases={{tag_name='hue-shift-v9.0.0',prerelease=true},
    {tag_name='other-v99.0.0'},{tag_name='hue-shift-v0.1.7'}, {tag_name='hue-shift-v0.1.9'}}
  json={decode=function(data)
    if options.badJson then error('invalid JSON') end
    if nativeJSON then return nativeJSON.decode(nativeJSON.encode(releases)) end
    return releases
  end}
  Timer=function() error('Updater must not use a Timer') end
  os.execute=function() error('Updater must not launch a detached helper') end
  os.remove=function(p)
    if options.cleanupDenied then error('deletion denied') end
    files[p]=nil;return true
  end
  io.popen=function(command)
    commands[#commands+1]=command
    local stage=#commands
    assert(not command:find('powershell',1,true) and not command:find('.json',1,true))
    if command:find('curl.exe',1,true) then
      assert(command:find('--connect-timeout 5',1,true) and command:find('--max-time',1,true))
    end
    assert(not u.checkNow(),'Nested permission/native calls cannot start another request')
    if options.popenThrows then error('execute denied') end
    if options.popenDenied then return nil,'permission denied' end
    if command:find('--output',1,true) then
      path=command:match('%-%-output "(.-)"');files[path]=true
    end
    local pipe={}
    function pipe:read()
      if options.readThrows then error('read failed') end
      if options.stopDuringRead then u.stop() end
      if stage==1 then return 'release JSON' end
      if stage==2 then return options.checksumMalformed and 'invalid' or hash..'  hue-shift-0.1.9.aseprite-extension\n' end
      if stage==3 then return '' end
      return 'SHA256 hash:\n'..(options.checksumMismatch and string.rep('b',64) or hash)..'\nDone'
    end
    function pipe:close()
      if options.curlError and stage==1 or options.downloadError and stage==3 or options.hashError and stage==4 then
        return nil,'exit',1
      end
      return true,'exit',0
    end
    return pipe
  end
  app={isUIAvailable=true,os={windows=true},fs={tempPath='C:/Temp Folder',
    joinPath=function(...) return table.concat({...},'/') end,isFile=function(p) return files[p]~=nil end},
    command={Options=function(args)
      installed=installed+1
      assert(u.busy and files[args.installExtension],'Retain package throughout native installer')
      assert(not u.checkNow(),'Do not start another installer')
      if options.stopDuringInstall then u.stop();assert(files[args.installExtension]) end
      if options.installerThrows then error('native installer error') end
      if options.installerFalse then return false end
      return true
    end}}
  u=factory(nil,options.current or '0.1.8')
  u.onStatus=function(kind) states[#states+1]=kind end
  local ok,message=u.checkNow()
  assert(not u.busy,'Always release busy state')
  if not options.cleanupDenied then assert(next(files)==nil,'Remove only downloaded package on every terminal path') end
  return u,ok,message,commands,installed,states
end
local u,ok,_,commands,installed=scenario()
assert(ok and u.state=='installer_closed' and #commands==4 and installed==1)
u,ok,_,commands,installed=scenario({current='1.0.0'})
assert(ok and u.state=='up_to_date' and #commands==1 and installed==0)
for _,fault in ipairs({'popenDenied','popenThrows','readThrows','curlError','badJson','checksumMalformed',
  'checksumMismatch','downloadError','hashError','installerFalse','installerThrows','stopDuringRead'}) do
  u,ok=scenario({[fault]=true})
  assert(not ok and u.state=='error',fault)
end
u,ok=scenario({stopDuringInstall=true})
assert(ok and u.state=='installer_closed')
u,ok=scenario({cleanupDenied=true})
assert(ok and u.launchStatus:find('Could not delete'))
u.stop()
assert(not u.checkNow())
io.popen,os.remove,os.execute=originalPopen,originalRemove,originalExecute
print('OK: sequential curl flow, stable versions, checksums, tool errors, permission denial, cleanup and native handoff')
