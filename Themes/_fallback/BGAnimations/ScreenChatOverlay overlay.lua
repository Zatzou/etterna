local width = THEME:GetMetric("ScreenChatOverlay","ChatWidth")
local height = THEME:GetMetric("ScreenChatOverlay","ChatHeight")
local maxlines = 20
local lineNumber = 20
local inputLineNumber = 2
local tabHeight = 1
local maxTabs = 5
local x, y = 5, SCREEN_HEIGHT - height * (maxlines + inputLineNumber + tabHeight)
local moveY = 0
local scale = 0.4
local minimised = true
local typing = false
local typingText = ""
local transparency = 0.667
local curmsgh = 0
local closeTabSize = 10
local tweentime = 0.25
local tipshown = false
local getMainColor = getMainColor or function(e) if e == "positive" then return color("#9654FD") else return color("2E2E2E99") end end
local topbaroffset = capWideScale(6,0)
local Colors = {
	background = getMainColor("tabs"),
	input = color("#888888"),
	activeInput = Brightness(getMainColor("positive"),0.2),
	chatSent = ColorMultiplier(getMainColor("positive"),1.5),
	output = color("#545454"),
	bar = color("#666666"),
	tab = color("#555555"),
	activeTab = color("#999999")
}
local translated_info = {
	WindowTitle = THEME:GetString("MultiPlayer", "ChatTitle"),
	LobbyTab = THEME:GetString("MultiPlayer", "LobbyTabName"),
	ServerTab = THEME:GetString("MultiPlayer", "ServerTabName"),
	ToggleTip = THEME:GetString("MultiPlayer", "InsertTip")
}
local chats = {}
chats[0] = {}
chats[1] = {}
chats[2] = {}
chats[0][""] = {}
local tabs = {{0, ""}}
--chats[tabName][tabType]
--tabtype: 0=lobby, 1=room, 2=pm
local messages = chats[0][""]
local currentTabName = ""
local currentTabType = 0
local isGameplay = false
local isInSinglePlayer = false
local currentScreen
local show = true
local online = IsNetSMOnline() and IsSMOnlineLoggedIn() and NSMAN:IsETTP()
local function changeTab(tabName, tabType)
	currentTabName = tabName
	currentTabType = tabType
	if not chats[tabType][tabName] then
		local i = 1
		local done = false
		while not done do
			if not tabs[i] then
				tabs[i] = {tabType, tabName}
				done = true
			end
		end
		chats[tabType][tabName] = {}
	end
	messages = chats[tabType][tabName]
end
local chat = Def.ActorFrame {
	BeginCommand = function(self)
		currentScreen = SCREENMAN:GetTopScreen()
		local updf = function(self)
			local s = SCREENMAN:GetTopScreen()
			if not s then
				return
			end
			local oldScreen = currentScreen
			currentScreen = s:GetName()
			if currentScreen == oldScreen then return end
		
			-- prevent the chat from showing in singleplayer because it can be annoying
			if
				oldScreen ~= currentScreen and
					(currentScreen == "ScreenSelectMusic" or currentScreen == "ScreenTitleMenu" or
						currentScreen == "ScreenOptionsService" or currentScreen == "ScreenInit" or
						currentScreen == "ScreenPackDownloader")
			then
				isInSinglePlayer = true
			end
			if string.sub(currentScreen, 1, 9) == "ScreenNet" and currentScreen ~= "ScreenNetSelectProfile" then
				isInSinglePlayer = false
			end
		
			online = IsNetSMOnline() and IsSMOnlineLoggedIn() and NSMAN:IsETTP()
			isGameplay = (currentScreen:find("Gameplay") ~= nil or currentScreen:find("StageInformation") ~= nil
							or currentScreen:find("PlayerOptions") ~= nil)
		
			if isGameplay or isInSinglePlayer then
				self:visible(false)
				show = false
				typing = false
				s:setTimeout(
					function()
						self:visible(false)
					end,
					0.025
				)
			else
				self:visible(online and not isInSinglePlayer)
				show = true
			end
			if currentScreen == "ScreenNetSelectMusic" then
				for i = 1, #tabs do
					if tabs[i] and tabs[i][2] == NSMAN:GetCurrentRoomName() then
						changeTab(tabs[i][2], tabs[i][1])
					end
				end
			end
			MESSAGEMAN:Broadcast("UpdateChatOverlay")
		end
		self:SetUpdateFunction(updf)
		updf(self)
		self:SetUpdateFunctionInterval(0.1)
	end,
}

