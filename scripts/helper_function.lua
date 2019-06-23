function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function encrypt_config(pw)
    os.execute('openssl enc -des-cfb -salt -in config.lua -out config.lua.aes -k '.. pw)
    --os.execute('rm config.lua')
end

function decrypt_config(pw)
    if file_exists("config.lua.aes") then
        --local rst = io.popen('openssl aes-128-cbc -d -salt -in config.lua.aes -out config.lua')
        print("decrypt your config file:")
        os.execute('openssl enc -des-cfb -d -salt -in config.lua.aes -out config.lua')
    end
end

function run_cmd(cm)
    print(cm)
    os.execute(cm)
end