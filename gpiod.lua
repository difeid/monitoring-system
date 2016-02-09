#!/usr/bin/env lua

-- Initialization and monitoring gpio
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 1.1

local DEBUG = true
local IN_GPIO = {21,22}
local IN_NAME = {'button 1','button 2'}
local OUT_GPIO = {18}
local WAIT_TIME = '1s'
local STATE_FILE = '/usr/local/etc/gpiod'
local ADMIN_TO = {'79500000000'}
local OUTGOING = '/var/spool/sms/outgoing/'

local function initgpio(in_gpio, out_gpio)
    for _,in_number in ipairs(in_gpio) do
        os.execute('echo '..in_number..' > /sys/class/gpio/export')
        os.execute('echo in > /sys/class/gpio/gpio'..in_number..'/direction')
        if DEBUG then print('gpio'..in_number..' in') end
    end
    for _,out_number in ipairs(out_gpio) do
        os.execute('echo '..out_number..' > /sys/class/gpio/export')
        os.execute('echo out > /sys/class/gpio/gpio'..out_number..'/direction')
        if DEBUG then print('gpio'..out_number..' out') end
    end
end

local function readgpio(gpio_number)
    local file = io.open('/sys/class/gpio/gpio'..gpio_number..'/value','r')
    local text
    if file then
        text = file:read('*n')
        file:close()
    end
    if DEBUG then print(gpio_number,text) end
    return text
end

local function sleep(s)
    os.execute('sleep '..s)
end

local function readfile(path, count)
    local tab = {}
    local file = io.open(path,'r')
    local state
    if file then
        for line in file:lines() do
            state = string.match(line,'^(%d)')
            table.insert(tab, tonumber(state))
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
            if DEBUG then print('sendsms to '..to..' OK') end
        end
    end
    t_str = {}
    return t_str
end


-- MAIN chunk
do
    local tab = readfile(STATE_FILE, #IN_GPIO)
    local result
    local tab_str = {}
    
    savefile(STATE_FILE, tab, IN_NAME)
    initgpio(IN_GPIO, OUT_GPIO)
    
    while(true) do
        for i = 1,#IN_GPIO do
            result = readgpio(IN_GPIO[i])
            if (result == 0) then
                if tab[i] == 1 then
                    tab[i] = 0
                    -- Send SMS (IN_MAME[i] OK)
                    table.insert(tab_str, string.format('%s %s',IN_NAME[i],'OK\n'))
                    if DEBUG then print('gpio'..IN_GPIO[i]..' OK') end
                end
            else
                if tab[i] == 0 then
                    tab[i] = 1
                    -- Send SMS (IN_MAME[i] FAIL)
                    table.insert(tab_str, string.format('%s %s',IN_NAME[i],'FAIL\n'))
                    if DEBUG then print('gpio'..IN_GPIO[i]..' FAIL') end
                end
            end
        end
        if #tab_str > 0 then
            savefile(STATE_FILE, tab, IN_NAME)
            tab_str = sendsms(ADMIN_TO, tab_str, OUTGOING)
        end
        sleep(WAIT_TIME)
    end -- end while
end -- end main
os.exit(0)