chat.MinimiseMessageCommand = function(self)
	self:decelerate(tweentime)
	moveY = minimised and height * (maxlines + inputLineNumber + tabHeight - 1) or 0
	self:y(moveY)
end
local i = 0
chat.InitCommand = function(self)
	online = IsNetSMOnline() and IsSMOnlineLoggedIn() and NSMAN:IsETTP()
	self:visible(false)
	MESSAGEMAN:Broadcast("Minimise")
end
chat.BeginTextEntryMessageCommand = function(self)
	if not minimised then
		minimised = not minimised
		MESSAGEMAN:Broadcast("Minimise")
	end
end

chat.MultiplayerDisconnectionMessageCommand = function(self)
	online = false
	self:visible(false)
	typing = false
	MESSAGEMAN:Broadcast("UpdateChatOverlay")
	chats = {}
	chats[0] = {}
	chats[1] = {}
	chats[2] = {}
	chats[0][""] = {}
	tabs = {{0, ""}}
	changeTab("", 0)
	SCREENMAN:set_input_redirected("PlayerNumber_P1", false)
end

local bg
chat[#chat + 1] = Def.Quad {
	Name = "Background",
	InitCommand = function(self)
		bg = self
		self:diffuse(Colors.background)
		self:diffusealpha(transparency)
		self:stretchto(x, y + height, width + x, height * (maxlines + inputLineNumber + tabHeight) + y)
	end
}
local minbar
chat[#chat + 1] = Def.Quad {
	Name = "Bar",
	InitCommand = function(self)
		minbar = self
		self:diffuse(Colors.bar)
		self:diffusealpha(transparency)
		self:stretchto(width * 0.425 + x, y, width * 0.575 + x, height + y)
		self:addx(topbaroffset)
	end,
	ChatMessageCommand = function(self, params)
		if minimised and params.tab ~= ""
			and not (params.msg:find("System:") and not params.msg:find("The room is now")
			and not params.msg:find("Can't start") and not params.msg:find("room operator")
			and not params.msg:find("You're not in a room") and not params.msg:find("Starting in")) then
			self:hurrytweening(0.2)
			self:linear(tweentime)
			self:glowshift()
			self:effectcolor1(Colors.chatSent)
			self:effectcolor2(Colors.bar)
			self:effectperiod(1)
		end
	end,
	MinimiseMessageCommand = function(self)
		if minimised then
			self:linear(tweentime)
			self:diffuse(Colors.bar):diffusealpha(transparency)
			self:stopeffect()
		else
			self:linear(tweentime)
			self:diffuse(Colors.bar):diffusealpha(0)
		end
	end,
	StopEffectCommand = function(self)
		self:stopeffect()
	end,
}
chat[#chat + 1] = LoadFont("Common Normal") .. {
	Name = "BarLabel",
	InitCommand = function(self)
		self:settext(translated_info["WindowTitle"])
		self:halign(0):valign(0.5)
		self:zoom(0.5)
		self:diffuse(color("#000000"))
		self:visible(true)
		self:xy(x + 3 + width * 0.425, y - 0.5 + height * 0.5)
		self:addx(topbaroffset)
	end,
	MinimiseMessageCommand = function(self)
		self:accelerate(tweentime):diffusealpha(minimised and 1 or 0)
	end
}
chat[#chat + 1] = LoadFont("Common Normal") .. {
	Name = "BarLabel2",
	InitCommand = function(self)
		self:settext("-")
		self:halign(1):valign(0.5)
		self:zoom(0.8)
		self:diffuse(color("#000000"))
		self:visible(true)
		self:xy(x - 3 + width * 0.575, y - 0.5 + height * 0.5)
		self:addx(topbaroffset)
	end,
	MinimiseMessageCommand = function(self)
		self:settext(minimised and "+" or "-")
		self:y(minimised and y - 1 + height * 0.5 or y - 2.5 + height * 0.5)
		self:accelerate(tweentime):diffusealpha(minimised and 1 or 0)
	end
}
chat[#chat + 1] = LoadFont("Common Normal") .. {
	Name = "InsertShortcutTip",
	InitCommand = function(self)
		self:settext(translated_info["ToggleTip"])
		self:halign(0):valign(0.5)
		self:zoom(0.5)
		self:xy(x + 3 + width * 0.575, y - 0.5 + height * 0.5)
		self:addx(topbaroffset)
		self:diffusealpha(0)
		self:maxwidth((width * 0.425 - 6 - topbaroffset) / 0.5)
		self:shadowlength(1)
	end,
	MinimiseMessageCommand = function(self)
		if not minimised and not tipshown then
			tipshown = true
			self:diffusealpha(1):sleep(3)
			self:linear(0.5):diffusealpha(0)
		end
	end
}

