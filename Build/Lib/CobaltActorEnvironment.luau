local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CobaltActorEnvironment = {}

local TemplatePath = "Spy/Actors/Environment"
local TemplateFilePath = "Src/Spy/Actors/Environment.txt"
local ManagedIncludeAsPattern = '^([ \t]*)%-%-%s*#region%s+@include%s+"([^"]+)"%s+as%s+"([^"]+)"%s*$'
local ManagedIncludePattern = '^([ \t]*)%-%-%s*#region%s+@include%s+"([^"]+)"%s*$'
local ManagedRegionIncludePattern = "^([ \t]*)%-%-%s*#region%s+@include%s+region%s+([%w_%-%.]+)%s*$"
local ManagedRegionEndPattern = "^%s*%-%-%s*#endregion%s*$"
local IncludeAsPattern = '^([ \t]*)%-%-%s*@include%s+"([^"]+)"%s+as%s+"([^"]+)"%s*$'
local IncludePattern = '^([ \t]*)%-%-%s*@include%s+"([^"]+)"%s*$'
local RegionIncludePattern = "^([ \t]*)%-%-%s*@include%s+region%s+([%w_%-%.]+)%s*$"
local ExportRegionPattern = '^%s*%-%-%s*#region%s+@export%s+"([%w_%-%.]+)"%s*$'

local function GetChildren(Instance)
	local Success, Children = pcall(function()
		return Instance:GetChildren()
	end)

	if Success then
		return Children
	end

	return {}
end

local function FindDirectChild(Instance, Name: string)
	for _, Child in GetChildren(Instance) do
		if Child.Name == Name then
			return Child
		end
	end

	return nil
end

local function FindPathFrom(Instance, Parts: { string }, Index: number)
	local Current = Instance
	for PathIndex = Index, #Parts do
		Current = FindDirectChild(Current, Parts[PathIndex])
		if not Current then
			return nil
		end
	end

	return Current
end

local function FindDescendantPath(Roots: { any }, Parts: { string })
	local function Visit(Instance)
		if Instance.Name == Parts[1] then
			local Match = FindPathFrom(Instance, Parts, 2)
			if Match then
				return Match
			end
		end

		for _, Child in GetChildren(Instance) do
			local Match = Visit(Child)
			if Match then
				return Match
			end
		end

		return nil
	end

	for _, Root in Roots do
		local Match = Visit(Root)
		if Match then
			return Match
		end
	end

	return nil
end

local function SplitPath(Path: string): { string }
	local Parts = {}
	for Part in string.gmatch(Path, "[^/]+") do
		table.insert(Parts, Part)
	end

	return Parts
end

local function ShouldScanFile(Path: string): boolean
	return string.match(Path, "%.luau$") ~= nil or string.match(Path, "%.txt$") ~= nil
end

local function ReadDirRecursive(Directory: string, Files: { string }?)
	local FileList = Files or {}
	for _, EntryName in fs.readDir(Directory) do
		local EntryPath = Directory .. "/" .. EntryName
		if fs.isFile(EntryPath) then
			if ShouldScanFile(EntryPath) then
				table.insert(FileList, EntryPath)
			end
		elseif fs.isDir(EntryPath) then
			ReadDirRecursive(EntryPath, FileList)
		end
	end

	return FileList
end

local function BuildRegionRegistry()
	local Regions = {}

	if not fs.isDir("Src") then
		return Regions
	end

	for _, Path in ReadDirRecursive("Src") do
		local ActiveRegion = nil
		local ActiveLines = nil

		for Line in string.gmatch(fs.readFile(Path) .. "\n", "([^\n]*)\n") do
			local RegionName = string.match(Line, ExportRegionPattern)
			if RegionName then
				if ActiveRegion then
					error(`Nested actor environment export region "{RegionName}" in "{Path}"`)
				end

				if Regions[RegionName] then
					error(
						`Duplicate actor environment export region "{RegionName}" in "{Path}" and "{Regions[RegionName].Path}"`
					)
				end

				ActiveRegion = RegionName
				ActiveLines = {}
			elseif string.match(Line, ManagedRegionEndPattern) and ActiveRegion then
				Regions[ActiveRegion] = {
					Path = Path,
					Source = table.concat(ActiveLines, "\n"),
				}

				ActiveRegion = nil
				ActiveLines = nil
			elseif ActiveRegion then
				table.insert(ActiveLines, Line)
			end
		end

		if ActiveRegion then
			error(`Unterminated actor environment export region "{ActiveRegion}" in "{Path}"`)
		end
	end

	return Regions
end

local function IndentSource(Source: string, Indent: string): string
	Source = string.gsub(Source, "\r\n", "\n")
	Source = string.gsub(Source, "\r", "\n")

	if Source == "" then
		return ""
	end

	local Lines = {}
	local HasTrailingNewline = string.sub(Source, -1) == "\n"

	for Line in string.gmatch(Source .. "\n", "([^\n]*)\n") do
		table.insert(Lines, if Line == "" then "" else Indent .. Line)
	end

	if HasTrailingNewline then
		table.remove(Lines)
	end

	return table.concat(Lines, "\n")
