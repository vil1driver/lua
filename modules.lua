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

dofile('/home/pi/domoticz/scripts/lua/settings.lua')

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

-- il fait jour
dayTime = timeofday['Daytime']
-- il fait nuit
nightTime = timeofday['Nighttime']

-- température
function getTemp(device)
	return round(tonumber(otherdevices_temperature[device]),1)
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
  os.execute('sleep '..tonumber(n))
end

-- création de variable utilisateur
-- usage
-- creaVar('toto','10') -- pour créer une variable nommée toto comprenant la valeur 10
function creaVar(name,value)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=saveuservariable&vname='..url_encode(name)..'&vtype=2&vvalue='..url_encode(value)..'" &')
end

-- update an existing variable
function updateVar(name,value)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=updateuservariable&vname='..url_encode(name)..'&vtype=2&vvalue='..url_encode(value)..'" &')
end

-- envoie dans un capteur text une chaîne de caractères
-- le text sera intercepté et lu par la custom page grâce à sa fonction MQTT
-- usage
-- speak('tts','bonjour nous sommes dimanche')
function speak(TTSDeviceName,txt)
	commandArray['OpenURL'] = domoticzIP..":"..domoticzPORT..'/json.htm?type=command&param=udevice&idx='..otherdevices_idx[TTSDeviceName]..'&nvalue=0&svalue='..url_encode(txt)
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
	if level ~= nil then
		os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Set%20Level&level='..level..'&passcode='..domoticzPASSCODE..'" &')
	else	
		os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=On&passcode='..domoticzPASSCODE..'" &')
	end	
end

-- switch On a devive for x secondes 
function switchOnFor(device, secs)
   switchOn(device)
   commandArray[device] = "Off AFTER "..secs
end

-- switch Off a device
function switchOff(device)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Off&passcode='..domoticzPASSCODE..'" &')
end

-- Toggle a device
function switch(device)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Toggle&passcode='..domoticzPASSCODE..'" &')
end

-- Set switch to Stop
function switchStop(device)
	local api = "/json.htm?type=command&param=switchlight&switchcmd=Stop"
	local idx = "&idx="..otherdevices_idx[device]
	local passcode = "&passcode="..domoticzPASSCODE
	api = api..idx..passcode
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- Setup a color & brightness of an RGB(W) light
-- API : https://www.domoticz.com/wiki/Domoticz_API/JSON_URL%27s#Set_an_RGB.28W.29_light_to_a_certain_color_and_brightness
function setColorAndBrightness(device, color, brightness)
	local api = "/json.htm?type=command&param=setcolbrightnessvalue"
	local idx = "&idx="..otherdevices_idx[device]
	local color = "&hue="..color
	local brightness = "&brightness="..brightness
	local iswhite = "&iswhite=false"
	api = api..idx..color..brightness..iswhite
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..api..'" &')
end

-- switch On a group or scene
function groupOn(device)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=switchscene&idx='..otherdevices_scenesgroups_idx[device]..'&switchcmd=On&passcode='..domoticzPASSCODE..'" &')
end

-- switch Off a group
function groupOff(device)
	os.execute(curl..'-u '..domoticzUSER..':'..domoticzPSWD..' "'..domoticzURL..'/json.htm?type=command&param=switchscene&idx='..otherdevices_scenesgroups_idx[device]..'&switchcmd=Off&passcode='..domoticzPASSCODE..'" &')
end


