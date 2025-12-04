local Utils = script.Parent.Parent

local LuaEncode = require(script.Parent.Parent.Serializer.LuaEncode)
local CodeGen = require(script.Parent.Generator)

local SessionExporter = {}
do
    local StringMapper = {}
    StringMapper.__index = StringMapper

    function StringMapper.New()
        return setmetatable({
            StringMap = {},
            StringList = {},
            NextStringId = 1,
        }, StringMapper)
    end

    function StringMapper:GetId(Str)
        if Str == nil then Str = "nil" end
        Str = tostring(Str)
        if not self.StringMap[Str] then
            self.StringMap[Str] = self.NextStringId
            self.StringList[tostring(self.NextStringId)] = Str
            self.NextStringId = self.NextStringId + 1
        end
        return self.StringMap[Str]
    end

    function StringMapper:GetString(Id)
        return self.StringList[Id]
    end

    SessionExporter.StringMapper = StringMapper
end

function SessionExporter:FetchAllLogs()
	local AllCalls = {}

	for _, LogCategory in next, wax.shared.Logs do
		for _, Log in next, LogCategory do
			for Idx, Call in next, Log.Calls do
				table.insert(AllCalls, setmetatable(Call, {
					__index = Log
				}))
			end
		end
	end

	return AllCalls
end

function SessionExporter:SortCalls(AllCalls)
	table.sort(AllCalls, function(a, b)
		local TimeA = a.CreationTime or 0
		local TimeB = b.CreationTime or 0
		return TimeA < TimeB
	end)
end

function SessionExporter:GetSessionData(AllCalls)
	local StartTime = wax.shared.CobaltStartTime or tick()
	local EndTime = AllCalls[#AllCalls] and AllCalls[#AllCalls].CreationTime or tick()
	local Duration = math.max(0.1, EndTime - StartTime)
	local SessionId = wax.shared.HttpService:GenerateGUID(false)

	return {
        StartTime = StartTime,
        EndTime = EndTime,
        Duration = Duration,
        SessionId = SessionId,
    }
end

function SessionExporter:EscapeHTML(Str)
	return Str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

function SessionExporter:SerializeLuauTableForHTML(Table)
	local SerializedString = LuaEncode(Table, {
		Prettify = true,
		InsertCycles = true,
		DisableNilParentHandler = true,
	})
	
	return self:EscapeHTML(SerializedString)
end

function SessionExporter:ProcessCalls(AllCalls, SessionData, UpdateProgress)
	local StringMapper = self.StringMapper.New()

    local Events = {}
    local AllCallsNum = #AllCalls
    for Idx, Call in next, AllCalls do
        if Idx % 500 == 0 then
            if UpdateProgress then
                UpdateProgress(`Processing... ({Idx}/{AllCallsNum})`)
            end
            task.wait()
        end

        local ArgsString = self:SerializeLuauTableForHTML(
            { table.unpack(Call.Arguments, 1, Call.Arguments.n) }
        )

        local Method = "Unknown"
        if wax.shared.FunctionForClasses[Call.Type] then
            Method = wax.shared.FunctionForClasses[Call.Type][Call.Instance.ClassName] or Method
        end

        local FunctionName, FunctionLine, FunctionSource, FunctionHash = "Unknown", Call.Line or -1, Call.Source or "Unknown", "N/A"
        local FunctionUpvalues, FunctionProtos, FunctionConstants = "{}", "{}", "{}"
        do
            if type(Call.Function) == "table" and Call.IsActor then
                FunctionName = Call.Function.Name ~= "" and Call.Function.Name or "Anonymous"
                FunctionSource = Call.Function.Source or "N/A"
                FunctionLine = Call.Function.Line or -1
                FunctionHash = Call.Function.FunctionHash or "N/A"

                if not Call.Function.IsC then
                    FunctionUpvalues = self:SerializeLuauTableForHTML(Call.Function.Upvalues)
                    FunctionProtos = self:SerializeLuauTableForHTML(Call.Function.Protos)
                    FunctionConstants = self:SerializeLuauTableForHTML(Call.Function.Constants)
                end
            elseif type(Call.Function) == "function" then
                FunctionName = debug.info(Call.Function, "n")
                FunctionHash = getfunctionhash and getfunctionhash(Call.Function) or "N/A"

                if islclosure(Call.Function) then
                    FunctionUpvalues = self:SerializeLuauTableForHTML(debug.getupvalues(Call.Function))
                    FunctionProtos = self:SerializeLuauTableForHTML(debug.getprotos(Call.Function))
                    FunctionConstants = self:SerializeLuauTableForHTML(debug.getconstants(Call.Function))
                end
            else
                FunctionName = tostring(Call.Function or "Unknown")
            end

            if FunctionName == "" then FunctionName = "Anonymous" end
        end

        local OriginPath = Call.Origin and CodeGen.GetFullPath(Call.Origin, {
            DisableNilParentHandler = true,
        }) or "Unknown"

        table.insert(Events, {
            StringMapper:GetId(Call.Instance.Name),
            StringMapper:GetId(Call.Instance.ClassName),
            StringMapper:GetId(CodeGen.GetFullPath(Call.Instance, {
                DisableNilParentHandler = true,
            })),

            StringMapper:GetId(Method),
            (Call.CreationTime or SessionData.StartTime),
            StringMapper:GetId(OriginPath),

            StringMapper:GetId(ArgsString),
            StringMapper:GetId(Method),

            StringMapper:GetId(FunctionName),
            FunctionLine,
            StringMapper:GetId(FunctionSource),
            Call.IsExecutor and 1 or 0,
            Call.IsActor and 1 or 0,

            StringMapper:GetId(FunctionHash),
            StringMapper:GetId(FunctionUpvalues),
            StringMapper:GetId(FunctionProtos),
            StringMapper:GetId(FunctionConstants)
        })
    end

    return Events, StringMapper
end

function SessionExporter:ExportSessionToHTML(Events, StringMapper, SessionData)
    local Template = Utils.CodeGen.SessionHTMLView.Value
    local StartDateStr = os.date("%d %b %Y, %H:%M:%S", math.floor(SessionData.StartTime))
    local EndDateStr = os.date("%d %b %Y, %H:%M:%S", math.floor(SessionData.EndTime))

    local HTML = Template
        :gsub("{{EVENTS_JSON}}", function() return wax.shared.HttpService:JSONEncode(Events) end)
        :gsub("{{DICTIONARY_JSON}}", function() return wax.shared.HttpService:JSONEncode(StringMapper.StringList) end)
        :gsub("{{SESSION_ID}}", SessionData.SessionId)
        :gsub("{{START_TIME}}", tostring(SessionData.StartTime))
        :gsub("{{DURATION}}", tostring(SessionData.Duration))
        :gsub("{{EVENT_COUNT}}", tostring(#Events))
        :gsub("{{TOTAL_DURATION}}", string.format("%.2f", SessionData.Duration))
        :gsub("{{PLACE_ID}}", tostring(game.PlaceId))
        :gsub("{{JOB_ID}}", game.JobId)
        :gsub("{{DATE}}", StartDateStr)
        :gsub("{{END_DATE}}", EndDateStr)

    return HTML
end

return SessionExporter