#!/usr/bin/env lua

-- Initialization and monitoring gpio
-- Written by DIfeID (difeid@yandex.ru), 2016, Copyleft GPLv3 license
-- Version 2.0

local DEBUG = false
local WAIT_TIME = '2s'
local PATH_CONFIG = '../../etc/mvss-conf.lua'

local function read_settings(path)
    local ok, e = pcall(dofile, path)
    if not ok then
        if DEBUG then print('error read settings: '..e) end
        os.exit(0)
    end
end

local function init_gpio(in_gpio, out_gpio)
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

local function read_gpio(gpio_number)
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
    
    local state_file = PATH_TMP..'gpiod'
    local tab = read_file(state_file, #IN_GPIO_NUMBER)
    local result
    local tab_str = {}
    
    save_file(state_file, tab, IN_GPIO_NAME)
    init_gpio(IN_GPIO_NUMBER, OUT_GPIO_NUMBER)
    
    while(true) do
        for i = 1,#IN_GPIO_NUMBER do
            result = read_gpio(IN_GPIO_NUMBER[i])
            if (result == 0) then
                if tab[i] == 1 then
                    tab[i] = 0
                    -- Send SMS (IN_MAME[i] OK)
                    table.insert(tab_str, string.format('%s %s',IN_GPIO_NAME[i],'OK\n'))
                    if DEBUG then print('gpio'..IN_GPIO_NUMBER[i]..' OK') end
                end
            else
                if tab[i] == 0 then
                    tab[i] = 1
                    -- Send SMS (IN_MAME[i] FAIL)
                    table.insert(tab_str, string.format('%s %s',IN_GPIO_NAME[i],'FAIL\n'))
                    if DEBUG then print('gpio'..IN_GPIO_NUMBER[i]..' FAIL') end
                end
            end
        end
        if #tab_str > 0 then
            save_file(state_file, tab, IN_GPIO_NAME)
            tab_str = send_sms(NOTIFY_NUMBER, tab_str, OUTGOING)
        end
        sleep(WAIT_TIME)
    end -- end while
end -- end main
os.exit(0)