end

local function SplitLines(Source: string): { string }
	local Lines = {}
	for Line in string.gmatch(Source .. "\n", "([^\n]*)\n") do
		table.insert(Lines, Line)
	end

	return Lines
end

local function RewriteReturnAs(Source: string, IncludePath: string, SourcePath: string, Target: string): string
	local Lines = SplitLines(Source)

	local ReturnLineIndex = nil
	for Index = #Lines, 1, -1 do
		if string.match(Lines[Index], "%S") then
			ReturnLineIndex = Index
			break
		end
	end

	if not ReturnLineIndex then
		error(`Actor environment include "{IncludePath}" from "{SourcePath}" has no return to assign to "{Target}"`)
	end

	local ReturnIndent, ReturnValue = string.match(Lines[ReturnLineIndex], "^([ \t]*)return%s+(.+)%s*$")
	if not ReturnValue then
		error(`Actor environment include "{IncludePath}" from "{SourcePath}" does not end with a return for "{Target}"`)
	end

	Lines[ReturnLineIndex] = ReturnIndent .. Target .. " = " .. ReturnValue

	return "do\n" .. IndentSource(table.concat(Lines, "\n"), "\t") .. "\nend"
end

local ExpandIncludes

local function ExpandFileInclude(
	IncludePath: string,
	SourcePath: string,
	Stack: { [string]: boolean },
	Regions: { [string]: { Path: string, Source: string } }
): string
	local StackKey = `file:{IncludePath}`
	if Stack[StackKey] then
		error(`Recursive actor environment include "{IncludePath}" in "{SourcePath}"`)
	end

	if not fs.isFile(IncludePath) then
		error(`Actor environment include "{IncludePath}" from "{SourcePath}" does not exist`)
	end

	Stack[StackKey] = true
	local IncludedSource = fs.readFile(IncludePath)
	local ExpandedSource = ExpandIncludes(IncludedSource, IncludePath, Stack, Regions)
	Stack[StackKey] = nil

	return ExpandedSource
end

local function ExpandRegionInclude(
	RegionName: string,
	SourcePath: string,
	Stack: { [string]: boolean },
	Regions: { [string]: { Path: string, Source: string } }
): string
	local Region = Regions[RegionName]
	if not Region then
		error(`Actor environment region "{RegionName}" from "{SourcePath}" does not exist`)
	end

	local StackKey = `region:{RegionName}`
	if Stack[StackKey] then
		error(`Recursive actor environment region include "{RegionName}" in "{SourcePath}"`)
	end

	Stack[StackKey] = true
	local ExpandedSource = ExpandIncludes(Region.Source, Region.Path, Stack, Regions)
	Stack[StackKey] = nil

	return ExpandedSource
end

local function FindManagedRegionEnd(Lines: { string }, StartIndex: number, SourcePath: string): number
	for PossibleEndIndex = StartIndex + 1, #Lines do
		if string.match(Lines[PossibleEndIndex], ManagedRegionEndPattern) then
			return PossibleEndIndex
		end
	end

	error(`Actor environment managed include region in "{SourcePath}" is missing #endregion`)
end

local function ResolveManagedInclude(
	IncludeAsPath: string?,
	IncludeAsTarget: string?,
	IncludePath: string?,
	RegionName: string?,
	SourcePath: string,
	Stack: { [string]: boolean },
	Regions: { [string]: { Path: string, Source: string } }
): string
	if IncludeAsPath then
		return RewriteReturnAs(
			ExpandFileInclude(IncludeAsPath, SourcePath, Stack, Regions),
			IncludeAsPath,
			SourcePath,
			IncludeAsTarget
		)
	elseif IncludePath then
		return ExpandFileInclude(IncludePath, SourcePath, Stack, Regions)
	end

	return ExpandRegionInclude(RegionName, SourcePath, Stack, Regions)
end

local function RefreshManagedIncludes(
	Source: string,
	SourcePath: string,
	Stack: { [string]: boolean },
	Regions: { [string]: { Path: string, Source: string } }
): string
	local Output = {}
	local Lines = SplitLines(Source)
	local LineIndex = 1

	while LineIndex <= #Lines do
		local Line = Lines[LineIndex]
		local ManagedIncludeAsIndent, ManagedIncludeAsPath, ManagedIncludeAsTarget =
			string.match(Line, ManagedIncludeAsPattern)
		local ManagedIndent, ManagedIncludePath = string.match(Line, ManagedIncludePattern)
		local ManagedRegionIndent, ManagedRegionName = string.match(Line, ManagedRegionIncludePattern)

		if ManagedIncludeAsPath or ManagedIncludePath or ManagedRegionName then
			local EndIndex = FindManagedRegionEnd(Lines, LineIndex, SourcePath)
			local ExpandedSource = ResolveManagedInclude(
				ManagedIncludeAsPath,
				ManagedIncludeAsTarget,
				ManagedIncludePath,
				ManagedRegionName,
				SourcePath,
				Stack,
				Regions
			)

			table.insert(Output, Line)
			table.insert(
				Output,
				IndentSource(ExpandedSource, ManagedIncludeAsIndent or ManagedIndent or ManagedRegionIndent)
			)
			table.insert(Output, Lines[EndIndex])
			LineIndex = EndIndex + 1
		else
			table.insert(Output, Line)
			LineIndex += 1
		end
	end

	return table.concat(Output, "\n")
