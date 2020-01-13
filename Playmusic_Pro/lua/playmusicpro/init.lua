
local API_KEY = "AIzaSyBek-uYZyjZfn2uyHwsSQD7fyKIRCeXifU"
local playerDataSaved = {}
PlayMP.CurrentQueueInfo = {}
PlayMP.CurPlayNum = 0

util.AddNetworkString("PlayMP:RESETALLDATA")
net.Receive( "PlayMP:RESETALLDATA", function()
	PlayMP:RemoveQueue( 0 )
	PlayMP.CurPlayNum = 0
	print("Notice! All media queue has been deleted from the serverside data!")
end)


function PlayMP:WriteLog( text )

	if PlayMP:GetSetting( "WriteLogs", false, true ) == false then return end

	if not file.IsDir( "Playmusic_Pro_Log", "DATA" ) then 
		file.CreateDir( "Playmusic_Pro_Log" )
	end
	
	local TimeString = os.date( "[%H:%M:%S] " , Timestamp )
	local DateString = os.date( "%Y_%m_%d" , Timestamp )
	
	file.Append( "Playmusic_Pro_Log/" .. DateString .. "_logs.txt", "\n" .. TimeString .. text )
	print( "[PlayM Pro] Logs - ".. TimeString .. text )
		
end


function PlayMP:WriteCache( datacode, name, ch, len, img, imglow )

	if not PlayMP:GetSetting( "SaveCache", false, true ) then return end

	if not file.IsDir( "Playmusic_Pro_Cache", "DATA" ) then 
		file.CreateDir( "Playmusic_Pro_Cache" )
	end
	
	local data = {}
	
	table.insert( data, {
		Name = name,
		Ch = ch,
		Len = len,
		Img = img,
		Imglow = imglow
	} )
	
	if data[1] == nil or data[1] == {} then error("Write Error of cache")return end
	
	
	
	file.Write( "Playmusic_Pro_Cache/" .. datacode .. ".txt", util.TableToJSON(data) )
		
end

function PlayMP:ReadCache(uri)
	
	if uri == nil or uri == "" then return nil end
	local data = file.Read( "Playmusic_Pro_Cache/" .. uri .. ".txt", "DATA" )
	
	if data == nil or data == "" then
		return nil
	end

	return util.JSONToTable(data)[1]

end

util.AddNetworkString("PlayMP:GetCacheSize")
function PlayMP:GetCacheSize(  )
	local files = file.Find( "playmusic_pro_cache/*.txt", "DATA" )
	local size = 0
	if #files > 0 then
		for k, f in ipairs( files ) do
			if f == nil then return end
			--print(file.Size( "Playmusic_Pro_UserData/0.txt", "DATA" ))
			local size2 = file.Size( "playmusic_pro_cache/" .. f, "DATA" )
			size = size + size2
			
		end
		
	end
	
	return #files, size
	
end

net.Receive( "PlayMP:GetCacheSize", function( len, ply )

	local f, s = PlayMP:GetCacheSize(  )
		
		net.Start("PlayMP:GetCacheSize")
			net.WriteTable( {f=f,s=s} )
		net.Send(ply)
		
	end)

function PlayMP:ReadSettingData( str, getAll, returnOnlyData )

	if file.Find( "PlayMusicPro_Setting_Server.txt", "DATA" ) == nil then
		return {}
	else
		local data = file.Read( "PlayMusicPro_Setting_Server.txt", "DATA" )
		if data == nil or data == "" then return {} end
		local table = util.JSONToTable(data)
		
		if getAll then
			return table
		end
		
		for k, v in pairs( table ) do
			if v.UniName == str then
			
				if returnOnlyData then
					return v.Data
				else
					return v
				end
				
			end
		end
				
		return {}
	end
	
end


PlayMP.CurSettings = PlayMP:ReadSettingData( "", true, false )


function PlayMP:GetSetting( str, getAll, returnOnlyData )
		
	if getAll then
		return PlayMP.CurSettings
	end
		
	for k, v in pairs( PlayMP.CurSettings ) do
		if v.UniName == str then
		
			if returnOnlyData then
				return v.Data
			else
				return v
			end
			
		end
	end
	
end



