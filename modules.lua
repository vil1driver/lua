--[[



bibliothèque de fonctions pour domoticz
utiles à la réalisation de scripts d'automation en langage lua

/!\ certaines fonctions ne fonctionneront pas sous windows.

copier ce qui se trouve entre les 2 lignes ci dessous, en début de tout vos script
pour charger ce fichier et pouvoir en utiliser les fonctions


--------------------------------------------------------------------------------------------------------


-- chargement des modules (http://easydomoticz.com/forum/viewtopic.php?f=17&t=3940)
dofile('/home/pi/domoticz/scripts/lua/modules.lua')

local debug = true  -- true pour voir les logs dans la console log Dz ou false pour ne pas les voir


--------------------------------------------------------------------------------------------------------


]]


--------------------------------
------ 	  USER SETTINGS	  ------
--------------------------------

-- domoticz
domoticzIP = '192.168.22.100'	--'127.0.0.1'
domoticzPORT = '8080'
domoticzUSER = ''		-- nom d'utilisateur
domoticzPSWD = ''		-- mot de pass
domoticzPASSCODE = ''	-- pour interrupteur protégés
domoticzURL = 'http://'..domoticzIP..':'..domoticzPORT


--------------------------------
------         END        ------
--------------------------------


-- chemin vers le dossier lua et curl
if (package.config:sub(1,1) == '/') then
	-- system linux
	luaDir = debug.getinfo(1).source:match("@?(.*/)")
	curl = '/usr/bin/curl -m 15 '		 							-- ne pas oublier l'espace à la fin
else
	-- system windows
	luaDir = string.gsub(debug.getinfo(1).source:match("@?(.*\\)"),'\\','\\\\')
	-- download curl : https://bintray.com/vszakats/generic/download_file?file_path=curl-7.54.0-win32-mingw.7z
	curl = 'c:\\Programs\\Curl\\curl.exe '		 					-- ne pas oublier l'espace à la fin
end

-- chargement du fichier JSON.lua
json = assert(loadfile(luaDir..'JSON.lua'))()

--time.hour ou time.min ou time.sec
--ex : if (time.hour == 17 and time.min == 05) then
time = os.date("*t")

-- retourne l'heure actuelle ex: "12:45"
heure = string.sub(os.date("%X"), 1, 5)

-- retourne la date ex: "01:01"
date = os.date("%d:%m")

-- retourne l'heure du lever de soleil ex: "06:41"
leverSoleil = string.sub(os.date("!%X",60*timeofday['SunriseInMinutes']), 1, 5)

-- retourne l'heure du coucher de soleil ex: "22:15"
coucherSoleil = string.sub(os.date("!%X",60*timeofday['SunsetInMinutes']), 1, 5)

-- retourne le jour actuel en français ex: "mardi"
days = {"dimanche","lundi","mardi","mercredi","jeudi","vendredi","samedi"}
jour = days[(os.date("%w")+1)]

-- est valide si la semaine est paire
-- usage :
-- if semainePaire then ..
semainePaire = os.date("%W")%2 == 0

-- il fait jour
dayTime = timeofday['Daytime']
-- il fait nuit
nightTime = timeofday['Nighttime']

-- température
function getTemp(device)
	return round(tonumber(otherdevices_temperature[device]),1)
end

-- humidité
function getHum(device)
	return round(tonumber(otherdevices_humidity[device]),1)
end

-- humidité absolue
function humAbs(t,hr)
-- https://carnotcycle.wordpress.com/2012/08/04/how-to-convert-relative-humidity-to-absolute-humidity/
-- Formule pour calculer l'humidité absolue
-- Dans la formule ci-dessous, la température (T) est exprimée en degrés Celsius, l'humidité relative (hr) est exprimée en%, et e est la base des logarithmes naturels 2.71828 [élevée à la puissance du contenu des crochets]:
-- Humidité absolue (grammes / m3 ) =  (6,122 * e^[(17,67 * T) / (T + 243,5)] * rh * 2,1674))/(273,15 + T)
-- Cette formule est précise à 0,1% près, dans la gamme de température de -30 ° C à + 35 ° C
	return round((6.112 * math.exp((17.67 * t)/(t+243.5)) * hr * 2.1674)/ (273.15 + t),1)
end

-- set setpoint (faster way)
function setPoint(device,value)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=udevice&idx='..otherdevices_idx[device]..'&nvalue=0&svalue='..value..'" &')
end