-- régulation chauffage (PID)
--[[

	usage:
	
	local pid={}
	pid['debug'] = true								-- true pour voir les logs dans la console log Dz ou false pour ne pas les voir
	pid['zone'] = 'salon'							-- nom de la zone pour affichage dans les logs et ditinction de variables
	pid['sonde'] = 'salon' 							-- Nom de la sonde de température
	pid['OnOff'] = 'chauffage' 						-- Nom de l'interrupteur virtuel de mise en route
	pid['thermostat'] = 'th_salon' 					-- consigne ou 'nom' de l'interrupteur virtuel de thermostat
	-- actionneur
	pid['radiateur'] = 'radiateur salon' 			-- Nom de l'interrupteur de chauffage
	pid['invert'] = false							-- si On et Off doivent être inversé ou non

	-- période de chauffage
	-- pour une période de 24h,
	-- mettre debut = '00:00' et fin = '24:00'
	-- bien respecter le format 'hh:mm'
	pid['debut'] = 	'00:00'
	pid['fin'] = 	'24:00'

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
	time = os.date("*t")
	-- création variable : 4 dernières erreurs
	if (uservariables['PID_erreurs_'..pid['zone']] == nil ) then
		creaVar('PID_erreurs_'..pid['zone'],'0;0;0;0') 
		log('PID '..pid['zone']..' initialisation..',pid['debug'])
		return commandArray
	end
	
	-- définition des variables locales
	local somme_erreurs = 0
	local heatTime
	local marche
	local arret

	-- somme nous dans la plage horaire de chauffage autorisé
	local inTime = (pid['debut'] < pid['fin'] and heure >= pid['debut'] and heure < pid['fin']) or
					(pid['debut'] > pid['fin'] and (heure >= pid['debut'] or heure < pid['fin']))

	-- définition des commandes marche/arrêt
	if pid['invert'] then
		marche = 'Off' ; arret = 'On'
	else
		marche = 'On' ; arret = 'Off'
	end
	
	-- si l'on veut chauffer
	if ( otherdevices[pid['OnOff']] == 'On' and time.min%pid['cycle'] == 0 and inTime ) then

		-- récupération température
		local temp = getTemp(pid['sonde'])
		-- récupération de la consigne
		local consigne = tonumber(otherdevices_svalues[pid['thermostat']]) or pid['thermostat']
		-- calcul de l'erreur
		local erreur = consigne-temp
		-- maj des 4 dernières erreurs
		local erreurs = string.match(uservariables['PID_erreurs_'..pid['zone']],";([^%s]+)")..";"..erreur
		-- somme les erreurs (valeur négative interdite)
		erreurs:gsub("([+-]?%d+%.*%d*)",function(err) somme_erreurs = somme_erreurs + err end)
		somme_erreurs = round(constrain(somme_erreurs,0,255),1)
		-- sauvegarde erreurs
		commandArray['Variable:PID_erreurs_'..pid['zone']] = erreurs
		
		-- créattion du script python de calcul de dérivée
		if not file_exists(luaDir..'derive.py') then
			f = assert(io.open(luaDir..'derive.py',"a"))
			f:write('#!/usr/bin/python\n')
			f:write('from sys import argv\n')
			f:write('import numpy\n')
			f:write('x=[1,2,3,4]\n')
			f:write('y=[float(i) for i in argv[1].split(\';\')]\n')
			f:write('a,b=numpy.polyfit(x,y,1)\n')
			f:write('print a\n')
			f:close()
			os.execute('chmod +x '..luaDir..'derive.py')
		end
		
		-- calcul de la dérivée via le script python précédent
		local delta_erreur = round(tonumber(os.capture(luaDir..'derive.py "'..erreurs..'"')),3)
	
		-- calcul pid
		local P = round(pid['Kp']*erreur,2)
		local I = round(pid['Ki']*somme_erreurs,2)
		local D = round(pid['Kd']*delta_erreur,2)
		
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
			commandArray[1] = {[pid['radiateur']] = marche}
			commandArray[2] = {[pid['radiateur']] = arret..' AFTER '..heatTime}
		else
			commandArray[pid['radiateur']]=arret
		end			
	
		-- journalisation
		if pid['debug'] then
			log('----+++--- PID zone: '..string.upper(pid['zone'])..' ---+++--------')
			log('température: '..temp..'°C pour '..consigne..'°C souhaité')
			log('Kp: '..pid['Kp'])
			log('Ki: '..pid['Ki'])
			log('Kd: '..pid['Kd'])
			log('erreur: '..erreur)
			log('&#8721; erreurs: '..somme_erreurs)
			log('&#916; erreurs: '..delta_erreur)
			log('P: '..P)
			log('I: '..I)
			log('D: '..D)
			log('cycle: '..pid['cycle']..'min (sécu: '..pid['secu']..'s)')
			-- avertissement si secu dépasse 1/4 du cycle
			if ((100*pid['secu'])/(60*pid['cycle'])>25) then
				warn('sécu trop importante, ralonger durée de cycle..')
			end
			log('commande: '..commande..'% ('..heatTime..'s)')
			log('----+++------------------------------+++----')
		end	

		
	-- toutes les 15 minutes, si on ne veut pas chauffer
	elseif ( (otherdevices[pid['OnOff']] == 'Off' or not inTime) and time.min%15 == 0 ) then

		-- arrêt chauffage (renvoi commande systematique par sécurité)
		commandArray[pid['radiateur']] = arret..' AFTER '..constrain(pid['secu']-lastSeen(pid['radiateur']),3,pid['secu'])
		
		-- reset variable somme des erreurs au besoin
		if (uservariables['PID_erreurs_'..pid['zone']] ~= '0;0;0;0') then
			commandArray['Variable:PID_erreurs_'..pid['zone']] = '0;0;0;0'
		end
		
		
	end

end