--[[gameevent.Listen( "player_connect_client" )
hook.Add( "player_connect_client", "player_connect_client", function( data )
	local name = data.name			// Same as Player:Nick()
	local steamid = data.networkid	// Same as Player:SteamID()
	local ip = data.address			// Same as Player:IPAddress()
	local bot = data.bot			// Same as Player:IsBot()
	local ent = player.GetBySteamID( steamid ) 
	
	if bot == 1 then -- bot!
		return
	end
	
	if PlayMP.isPlaying == true then
	
		print("재생 중이에용")
	
		net.Start("player_connect_PlayMP:Playmusic")
			net.WriteTable( PlayMP.CurrentQueueInfo )
			net.WriteString( PlayMP.CurPlayNum )
		net.Send( ent ) 
		
		net.Start("PlayMP:DoSeekToVideo")
			net.WriteString( tostring(PlayMP.CurPlayTime) )
		net.Send( ent ) 
		
	end

end )]]

util.AddNetworkString("player_connect_PlayMP:Playmusic")

net.Receive( "player_connect_PlayMP:Playmusic", function( len, ply )

	PlayMP:NewPlayer( ply )
	
end)

function PlayMP:NewPlayer( ply )

	net.Start("player_connect_PlayMP:Playmusic")
		net.WriteTable( PlayMP.CurrentQueueInfo )
		net.WriteString( PlayMP.CurPlayNum )
		if PlayMP.isPlaying == true then
			net.WriteString( "playing" )
			net.WriteString( tostring(PlayMP.CurPlayTime) )
		end
	net.Send( ply ) 
	
end


function PlayMP:ChangeSetting( str, any )
	
	local data = PlayMP:GetSetting( str, true, false )
	
	if data then
		
		for k, v in pairs( data ) do
			if v.UniName == str then
				
				if isnumber(any) or isstring(any) or isbool(any) then
					PlayMP:WriteLog( "Try to change setting... (" .. str .. ", " .. tostring(v.Data) .. " >>> " .. tostring(any) .. ")" )
				else
					PlayMP:WriteLog( "Try to change setting... (" .. str .. ")" )
				end
				
				v.Data = any
				file.Write( "PlayMusicPro_Setting_Server.txt", util.TableToJSON(data) )
				
				PlayMP.CurSettings = data
				PlayMP:SettingSendToPlayer()
				return
				
			end
		end
		
		PlayMP:AddSetting( str, any )
		PlayMP.CurSettings = data
		
	else
		PlayMP:WriteLog( "Failed to change settings: Failed to get client settings. Target:[" .. str .. "]" )
		error("Failed to change settings: Failed to get client settings. Target:[" .. str .. "]")
	end
	
end


function PlayMP:AddSetting( name, data )

	
	local CurData = PlayMP:GetSetting( str, true, false )

	table.insert( CurData, {
		Data = data, 
		UniName = name
	} )
	
	file.Write( "PlayMusicPro_Setting_Server.txt", util.TableToJSON(CurData) )

	
	PlayMP.CurSettings = CurData
	
end

local data = file.Read( "PlayMusicPro_Setting_Server.txt", "DATA" )
if data == nil or data == "" then

	PlayMP:AddSetting( "AOAQueue", false )
	PlayMP:AddSetting( "AOASkip", false )
	PlayMP:AddSetting( "AOACPL", false )
	PlayMP:AddSetting( "RepeatQueue", false )
	PlayMP:AddSetting( "SaveCache", true )
	PlayMP:AddSetting( "AOAPMP", false )
	PlayMP:AddSetting( "WriteLogs", true )
	
	
	PlayMP:AddSetting( "AdminSet_DONOTshowInfoPanel", false )
	
end

	util.AddNetworkString("PlayMP:GetServerSettings")
function PlayMP:SettingSendToPlayer( ply )
	
	net.Start("PlayMP:GetServerSettings")
		net.WriteTable( PlayMP:GetSetting( "", true ) )
	net.Broadcast()
	
end

	net.Receive( "PlayMP:GetServerSettings", function()
		local ply = net.ReadEntity()
		
		PlayMP:SettingSendToPlayer( ply )
	end)
	
	
	util.AddNetworkString("PlayMP:ChangeServerSettings")

	net.Receive( "PlayMP:ChangeServerSettings", function()
		local ply = net.ReadEntity()
		local v = net.ReadTable()
		
		PlayMP:ChangeSetting( v.UniName, v.Data )
	end)


	util.AddNetworkString( "PlayMP:NoticeForPlayer" )