function dimUp15(device)
	-- 15 step
	switchOn(device, constrain(otherdevices_svalues[device]+1,1,15))
end

function dimDown15(device)
	-- 15 step
	switchOn(device, constrain(otherdevices_svalues[device]-1,1,15))
end

function dimUp(device)
	-- 100 step
	switchOn(device, constrain(otherdevices_svalues[device]+10,10,100))
end

function dimDown(device)
	-- 100 step
	switchOn(device, constrain(otherdevices_svalues[device]-10,10,100))
end

-- vérifie s'il y a eu changement d'état
function stateChange(device)
	if (uservariables['lastState_'..device] == nil) then
		creaVar('lastState_'..device,otherdevices[device])
		log('stateChange : création variable manquante lastState_'..device,debug)
		return false
	elseif (devicechanged[device] == nil) then
		return false
	elseif (devicechanged[device] == uservariables['lastState_'..device]) then
		return false
	else
		duree = lastSeen(uservariables_lastupdate['lastState_'..device])
		updateVar('lastState_'..device,otherdevices[device])
		return otherdevices[device]
	end
end	

-- convertion degrés en direction cardinale
function wind_cardinals(deg)
	local cardinalDirections = {
		['N'] = {348.75, 360},
		['N'] = {0, 11.25},
		['NNE'] = {11.25, 33.75},
		['NE'] = {33.75, 56.25},
		['ENE'] = {56.25, 78.75},
		['E'] = {78.75, 101.25},
		['ESE'] = {101.25, 123.75},
		['SE'] = {123.75, 146.25},
		['SSE'] = {146.25, 168.75},
		['S'] = {168.75, 191.25},
		['SSW'] = {191.25, 213.75},
		['SW'] = {213.75, 236.25},
		['WSW'] = {236.25, 258.75},
		['W'] = {258.75, 281.25},
		['WNW'] = {281.25, 303.75},
		['NW'] = {303.75, 326.25},
		['NNW'] = {326.25, 348.75}
		}
	local cardinal
	for dir, angle in pairs(cardinalDirections) do
		if (deg >= angle[1] and deg < angle[2]) then
			cardinal = dir
			break
		end	
	end
	return cardinal
end
	
-- dump all variables supplied to the script
-- usage
-- LogVariables(_G,0,'')
function LogVariables(x,depth,name)
    for k,v in pairs(x) do
        if (depth>0) or ((string.find(k,'device')~=nil) or (string.find(k,'variable')~=nil) or 
                         (string.sub(k,1,4)=='time') or (string.sub(k,1,8)=='security')) then
            if type(v)=="string" then print(name.."['"..k.."'] = '"..v.."'") end
            if type(v)=="number" then print(name.."['"..k.."'] = "..v) end
            if type(v)=="boolean" then print(name.."['"..k.."'] = "..tostring(v)) end
            if type(v)=="table" then LogVariables(v,depth+1,k); end
        end
    end
end

-- os.execute() output or web page content return
-- usage
-- local resultat = os.capture(cmd , true)
-- print('resultat: ' .. resultat)
function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

-- retourne le type de la variable
-- 'string' , 'number' , 'table'
function typeof(var)
    local _type = type(var);
    if(_type ~= "table" and _type ~= "userdata") then
        return _type;
    end
    local _meta = getmetatable(var);
    if(_meta ~= nil and _meta._NAME ~= nil) then
        return _meta._NAME;
    else
        return _type;
    end
end

-- affiche les logs en bleu sauf si debug est spécifié à false
function log(txt,debug)
    if (debug ~= false) then
        print("<font color='#0206a9'>"..txt.."</font>")
    end
end  

-- affiche les logs en rouge sauf si debug est spécifié à false
function warn(txt,debug)
    if (debug ~= false) then
        print("<font color='red'>"..txt.."</font>")
    end
end

-- écriture dans un fichier texte dans le dossier lua
function logToFile(fileName,data)
	f = assert(io.open(luaDir..fileName..'.txt',"a"))
	f:write(os.date("%c")..' '..data..'\n')
	f:close()
end  

-- teste l'existance d'un fichier
function file_exists(file)
     local f = io.open(file, "rb")
     if f then f:close() end
     return f ~= nil
end
   
-- encode du texte pour le passer dans une url
function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str	
end

