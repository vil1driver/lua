--[[


bibliothèque de fonctions pour domoticz
utiles à la réalisation de scripts d'automation en langage lua
certaines fonctions ne foncteionneront pas sous windows.

pour charger ce fichier et pouvoir en utiliser les fonctions

--------------------------------------------------------------------------------------------------------


-- chargement des modules
dofile('home/pi/domoticz/scripts/lua/modules')

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

admin = 'xxxx@gmail.com'

--------------------------------
------         END        ------
--------------------------------

luaDir = debug.getinfo(1).source:match("@?(.*/)")					-- chemin vers le dossier lua
curl = '/usr/bin/curl -m 5 -u domoticzUSER:domoticzPSWD '		 	-- ne pas oublier l'espace à la fin curl
json = assert(loadfile(luaDir..'JSON.lua'))()						-- chargement du fichier JSON.lua

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

-- dump all variables supplied to the script
-- usage
-- LogVariables(_G,0,'');
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

-- os.execute output or web page content return
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
-- 'string' ou 'number'
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
	s = otherdevices_lastupdate[device] or device
	year = string.sub(s, 1, 4)
	month = string.sub(s, 6, 7)
	day = string.sub(s, 9, 10)
	hour = string.sub(s, 12, 13)
	minutes = string.sub(s, 15, 16)
	seconds = string.sub(s, 18, 19)
	t1 = os.time()
	t2 = os.time{year=year, month=month, day=day, hour=hour, min=minutes, sec=seconds}
	difference = os.difftime (t1, t2)
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
  local mult = 10^(dec or 0)
  return math.floor(num * mult + 0.5) / mult
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
	os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=saveuservariable&vname='..url_encode(name)..'&vtype=2&vvalue='..url_encode(value)..'" &')
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
	local rid = assert(io.popen(curl..'"'..domoticzURL..'/json.htm?type=devices&rid='..otherdevices_idx[device]..'"'))
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

-- retourne la table des derniers log (première ligne = dernier log)
function lastLogEntry()
	local rid = assert(io.popen(curl..'"'..domoticzURL..'/json.htm?type=command&param=getlog"'))
	local list = rid:read('*all')
	rid:close()
	local tableau = json:decode(list).result
	return ReverseTable(tableau)
end

-- switch On a device and set level if dimmmable
function switchOn(device,level)
	if level ~= nil then
		os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Set%20Level&level='..level..'&passcode='..domoticzPASSCODE..'" &')
	else	
		os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=On&passcode='..domoticzPASSCODE..'" &')
	end	
end

-- switch On a devive for x secondes 
function switchOnFor(device, secs)
   switchOn(device)
   commandArray[device] = "Off AFTER "..secs
end

-- switch Off a device
function switchOff(device)
	os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Off&passcode='..domoticzPASSCODE..'" &')
end

-- Toggle a device
function switch(device)
	os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchlight&idx='..otherdevices_idx[device]..'&switchcmd=Toggle&passcode='..domoticzPASSCODE..'" &')
end

-- switch On a group or scene
function groupOn(device)
	os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchscene&idx='..otherdevices_scenesgroups_idx[device]..'&switchcmd=On&passcode='..domoticzPASSCODE..'" &')
end

-- switch Off a group
function groupOff(device)
	os.execute(curl..'"'..domoticzURL..'/json.htm?type=command&param=switchscene&idx='..otherdevices_scenesgroups_idx[device]..'&switchcmd=Off&passcode='..domoticzPASSCODE..'" &')
end

-- régulation chauffage (PID)
function compute(pid)

--[[

	-- script exemple
	
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

	time = os.date("*t")
	-- création des variables mémoires si besoin
	-- variable : somme des erreurs
	if (uservariables['somme_erreurs_'..pid['zone']] == nil ) then
		creaVar('somme_erreurs_'..pid['zone'],'0') 
		log('PID '..pid['zone']..' intérrompu pour création de la variable somme_erreurs_'..pid['zone'],pid['debug'])
		return commandArray
	end
	-- variable : 4 dernières températures
	if (uservariables['lastTemps_'..pid['zone']] == nil ) then
		local temp = getTemp(pid['sonde'])
		creaVar('lastTemps_'..pid['zone'],string.rep(temp..";",3)..temp)
		log('PID '..pid['zone']..' intérrompu pour création de la variable lastTemps_'..pid['zone'],pid['debug'])
		return commandArray
	end

	local commande = 0

	-- somme nous dans la plage horaire de chauffage autorisé
	local inTime = (pid['debut'] < pid['fin'] and heure >= pid['debut'] and heure < pid['fin']) or
					(pid['debut'] > pid['fin'] and (heure >= pid['debut'] or heure < pid['fin']))

	-- à chaque cycle, memo temps
	if (time.min%pid['cycle'] == 0) then
		temp = getTemp(pid['sonde'])
		temps = string.match(uservariables['lastTemps_'..pid['zone']],";([^%s]+)")..";"..temp
		commandArray['Variable:lastTemps_'..pid['zone']] = temps
	end
	
	-- si l'on veut chauffer
	if ( otherdevices[pid['OnOff']] == 'On' and time.min%pid['cycle'] == 0 and inTime ) then

		-- récupération de la consigne
		local consigne = tonumber(otherdevices_svalues[pid['thermostat']]) or pid['thermostat']
		-- calcul erreur
		local erreur = consigne-temp
		-- somme les erreurs (valeur négative interdite)
		local somme_erreurs = constrain(tonumber(uservariables['somme_erreurs_'..pid['zone']]+erreur),0,255)
		-- memo somme erreurs (1°C autour de la consigne pour limiter tout dérangement lié à l'environnement, soleil, aération, etc..)
		if (math.abs(erreur) < 1) then
			commandArray['Variable:somme_erreurs_'..pid['zone']] = tostring(somme_erreurs)
		end	

		-- créattion du script python de calcul de dérivée
		if not file_exists(luaDir..'derive.py') then
			f = assert(io.open(luaDir..'derive.py',"a"))
			f:write('#!/usr/bin/python\n')
			f:write('from sys import argv\n')
			f:write('import numpy\n')
			f:write('x=[1,2,3,4]\n')
			f:write('y=[float(i) for i in argv[1].split(\';\')]\n')
			f:write('a,b=numpy.polyfit(x,y,1)\n')
			f:write('print 0 - round(a,3)\n')
			f:close()
			os.execute('chmod +x '..luaDir..'derive.py')
		end
		
		-- calcul de la dérivée via le script python précédent
		local delta_erreur = tonumber(os.capture(luaDir..'derive.py "'..temps..'"'))
	
		-- calcul pid
		local P = round(pid['Kp']*erreur,2)
		local I = round(pid['Ki']*somme_erreurs,2)
		local D = round(pid['Kd']*delta_erreur,2)
		
		-- calcul de la commande en %
		commande = round(constrain(P+I+D,0,100))
				
		-- calcul du temps de fonctionnement
		local heatTime
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
		
		-- action sur l'élément chauffant
		if pid['invert'] then
			if heatTime > 0 then
				commandArray[1]={[pid['radiateur']]='Off'}
				commandArray[2]={[pid['radiateur']]='On AFTER '..heatTime}
			else
				commandArray[pid['radiateur']]='On'
			end
		else
			if heatTime > 0 then
				commandArray[1]={[pid['radiateur']]='On'}
				commandArray[2]={[pid['radiateur']]='Off AFTER '..heatTime}
			else
				commandArray[pid['radiateur']]='Off'
			end			
		end
	
		-- journalisation
		if pid['debug'] then
			log('----+++--- PID zone: '..string.upper(pid['zone'])..' ---+++--------')
			log('température: '..temp..'°C pour '..consigne..'°C souhaité')
			log('Kp: '..pid['Kp'])
			log('Ki: '..pid['Ki'])
			log('Kd: '..pid['Kd'])
			log('erreur: '..erreur)
			log('&#8721; erreur: '..somme_erreurs)
			log('&#916; erreur: '..delta_erreur)
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
		if pid['invert'] then
			commandArray[pid['radiateur']]='On AFTER '..constrain(pid['secu']-lastSeen(pid['radiateur']),0,pid['secu'])
		else
			commandArray[pid['radiateur']]='Off AFTER '..constrain(pid['secu']-lastSeen(pid['radiateur']),0,pid['secu'])
		end
		
		-- reset variable somme des erreurs au besoin
		if (uservariables['somme_erreurs_'..pid['zone']] ~= '0') then
			commandArray['Variable:somme_erreurs_'..pid['zone']] = '0'
		end
		
	end

end