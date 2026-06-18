local FileHelper = {}
FileHelper.__index = FileHelper

--[[
    Creates a new FileHelper instance.

    @param basePath: The base path to use for the FileHelper.
    @return FileHelper: The new FileHelper instance.
]]
function FileHelper.new(basePath: string)
    local self = setmetatable({
        BasePath = FileHelper.NormalizePath(basePath),
    }, FileHelper)

    self:EnsureDirectory()
    return self
end

--[[
    Ensures that the directory exists.

    @return: None.
]]
function FileHelper:EnsureDirectory()
    local paths = {}
    local parts = self.BasePath:split("/")

    for idx = 1, #parts do
        if parts[idx] == "" then continue end
        paths[#paths + 1] = table.concat(parts, "/", 1, idx)
    end

    for i = 1, #paths do
        local str = paths[i]
        if isfolder(str) then continue end
        makefolder(str)
    end
end

--[[
    Gets the path to the file.
    @param relativePath: The relative path to the file.
    @return: The path to the file.
]]
function FileHelper:GetPath(relativePath: string)
    local normalizedPath = self.NormalizePath(relativePath or "")
    
    if self.BasePath == "" then
        return normalizedPath
    end
    
    if self.BasePath:sub(-1) == "/" then
        return self.BasePath .. normalizedPath
    end
    
    if normalizedPath == "" then
        return self.BasePath
    end
    
    return self.BasePath .. "/" .. normalizedPath
end

--[[
    Normalizes a path.
    @param path: The path to normalize.
    @return: The normalized path.
]]
function FileHelper.NormalizePath(path: string)
    if type(path) ~= "string" then return "" end
    return path:gsub("\\", "/")
end

--[[
    Gets the relative path to the file.
    @param path: The path to get the relative path of.
    @return: The relative path.
]]
function FileHelper:GetRelativePath(path: string)
    path = self.NormalizePath(path)
    local basePath = self.NormalizePath(self.BasePath)
    if basePath:sub(-1) ~= "/" then
        basePath = basePath .. "/"
    end
    
    local Start, End = string.find(path, basePath, 1, true)
    if Start then
        return string.sub(path, End + 1)
    end
    
    return path
end

--[[
    Ensures that the file exists.
    @param relativePath: The relative path to the file.
    @param default: The default content to write to the file.
    @return: None.
]]
function FileHelper:EnsureFile(relativePath: string, default: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    if not isfile(self:GetPath(relativePath)) then
        writefile(self:GetPath(relativePath), default)
    end
end

--[[
    Checks if a file or directory exists.
    @param relativePath: The relative path to the file or directory.
    @return: True if the file or directory exists, false otherwise.
]]
function FileHelper:DoesExist(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    local path = self:GetPath(relativePath)

    local fileSuccess = pcall(assert, isfile(path), "File does not exist.")
    local folderSuccess = pcall(assert, isfolder(path), "Directory does not exist.")

    return fileSuccess or folderSuccess
end

--[[
    Reads the contents of a file.
    @param relativePath: The relative path to the file.
    @return: The contents of the file.
]]
function FileHelper:ReadFile(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    return readfile(self:GetPath(relativePath))
end

--[[
    Reads the contents of a file.
    @param path: The path to the file.
    @return: The contents of the file.
]]
function FileHelper:ReadRawFile(path: string)
    return readfile(path)
end

--[[
    Writes the contents of a file.
    @param relativePath: The relative path to the file.
    @param data: The contents to write to the file.
    @return: None.
]]
function FileHelper:WriteFile(relativePath: string, data: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    writefile(self:GetPath(relativePath), data)
end

--[[
    Appends contents to a file.
    @param relativePath: The relative path to the file.
    @param data: The contents to append to the file.
    @return: None.
]]
function FileHelper:AppendFile(relativePath: string, data: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    appendfile(self:GetPath(relativePath), data)
end

--[[
    Deletes a file.
    @param relativePath: The relative path to the file.
    @return: None.
]]
function FileHelper:DeleteFile(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    if isfile(self:GetPath(relativePath)) then
        delfile(self:GetPath(relativePath))
    end
end

--[[
    Deletes a directory.
    @param relativePath: The relative path to the directory.
    @return: None.
]]
function FileHelper:DeleteDirectory(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    if isfolder(self:GetPath(relativePath)) then
        delfolder(self:GetPath(relativePath))
    end
end

--[[
    Lists the files in a directory.
    @param relativePath: The relative path to the directory.
    @return: The files in the directory.
]]
function FileHelper:ListFiles(relativePath: string?)
    relativePath = self.NormalizePath(relativePath or "")
    
    local files = {}
    for _, file in listfiles(self:GetPath(relativePath)) do
        table.insert(files, self:GetRelativePath(file))
    end

    return files
end

--[[
    Gets the file name from a path.
    @param relativePath: The relative path to the file.
    @return: The file name.
]]
function FileHelper:GetFileName(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    return relativePath:match("[^/]+$")
end

--[[
    Lists the file names in a directory.
    @param relativePath: The relative path to the directory.
    @return: The file names in the directory.
]]
function FileHelper:ListFileNames(relativePath: string?)
    relativePath = self.NormalizePath(relativePath or "")
    
    local names = {}
    for _, file in self:ListFiles(relativePath) do
        table.insert(names, self:GetFileName(file))
    end

    return names
end

return FileHelper
