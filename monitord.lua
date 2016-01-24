#!/usr/bin/env lua

-- Monitoring system
-- Required nc, ping, sleep support
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 0.5

local DEBUG = true
local ADDRESS = {'n 192.168.100.1:80','p 192.168.8.245','p 8.8.8.8','ya.ru'}
local ADDR_NAME = {'TP LINK','notebook','IP google','ya.ru'}
local WAIT_TIME = '5m' -- 5 min
local ATTEMPTS = 2
local TMP_FILE = '/var/tmp/monitor.tmp'
local ADMIN_TO = {'79520405261','79509465765'}
local OUTGOING = '/var/spool/sms/outgoing'

local function testping(addr)
    return os.execute('ping -qc 1 -w 5 '..addr)
end

local function testnc(addr, port)
    return os.execute('nc -zw 5 '..addr..' '..port)
end

local function sleep(s)
    os.execute('sleep '..s)
end

local function readfile(path, count)
    local tab = {}
    local file = io.open(path,'r')
    local state
    if file then
        for line in file.lines() do
            state = string.match(line,'^(%d)')
            table.insert(tab, state)
        end
        file:close()
        if DEBUG then print('readfile '..path..' OK') end
    end
    if #tab < count then
        for _ = 1,count do
            table.insert(tab, 0)
        end
        if DEBUG then print('create empty tab') end
    end
    return tab
end

local function savefile(path, tab, name)
    local file = io.open(path,'w')
    local str
    if file then
        for i = 1,#tab do
            str = string.format('%d %s%s',tab[i],name[i],'\n')
            file:write(str)
        end
        file:flush()
        file:close()
        if DEBUG then print('savefile '..path..' OK') end
    end
end

local function sendsms(admin_to, t_str, outgoing)
    for _, to in ipairs(admin_to) do
        local pathsms = os.date('/var/tmp/'..to..'_%d_%b_%X')
        local file = io.open(path,'w')
        if file then
            file:write('To: '..to..'\n\n')
            for i = 1,#t_str do
                file:write(t_str[i])
            end
            file:write(os.date('%X'))
            file:flush()
            file:close()
            os.execute('mv '..pathsms..' '..outgoing)
            if DEBUG then print('sendsms to '..to..' OK') end
        end
    end
    t_str = {}
    return t_str
end

-- MAIN chunk
do
    local tab = readfile(TMP_FILE, #ADDRESS)
    local tab_str = {}
    local method
    local address
    local port
    local test_return
    local is_work = {}
    for _ = 1,#ADDRESS do
        table.insert(is_work, true)
    end
    
    savefile(TMP_FILE, tab, ADDR_NAME)

    while(true) do
        is_changes = false
        for i,value in ipairs(ADDRESS) do
            method, address, port = string.match(value,'(%a)%s(%d+%.%d+%.%d+%.%d+):?(%d*)')
            if method == 'n' then
                if port == '' then
                    port = '80'
                end
                test_return = testnc(address, port)
                if DEBUG then print(method, address, port, test_return) end
            elseif method == 'p' then
                test_return = testping(address)
                if DEBUG then print(method, address, test_return) end
            else
                address = value
                print(address)
                test_return = testping(address)
                if DEBUG then print(address, test_return) end
            end -- end if method
            
            if test_return then
                -- ok
                if tab[i] > 0 then
                    tab[i] = tab[i] - 1
                    if ((tab[i] == 0) and (not is_work[i])) then
                        is_work[i] = true
                        -- Send SMS (ADDR_NAME[i] OK)
                        table.insert(tab_str, string.format('%s %s:%s %s',ADDR_NAME[i],address,port,'OK\n'))
                        if DEBUG then print(string.format('%s %s:%s %s',ADDR_NAME[i],address,port,'OK')) end
                    end
                end
            else
                -- fail
                if tab[i] < ATTEMPTS then
                    tab[i] = tab[i] + 1
                    if ((tab[i] == ATTEMPTS) and is_work[i]) then
                        is_work[i] = false
                        -- Send SMS (ADDR_NAME[i] FAIL)
                        table.insert(tab_str, string.format('%s %s:%s %s',ADDR_NAME[i],address,port,'FAIL\n'))
                        if DEBUG then print(string.format('%s %s:%s %s',ADDR_NAME[i],address,port,'FAIL')) end
                    end
                end
            end
        end -- end for
        if #tab_str > 0 then
            savefile(TMP_FILE, tab, ADDR_NAME)
            tab_str = sendsms(ADMIN_TO, tab_str, OUTGOING)
        end
        sleep(WAIT_TIME)
    end -- end while
end -- end main
os.exit(0)
