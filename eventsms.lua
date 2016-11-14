#!/usr/bin/env lua

-- Eventhandler for SMS Tools 3
-- Add eventhandler=/path/to/eventsms.lua into global part of smsd.conf
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 1.7

local status = arg[1]
local path = arg[2]

local DEBUG = false
local ADMIN_FROM = {'79500000000'}
local PASSWORD = 'goodlife'
local GPIO_NUMBER = {18}
local GPIO_NAME = {'relay'}
local CAM_ADDR = {'192.168.2.146','192.168.2.147'}
local CAM_NAME = {'cam1','cam2'}
local CAM_USER = {'admin','admin'}
local CAM_PASS = {'admin123','password1'}
local OUTGOING = '/var/spool/sms/outgoing/'
local PATH_TMP = '/usr/local/tmp/'
local PATH_XML = '/usr/local/etc/'
    
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
        if #t_str > 0 then
            for i = 1,#t_str do
                file:write(t_str[i]..'\n')
            end
        else
            file:write('command not found\n')
            if DEBUG then print('command not found') end
        end
        file:write(os.date('%X'))
        file:flush()
        file:close()
        os.execute('mv '..pathsms..' '..outgoing)
        if DEBUG then print('sendsms to '..to) end
    end
end

-- MAIN chunk
do
    if DEBUG then print('event handled') end
    if status == 'RECEIVED' then
        -- RECEIVED
        if DEBUG then print('event status - received') end
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
            
            -- GPIO control
            for i = 1,#GPIO_NUMBER do
                if string.match(cmd, GPIO_NAME[i]..' on') then
                    os.execute('echo 1 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' on')
                    if DEBUG then print(GPIO_NAME[i]..' on') end
                elseif string.match(cmd, GPIO_NAME[i]..' off') then
                    os.execute('echo 0 > /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    table.insert(out, GPIO_NAME[i]..' off')
                    if DEBUG then print(GPIO_NAME[i]..' off') end
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
                    if DEBUG then print(GPIO_NAME[i]..' pulse') end
                end
            end -- for (GPIO control)
            
            -- Camera control
            for i = 1,#CAM_ADDR do
                if string.match(cmd, CAM_NAME[i]..' ir on') then
                    local report = capture('curl -s -f -X PUT -d @'..PATH_XML..'ir_night.xml --user '..CAM_USER[i]..':'..CAM_PASS[i]..' http://'..CAM_ADDR[i]..'/ISAPI/Image/channels/1/ircutFilter')
                    if DEBUG then print('curl:'..report) end
                    if string.len(report) > 0 then
                        table.insert(out, CAM_NAME[i]..' night mode on')
                        if DEBUG then print(CAM_NAME[i]..' night mode on') end
                    else
                        table.insert(out, CAM_NAME[i]..' night mode FAIL')
                        if DEBUG then print(CAM_NAME[i]..' night mode FAIL') end
                    end
                elseif string.match(cmd, CAM_NAME[i]..' ir off') then
                    local report = capture('curl -s -f -X PUT -d @'..PATH_XML..'ir_auto.xml --user '..CAM_USER[i]..':'..CAM_PASS[i]..' http://'..CAM_ADDR[i]..'/ISAPI/Image/channels/1/ircutFilter')
                    if DEBUG then print('curl:'..report) end
                    if string.len(report) > 0 then
                        table.insert(out, CAM_NAME[i]..' night mode auto')
                        if DEBUG then print(CAM_NAME[i]..' night mode auto') end
                    else
                        table.insert(out, CAM_NAME[i]..' night mode FAIL')
                        if DEBUG then print(CAM_NAME[i]..' night mode FAIL') end
                    end
                end
            end -- for (Camera control)
            
            -- System status
            if string.match(cmd, 'stat') then
                out = readfile(PATH_TMP..'gpiod', out)
                for i = 1,#GPIO_NUMBER do
                local states = capture('cat /sys/class/gpio/gpio'..GPIO_NUMBER[i]..'/value')
                    states = tonumber(states)
                    if states == 1 then
                        table.insert(out, GPIO_NAME[i]..' on')
                    elseif states == 0 then
                        table.insert(out, GPIO_NAME[i]..' off')
                    else
                        table.insert(out, 'FAIL '..GPIO_NAME[i]..' status')
                    end
                end
                out = readfile(PATH_TMP..'monitord', out)
                if DEBUG then print('current states ready') end
            
            -- Kill monitoring system
            elseif string.match(cmd, 'stop') then
                os.execute('killall -9 lua && /etc/init.d/smstools3 stop')
                table.insert(out, 'stop monitoring system')
                if DEBUG then print('stop monitoring system') end
                
            -- Reboot monitoring device
            elseif string.match(cmd, 'reboot') then
                os.execute('reboot')
                table.insert(out, 'reboot monitoring device')
                if DEBUG then print('reboot monitoring device') end
            end
            
            -- Send SMS
            sendsms(from,out,OUTGOING)
        end -- if cmd
    elseif status == 'SEND' then
        -- SEND
        if DEBUG then print('event status - send') end
    elseif status == 'FAILED' then
        -- FAIL
        if DEBUG then print('event status - fail') end
    elseif status == 'REPORT' then
        -- REPORT
        if DEBUG then print('event status - report') end
    elseif status == 'CALL' then
        -- CALL
        if DEBUG then print('event status - call') end
    end -- if status
end
os.exit(0)
