#!/usr/bin/env lua

-- Monitoring network system
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 2.0

local DEBUG = false
local WAIT_TIME = '5m'
local ATTEMPTS = 2
local PATH_CONFIG = '/usr/local/etc/mvss-conf.lua'

local function read_settings(path)
    local ok, e = pcall(dofile, path)
    if not ok then
        if DEBUG then print('error read settings: '..e) end
        os.exit(0)
    end
end

local function test_ping(addr)
    return os.execute('ping -qc 1 -w 5 '..addr..' &> /dev/null')
end

local function test_nc(addr, port)
    return os.execute('netcat -zw 5 '..addr..' '..port..' &> /dev/null')
end

local function sleep(s)
    os.execute('sleep '..s)
end

local function read_file(path, count)
    local tab = {}
    local file = io.open(path,'r')
    local state
    if file then
        for line in file:lines() do
            state = string.match(line,'^(%d)')
            table.insert(tab, tonumber(state))
        end
        file:close()
        if DEBUG then print('read file '..path..' OK') end
    end
    if #tab < count then
        for _ = 1,count do
            table.insert(tab, 0)
        end
        if DEBUG then print('create empty tab') end
    end
    return tab
end

local function save_file(path, tab, name)
    local file = io.open(path,'w')
    local str
    if file then
        for i = 1,#tab do
            str = string.format('%d %s%s',tab[i],name[i],'\n')
            file:write(str)
        end
        file:flush()
        file:close()
        if DEBUG then print('save file '..path..' OK') end
    end
end

local function send_sms(admin_to, t_str, outgoing)
    for _, to in ipairs(admin_to) do
        local pathsms = os.date('/tmp/'..to..'_%d_%b_%X')
        local file = io.open(pathsms,'w')
        if file then
            file:write('To: '..to..'\n\n')
            for i = 1,#t_str do
                file:write(t_str[i])
            end
            file:write(os.date('%X'))
            file:flush()
            file:close()
            os.execute('mv '..pathsms..' '..outgoing)
            if DEBUG then print('send sms to '..to..' OK') end
        end
    end
    t_str = {}
    return t_str
end

-- MAIN chunk
do
    read_settings(PATH_CONFIG)
    
    local state_file = PATH_TMP..'monitord'
    local tab = read_file(state_file, #MONITOR_ADDR)
    local tab_str = {}
    local method
    local address
    local port
    local test_return
    local is_work = {}
    for i = 1,#MONITOR_ADDR do
        if tab[i] == 0 then
            table.insert(is_work, true)
        else
            table.insert(is_work, false)
        end
    end
    
    save_file(state_file, tab, MONITOR_NAME)

    while(true) do
        is_changes = false
        for i,value in ipairs(MONITOR_ADDR) do
            method, address, port = string.match(value,'(%a)%s(%d+%.%d+%.%d+%.%d+):?(%d*)')
            if method == 'n' then
                if port == '' then
                    port = '80'
                end
                test_return = test_nc(address, port)
                if DEBUG then print(method, address, port, test_return) end
            elseif method == 'p' then
                test_return = test_ping(address)
                if DEBUG then print(method, address, test_return) end
            else
                address = value
                test_return = test_ping(address)
                if DEBUG then print(address, test_return) end
            end -- end if method
            
            if test_return == 0 then
                -- ok
                if tab[i] > 0 then
                    tab[i] = tab[i] - 1
                    if ((tab[i] == 0) and (not is_work[i])) then
                        is_work[i] = true
                        -- Send SMS (MONITOR_NAME[i] OK)
                        table.insert(tab_str, MONITOR_NAME[i]..' OK\n')
                        if DEBUG then print(MONITOR_NAME[i]..' OK') end
                    end
                end
            else
                -- fail
                if tab[i] < ATTEMPTS then
                    tab[i] = tab[i] + 1
                    if ((tab[i] == ATTEMPTS) and is_work[i]) then
                        is_work[i] = false
                        -- Send SMS (MONITOR_NAME[i] FAIL)
                        table.insert(tab_str, MONITOR_NAME[i]..' FAIL\n')
                        if DEBUG then print(MONITOR_NAME[i]..' FAIL') end
                    end
                end
            end
        end -- end for
        if #tab_str > 0 then
            save_file(state_file, tab, MONITOR_NAME)
            tab_str = send_sms(NOTIFY_NUMBER, tab_str, OUTGOING)
        end
        sleep(WAIT_TIME)
    end -- end while
end -- end main
os.exit(0)