function PlayMP:NoticeForPlayer( str, msgtype, type, target )

	net.Start("PlayMP:NoticeForPlayer")
		net.WriteString( str )
		
		if msgtype == "red" then
			net.WriteTable( Color(231, 76, 47) )
			
		elseif msgtype == "green" then
			net.WriteTable( Color(42, 205, 114) )
			
		elseif msgtype == "gray" or msgtype == nil then
			net.WriteTable( Color(50, 50, 50) )
			
		end
		
		net.WriteString( type )
		
	if target then
		net.Send(target)
	else
		net.Broadcast()
	end
	
end

	util.AddNetworkString("PlayMP:GetQueueData")
	net.Receive( "PlayMP:GetQueueData", function( len, ply )
		
		local getself = net.ReadBool() 
		
		PlayMP:GetQueueData( getself, ply )
		
	end)
	
	function PlayMP:GetQueueData( getself, ply )
	
		net.Start("PlayMP:GetQueueData")
		net.WriteTable( PlayMP.CurrentQueueInfo )
		net.WriteString( tostring(PlayMP.CurPlayNum) )
		local getself = net.ReadBool() 
		if getself then
			net.Send(ply)
		else
			net.Broadcast()
		end
		
	end

	util.AddNetworkString( "PlayMP:AddQueue" )

function PlayMP:AddQueue( url, startTime, endTime, ply )
	
	local uri = PlayMP:UrlProcessing( url )

	
	if uri == "Error" then
		PlayMP:NoticeForPlayer( "IncorrectUrl", "red", "warning" , ply )
		return
	end
	
	PlayMP.QueueLimit = 500000
	
	if table.Count( PlayMP.CurrentQueueInfo ) - PlayMP.CurPlayNum >= PlayMP.QueueLimit then
		PlayMP:NoticeForPlayer( "TooManyQueue", "red", "warning", ply )
		return
	end
	
	local queue = {}
	queue.Uri = uri
	queue.startTime = startTime
	queue.endTime = endTime
	queue.Ply = ply
	
	local er = PlayMP:ReadVideoInfo( uri, startTime, endTime, ply )
		
	--table.insert( PlayMP.CurrentQueue, queue )
	
	--timer.Simple( 1, function()
	
		if er == "err" then
			PlayMP:NoticeForPlayer( "Error_VideoDataReadError", "red", "warning", ply )
			return 
		elseif er == "isLive" then
			PlayMP:NoticeForPlayer( "CantPlayLiveCont", "red", "warning", ply )
			return 
		elseif er == "ok" then
			--PlayMP:NoticeForPlayer( "QueueAdded", "green", "notice", ply )
			PlayMP:Playmusic()
			PlayMP:WriteLog("User '" .. ply:Nick() .. "'(" .. ply:SteamID() .. ") add music to queue! (" .. url .. ")")
		end
	
	--end)

end



function PlayMP:AddPlaylistQueue( id, ply, nextPageTokenOld )

	local url = "https://www.googleapis.com/youtube/v3/playlistItems?part=contentDetails&maxResults=50&playlistId=" .. id .. "&key=AIzaSyBek-uYZyjZfn2uyHwsSQD7fyKIRCeXifU"

	if nextPageTokenOld != nil then
		url = "https://www.googleapis.com/youtube/v3/playlistItems?part=contentDetails&maxResults=50&playlistId=" .. id .. "&key=AIzaSyBek-uYZyjZfn2uyHwsSQD7fyKIRCeXifU&pageToken=" .. nextPageTokenOld
	end

	http.Fetch(url, function(data,code,headers)
		
		local strJson = data
		local json = util.JSONToTable(strJson)
		if json == nil then return end
		
		local nextPageToken = "no"
		
		if json["nextPageToken"] then
			nextPageToken = json["nextPageToken"]
		end
		
		
		for k, v in pairs(json.items) do
			print(k, v["contentDetails"]["videoId"])
			--if k > 1 then
				PlayMP:AddQueue( v["contentDetails"]["videoId"], 0, 0, ply )
					
				if k == 50 and nextPageToken != "no" then
					PlayMP:AddPlaylistQueue( id, ply, nextPageToken )
				end
			--end
		end
		
	end)
	
