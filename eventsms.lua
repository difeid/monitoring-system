#!/usr/bin/env lua

-- Eventhandler for SMS Tools 3
-- Add eventhandler=/path/to/eventsms.lua into global part of smsd.conf
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 0.6

local status = arg[1]
local path = arg[2]

local ADMIN_FROM = {'79520405261'}
local PASSWORD = 'goodlife'
local GPIO_NUMBER = {21}
local GPIO_NAME = {'relay'}
local OUTGOING = '/var/spool/sms/outgoing/'
    
local function capture(cmd)
    local file = assert(io.popen(cmd,'r'))
    local str = assert(file:read('*a'))
    file:close()
    return str
end

local function sleep(s)
    os.execute('sleep '..s)
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
        text = file:read('*a')
        file:close()

        --convert UCS
        if string.match(alphabet, 'UCS') then
            text = capture('echo "'..text..'" | iconv -f UCS-2BE -t UTF-8')
        end
        text = string.gsub(text, '[\n\r]+', ' ')
        text = string.gsub(text, '^%s+', '')
        text = string.gsub(text, '%s+$', '')
    end -- if file
    return from, text
end

local function checkfrom(from, admin_from)
    for _, admin in ipairs(admin_from) do
        if from == admin then
            return true
        end
    end
    return false
end

local function checkpass(text, password)
    local _,b = string.find(text, password)
    if b then
        b = b + 1
        text = string.sub(text, b)
        text = string.gsub(text, '^%s+', '')
        return text
    else
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
    end
end

-- MAIN chunk
do
    if status == 'RECEIVED' then
        -- RECEIVED
        local from, text = readtext(path)
        local cmd = checkpass(text, PASSWORD)
        if not cmd then
            if checkfrom(from, ADMIN_FROM) then
                cmd = text
            end
        end
        
        -- Execute command
        if cmd then
            local cmd_return
            local out = {}
            
            cmd = string.lower(cmd)
            for i = 1,#GPIO_NUMBER do
                if string.match(cmd, GPIO_NAME[i]..' off[^%-]') then
                    _,_,cmd_return = os.execute('echo 1 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' off '..cmd_return)
                elseif string.match(cmd, GPIO_NAME[i]..' on[^%-]') then
                    _,_,cmd_return = os.execute('echo 0 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' on '..cmd_return)
                elseif string.match(cmd, GPIO_NAME[i]..' off%-on') then
                    _,_,cmd_return = os.execute('echo 1 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    sleep('5s')
                    _,_,cmd_return = os.execute('echo 0 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' off-on '..cmd_return)
                end
            end
            
            if string.match(cmd, 'state') then
                -- _,_,out = os.execute('uptime')
                -- table.insert(tab_out, out)
            elseif string.match(cmd, 'stop') then
                os.execute('kill $(pidof lua) && /etc/init.d/smstools stop')
            elseif string.match(cmd, 'reboot') then
                os.execute('reboot')
            end
            -- Send SMS
            sendsms(from,out,OUTGOING)
        end
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