-- supprime les accents de la chaîne
function sans_accent(str)
    if (str) then
		str = string.gsub (str,"Ç", "C")
		str = string.gsub (str,"ç", "c")
		str = string.gsub (str,"[-èéêë']+", "e")
		str = string.gsub (str,"[-ÈÉÊË']+", "E")
		str = string.gsub (str,"[-àáâãäå']+", "a")
		str = string.gsub (str,"[-@ÀÁÂÃÄÅ']+", "A")
		str = string.gsub (str,"[-ìíîï']+", "i")
		str = string.gsub (str,"[-ÌÍÎÏ']+", "I")
		str = string.gsub (str,"[-ðòóôõö']+", "o")
		str = string.gsub (str,"[-ÒÓÔÕÖ']+", "O")
		str = string.gsub (str,"[-ùúûü']+", "u")
		str = string.gsub (str,"[-ÙÚÛÜ']+", "U")
		str = string.gsub (str,"[-ýÿ']+", "y")
		str = string.gsub (str,"Ý", "Y")
    end
    return str
end

-- retourne le temps en seconde depuis la dernière maj du péréphérique
function lastSeen(device)
  timestamp = otherdevices_lastupdate[device] or device
  y, m, d, H, M, S = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  difference = os.difftime(os.time(), os.time{year=y, month=m, day=d, hour=H, min=M, sec=S})
  return difference
end

-- contraindre
function constrain(x, a, b)
	if (x < a) then
		return a
	elseif (x > b) then
		return b
	else
		return x
	end
end

-- arrondire
function round(num, dec)
   if num == 0 then
	 return 0
   else
	 local mult = 10^(dec or 0)
	 return math.floor(num * mult + 0.5) / mult
   end
end

-- met le script en pause (fortement déconseillé)
-- usage
-- sleep(10) -- pour mettre en pause 10 secondes
function sleep(n)
  os.execute('sleep '..n)
end