end


	net.Receive( "PlayMP:AddQueue", function()
		local url = net.ReadString()
		local startTime = net.ReadString()
		local endTime = net.ReadString()
		local ply = net.ReadEntity()
		local isPlaylist = net.ReadBool()
		
		local plydata = PlayMP:GetUserInfoBySID(ply:SteamID())[1]
		
		if PlayMP:GetSetting( "AOAPMP", false, true ) and ply:IsAdmin() != true and plydata.power == false then PlayMP:NoticeForPlayer( "MyState_CanTUsePlaymusic", "red", "warning" ) return end
		if plydata.ban then PlayMP:NoticeForPlayer( "MyState_CanTUsePlaymusic", "red", "warning" ) return end

		--[[if PlayMP:GetSetting( "AOAQueue", false, true ) == true and ply:IsAdmin() != false and plydata.power == false then
			PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Queue", "red", "warning" )
			return
		end
		
		if plydata.qeeue == false and ply:IsAdmin() == false and plydata.power == false then
			PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Queue", "red", "warning" )
			return
		end]]
		
		if PlayMP:GetSetting( "AOAQueue", false, true ) and ply:IsAdmin() != true and plydata.power == false  then
			PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Queue", "red", "warning" )
			return
		elseif plydata.qeeue == false and ply:IsAdmin() == false and plydata.power == false then
			PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Queue", "red", "warning" )
			return
		end
		
		
		if isPlaylist then
			PlayMP:AddPlaylistQueue( url, ply )
		end
		
		if startTime == "" then
			startTime = 0
		end
		
		if endTime == "" then
			endTime = 0
		end
		
		PlayMP:AddQueue( url, tonumber(startTime), tonumber(endTime), ply, isPlaylist )
	end)
	
	
	
	util.AddNetworkString( "PlayMP:SkipMusic" )
	
function PlayMP:SkipMusic( ply )

	--for k, v in pairs(PlayMP.CurrentQueueInfo) do
	
		--if v["QueueNum"] == PlayMP.CurPlayNum then
			--local PlayUser = v["PlayUser"]

			
			--if PlayUser:SteamID() == ply:SteamID() then
			
				local plydata = PlayMP:GetUserInfoBySID(ply:SteamID())[1]
				
				if PlayMP:GetSetting( "AOAPMP", false, true ) and ply:IsAdmin() != true and plydata.power == false then PlayMP:NoticeForPlayer( "MyState_CanTUsePlaymusic", "red", "warning" ) return end
				if plydata.ban then PlayMP:NoticeForPlayer( "MyState_CanTUsePlaymusic", "red", "warning" ) return end
			
				if ply:IsAdmin() then
					timer.Simple(1, function()
						PlayMP:EndMusic()
					end)
				elseif PlayMP:GetSetting( "AOASkip", false, true ) and ply:IsAdmin() != true and plydata.power == false  then
					PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Skip", "red", "warning" )
				elseif plydata.skip == false and ply:IsAdmin() == false and plydata.power == false then
					PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Skip", "red", "warning" )
				else
					PlayMP:EndMusic()
				end
			
			--end
			
		--end
	--end
	
end
	
	net.Receive( "PlayMP:SkipMusic", function()
		local ply = net.ReadEntity()
		
		PlayMP:SkipMusic( ply )
	end)
	
	
	
util.AddNetworkString("PlayMP:GetUserInfoBySID")

function PlayMP:GetUserInfoBySID(target)

	local target = util.SteamIDTo64( target ) 

	local dir = "Playmusic_Pro_UserData/"
	
	if not file.IsDir( "Playmusic_Pro_UserData", "DATA" ) then 
		file.CreateDir( "Playmusic_Pro_UserData" )
	end

	if file.Find( dir .. tostring(target) .. ".txt", "DATA" ) == nil then
		file.Append(tostring(target) .. ".txt", "Playmusic_Pro_UserData")
	end
	
		local data = file.Read( dir .. tostring(target) .. ".txt", "DATA" )
		if data == nil or data == "" then
			local Table = {}
			table.insert( Table, {
				qeeue = true,
				skip = true,
				seekto = true,
				power = false,
				ban = false
			})
			table.RemoveByValue( playerDataSaved, target )
			table.insert( playerDataSaved, {
				qeeue = true,
				skip = true,
				seekto = true,
				power = false,
				ban = false,
				ply = target
			})
			
			file.Write( dir .. tostring(target) .. ".txt", util.TableToJSON(Table) )
			return Table
		else
			local table = util.JSONToTable(data)
			return table
		end
	
end

	net.Receive( "PlayMP:GetUserInfoBySID", function( len, ply )
		local target = net.ReadString()
		local data = PlayMP:GetUserInfoBySID(target)
		
		net.Start("PlayMP:GetUserInfoBySID")
			net.WriteTable( data )
		net.Send(ply)
		
	end)
	
	
