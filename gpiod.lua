#!/usr/bin/env lua

-- Initialization and monitoring gpio
-- Required io support
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 0.3

local IN_GPIO = {18,19}
local IN_NAME = {'door','power'}
local OUT_GPIO = {20,21,22}
local WAIT_TIME = '3s'
local TMP_FILE = '/var/tmp/gpiod.tmp'
local ADMIN_TO = {'79520405261','79509465765'}
local OUTGOING = '/var/spool/sms/outgoing'

local function initgpio(in_gpio, out_gpio)
    for _,in_number in ipairs(in_gpio) do
        os.execute('echo '..in_number..' > /sys/class/gpio/export')
        os.execute('echo in > /sys/class/gpio/gpio'..in_number..'/direction')
    end
    for _,out_number in ipairs(out_gpio) do
        os.execute('echo '..out_number..' > /sys/class/gpio/export')
        os.execute('echo out > /sys/class/gpio/gpio'..out_number..'/direction')
    end
end

local function readgpio(gpio_number)
    local file = io.open('/sys/class/gpio/gpio'..gpio_number..'/value','r')
    local text
    if file then
        text = file:read('*n')
        file:close()
    end
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
        for line in file.lines() do
            state = string.match(line,'^(%d)')
            table.insert(tab, state)
        end
        file:close()
    end
    if #tab < count then
        for _ = 1,count do
            table.insert(tab, 0)
        end
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
    end
end

local function sendsms(tab_str, admin_to, outgoing)
    for _, admin in ipairs(admin_to) do
        local pathsms = os.date('/var/tmp/'..admin..'_%d_%b_%X')
        local file = io.open(path,'w')
        if file then
            file:write('To: '..admin..'\n\n')
            for i = 1,#tab_str do
                file:write(tab_str[i])
            end
            file:write(os.date(%X))
            file:flush()
            file:close()
            os.execute('mv '..pathsms..' '..outgoing)
        end
    end
    tab_str = {}
    return tab_str
end


-- MAIN chunk
do
    local tab = readfile(TMP_FILE, #IN_GPIO)
    local result
    local tab_str = {}
    
    savefile(TMP_FILE, tab, IN_NAME)
    initgpio(IN_GPIO, OUT_GPIO)
    
    while(true) do
        for i = 1,#IN_GPIO do
            result = readgpio(IN_GPIO[i])
            if (result == 0) then
                if tab[i] == 1 then
                    tab[i] = 0
                    -- Send SMS (IN_MAME[i] OK)
                    table.insert(tab_str, string.format('%s %s',IN_NAME[i],'OK\n'))
                    savefile(TMP_FILE, tab, IN_NAME)
                end
            else
                if tab[i] == 0 then
                    tab[i] = 1
                    -- Send SMS (IN_MAME[i] FAIL)
                    table.insert(tab_str, string.format('%s %s',IN_NAME[i],'FAIL\n'))
                    savefile(TMP_FILE, tab, IN_NAME)
                end
            end
        end
        if #tab_str > 0 then
            tab_str = sendsms(tab_str, ADMIN_TO, OUTGOING)
        end
        sleep(WAIT_TIME)
    end -- end while
end -- end main
os.exit(0)
