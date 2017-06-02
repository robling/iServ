function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function encrypt_config(pw)
    os.execute('openssl aes-128-cbc -salt -in config.lua -out config.lua.aes -k '.. pw)
    os.execute('rm config.lua')
end

