-- Updates live in their own modeless window, separate from palette actions.
local M = {}
local active

function M.open(updater, version)
  if not app.isUIAvailable then return end
  if active then return active end
  local dlg, refresh
  dlg=Dialog{title="Hue Shift Updates",onclose=function()
    if updater.onStatus==refresh then updater.onStatus=nil end
    active=nil
  end}
  active=dlg
  dlg:label{label="Installed:",text="v" .. tostring(version)}
  dlg:separator{text="Update Status"}
  for i=1,4 do dlg:label{id="update_line_"..i,text=" "};dlg:newrow() end
  dlg:separator{}
  dlg:label{text="Aseprite asks before installing."}
  dlg:newrow()
  dlg:label{text="Restart after accepting an update."}
  dlg:button{id="check",text="Check Updates",onclick=function()
    local ok,message=updater.checkNow()
    if not ok then refresh("error",message) end
  end}
  dlg:button{text="Close"}
  refresh=function(_,message)
    local lines={""}
    for word in tostring(message):gmatch("%S+") do
      if #word>45 then word=word:sub(1,42).."..." end
      local line=lines[#lines]
      if #line+#word+1>45 then lines[#lines+1]=word
      else lines[#lines]=line=="" and word or line.." "..word end
    end
    for i=1,4 do
      local text=lines[i] or " "
      if i==4 and #lines>4 then text=text.."..." end
      dlg:modify{id="update_line_"..i,text=text}
    end
    dlg:modify{id="check",enabled=not updater.busy}
  end
  updater.onStatus=refresh
  refresh(updater.state,updater.launchStatus)
  dlg:show{wait=false,autoscrollbars=true}
  return dlg
end

function M.close()
  if active then active:close() end
end

return M
