ItemAnnouncer = LibStub("AceAddon-3.0"):NewAddon("ItemAnnouncer", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local libc = LibStub:GetLibrary("LibCompress")

local frame = CreateFrame("Frame")
local AceGUI = LibStub("AceGUI-3.0")
local status = 'Ready to import data'

local defaultDB = {}
defaultDB.delimiter = ""
defaultDB.watchingChannels = {}
defaultDB.watchingPlayers = {}
defaultDB.items = {}

ItemAnnouncerDB = ItemAnnouncerDB or defaultDB

local function isIndoor()
	return IsInInstance()
end

local function isInGroup()
	return GetNumPartyMembers() > 0
end

local function isInRaid()
	return UnitInRaid("player")
end

local function isInGuild()
	return IsInGuild()
end

local function isGuildOfficer()
	return C_GuildInfo.IsGuildOfficer()
end

local function hasRaidAssist()
	return UnitIsGroupAssistant("player")
end

local channels = {
	{ cond = isIndoor, to = 'SAY', from = { 'CHAT_MSG_SAY' } , cmds={'/s','/say'}, name = 'Say' },
	{ cond = isIndoor, to = 'YELL', from = { 'CHAT_MSG_YELL' } , cmds={'/y','/yell'}, name = 'Yell' },
	{ cond = isInGroup, to = 'PARTY', from = { 'CHAT_MSG_PARTY', 'CHAT_MSG_PARTY_LEADER' }, cmds={'/p','/party'}, name = 'Party' },
	{ cond = isInRaid, to = 'RAID', from = { 'CHAT_MSG_RAID', 'CHAT_MSG_RAID_LEADER' }, cmds={'/raid'}, name = 'Raid' },
	{ cond = isInGuild, to = 'GUILD', from = { 'CHAT_MSG_GUILD' }, cmds={'/g','/guild'}, name = 'Guild' },
	{ cond = isGuildOfficer, to = 'OFFICER', from = { 'CHAT_MSG_OFFICER' }, cmds={'/o','/officer'}, name = 'Officer' },
	{ cond = hasRaidAssist, to = 'RAID_WARNING', from = { 'CHAT_MSG_RAID_WARNING' }, cmds={'/rw','/raidwarning'}, name = 'Raid Warning' },
}

local ChannelById = {}
for i, channel in ipairs(channels) do
	ChannelById[channel.to] = channel
end

local function split(s, delimiter)
	local result = { }
	local from  = 1
	local delim_from, delim_to = string.find( s, delimiter, from  )
	while delim_from do
		table.insert( result, string.sub( s, from , delim_from-1 ) )
		from  = delim_to + 1
		delim_from, delim_to = string.find( s, delimiter, from  )
	end
	table.insert( result, string.sub( s, from  ) )
	return result
end

function splitLines(text)
	local lines = {}
	for s in text:gmatch("[^\r\n]+") do
	    table.insert(lines, s)
	end
	return lines
end

local function getChannelFromCommand(command)
	for i=1, #channels do
		for j=1, #channels[i].cmds do
			if channels[i].cmds[j] == command then
				return channels[i]
			end
		end
	end
end

local function parseLine(line, lineNumber, delimiter)
	local result = {}
	local parts = split(line, delimiter)
	local itemId = parts[1]
	-- check itemId is only digits
	if not tonumber(itemId) then
		return "Line "..lineNumber.." has invalid item id : "..itemId
	end

	for i=2, #parts do
		local message = parts[i]
		local blackList = {}
		local whiteList = {}
		local found = true

		while found do
			found = false
		
			-- check for black list : [^foo]message
			local bl, rbl = message:match("^[[][\\^]([^\\^]-)[]](.*)$")
			if bl then
				found = true
				table.insert(blackList, bl)
				message = rbl
			end
		
			-- check for white list : [foo]message
			local wl, rwl = message:match("^[[]([^\\^]-)[]](.*)$")
			if wl then
				found = true
				table.insert(whiteList, wl)
				message = rwl
			end
		end

		-- command is everything before the first space
		local command = message:match("^(%S*)")
		local channel = getChannelFromCommand(command)

		if not channel then
			return "Line "..lineNumber.." has invalid channel : "..command
		end
		-- message is everything after the first space
		message = message:match("^%S*%s*(.-)$")

		-- check message is not empty
		if message == "" then
			return "Line "..lineNumber.." has empty message"
		end

		-- append result with message and channel
		table.insert(result, {message=message, channelId=channel.to, blackList=blackList, whiteList=whiteList})
	end

	return tonumber(itemId), result
end

local function parseHeader(firstLine, secondLine, thirdLine)
	-- first line must be only 1 character long
	if string.len(firstLine) ~= 1 then
		return 'First line must contains only the delimiter character'
	end

	-- delimiter is first char of first line
	local delimiter = firstLine:sub(1,1)

	local channelCommands = split(secondLine, delimiter)

	if (#channelCommands < 1) then
		return 'Second line must contains at least one channel'
	end

	local channelIds = {}
	for i=1, #channelCommands do
		local channel = getChannelFromCommand(channelCommands[i])
		if channel == nil then
			return 'In header, channel ' .. channelCommands[i] .. ' is not valid'
		end
		table.insert(channelIds, channel.to)
	end

	local players = split(thirdLine, delimiter)

	if (#players < 1) then
		return 'Third line must contains at least one player name'
	end

	return {delimiter = delimiter, channelIds = channelIds, players = players}
end

local function parseData(data)
	-- get each lines as an array
	local lines = splitLines(data)
	
	-- must have at least 3 lines
	if #lines < 3 then
		return 'Data must contains at least the 3 header lines'
	end

	-- parse header
	local header = parseHeader(lines[1], lines[2], lines[3])

	if type(header) == 'string' then
		return header
	end

	-- parse every other lines
	local items = {}
	for i=4, #lines do
		local itemId, results = parseLine(lines[i], i, header.delimiter)
		if type(itemId) == "string" then
			return itemId
		end

		-- check if itemId is already in items
		if items[itemId] then
			return "Line "..i.." contains a duplicated item id : "..itemId
		end
		items[itemId] = results
	end

	return {delimiter = header.delimiter, watchingChannels = header.channelIds, watchingPlayers = header.players, items = items }
end

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
 end

 local function unquote(s)
	return (s:gsub("^\"(.-)\"$", "%1"))
 end
	
local function handleNewData(data, db)
	-- if data is empty then return empty set
	local result = {}
	if data ~= "" then
		-- parse data
		local trimmedData = trim(data)
		-- if first char and last char is quote, then unquote string
		if trimmedData:sub(1,1) == '"' and trimmedData:sub(-1) == '"' then
			trimmedData = unquote(trimmedData)
		end

		local parsedData = parseData(trimmedData)

		if type(parsedData) == 'string' then
			return parsedData
		end
		db.delimiter = parsedData.delimiter
		db.watchingChannels = parsedData.watchingChannels
		db.watchingPlayers = parsedData.watchingPlayers
		db.items = parsedData.items
	else
		db.delimiter = ""
		db.watchingChannels = {}
		db.watchingPlayers = {}
		db.items = {}
	end

	-- count keys in db.items
	local count = 0
	for k,v in pairs(db.items) do
		count = count + 1
	end

	return 'Imported '..count..' items'
end

-- register to all channels
for i=1, #channels do
	for j=1, #channels[i].from do
		frame:RegisterEvent(channels[i].from[j])
	end
end

function checkChannel(channelId)
	for i=1, #ItemAnnouncerDB.watchingChannels do
		local channel = ChannelById[ItemAnnouncerDB.watchingChannels[i]]
		for j=1, #channel.from do
			if channel.from[j] == channelId then
				return true
			end
		end
	end
	return false
end

function checkPlayer(player)
	for i=1, #ItemAnnouncerDB.watchingPlayers do
		if ItemAnnouncerDB.watchingPlayers[i] == player then
			return true
		end
	end
	return false
end

function findItemEntriesInMessage(itemLink)
	local itemId = itemLink:match("item:(%d+):")
	if itemId and tonumber(itemId) then
		return ItemAnnouncerDB.items[tonumber(itemId)]
	else
		return nil
	end
end

function checkEntryConditions(message, itemEntry)
	local isConditionOk = ChannelById[itemEntry.channelId].cond()

	if not isConditionOk then
		return false
	end

	-- check message contains all whitelist
	local whiteList = itemEntry.whiteList
	for m=1, #whiteList do
		if not message:find(whiteList[m]) then
			return false
		end
	end

	-- check message does not contains any blacklist
	local blackList = itemEntry.blackList
	local blackListOk = true
	for m=1, #blackList do
		if message:find(blackList[m]) then
			return false
		end
	end

	return true
end

frame:SetScript("OnEvent",
    function(self, event, message, sender)
		if checkChannel(event) and checkPlayer(sender) then
			-- print('channel ok and sender ok')
			local itemEntries = findItemEntriesInMessage(message)

			if itemEntries then
				-- print('item found')
				for i=1, #itemEntries do
					local itemEntry = itemEntries[i]
					if checkEntryConditions(message, itemEntry) then
						-- print('condition ok')
						SendChatMessage(itemEntry.message, itemEntry.channelId)
					end
				end
			end
		end
	end
)

local function importPopup()
	if frameShown then
		return
	end
	
	frameShown = true

	popup = AceGUI:Create("Frame")
	popup:SetTitle("ItemAnnouncer Settings")
    popup:SetStatusText(status)

	popup.sizer_se:Hide()
	popup.sizer_s:Hide()
	popup.sizer_e:Hide()
	popup:SetWidth(600)
	popup:SetHeight(370)
	local textboxGroup = AceGUI:Create("SimpleGroup")
	textboxGroup:SetRelativeWidth(1)

	inputfield = AceGUI:Create("MultiLineEditBox")
	inputfield:SetLabel("Paste data here")
	inputfield:SetNumLines(14)
	inputfield:SetWidth(500)

	local textBuffer, i, lastPaste = {}, 0, 0
	local pasted = ""
	inputfield.editBox:SetScript("OnShow", function(obj)
		obj:SetText("")
		pasted = ""
	end)
	local function clearBuffer(obj1)
		obj1:SetScript('OnUpdate', nil)
		pasted = strtrim(table.concat(textBuffer))
		inputfield.editBox:ClearFocus()
	end
	inputfield.editBox:SetScript('OnChar', function(obj2, c)
		if lastPaste ~= GetTime() then
			textBuffer, i, lastPaste = {}, 0, GetTime()
			obj2:SetScript('OnUpdate', clearBuffer)
		end
		i = i + 1
		textBuffer[i] = c
	end)
	inputfield.editBox:SetMaxBytes(250000)
	inputfield.editBox:SetScript("OnMouseUp", nil);

	inputfield:DisableButton(true)
	popup:AddChild(inputfield)

	local parseData = AceGUI:Create("Button")
	parseData:SetText("Import data")
	popup:AddChild(parseData)

	popup:SetLayout("List")

	parseData:SetCallback("OnClick", function (obj, button, down)
		--message(pasted)
		status = handleNewData(pasted, ItemAnnouncerDB)
        popup:SetStatusText(status)
		inputfield:SetText("")
	end)

	popup:SetCallback("OnClose", 
	function(widget)
	  AceGUI:Release(widget)
	  frameShown = false
	end
   )
end

local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("ItemAnnouncer", {
    type = "data source",
    text = "Item Announcer",
    icon = "Interface\\icons\\ui_chat",
    OnClick = function(self, btn)
        importPopup()
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("Item Announcer Settings")
    end,
})
local icon = LibStub("LibDBIcon-1.0", true)
icon:Register("ItemAnnouncer", miniButton, ItemAnnouncerDB)