util.AddNetworkString("PlayMP:SetUserInfoBySID")
util.AddNetworkString("PlayMP:GetUserInfoBySID2")
	
function PlayMP:SetUserInfoBySID(target, data)

	local dir = "Playmusic_Pro_UserData/"
	
	local ply = player.GetBySteamID( target ) 
	local target = util.SteamIDTo64( target ) 
	
	if target == "0" then
		print("[PlayM Pro] Error occurred while set user info by sid because target is bot or wrong steamID.")
	end

	if file.Find( dir .. tostring(target) .. ".txt", "DATA" ) == nil then
		file.Append(tostring(target) .. ".txt", "Playmusic_Pro_UserData")
	end

	file.Write( dir .. tostring(target) .. ".txt", util.TableToJSON(data) )
	
	table.RemoveByValue( playerDataSaved, target )
	table.insert( playerDataSaved, data)
	
	if ply != nil and ply != false and ply:IsPlayer() then
		net.Start("PlayMP:GetUserInfoBySID2")
			net.WriteTable( data )
		net.Send(ply)
	end
		
	return true
	
end

util.AddNetworkString("PlayMP:SendUserInfoAll")
function PlayMP:SendUserInfoAll( ply )

	local dir = "Playmusic_Pro_UserData/"

	local data, data2 = file.Find( dir .. "*.txt", "DATA" )

	if ply != nil and ply != false and ply:IsPlayer() then
		net.Start("PlayMP:SendUserInfoAll")
			net.WriteTable( data )
		net.Send(ply)
	end
	
end

net.Receive( "PlayMP:SendUserInfoAll", function( len, ply )
		
	PlayMP:SendUserInfoAll( ply )
		
end)
	
	concommand.Add( "pmpro_addadmin", function( ply, cmd, args, str )
		if ply == nil or not ply:IsPlayer() then
			local plydata = PlayMP:GetUserInfoBySID(str)
			if plydata == nil then
				print( "[PlayM Pro] Error occurred while adding user to admin..." )
				return
			end
			plydata[1]["power"] = true
			PlayMP:SetUserInfoBySID(str, plydata)
			print( "[PlayM Pro] Added user(" .. str .. ") to Admin..." )
		end
	end )
	
	
	net.Receive( "PlayMP:SetUserInfoBySID", function( len, ply )
		local target = net.ReadString()
		local data = net.ReadTable()
		
		local stat = PlayMP:SetUserInfoBySID(target, data)
		
		net.Start("PlayMP:SetUserInfoBySID")
			net.WriteBool( stat )
		net.Send(ply)
		
	end)
	
	

util.AddNetworkString("PlayMP:DoSeekToVideo")

PlayMP.SeekToTimeThink = 0

local function DoSeekToVideo( time, ply )

	local plydata = PlayMP:GetUserInfoBySID(ply:SteamID())[1]
	
	if PlayMP:GetSetting( "AOAPMP", false, true ) and ply:IsAdmin() != true and plydata.power == false then PlayMP:NoticeForPlayer( "MyState_CanTUsePlaymusic", "red", "warning" ) return end
	if plydata.ban then PlayMP:NoticeForPlayer( "MyState_CanTUsePlaymusic", "red", "warning" ) return end

	if PlayMP:GetSetting( "AOACPL", false, true ) and ply:IsAdmin() != true and plydata.power == false  then
		PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Loca", "red", "warning" )
		return
	end
	
	if plydata.seekto == false and ply:IsAdmin() == false and plydata.power == false then
		PlayMP:NoticeForPlayer( "AllowOnlyAdmin_Loca", "red", "warning" )
		return
	end
	
	if PlayMP.CurPlayTime == nil then return end

	local time = tonumber(time)
	
	--PlayMP.SeekToTimeThink = PlayMP.SeekToTimeThink - (CurTime() - PlayMP.VideoStartTime - tonumber(time))
	PlayMP.SeekToTimeThink = PlayMP.SeekToTimeThink - (PlayMP.CurPlayTime - tonumber(time))
	
	net.Start("PlayMP:DoSeekToVideo")
		net.WriteString( tostring(time) )
	net.Broadcast()
	
end

	net.Receive( "PlayMP:DoSeekToVideo", function()
		local time = net.ReadString()
		local ply = net.ReadEntity()
		DoSeekToVideo( time, ply )
	end)


