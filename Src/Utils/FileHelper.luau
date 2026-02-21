local FileHelper = {}
FileHelper.__index = FileHelper

function FileHelper.new(basePath: string)
    local self = setmetatable({
        BasePath = FileHelper.NormalizePath(basePath),
    }, FileHelper)

    self:EnsureDirectory()
    return self
end

function FileHelper:EnsureDirectory()
    local paths = {}
    local parts = self.BasePath:split("/")

    for idx = 1, #parts do
        paths[#paths + 1] = table.concat(parts, "/", 1, idx)
    end

    for i = 1, #paths do
        local str = paths[i]
        if isfolder(str) then continue end
        makefolder(str)
    end
end

function FileHelper:GetPath(relativePath: string)
    local normalizedPath = self.NormalizePath(relativePath or "")
    
    if self.BasePath:sub(-1) == "/" then
        return self.BasePath .. normalizedPath
    end
    
    if normalizedPath == "" then
        return self.BasePath
    end
    
    return self.BasePath .. "/" .. normalizedPath
end

function FileHelper.NormalizePath(path: string)
    if type(path) ~= "string" then return "" end
    return path:gsub("\\", "/")
end

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

function FileHelper:EnsureFile(relativePath: string, default: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    if not isfile(self:GetPath(relativePath)) then
        writefile(self:GetPath(relativePath), default)
    end
end

function FileHelper:ReadFile(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    return readfile(self:GetPath(relativePath))
end

function FileHelper:ReadRawFile(path: string)
    return readfile(path)
end

function FileHelper:WriteFile(relativePath: string, data: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    writefile(self:GetPath(relativePath), data)
end

function FileHelper:DeleteFile(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    if isfile(self:GetPath(relativePath)) then
        delfile(self:GetPath(relativePath))
    end
end

function FileHelper:DeleteDirectory(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    if isfolder(self:GetPath(relativePath)) then
        delfolder(self:GetPath(relativePath))
    end
end

function FileHelper:ListFiles(relativePath: string?)
    relativePath = self.NormalizePath(relativePath or "")
    
    local files = {}
    for _, file in listfiles(self:GetPath(relativePath)) do
        table.insert(files, self:GetRelativePath(file))
    end

    return files
end

function FileHelper:GetFileName(relativePath: string)
    relativePath = self.NormalizePath(relativePath or "")
    
    return relativePath:match("[^/]+$")
end

function FileHelper:ListFileNames(relativePath: string?)
    relativePath = self.NormalizePath(relativePath or "")
    
    local names = {}
    for _, file in self:ListFiles(relativePath) do
        table.insert(names, self:GetFileName(file))
    end

    return names
end

return FileHelper