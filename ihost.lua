require("./scripts/helper_function")

if file_exists("config.lua") ~= true then
    if file_exists("config.lua.aes") then
    --local rst = io.popen('openssl aes-128-cbc -d -salt -in config.lua.aes -out config.lua')
    print("decrypt your config file:")
    os.execute('openssl aes-128-cbc -d -salt -in config.lua.aes -out config.lua')
    else
        do return end
    end
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
    os.execute("./scripts/auto_backup.sh " .. db_username .. " " .. db_password)
end

cmd = arg[1]

if cmds[cmd] ~= nil then
    cmds[cmd](arg)
else
    print("No such command")
end
