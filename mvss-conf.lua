#!/usr/bin/env lua

-- Configuration management of video surveillance system

PASSWORD = 'password'
ADMIN_NUMBER  = {'79500000000'}
NOTIFY_NUMBER = {'79500000000'}

-- Monitoring settings
MONITOR_ADDR = {'n 192.168.100.1:80','p 192.168.8.245','ya.ru'}
MONITOR_NAME = {'TP LINK','notebook','ya.ru'}

-- Management camera settings
CAM_CONTROL_ADDR = {'192.168.2.146','192.168.2.147'}
CAM_CONTROL_NAME = {'cam1','cam2'}
CAM_CONTROL_USER = {'admin','admin'}
CAM_CONTROL_PASS = {'admin123','password1'}

-- GPIO settings
IN_GPIO_NUMBER = {21,22}
IN_GPIO_NAME = {'button 1','button 2'}
OUT_GPIO_NUMBER = {18}
OUT_GPIO_NAME = {'relay'}

-- Path settings
OUTGOING = '/var/spool/sms/outgoing/'
PATH_TMP = '/usr/local/tmp/'
PATH_XML = '/usr/local/etc/'