-- création de variable utilisateur
-- usage
-- creaVar('toto','10') -- pour créer une variable nommée toto comprenant la valeur 10
function creaVar(name,value)
	local api = '/json.htm?type=command&param=saveuservariable'
	local name = '&vname='..url_encode(name)
	local vtype = '&vtype=2'
	local value = '&vvalue='..url_encode(value)
	api = api..name..vtype..value
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- update an existing variable
function updateVar(name,value)
	local api = '/json.htm?type=command&param=updateuservariable'
	local name = '&vname='..url_encode(name)
	local vtype = '&vtype=2'
	local value = '&vvalue='..url_encode(value)
	api = api..name..vtype..value
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- envoie dans un capteur text une chaîne de caractères
-- le text sera intercepté et lu par la custom page grâce à sa fonction MQTT
-- usage
-- speak('tts','bonjour nous sommes dimanche')
function speak(TTSDeviceName,txt)
	commandArray[#commandArray+1] = {['OpenURL'] = domoticzIP..":"..domoticzPORT..'/json.htm?type=command&param=udevice&idx='..otherdevices_idx[TTSDeviceName]..'&nvalue=0&svalue='..url_encode(txt)}
end

-- récupère les infos json du périphérique
-- usage
-- local lampe = jsonInfos('ma lampe')
-- print(lampe.Name)
-- print(lampe.Status)
-- etc..
function jsonInfos(device)
	local rid = assert(io.popen(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=devices&rid='..otherdevices_idx[device]..'"'))
	local list = rid:read('*all')
	rid:close()
	return json:decode(list).result[1]
end

-- parcours la table dans l'ordre
function spairs(t)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
	table.sort(keys)
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

-- Renverse une table
function ReverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

-- affiche le contenu d'une table
--[[  

   Author: Julio Manuel Fernandez-Diaz
   Date:   January 12, 2007
   (For Lua 5.1)
   
   Modified slightly by RiciLake to avoid the unnecessary table traversal in tablecount()

   Formats tables with cycles recursively to any depth.
   The output is returned as a string.
   References to other tables are shown as values.
   Self references are indicated.

   The string returned is "Lua code", which can be procesed
   (in the case in which indent is composed by spaces or "--").
   Userdata and function keys and values are shown as strings,
   which logically are exactly not equivalent to the original code.

   This routine can serve for pretty formating tables with
   proper indentations, apart from printing them:

      print(table_show(t, "t"))   -- a typical use
   
   Heavily based on "Saving tables with cycles", PIL2, p. 113.

   Arguments:
      t is the table.
      name is the name of the table (optional)
      indent is a first indentation (optional).
]]
function table_show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else 
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" or type(o) == "boolean" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] 
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "table"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end

-- retourne la table des derniers log (première ligne = dernier log)
function lastLogEntry()
	local rid = assert(io.popen(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=getlog"'))
	local list = rid:read('*all')
	rid:close()
	local tableau = json:decode(list).result
	return ReverseTable(tableau)
end

-- notification pushbullet
-- usage:
-- pushbullet('test','ceci est un message test')
function pushbullet(title,body)
	local settings = assert(io.popen(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=settings"'))
	local list = settings:read('*all')
	settings:close()
	local pushbullet_key = json:decode(list).PushbulletAPI
	os.execute(curl..'-H \'Access-Token:'..pushbullet_key..'\' -H \'Content-Type:application/json\' --data-binary \'{"title":"'..title..'","body":"'..body..'","type":"note"}\' -X POST "https://api.pushbullet.com/v2/pushes"')
end

-- switch On a device and set level if dimmmable
function switchOn(device,level)
	local api = '/json.htm?type=command&param=switchlight'
	local idx = '&idx='..otherdevices_idx[device]
	local cmd
	if level ~= nil then 
		cmd = '&switchcmd=Set%20Level&level='..level
	else
		cmd = '&switchcmd=On'
	end
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..cmd..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- switch On a devive for x secondes 
function switchOnFor(device, secs)
   switchOn(device)
   commandArray[#commandArray+1] = {[device] = "Off AFTER "..secs}
end

-- switch Off a device
function switchOff(device)
	local api = '/json.htm?type=command&param=switchlight'
	local idx = '&idx='..otherdevices_idx[device]
	local cmd = '&switchcmd=Off'
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..cmd..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- Toggle a device
function switch(device)
	local api = '/json.htm?type=command&param=switchlight'
	local idx = '&idx='..otherdevices_idx[device]
	local cmd = '&switchcmd=Toggle'
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..cmd..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- switch On a group or scene
function groupOn(device)
	local api = '/json.htm?type=command&param=switchscene'
	local idx = '&idx='..otherdevices_scenesgroups_idx[device]
	local cmd = '&switchcmd=On'
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..cmd..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- switch Off a group
function groupOff(device)
	local api = '/json.htm?type=command&param=switchscene'
	local idx = '&idx='..otherdevices_scenesgroups_idx[device]
	local cmd = '&switchcmd=Off'
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..cmd..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- Set switch to Stop
function switchStop(device)
	local api = '/json.htm?type=command&param=switchlight'
	local idx = '&idx='..otherdevices_idx[device]
	local cmd = '&switchcmd=Stop'
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..cmd..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end
 
-- Setup a color & brightness of an RGB(W) light
-- API : https://www.domoticz.com/wiki/Domoticz_API/JSON_URL%27s#Set_an_RGB.28W.29_light_to_a_certain_color_and_brightness
function setColorAndBrightness(device, color, brightness)
	local api = '/json.htm?type=command&param=setcolbrightnessvalue'
	local idx = '&idx='..otherdevices_idx[device]
	--local color = '&hue='..color
	local color = '&hex='..color
	local brightness = '&brightness='..brightness
	local iswhite = '&iswhite=false'
	local passcode = '&passcode='..domoticzPASSCODE
	api = api..idx..color..brightness..iswhite..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

function KelvinToRGB(temp)
	-- http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
    temp = temp/100
    local red, green, blue
	--Calculate Red:
	if temp <= 66 then
        red = 255
    else
        red = constrain(round(329.698727446 * ((temp - 60) ^ -0.1332047592)),0,255)
	end
    --Calculate Green:
	if temp <= 66 then
		green = constrain(round(99.4708025861 * math.log(temp) - 161.1195681661),0,255)
    else
		green = constrain(round(288.1221695283 * ((temp - 60) ^ -0.0755148492)),0,255)
    end
    --Calculate Blue:
	if temp >= 66 then
        blue = 255
    else
		if temp <= 19 then
            blue = 0
        else
			blue = constrain(round(138.5177312231 * math.log(temp - 10) - 305.0447927307),0,255)
		end
	end
	return {red,green,blue}
end

function RGBToHex(rgb)
	-- https://gist.github.com/marceloCodget/3862929
	local hexadecimal = ''
	for key, value in pairs(rgb) do
		local hex = ''
		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex			
		end
		if(string.len(hex) == 0)then
			hex = '00'
		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end
		hexadecimal = hexadecimal .. hex
	end
	return hexadecimal
end

function suntimeToKelvin()
	-- http://easydomoticz.com/forum/viewtopic.php?f=10&t=6160
	local mini = 1900
	local maxi = 6600
	local delta = maxi - mini
	local wakeup = 60*timeofday['SunriseInMinutes']
	local goodnight = 60*timeofday['SunsetInMinutes']
	local periode = goodnight - wakeup
	local offset = wakeup-periode/2
	local color = mini
	local time = os.date("*t")
	local now = 60*(time.hour*60 + time.min)
	if now >= wakeup and now < goodnight then
		color = math.floor((maxi-delta/2)+(delta/2)*math.cos((now-offset)*2*math.pi/periode)+0.5)
	end
	return color
end	

-- régulation chauffage (PID)
--[[

	usage:
	
	local pid={}
	pid['debug'] = true								-- true pour voir les logs dans la console log Dz ou false pour ne pas les voir
	pid['zone'] = 'salon'							-- nom de la zone pour affichage dans les logs et ditinction de variables
	pid['sonde'] = 'salon' 							-- Nom de la sonde de température
	pid['OnOff'] = 'chauffage' 						-- Nom de l'interrupteur virtuel de mise en route (hivers/été)
	pid['thermostat'] = 'th_salon' 					-- consigne ou 'nom' de l'interrupteur virtuel de thermostat
	-- actionneur
	pid['radiateur'] = 'radiateur salon' 			-- Nom de l'interrupteur de chauffage
	pid['invert'] = false							-- si On et Off doivent être inversé ou non

	-- PID -- 
	pid['Kp'] = 70 									-- Coefficient proportionnel 
	pid['Ki'] = 8 									-- Coefficient intégrateur
	pid['Kd'] = 3 									-- Coefficient dérivateur

	pid['cycle'] = 15								-- temps en minute d'un cycle PID
	pid['secu'] = 60								-- temps mini en seconde entre 2 ordres opposés
	
	commandArray = {} 
	compute(pid)
	return commandArray

]]
function compute(pid)
	local init = 0
	
	-- récupération température
	local temp = getTemp(pid['sonde'])
	
	-- création variable : 4 dernières températures
	if (uservariables['PID_temps_'..pid['zone']] == nil ) then
		creaVar('PID_temps_'..pid['zone'],string.rep(temp..';',3)..temp) 
		init = 1
	end
	-- création variable : intégrale
	if (uservariables['PID_integrale_'..pid['zone']] == nil ) then
		creaVar('PID_integrale_'..pid['zone'],'0')
		init = 1
	end
	
	if init == 1 then
		log('PID '..pid['zone']..' initialisation..',pid['debug'])
		do return end
	end
	
	-- définition des variables locales
	local moy_erreur = 0
	local n = 1
	local somme_erreurs = 0
	local heatTime
	local marche
	local arret
	local tmp = {}

	-- définition des commandes marche/arrêt
	if pid['invert'] then
		marche = 'Off' ; arret = 'On'
	else
		marche = 'On' ; arret = 'Off'
	end
	
	-- à chaque cycle
	if ( time.min%pid['cycle'] == 0 ) then
	
		-- maj des 4 dernières temps
		local temps = string.match(uservariables['PID_temps_'..pid['zone']],";([^%s]+)")..";"..temp
		commandArray[#commandArray+1] = {['Variable:PID_temps_'..pid['zone']] = temps}
		
		-- si l'on veut chauffer
		if ( otherdevices[pid['OnOff']] == 'On' ) then

			-- récupération de la consigne
			local consigne = tonumber(otherdevices_svalues[pid['thermostat']]) or pid['thermostat']
			-- calcul de l'erreur
			local erreur = consigne-temp
			-- calcul intégrale auto consumée et moyenne erreur glissante
			temps:gsub("([+-]?%d+%.*%d*)",function(t)
												tmp[n] = tonumber(t)
												err = tonumber(consigne-t)
												somme_erreurs = somme_erreurs+err
												moy_erreur = moy_erreur+err*n^3
												n = n+1
											end)

			somme_erreurs = round(constrain(somme_erreurs,0,255),1)
			moy_erreur = round(moy_erreur/100,2)
			
			-- calcul de la dérivée (régression linéaire - méthode des moindres carrés)
			local delta_erreurs = round((4*(4*tmp[1]+3*tmp[2]+2*tmp[3]+tmp[4])-10*(tmp[1]+tmp[2]+tmp[3]+tmp[4]))/20,2)
			
			-- aux abords de la consigne, passage au second systême integrale
			if somme_erreurs < 2 then
				somme_erreurs = tonumber(uservariables['PID_integrale_'..pid['zone']])
				-- re calcule intégrale si hors hysteresis
				-- à moins d'un dixièmes de degré d'écart avec la consigne
				-- le ratrapage est considéré OK, l'intégrale n'est pas recalculée
				if math.abs(erreur) > 0.11 then
					-- calcule intégrale
					somme_erreurs = round(constrain(somme_erreurs+erreur/2,0,2),2)
					-- maj
					commandArray[#commandArray+1] = {['Variable:PID_integrale_'..pid['zone']] = tostring(somme_erreurs)}
				end
			end
			
			-- calcul pid
			local P = round(pid['Kp']*moy_erreur,2)
			local I = round(pid['Ki']*somme_erreurs,2)
			local D = round(pid['Kd']*delta_erreurs,2)
			
			-- calcul de la commande en %
			local commande = round(constrain(P+I+D,0,100))
					
			-- calcul du temps de fonctionnement
			if commande == 100 then
				-- débordement de 20s pour ne pas couper avant recalcule
				heatTime = (pid['cycle']*60)+20
			elseif commande > 0 then
				-- secu mini maxi
				heatTime = round(constrain(commande*pid['cycle']*0.6,pid['secu'],(pid['cycle']*60)-pid['secu']))
			elseif commande == 0 then
				-- coupure retardée
				heatTime = constrain(pid['secu']-lastSeen(pid['radiateur']),0,pid['secu'])
			end
			
			-- AFTER n'aime pas 1 ou 2..
			if heatTime == 1 or heatTime == 2 then
				heatTime = 0
			end	
			
			-- action sur l'élément chauffant
			if heatTime > 0 then
				commandArray[#commandArray+1] = {[pid['radiateur']] = marche}
				commandArray[#commandArray+1] = {[pid['radiateur']] = arret..' AFTER '..heatTime}
			else
				commandArray[#commandArray+1] = {[pid['radiateur']]=arret}
			end			
		
			-- journalisation
			if pid['debug'] then
				log('PID zone: '..string.upper(pid['zone']))
				log('température: '..temp..'°C pour '..consigne..'°C souhaité')
				log('Kp: '..pid['Kp'])
				log('Ki: '..pid['Ki'])
				log('Kd: '..pid['Kd'])
				log('erreur: '..moy_erreur)
				log('&#8721; erreurs: '..somme_erreurs)
				log('&#916; erreurs: '..delta_erreurs)
				log('P: '..P)
				log('I: '..I)
				log('D: '..D)
				log('cycle: '..pid['cycle']..'min (sécu: '..pid['secu']..'s)')
				-- avertissement si secu dépasse 1/4 du cycle
				if ((100*pid['secu'])/(60*pid['cycle'])>25) then
					warn('sécu trop importante, ralonger durée de cycle..')
				end
				log('commande: '..commande..'% ('..string.sub(os.date("!%X",heatTime),4,8):gsub("%:", "\'")..'\")')
				log('')
			end
			
			-- maj sonde virtuelle
			--commandArray[#commandArray+1] = {['UpdateDevice'] = otherdevices_idx[pid['sonde']..'_pid']..'|0|'..temp..';'..commande..';0'}
			
		end
		
	end
	-- toutes les 15 minutes, si on ne veut pas chauffer
	if ( time.min%15 == 0 and otherdevices[pid['OnOff']] == 'Off' ) then

		-- arrêt chauffage (renvoi commande systematique par sécurité)
		commandArray[#commandArray+1] = {[pid['radiateur']] = arret..' AFTER '..constrain(pid['secu']-lastSeen(pid['radiateur']),3,pid['secu'])}
		
		-- maj sonde virtuelle
		--commandArray[#commandArray+1] = {['UpdateDevice'] = otherdevices_idx[pid['sonde']..'_pid']..'|0|'..temp..';0;0'}
	end

end