end

function ExpandIncludes(
	Source: string,
	SourcePath: string,
	Stack: { [string]: boolean },
	Regions: { [string]: { Path: string, Source: string } }
): string
	local Output = {}
	local Lines = SplitLines(Source)
	local LineIndex = 1

	while LineIndex <= #Lines do
		local Line = Lines[LineIndex]
		local ShouldAdvance = true
		local ManagedIncludeAsIndent, ManagedIncludeAsPath, ManagedIncludeAsTarget =
			string.match(Line, ManagedIncludeAsPattern)
		local ManagedIndent, ManagedIncludePath = string.match(Line, ManagedIncludePattern)
		local ManagedRegionIndent, ManagedRegionName = string.match(Line, ManagedRegionIncludePattern)
		local IncludeAsIndent, IncludeAsPath, IncludeAsTarget = string.match(Line, IncludeAsPattern)
		local Indent, IncludePath = string.match(Line, IncludePattern)
		local RegionIndent, RegionName = string.match(Line, RegionIncludePattern)

		if ManagedIncludeAsPath or ManagedIncludePath or ManagedRegionName then
			local EndIndex = FindManagedRegionEnd(Lines, LineIndex, SourcePath)
			local ExpandedSource = ResolveManagedInclude(
				ManagedIncludeAsPath,
				ManagedIncludeAsTarget,
				ManagedIncludePath,
				ManagedRegionName,
				SourcePath,
				Stack,
				Regions
			)

			table.insert(Output, Line)
			table.insert(
				Output,
				IndentSource(ExpandedSource, ManagedIncludeAsIndent or ManagedIndent or ManagedRegionIndent)
			)
			table.insert(Output, Lines[EndIndex])
			LineIndex = EndIndex + 1
			ShouldAdvance = false
		elseif IncludeAsPath then
			table.insert(
				Output,
				IndentSource(
					RewriteReturnAs(
						ExpandFileInclude(IncludeAsPath, SourcePath, Stack, Regions),
						IncludeAsPath,
						SourcePath,
						IncludeAsTarget
					),
					IncludeAsIndent
				)
			)
		elseif IncludePath then
			table.insert(Output, IndentSource(ExpandFileInclude(IncludePath, SourcePath, Stack, Regions), Indent))
		elseif RegionName then
			table.insert(
				Output,
				IndentSource(ExpandRegionInclude(RegionName, SourcePath, Stack, Regions), RegionIndent)
			)
		else
			table.insert(Output, Line)
		end

		if ShouldAdvance then
			LineIndex += 1
		end
	end

	local Expanded = table.concat(Output, "\n")
	for Line in string.gmatch(Expanded .. "\n", "([^\n]*)\n") do
		local UnresolvedInclude = string.match(Line, "^%s*%-%-%s*@include%s+(.+)$")
		if UnresolvedInclude then
			error(`Actor environment include "{UnresolvedInclude}" from "{SourcePath}" was not resolved`)
		end
	end

	return Expanded
end

function CobaltActorEnvironment.ProcessModel(ModelRoot: { any })
	local Environment = FindDescendantPath(ModelRoot, SplitPath(TemplatePath))
	if not Environment then
		return
	end

	if Environment.ClassName ~= "StringValue" then
		error(`Expected "{TemplatePath}" to be a StringValue, got "{Environment.ClassName}"`)
	end

	local Regions = BuildRegionRegistry()
	local RefreshedTemplate = RefreshManagedIncludes(Environment.Value, TemplatePath, {
		[`file:{TemplatePath}`] = true,
	}, Regions)

	if RefreshedTemplate ~= Environment.Value then
		Environment.Value = RefreshedTemplate

		if fs.isFile(TemplateFilePath) then
			fs.writeFile(TemplateFilePath, RefreshedTemplate)
		end
	end

	local Expanded = ExpandIncludes(RefreshedTemplate, TemplatePath, {
		[`file:{TemplatePath}`] = true,
	}, Regions)

	local CompileSuccess, CompileError = pcall(luau.compile, Expanded)
	if not CompileSuccess then
		error(`Expanded actor environment "{TemplatePath}" failed to compile: {tostring(CompileError)}`)
	end

	Environment.Value = Expanded
end

return CobaltActorEnvironment
