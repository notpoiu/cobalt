-- Logger
-- ActualMasterOogway
-- December 8, 2024

--[=[
    A simple logging utility that writes messages to a file. Supports different log levels
    and can be configured to overwrite or append to the log file.

    Log Format:  2024-12-04T15:28:31.131Z,0.131060,MyThread,Warning [FLog::RobloxStarter] Roblox stage ReadyForFlagFetch completed
                 <timestamp>,<elapsed_time>,<thread_id>,<level> <message>
]=]

local Logger = {}
Logger.__index = Logger

local FileHelper = require(script.Parent.FileHelper)

Logger.LOG_LEVELS = {
	ERROR = 1,
	WARNING = 2,
	INFO = 3,
	DEBUG = 4,
}

local LOG_LEVEL_STRINGS = {
	[Logger.LOG_LEVELS.ERROR] = "ERROR",
	[Logger.LOG_LEVELS.WARNING] = "WARNING",
	[Logger.LOG_LEVELS.INFO] = "INFO",
	[Logger.LOG_LEVELS.DEBUG] = "DEBUG",
}

local startTime = tick()

local function SplitFilePath(path: string): (string, string)
	local normalizedPath = FileHelper.NormalizePath(path)
	local directory, fileName = normalizedPath:match("^(.*)/([^/]*)$")

	return directory or "", fileName or normalizedPath
end

--[=[
    Generates a unique file name for the log file. The file name is based on the current
    job ID, ensuring it is unique per server instance but consistent across multiple
    executions within the same server.

    @return string A unique file name for the log file.
]=]
function Logger:GenerateFileName()
	local JobIdNumber = game.JobId:gsub("%D", "")
	local timestamp = os.date("!%Y%m%d%H%M%S")
	local fileName = `{JobIdNumber * 1.7 // 1.8}_{timestamp}.log`

	if self.logFileDirectory == "" then
		return fileName
	end

	return `{self.logFileDirectory}/{fileName}`
end

--[=[
    Creates a new Logger instance.

    @param logFilePath string The path to the log file.
    @param logLevel number The minimum log level to write to the file. Defaults to INFO.
    @param overwrite boolean Whether to overwrite the log file or append to it. Defaults to false (append).
    @return Logger A new Logger instance.
]=]
function Logger.new(logFilePath: string, logLevel: number?, overwrite: boolean?)
	local self = setmetatable({}, Logger)
	local logFileDirectory, logFileName = SplitFilePath(logFilePath)

	self.fileHelper = FileHelper.new(logFileDirectory)
	self.logFileName = logFileName
	self.logFileDirectory = logFileDirectory
	self.logFilePath = self.fileHelper:GetPath(logFileName)
	self.logLevel = logLevel or Logger.LOG_LEVELS.INFO
	self.overwrite = overwrite or false

	local success, err = pcall(function()
		if self.overwrite then
			self.fileHelper:WriteFile(self.logFileName, "")
		else
			self.fileHelper:EnsureFile(self.logFileName, "")
		end
	end)
	if not success then
		warn(debug.traceback(`Failed to initialize log file: {self.logFilePath} - {err}`, 2))
	end

	self:Info("Logger", "Logger initialized")

	return self
end

--[=[
    Logs a message to the file.

    @param level number The log level of the message.
    @param threadId string The ID of the thread or source of the log message.
    @param message string The message to log.
]=]
function Logger:Log(level: number, threadId: string, message: string)
	if level <= self.logLevel then
		local levelStr = LOG_LEVEL_STRINGS[level]

		local timestamp = `{os.date("!%Y-%m-%dT%H:%M:%S")}{("%.3f"):format(tick() % 1)}Z`
		local elapsedTime = ("%.6f"):format(tick() - startTime)

		local logMessage = `{timestamp},{elapsedTime},{threadId},{levelStr} {message}\n`

		local success, err = pcall(self.fileHelper.AppendFile, self.fileHelper, self.logFileName, logMessage)
		if not success then
			warn(debug.traceback(`Failed to write to log file: {self.logFilePath} - {err}`, 2))
		end
	end
end

--[=[
    Logs a debug message.

    @param threadId string The ID of the thread or source of the log message.
    @param message string The message to log.
]=]
function Logger:Debug(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.DEBUG, threadId, message)
end

--[=[
    Logs an info message.

    @param threadId string The ID of the thread or source of the log message.
    @param message string The message to log.
]=]
function Logger:Info(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.INFO, threadId, message)
end

--[=[
    Logs a warning message.

    @param threadId string The ID of the thread or source of the log message.
    @param message string The message to log.
]=]
function Logger:Warning(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.WARNING, threadId, message)
end

--[=[
    Logs an error message.

    @param threadId string The ID of the thread or source of the log message.
    @param message string The message to log.
]=]
function Logger:Error(threadId: string, message: string)
	self:Log(Logger.LOG_LEVELS.ERROR, threadId, message)
end

return Logger