local chatWindow = Def.ActorFrame {
	InitCommand = function(self)
		self:visible(true)
	end,
	ChatMessageCommand = function(self, params)
		local msgs = chats[params.type][params.tab]
		local newTab = false
		if not msgs then
			chats[params.type][params.tab] = {}
			msgs = chats[params.type][params.tab]
			tabs[#tabs + 1] = {params.type, params.tab}
			newTab = true
		end
		msgs[#msgs + 1] = os.date("%X") .. params.msg
		if msgs == messages or newTab then --if its the current tab
			MESSAGEMAN:Broadcast("UpdateChatOverlay")
		end
	end
}
local chatbg
chatWindow[#chatWindow + 1] = Def.Quad {
	Name = "ChatWindow",
	InitCommand = function(self)
		chatbg = self
		self:diffuse(Colors.output)
		self:diffusealpha(transparency)
	end,
	UpdateChatOverlayMessageCommand = function(self)
		self:stretchto(x, height * (1 + tabHeight) + y, width + x, height * (maxlines + tabHeight) + y)
		curmsgh = 0
		MESSAGEMAN:Broadcast("UpdateChatOverlayMsgs")
	end
}
chatWindow[#chatWindow + 1] = Def.Quad { --masking quad, hides any text outside chatwindow
	InitCommand = function(self)
		self:stretchto(x, -SCREEN_HEIGHT, width + x, height * 2 + y)
		self:zwrite(true):blend("BlendMode_NoEffect")
	end,
}
chatWindow[#chatWindow + 1] = LoadColorFont("Common Normal") .. {
	Name = "ChatText",
	InitCommand = function(self)
		self:settext("")
		self:halign(0):valign(1)
		self:vertspacing(0)
		self:zoom(scale)
		self:SetMaxLines(maxlines, 1)
		self:wrapwidthpixels((width - 8) / scale)
		self:xy(x + 4, y + height * (maxlines + tabHeight) - 4)
		self:ztest(true)
	end,
	UpdateChatOverlayMsgsMessageCommand = function(self)
		local t = ""
		for i = lineNumber - 1, lineNumber - maxlines, -1 do
			if messages[#messages - i] then
				t = t .. messages[#messages - i] .. "\n"
			end
		end
		self:settext(t)
	end
}

local tabWidth = width / maxTabs
for i = 0, maxTabs - 1 do
	chatWindow[#chatWindow + 1] = Def.ActorFrame {
		Name = "Tab" .. i + 1,
		UpdateChatOverlayMessageCommand = function(self)
			self:visible(not (not tabs[i + 1]))
		end,
		Def.Quad {
			InitCommand = function(self)
				self:diffuse(Colors.tab)
				self:diffusealpha(transparency)
			end,
			UpdateChatOverlayMessageCommand = function(self)
				self:diffuse(
					(tabs[i + 1] and currentTabName == tabs[i + 1][2] and currentTabType == tabs[i + 1][1]) and Colors.activeTab or
						Colors.tab
				)
				self:stretchto(x + tabWidth * i, y + height, x + tabWidth * (i + 1), y + height * (1 + tabHeight))
			end,
			ChatMessageCommand = function(self, params)
				if params.tab == self:GetParent():GetChild("TabName"):GetText() and params.tab ~= currentTabName
					and not (params.msg:find("System:") and not params.msg:find("The room is now")
					and not params.msg:find("Can't start") and not params.msg:find("room operator")
					and not params.msg:find("You're not in a room") and not params.msg:find("Starting in")) then
					self:decelerate(0.2):diffuse(Colors.chatSent)
				end
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:diffuse(Color.Black)
				self:diffusealpha(transparency)
				self:halign(0.5)
				self:stretchto(x + tabWidth * (i + 1) - 1, y + height,x + tabWidth * (i + 1), y + height * (1 + tabHeight))
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "TabName",
			InitCommand = function(self)
				self:halign(0):valign(0.5)
				self:maxwidth((tabWidth - 5) / scale)
				self:zoom(scale)
				self:diffuse(color("#000000"))
				self:xy(x + tabWidth * i + 4 - 1.5, y + height * (1 + (tabHeight / 2.3)))
			end,
			UpdateChatOverlayMessageCommand = function(self)
				if not tabs[i + 1] then
					self:settext("")
					return
				end
				if tabs[i + 1][1] == 0 and tabs[i + 1][2] == "" then
					self:settext(translated_info["LobbyTab"])
				elseif tabs[i + 1][1] ~= 0 and tabs[i + 1][2] == "" then
					self:settext(translated_info["ServerTab"])
				else
					self:settext(tabs[i + 1][2] or "")
				end
				if
					tabs[i + 1] and
						((tabs[i + 1][1] == 0 and tabs[i + 1][2] == "") or
							(tabs[i + 1][1] == 1 and tabs[i + 1][2] ~= nil and tabs[i + 1][2] == NSMAN:GetCurrentRoomName()))
					then
					self:maxwidth((tabWidth - 5) / scale)
				else
					self:maxwidth((tabWidth - 15) / scale)
				end
			end
		},
		Def.Sprite {
			Texture = THEME:GetPathG("","X.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5)
				self:zoom(scale - 0.1)
				self:diffuse(Color.Red)
				self:xy(x + tabWidth * (i + 1) - closeTabSize, y + height * (1 + (tabHeight / 2.1)))
			end,
			UpdateChatOverlayMessageCommand = function(self)
				if
					tabs[i + 1] and
						((tabs[i + 1][1] == 0 and tabs[i + 1][2] == "") or
							(tabs[i + 1][1] == 1 and tabs[i + 1][2] ~= nil and tabs[i + 1][2] == NSMAN:GetCurrentRoomName()))
					then
					self:visible(false)
				else
					self:visible(true)
				end
			end
		}
	}
end

local inbg
chatWindow[#chatWindow + 1] = Def.Quad {
	Name = "ChatBox",
	InitCommand = function(self)
		inbg = self
		self:diffuse(Colors.input)
		self:diffusealpha(transparency)
	end,
	UpdateChatOverlayMessageCommand = function(self)
		self:stretchto(x, height * (maxlines + 1) + y + 4, width + x, height * (maxlines + 1 + inputLineNumber) + y)
		self:diffuse(typing and Colors.activeInput or Colors.input):diffusealpha(transparency)
	end
}
chatWindow[#chatWindow + 1] = LoadColorFont("Common Normal") .. {
	Name = "ChatBoxText",
	InitCommand = function(self)
		self:settext("")
		self:halign(0):valign(0)
		self:vertspacing(0)
		self:zoom(scale)
		self:SetMaxLines(maxlines, 1)
		self:wrapwidthpixels((width - 8) / scale)
		self:diffuse(color("#FFFFFF"))
	end,
	UpdateChatOverlayMessageCommand = function(self)
		self:settext(typingText)
		self:xy(x + 4, height * (maxlines + 1) + y + 4 + 4)
	end
}

chat[#chat + 1] = chatWindow

chat.UpdateChatOverlayMessageCommand = function(self)
	SCREENMAN:set_input_redirected("PlayerNumber_P1", typing)
end

local function shiftTab(fromIndex, toIndex)
	-- tabs[index of tab][parameter table....]
	-- 					[1 is type, 2 is tab contents?]
	tabs[toIndex] = tabs[fromIndex]
	tabs[fromIndex] = nil
end

local function shiftAllTabs(emptyIndex)
	for i = emptyIndex + 1, maxTabs - 1 do
		shiftTab(i, i - 1)
	end
end

local function overTab(mx, my)
	for i = 0, maxTabs - 1 do
		if tabs[i + 1] then
			if
				mx >= x + tabWidth * i and my >= y + height + moveY and mx <= x + tabWidth * (i + 1) and
					my <= y + height * (1 + tabHeight) + moveY
			 then
				return i + 1, mx >= x + tabWidth * (i + 1) - closeTabSize
			end
		end
	end
	return nil, nil
end

function MPinput(event)
	if (not show or not online) or isGameplay then
		return false
	end
	local update = false
	if event.DeviceInput.button == "DeviceButton_left mouse button" then
		if typing then
			update = true
		end
		typing = false
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		if isOver(minbar) then --hard mouse toggle -mina
			minimised = not minimised
			MESSAGEMAN:Broadcast("Minimise")
			update = true
		elseif isOver(inbg) and not minimised then
			typing = true
			update = true
		elseif mx >= x and mx <= x + width and my >= y + moveY and my <= y + height + moveY then
			update = true
		elseif not minimised then
			local tabButton, closeTab = overTab(mx, my)
			if not tabButton then
				if typing then
					update = true
				end
			else
				if event.type == "InputEventType_FirstPress" then -- only change tabs on press (to stop repeatedly closing tabs or changing to a tab we close) -poco
					if not closeTab then
						changeTab(tabs[tabButton][2], tabs[tabButton][1])
					else
						local tabT = tabs[tabButton][1]
						local tabN = tabs[tabButton][2]
						if (tabT == 0 and tabN == "") or (tabT == 1 and tabN ~= nil and tabN == NSMAN:GetCurrentRoomName()) then
							return false
						end
						tabs[tabButton] = nil
						if chats[tabT][tabN] == messages then
							for i = #tabs, 1, -1 do
								if tabs[i] then
									changeTab(tabs[i][2], tabs[i][1])
								end
							end
						end
						chats[tabT][tabN] = nil
						shiftAllTabs(tabButton)
					end
					update = true
				end
			end
		end
	end

	-- hard kb toggle
	if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_insert" then
		if minimised then
		typing = true
		end
		minimised = not minimised
		MESSAGEMAN:Broadcast("Minimise")
		update = true
	end

	if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_/" then
		shouldOpen = true
	end

	if shouldOpen and event.type == "InputEventType_FirstPress" and event.DeviceInput.button ~= "DeviceButton_/" then
		shouldOpen = false
	end

	if not typing and event.type == "InputEventType_Release" then -- keys for auto turning on chat if not already on -mina
		if event.DeviceInput.button == "DeviceButton_/" and shouldOpen then
			typing = true
			update = true
			if minimised then
				minimised = not minimised
				MESSAGEMAN:Broadcast("Minimise")
			end
			typingText = "/"
			shouldOpen = false
		end
	end

	if typing then
		if event.type == "InputEventType_Release" then
			if event.DeviceInput.button == "DeviceButton_enter" then
				if typingText:len() > 0 then
					NSMAN:SendChatMsg(typingText, currentTabType, currentTabName)
					typingText = ""
				elseif typingText == "" then
					typing = false -- pressing enter when text is empty to deactive chat is expected behavior -mina
				end
				update = true
			end
		elseif event.button == "Back" then
			typingText = ""
			typing = false
			update = true
		elseif event.DeviceInput.button == "DeviceButton_space" then
			typingText = typingText .. " "
			update = true
		elseif event.DeviceInput.button == "DeviceButton_delete" then -- reset msg with delete (since there's no cursor)
			typingText = ""
			update = true
		elseif (INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl")) and
			event.DeviceInput.button == "DeviceButton_v" then
			typingText = typingText .. Arch.getClipboard()
			update = true
		elseif event.DeviceInput.button == "DeviceButton_backspace" then
			typingText = typingText:sub(1, -2)
			update = true
		elseif event.char then
			typingText = (tostring(typingText) .. tostring(event.char)):gsub("[^%g%s]", "")
			update = true
		end
	end

	if event.DeviceInput.button == "DeviceButton_mousewheel up" and event.type == "InputEventType_FirstPress" then
		if isOver(chatbg) then
			if lineNumber < #messages then
				lineNumber = lineNumber + 1
			end
			update = true
		end
	end
	if event.DeviceInput.button == "DeviceButton_mousewheel down" and event.type == "InputEventType_FirstPress" then
		if isOver(chatbg) then
			if lineNumber > maxlines then
				lineNumber = lineNumber - 1
			end
			update = true
		end
	end

	-- right click over the chat to minimize
	if event.DeviceInput.button == "DeviceButton_right mouse button" and isOver(bg) then
		if event.type == "InputEventType_FirstPress" then
			minimised = not minimised
			MESSAGEMAN:Broadcast("Minimise")
		end
		return true
	end

	-- kb activate chat input if not minimized (has to go after the above enter block)
	if event.type == "InputEventType_Release" and INPUTFILTER:IsBeingPressed("left ctrl") then
		if event.DeviceInput.button == "DeviceButton_enter" and not minimised then
			typing = true
			update = true
		end
	end

	if update then
		if minimised then -- minimise will be set in the above blocks, disable input and clear text -mina
			typing = false
			typingText = ""
		end
		MESSAGEMAN:Broadcast("UpdateChatOverlay")
	end

	-- always eat mouse inputs if its within the broader chatbox
	if event.DeviceInput.button == "DeviceButton_left mouse button" and isOver(bg) then
		return true
	end

	returnInput = update or typing
	return returnInput
end

return chat
--[[
	Untested half done prototype stuff for chart request front end (Probably
		wanna put this in a special tab located at the rightmost possible position)

local chartRequestsConfig = {
	numChartReqActors = 4,
	padding = 10,
	spacing = 10,
	height = 1,
	width = SCREEN_WIDTH
}
chartRequestsConfig.itemHeight =
	(chartRequestsConfig.height - chartRequestsConfig.padding * 2) / chartRequestsConfig.numChartReqActors
chartRequestsConfig.itemWidth = chartRequestsConfig.width - chartRequestsConfig.padding * 2
function chartRequestActor(i)
	local song
	local steps
	local req
	req =
		Def.ActorFrame {
		y = (chartRequestsConfig.itemHeight + chartRequestsConfig.spacing) * (i - 1)
	}
	req.sprite = Widg.Sprite {}
	req.rateFont = Widg.Label {}
	req.songNameFont = Widg.Label {}
	req.rect =
		Widg.Rectangle {
		width = chartRequestsConfig.itemWidth,
		height = chartRequestsConfig.itemHeight - chartRequestsConfig.spacing,
		onClick = function()
			if song and steps then
				local screen = SCREENMAN:GetTopScreen()
				local sName = screen:GetName()
				if sName == "ScreenSelectMusic" or sName == "ScreenNetSelectMusic" then
					screen:GetMusicWheel():SelectSong(song)
				end
			end
		end
	}
	req[#req + 1] = req.sprite
	req[#req + 1] = req.rateFont
	req[#req + 1] = req.songNameFont
	req[#req + 1] = req.rect
	req.updateWithRequest = function(req)
		if not req then
			song = nil
			steps = nil
			req.actor:visible(false)
			return
		end
		req.actor:visible(true)

		local ck = req:GetChartkey()
		local requester = req:GetUser()
		local rate = req:GetRate()

		song = SONGMAN:GetSongByChartKey(ck)
		steps = SONGMAN:GetStepsByChartKey(ck)

		req.sprite.actor:fadeleft(1)
		req.sprite.actor:Load(song:GetBannerPath())
		req.sprite.actor:scaletocover(0, 0, chartRequestsConfig.itemWidth, chartRequestsConfig.itemHeight)
		req.rateFont.actor:settext(tostring(rate))
		req.songNameFont.actor:settext(song:GetMainTitle())
	end
	return req
end
local bg =
	Widg.Rectangle {
	width = chartRequestsConfig.width - chartRequestsConfig.padding * 2,
	height = chartRequestsConfig.height - chartRequestActor.padding * 2
}
local t =
	Def.Container {
	x = chartRequestsConfig.padding,
	y = chartRequestsConfig.padding,
	content = {
		bg
	}
}
local reqWidgs = {}
for i = 1, chartRequestsConfig.numChartReqActors do
	reqWidgs[#reqWidgs + 1] = chartRequestActor(i)
	t[#t + 1] = reqWidgs[#reqWidgs]
end
local offset = 0
t.ChartRequestMessageCommand = function(self)
	local reqs = NSMAN:GetChartRequests()
	for i = 1, #reqWidgs do
		local widg = reqWidgs[i]
		widg.updateWithRequest(reqs[i + offsset])
	end
end
t.BeginCommand = function(self)
	SCREENMAN:GetTopScreen():AddInputCallback(
		function(event)
			if event.type ~= "InputEventType_FirstPress" or not bg:isOver() then
				return false
			end
			if event.DeviceInput.button == "DeviceButton_mousewheel up" then
				offset = math.min(offset - 1, 0)
				t.ChartRequestMessageCommand()
			elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
				local reqs = NSMAN:GetChartRequests()
				offset = math.min(offset + 1, #reqs)
				t.ChartRequestMessageCommand()
			end
		end
	)
end

]]
