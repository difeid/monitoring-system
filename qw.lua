#!/usr/bin/env lua

local function sleep(s)
    os.execute('sleep '..s)
end

local tab = {1,2}
while (true) do
    print(tab, tab[1])
    tab = {}
    print(tab, tab[1])
    sleep(3)
end
