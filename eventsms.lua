#!/usr/bin/env lua

-- Eventhandler for SMS Tools 3
-- Add eventhandler=/path/to/eventsms.lua into global part of smsd.conf
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 1.4

local status = arg[1]
local path = arg[2]

local DEBUG = true
local ADMIN_FROM = {'79500000000'}
local PASSWORD = 'goodlife'
local GPIO_NUMBER = {18}
local GPIO_NAME = {'relay'}
local OUTGOING = '/var/spool/sms/outgoing/'
local STATE_GPIO = '/usr/local/etc/gpiod'
local STATE_MON = '/usr/local/etc/monitord'
    
local function capture(cmd)
    local file = assert(io.popen(cmd,'r'))
    local str = assert(file:read('*a'))
    file:close()
    return str
end

local function sleep(s)
    os.execute('sleep '..s)
end

local function readfile(path, tab)
    local file = io.open(path,'r')
    local state
    local text
    if file then
        for line in file:lines() do
            state, text = string.match(line,'^(%d)%s*(.*)')
            state = tonumber(state)
            if state == 0 then
                table.insert(tab, text..' OK')
            else
                table.insert(tab, text..' FAIL')
            end
        end
        file:close()
        if DEBUG then print('readfile '..path..' OK') end
    end
    return tab
end

local function readtext(path)
    local file = io.open(path,'r')
    local form
    local alphabet
    local text
    if file then
        local line
        for i = 1,12 do
            line = file:read('*l')
            from = from or string.match(line, '^From:%s+(.*)')
            alphabet = alphabet or string.match(line, '^Alphabet:%s+(.*)')
        end

        --convert UCS
        if string.match(alphabet, 'UCS2') then
            text = capture('tail -n +13 '..path..' | iconv -f UCS-2BE -t UTF-8')
        else
            text = file:read('*a')
        end
        file:close()

        text = string.gsub(text, '[\n\r]+', ' ')
        text = string.gsub(text, '^%s+', '')
        text = string.gsub(text, '%s+$', '')
    end -- if file
    if DEBUG then print(from, alphabet, text) end
    return from, text
end

local function checkfrom(from, admin_from)
    for _, admin in ipairs(admin_from) do
        if from == admin then
            if DEBUG then print('from is admin') end
            return true
        end
    end
    if DEBUG then print('from is not admin') end
    return false
end

local function checkpass(text, password)
    local _,b = string.find(text, password)
    if b then
        b = b + 1
        text = string.sub(text, b)
        text = string.gsub(text, '^%s+', '')
        if DEBUG then print('password correct') end
        return text
    else
        if DEBUG then print('password incorrect') end
        return false
    end
end

local function sendsms(to,t_str,outgoing)
    local pathsms = os.date('/tmp/'..to..'_%d_%b_%X')
    local file = io.open(pathsms,'w')
    if file then
        file:write('To: '..to..'\n\n')
        if #t_str == 0 then
            file:write('Command not found\n')
        else
            for i = 1,#t_str do
                file:write(t_str[i]..'\n')
            end
        end
        file:write(os.date('%X'))
        file:flush()
        file:close()
        os.execute('mv '..pathsms..' '..outgoing)
        if DEBUG then print('sendsms to '..to..' OK') end
    end
end

-- MAIN chunk
do
    if status == 'RECEIVED' then
        -- RECEIVED
        if DEBUG then print('sms received') end
        local from, text = readtext(path)
        local cmd = checkpass(text, PASSWORD)
        if not cmd then
            if checkfrom(from, ADMIN_FROM) then
                cmd = text
            end
        end
        
        -- Execute command
        if cmd then
            local out = {}
            cmd = string.lower(cmd)
            if DEBUG then print(cmd) end
            
            for i = 1,#GPIO_NUMBER do
                if string.match(cmd, GPIO_NAME[i]..' on') then
                    os.execute('echo 1 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' on')
                elseif string.match(cmd, GPIO_NAME[i]..' off') then
                    os.execute('echo 0 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' off')
                elseif string.match(cmd, GPIO_NAME[i]..' pulse') then
                    local states = capture('cat /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    states = tonumber(states)
                    if states == 0 then
                        states = 1
                    else
                        states = 0
                    end
                    os.execute('echo '..states..' > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    sleep(5)
                    if states == 0 then
                        states = 1
                    else
                        states = 0
                    end
                    os.execute('echo '..states..' > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' pulse')
                end
            end
            
            if string.match(cmd, 'stat') then
                out = readfile(STATE_GPIO, out)
                out = readfile(STATE_MON, out)
            elseif string.match(cmd, 'stop') then
                os.execute('killall -9 lua && /etc/init.d/smstools3 stop')
            elseif string.match(cmd, 'reboot') then
                os.execute('reboot')
            end
            -- Send SMS
            sendsms(from,out,OUTGOING)
        end -- if cmd
    elseif status == 'SEND' then
        -- SEND
    elseif status == 'FAILED' then
        -- FAIL
    elseif status == 'REPORT' then
        -- REPORT
    elseif status == 'CALL' then
        -- CALL
    end
end
os.exit(0)
