#!/usr/bin/lua
require("./scripts/helper_function")

if file_exists("config.lua") ~= true then
    decrypt_config()
    return
end
if file_exists("config.lua") then
    require("config")
else
    print("config file missing!")
    do return end    
end

-- On command
cmds = {}
cmds["clean"] = function ()
    encrypt_config(encrypt_pw)
end

cmds["backup"] = function()
    encrypt_config(encrypt_pw)
    run_cmd("./scripts/auto_backup.sh " .. db_username .. " " .. db_password)
end

cmds["deploy_systemd"] = function()
    encrypt_config(encrypt_pw)
    run_cmd("sudo ./scripts/deploy_systemd.sh")
end

cmds["enable_site"] = function()
    encrypt_config(encrypt_pw)
    run_cmd("sudo ./scripts/enable_site.sh")
end

cmds["acme"] = function()
    run_cmd("sudo ./scripts/auto_certs_acquire.sh " .. dnspod_id .. " " .. dnspod_token)
end

cmd = arg[1]

if cmds[cmd] ~= nil then
    cmds[cmd](arg)
else
    print("No such command")
end