function PlayMP:ReadVideoInfo( uri, startTime, endTime, ply )

	PlayMP.videoReadError = false
	PlayMP.IsliveBroadcast = false
	
	if PlayMP:ReadCache(uri) then
		local cache = PlayMP:ReadCache(uri)
		local endTime = endTime
		local startTime = startTime
	
			if endTime > cache.Len or endTime == 0 then
				endTime = cache.Len
			end
			
			if cache.Len != nil and startTime > endTime or startTime > cache.Len then
				startTime = 0
			end
		
			local video = {
				Length = cache.Len, 
				Title = cache.Name, 
				Channel = cache.Ch, 
				BroadCast = "none", 
				Image = cache.Img,
				ImageLow = cache.Imglow,
				Uri = uri,
				QueueNum = table.Count( PlayMP.CurrentQueueInfo ) + 1,
				PlayUser = ply,
				startTime = startTime,
				endTime = endTime}
			
			net.Start("PlayMP:AddQueue")
				net.WriteTable( video )
			net.Broadcast()
		
			table.insert( PlayMP.CurrentQueueInfo, video )
			
			PlayMP:Playmusic()
			PlayMP:WriteLog("User '" .. ply:Nick() .. "'(" .. ply:SteamID() .. ") add music to queue! (" .. uri .. ")")
			return
	end

	local video = {}

	http.Fetch("https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=" .. uri .. "&key=" .. API_KEY, function(data,code,headers)
			
		local strJson = data
		local json = util.JSONToTable(strJson)
			
		if json["items"][1] == nil then
			PlayMP:NoticeForPlayer( "Error_VideoDataReadError", "red", "warning", ply )
			PlayMP.videoReadError = true
			return "err"
		end
		
		if json.error then
			local message = json["error"]["message"]
			if json["error"]["code"] == "403" then
				message = "Request refused by Google server. Please try again later."
			end
			PlayMP:NoticeForPlayer( PlayMP:Str( "GOOGLEAPI_Error02", json["error"]["code"], message), "red", "warning" )
			return "err"
		end

		local contentDetails = json["items"][1]["contentDetails"]
			
		local strVideoDuration = contentDetails["duration"]
			

		video.Sec = string.match(strVideoDuration, "M([^<]+)S")
		if video.Sec == nil then
			video.Sec = string.match(strVideoDuration, "H([^<]+)S")
			if video.Sec == nil then
				video.Sec = string.match(strVideoDuration, "PT([^<]+)S")
				if video.Sec == nil then
					video.Sec = 0
				end
			end
		end
		
		video.Min = string.match(strVideoDuration, "H([^<]+)M")
		if video.Min == nil then
			video.Min = string.match(strVideoDuration, "PT([^<]+)M")
			if video.Min == nil then
				video.Min = 0
			end
		end
			
		video.Hour = string.match(strVideoDuration, "PT([^<]+)H")
		if video.Hour == nil then
			video.Hour = 0
		end
		
		video.VideoLength = video.Sec + video.Min * 60 + video.Hour * 3600 + 1
		
		--http.Fetch("https://www.googleapis.com/youtube/v3/videos?part=snippet&id=" .. uri .. "&key=" .. API_KEY, function(data,code,headers)
				
			local strJson = data
			local json = util.JSONToTable(strJson)
					
			if json["items"][1] == nil then
				PlayMP:NoticeForPlayer( "Error_VideoDataReadError", "red", "warning", ply )
				PlayMP.videoReadError = true
				return "err"
			end
					
			local snippet = json["items"][1]["snippet"]
					
			video.titleText = snippet["title"]
			video.ChannelTitle = snippet["channelTitle"]
			video.IsliveBroadcast = snippet["liveBroadcastContent"]
			
			if video.titleText == nil or video.titleText == "" then 
				PlayMP:NoticeForPlayer( "Error_VideoDataReadError", "red", "warning", ply )
				PlayMP.videoReadError = true
				return "err" 
			end
			if video.ChannelTitle == nil or video.ChannelTitle == "" then
				PlayMP:NoticeForPlayer( "Error_VideoDataReadError", "red", "warning", ply )
				PlayMP.videoReadError = true
				return "err"
			end
			if video.IsliveBroadcast == "live" then
				PlayMP.IsliveBroadcast = true
				PlayMP:NoticeForPlayer( "CantPlayLiveCont", "red", "warning", ply )
				return "isLive" 
			end
					
			local Imagedefault = snippet["thumbnails"]
			video.ImageUrl = Imagedefault["maxres"]
			video.ImageUrlLow = Imagedefault["default"]
					
			if video.ImageUrl == nil then
				video.ImageUrl = Imagedefault["medium"]
			end
					
			video.ImageUrl = video.ImageUrl["url"]
			video.ImageUrlLow = video.ImageUrlLow["url"]
			
			if PlayMP.videoReadError or PlayMP.IsliveBroadcast then
				PlayMP:NoticeForPlayer( "Error_unknownError", "red", "warning" )
				PlayMP.IsliveBroadcast = false
				PlayMP.videoReadError = false
				return "err"
			end
			
			print("endTime = " .. endTime .. " / video.VideoLength = " .. video.VideoLength )
			
			if endTime > video.VideoLength or endTime == 0 then
				endTime = video.VideoLength
			end
			
			if video.VideoLength != nil and startTime > endTime or startTime > video.VideoLength then
				startTime = 0
			end
			
			PlayMP:WriteCache( uri, video.titleText, video.ChannelTitle, video.VideoLength, video.ImageUrl, video.ImageUrlLow )
		
			local video = {
				Length = video.VideoLength, 
				Title = video.titleText, 
				Channel = video.ChannelTitle, 
				BroadCast = video.IsliveBroadcast, 
				Image = video.ImageUrl,
				ImageLow = video.ImageUrlLow,
				Uri = uri,
				QueueNum = table.Count( PlayMP.CurrentQueueInfo ) + 1,
				PlayUser = ply,
				startTime = startTime,
				endTime = endTime}
			
			net.Start("PlayMP:AddQueue")
				net.WriteTable( video )
			net.Broadcast()
		
			table.insert( PlayMP.CurrentQueueInfo, video )
			
			
			if PlayMP.videoReadError then
				PlayMP:NoticeForPlayer( "Error_VideoDataReadError", "red", "warning", ply )
			elseif PlayMP.IsliveBroadcast then
				PlayMP:NoticeForPlayer( "CantPlayLiveCont", "red", "warning", ply )
			else
				--PlayMP:NoticeForPlayer( "QueueAdded", "green", "notice", ply )
				PlayMP:Playmusic()
				PlayMP:WriteLog("User '" .. ply:Nick() .. "'(" .. ply:SteamID() .. ") add music to queue! (" .. uri .. ")")
			end
			
			PlayMP.videoReadError = false
			PlayMP.IsliveBroadcast = false

	end,nil)
		
end


	PlayMP.isPlaying = false
	util.AddNetworkString( "PlayMP:Playmusic" )

function PlayMP:Playmusic()

	if PlayMP.isPlaying == true then return end

	--[[for k, v in pairs( PlayMP.CurrentQueue ) do
		if k == 1 then
			PlayMP.CurrentMusicUri = v.Uri
			PlayMP.CurrentMusicPly = v.Ply
		end
	end]]
	
	if PlayMP.CurrentQueueInfo == nil or PlayMP.CurrentQueueInfo[PlayMP.CurPlayNum + 1] == nil or PlayMP.CurrentQueueInfo[PlayMP.CurPlayNum + 1]["QueueNum"] == "err" then
		PlayMP:NoticeForPlayer( "Error_unknownError", "red", "warning" )
		--PlayMP:EndMusic() stack overflow!?!?
		if PlayMP.CurrentQueueInfo != nil and PlayMP.CurrentQueueInfo[PlayMP.CurPlayNum + 2] != nil and PlayMP.CurrentQueueInfo[PlayMP.CurPlayNum + 2]["QueueNum"] == "err" then
			PlayMP.CurPlayNum = PlayMP.CurPlayNum + 1 -- jump to next media if no problems
			PlayMP:Playmusic()
		else -- serious error has occurred... it probably cause serious problem for server or client! or.. causing stack overflow.. sometimes?
			PlayMP.CurrentQueueInfo = {}
			PlayMP.CurPlayNum = 0
			PlayMP:GetQueueData( false )
		end
		return 
	end
	
	PlayMP.VideoStartTime = CurTime() + 2

	PlayMP.CurPlayNum = PlayMP.CurPlayNum + 1
	
	PlayMP.isPlaying = true
	
	PlayMP.SeekToTimeThink = 0
	
	PlayMP:VideoTimeThink()
	
	net.Start("PlayMP:Playmusic")
		--net.WriteTable( PlayMP.CurrentQueueInfo )
		net.WriteString( PlayMP.CurPlayNum )
	net.Broadcast()

end



function PlayMP:EndMusic()

	hook.Remove("Think", "PMP Video Time Think")
	PlayMP.isPlaying = false
	
	PlayMP:NoticeForPlayer( "MusicStoped", "red", "warning" )
	
	PlayMP:StopMusic()
	
	if table.Count( PlayMP.CurrentQueueInfo ) == PlayMP.CurPlayNum then
		if PlayMP:GetSetting( "RepeatQueue", false, true ) then
			PlayMP.CurPlayNum = 0
			PlayMP:Playmusic()
		else
			return
		end
	else
		PlayMP:Playmusic()
	end
	
end


	util.AddNetworkString( "PlayMP:StopMusic" )
function PlayMP:StopMusic()
	net.Start("PlayMP:StopMusic")
	net.Broadcast()
end
	



function PlayMP:VideoTimeThink()

	for k, v in pairs( PlayMP.CurrentQueueInfo ) do
		if tonumber(v["QueueNum"]) == PlayMP.CurPlayNum then
		
			local PlayLength = v["Length"]
			local startTime = v["startTime"]
			local endTime = v["endTime"]
			local length = endTime - startTime
			
			PlayMP.CurPlayLength = length
			
			hook.Add( "Think", "PMP Video Time Think", function()
			
				--if PlayMP.CurPlayLength < CurTime() - PlayMP.VideoStartTime + PlayMP.SeekToTimeThink then
				if PlayMP.SeekToTimeThink + (CurTime() - PlayMP.VideoStartTime) > PlayMP.CurPlayLength then
					PlayMP:EndMusic()
				end
				
				PlayMP.CurPlayTime = (CurTime() - PlayMP.VideoStartTime) + PlayMP.SeekToTimeThink
				
			end )
			
		end
	end
	
end



	util.AddNetworkString( "PlayMP:RemoveQueue" )
function PlayMP:RemoveQueue( num )

	if not isnumber( num ) then return end
	
	if num == 0 then
		table.Empty( PlayMP.CurrentQueueInfo )
		PlayMP.CurPlayNum = 0
		PlayMP:GetQueueData( false )
		PlayMP:StopMusic()
		PlayMP.isPlaying = false
		PlayMP:GetQueueData( false )
		return
	end
	
	local curm = false
	
	table.remove( PlayMP.CurrentQueueInfo, num )
	
	if num == PlayMP.CurPlayNum then
		curm = true
	end
	
	if num <= PlayMP.CurPlayNum then
		PlayMP.CurPlayNum = PlayMP.CurPlayNum - 1
	end
	
	for k, v in pairs(PlayMP.CurrentQueueInfo) do
		if k >= num and tonumber(v["QueueNum"]) != 1 then
			v["QueueNum"] = tonumber(v["QueueNum"]) - 1
		end
	end
	PlayMP:GetQueueData( false )
	
	if curm then
		PlayMP:EndMusic()
	end

end
net.Receive( "PlayMP:RemoveQueue", function( len, ply )
		
	local num = tonumber(net.ReadString())
		
	PlayMP:RemoveQueue( num )
		
end)




function PlayMP:UrlProcessing( str )

		if string.find(str,"youtube")!=nil then
			str = string.match(str,"[?&]v=([^&]*)")
		elseif string.find(str,"youtu.be")!=nil then
			str = string.match(str,"https://youtu.be/([^&]*)")
		end

	
	if str == nil or str == "" then
		return "Error"
	else
		return str
	end
end

util.AddNetworkString( "PlayMP:ChangePlayerMode" )
function PlayMP:ChangePlayerMode( target, mode )
	net.Start("PlayMP:ChangePlayerMode")
	
	if mode == "worldScr" then
		net.WriteString("worldScr")
	elseif mode == "nomal" then
		net.WriteString("nomal")
	end
	
	if target then
		net.Send(target)
	else
		net.Broadcast()
	end
end

util.AddNetworkString( "PlayMP:RemoveCache" )
net.Receive( "PlayMP:RemoveCache", function()

	local files = file.Find( "playmusic_pro_cache/*.txt", "DATA" )
	if #files > 0 then
		for k, f in ipairs( files ) do
			if f == nil then return end

			file.Delete( "Playmusic_Pro_Cache/" .. f )
			print("Delete Playmusic_Pro_Cache/" .. f .. "...")
			
		end
		
	end

end)
