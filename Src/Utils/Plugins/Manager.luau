local Manager = {
    Registry = {
        Plugins = {},
        Errored = {},
        Interceptors = {
            Global = {},
            Instance = {}
        },
        UIHooks = {
            RemoteInfo = {
                Tabs = {},
                Open = {},
                Intercept = {}
            },
            ContextMenus = {
                RemoteList = {},
                CallList = {}
            },
            Spy = {
                RemoteList = {},
                CallList = {},
            },
            CodeGen = { Call = {}, Hook = {}, InstancePath = {} },
        },
    },
    HasInterceptors = false,
    HasCodeGenInterceptors = false,
    Initialized = false,
}

local UIUtils = script.Parent.Parent.UI
local Highlighter = require(UIUtils.Highlighter)
local Interface = require(UIUtils.Interface)
local Resize = require(UIUtils.Resize)
local UIHelper = require(UIUtils.Helper)

local Signals = require(script.Parent.Parent.Signal)
local CodeGen = require(script.Parent.Parent.CodeGen.Generator)

-- File Helper
local FileHelperUtil = require(script.Parent.Parent.FileHelper)

local PluginFiles = FileHelperUtil.new("Cobalt/Plugins")

-- Templates
local TemplatePluginData = {
    Name = "Untitled Plugin",
    Description = "No description provided.",
    Author = "N/A",
    Version = "0.0.0",
    Game = "*",
}

--[[
    Validates plugin data against a template.

    @param Data: The plugin data to validate.
    @param Template: The template to validate against.
    @return: The validated plugin data.
]]
local function Validate(Data, Template)
    local NewData = {}
    for Key, Value in Template do
        if Data[Key] == nil or typeof(Data[Key]) ~= typeof(Value) then
            NewData[Key] = Value
        else
            NewData[Key] = Data[Key]
        end
    end
    return NewData
end

-- Helpers
--[[
    Handles a plugin error.

    @param FilePath: The path to the plugin file.
    @param Error: The error message.
]]
local function PluginErrored(FilePath, Error)
    if #Manager.Registry.Errored == 0 then
        wax.shared.Sonner.error(`Failed to load plugin: {FilePath}.`)
    end

    local PluginIndex
    do
        for Idx, Plugin in Manager.Registry.Plugins do
            if Plugin.FilePath ~= FilePath then
                continue
            end

            PluginIndex = Idx
            break
        end
    end

    if PluginIndex then
        local PluginData = table.remove(Manager.Registry.Plugins, PluginIndex)
        table.insert(Manager.Registry.Errored, {
            FilePath = PluginData.FilePath,
            Name = PluginData.Name,
            Author = PluginData.Author,
            Version = PluginData.Version,
            Error = Error,
        })
    else
        table.insert(Manager.Registry.Errored, {
            FilePath = FilePath,
            Error = Error,
        })
    end
end

--[[
    Creates a plugin environment for a plugin.

    @param FilePath: The path to the plugin file.
    @param PluginCallback: The plugin callback function.
    @param PluginThread: The plugin thread.
    @return: The plugin environment.
]]
local function CreatePluginEnvironement(FilePath: string, PluginCallback: (...any) -> (...any), PluginThread: thread)
    -- Setup global Cobalt table
    local Cobalt = {
        Sonner = wax.shared.Sonner,
        UI = { RemoteInfo = {}, ContextMenu = {} },
        Spy = {},
        CodeGen = {},
    }
    
    -- Settings Proxy
    Cobalt.Settings = setmetatable({}, {
        __index = function(_, key)
            return wax.shared.SaveManager:GetState(key, false)
        end,
        __newindex = function(_, key, value)
            wax.shared.SaveManager:SetState(key, value)
        end
    })

    local CurrentPluginData = nil
    local CurrentPluginSettings = nil

    -- UI Functions
    --[[
        Gets the currently selected remote instance in the UI.

        @return: The selected remote instance and its type.
    ]]
    function Cobalt.UI:GetSelectedRemote()
        local Log = wax.shared.GetCurrentLog()
        return Log and Log.Instance or nil, Log and Log.Type or nil
    end

    --[[
        Creates a custom blank modal.

        @param Title: The title of the modal.
        @param Icon: The icon of the modal (Lucide icon).
        @return: The modal interface with Open(), Close(), OnClose() and the Content Frame.
    ]]
    function Cobalt.UI:CreateModal(Title: string, Icon: string)
        local ModalFrame = Interface.New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(10, 10, 10),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0.65, 0, 0, 285),
            Text = "",
            Visible = false,
            Parent = wax.shared.ModalBackground,

            ["UICorner"] = {
                CornerRadius = UDim.new(0, 8),
            },

            ["UIStroke"] = {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = Color3.fromRGB(25, 25, 25),
                Thickness = 1,
            },
        })

        Resize.new({
            MainFrame = ModalFrame,

            MaximumSize = UDim2.new(1, -2, 1, -2),
            MinimumSize = UDim2.fromScale(0.65, 0.712),
            Mirrored = true,
            LockedPosition = true,

            CornerHandleSize = 20,
            HandleSize = 6,
        })

        wax.shared.CreateModalTop(Title, Icon, ModalFrame)

        local ContentFrame = Interface.New("ScrollingFrame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 1, -37),
            AutomaticCanvasSize = Enum.AutomaticSize.XY,
            CanvasSize = UDim2.fromScale(0, 0),
            ScrollBarThickness = 0,
            HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Parent = ModalFrame,
        })

        local OnCloseEvent = Signals:New()
        local ClosedByInternal = false

        ModalFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if not ModalFrame.Visible and not ClosedByInternal then
                OnCloseEvent:Fire()
            end
            ClosedByInternal = false
        end)

        local TabsState = {
            Container = nil,
            Scroller = nil,
            FooterContainer = nil,
            CurrentTab = nil,
            Buttons = {},
            Contents = {}
        }

        local ModalInterface = {
            Container = ContentFrame,
            Open = function()
                wax.shared.OpenModal(ModalFrame)
            end,
            Close = function()
                ClosedByInternal = true
                wax.shared.CloseModal()
                OnCloseEvent:Fire()
            end,
            OnClose = OnCloseEvent
        }

        function ModalInterface:SelectTab(TabName: string)
            if not TabsState.Buttons[TabName] then return end
            
            for _, Button in pairs(TabsState.Buttons) do
                Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                Button.Mask.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            end
            for _, Content in pairs(TabsState.Contents) do
                Content.Visible = false
            end
            
            TabsState.Buttons[TabName].BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            TabsState.Buttons[TabName].Mask.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            TabsState.Contents[TabName].Visible = true
            TabsState.CurrentTab = TabName
        end

        function ModalInterface:AddTab(TabName: string, Icon: string)
            if not TabsState.Container then
                ContentFrame.Visible = false
                
                TabsState.Scroller = Interface.New("ScrollingFrame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 4, 0, 44),
                    Size = UDim2.new(1, -10, 0, 36),
                    CanvasSize = UDim2.fromScale(0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.X,
                    ScrollBarThickness = 0,
                    ScrollingDirection = Enum.ScrollingDirection.X,
                    ClipsDescendants = false,
                    Parent = ModalFrame,
                })
                
                TabsState.Container = Interface.New("Frame", {
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.X,
                    Size = UDim2.fromScale(0, 1),
                    Parent = TabsState.Scroller,
        
                    ["UIListLayout"] = {
                        Padding = UDim.new(0, 6),
                        FillDirection = Enum.FillDirection.Horizontal,
                        VerticalAlignment = Enum.VerticalAlignment.Top,
                    },
        
                    ["UIPadding"] = {
                        PaddingRight = UDim.new(0, 20),
                        PaddingTop = UDim.new(0, 2),
                        PaddingLeft = UDim.new(0, 2),
                    },
                })
            end
            
            local TabUI, TabContent = wax.shared.CreateTabContent()
            
            if TabsState.FooterContainer then
                TabUI.Size = UDim2.new(1, -12, 1, -118)
            else
                TabUI.Size = UDim2.new(1, -12, 1, -79)
            end
            
            TabUI.Parent = ModalFrame
            TabUI.Visible = false
            
            local TextWrapper = Interface.New("Frame", {
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.fromOffset(0, 24),
                ZIndex = 2,
    
                ["UIListLayout"] = {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 5),
                },
    
                ["UIPadding"] = {
                    PaddingRight = UDim.new(0, 8),
                    PaddingLeft = UDim.new(0, 8),
                },
    
                ["TextLabel"] = {
                    Text = TabName,
                    TextSize = 15,
                    Size = UDim2.fromScale(0, 1),
                    AutomaticSize = Enum.AutomaticSize.X,
                    LayoutOrder = 2,
                    ZIndex = 2,
                },
            })
    
            Interface.NewIcon(Icon, {
                Position = UDim2.fromOffset(8, 5),
                Size = UDim2.fromOffset(16, 16),
                LayoutOrder = 1,
                ZIndex = 2,
                Parent = TextWrapper,
            })
            
            local ButtonColor = TabsState.CurrentTab == TabName and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(0, 0, 0)
            local TabButton = Interface.New("TextButton", {
                BackgroundColor3 = ButtonColor,
                Size = UDim2.fromScale(0, 1),
                AutomaticSize = Enum.AutomaticSize.X,
                Text = "",
                Parent = TabsState.Container,
    
                ["UICorner"] = {
                    CornerRadius = UDim.new(0, 8),
                },
    
                ["UIStroke"] = {
                    Color = Color3.fromRGB(25, 25, 25),
                    Thickness = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                },
    
                ["Frame"] = {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.fromScale(0, 1),
                    Size = UDim2.fromScale(1, 0.6),
                    BackgroundColor3 = ButtonColor,
                    BorderSizePixel = 0,
                },
                
                TextWrapper
            })
            
            TabsState.Buttons[TabName] = TabButton
            TabsState.Contents[TabName] = TabUI
            
            TabButton.MouseButton1Click:Connect(function()
                ModalInterface:SelectTab(TabName)
            end)
            
            if not TabsState.CurrentTab then
                ModalInterface:SelectTab(TabName)
            end
            
            return TabContent
        end

        function ModalInterface:AddFooterButton(Icon: string, Title: string, Options: {})
            if not TabsState.FooterContainer then
                TabsState.FooterContainer = Interface.New("Frame", {
                    AnchorPoint = Vector2.new(0, 1),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 6, 1, -7),
                    Size = UDim2.new(1, -12, 0, 32),
                    Parent = ModalFrame,
                
                    ["UIListLayout"] = {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        Padding = UDim.new(0, 6),
                    },
                })
                
                ContentFrame.Size = UDim2.new(1, 0, 1, -69) 
                for _, Content in pairs(TabsState.Contents) do
                    Content.Size = UDim2.new(1, -12, 1, -118)
                end
            end

            local Button = wax.shared.CreateInfoDropdownButton(Icon, Title, Options)
            Button.Parent = TabsState.FooterContainer
            
            return Button
        end

        return ModalInterface
    end

    --[[
        Creates a plugin settings tab, (visible after clicking a plugin in the plugins list)

        @return: The plugin settings tab.
    ]]
    function Cobalt.UI:CreatePluginSettings()
        if not CurrentPluginSettings then
            CurrentPluginSettings = wax.shared.PluginSettings:CreateSection(CurrentPluginData.Name, `PluginSettings-{CurrentPluginData.Name}-`)
        end

        return CurrentPluginSettings
    end
    
    --[[
        Creates a remote info tab, (visible after clicking a remote)

        @param TabName: The name of the tab.
        @param Icon: The icon of the tab.
        @return: The tab content and tab UI.
    ]]
    function Cobalt.UI.RemoteInfo:CreateTab(TabName: string, Icon: string)
        local TabUI, TabContent = wax.shared.CreateTabContent()
        wax.shared.CreateRemoteInfoTab(Icon, TabName, TabUI)
        
        return TabContent, TabUI
    end

    --[[
        Disables the default footer buttons for a specific Remote Info tab.

        @param TabName: The name of the tab to disable default buttons for.
    ]]
    function Cobalt.UI.RemoteInfo:DisableDefaultButtons(TabName: string)
        local TabRegistry = Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName]
        		if not TabRegistry then
			Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName] = { DisableDefaults = true, Buttons = {} }
		else
			TabRegistry.DisableDefaults = true
		end
		
		if Cobalt.UI.RemoteInfo.UpdateFooterButtons then
			Cobalt.UI.RemoteInfo.UpdateFooterButtons()
		end
	end

    --[[
		Empty function that gets hooked by Window.luau.
		When called, it forces the RemoteInfo footer buttons to update.
	]]
	function Cobalt.UI.RemoteInfo.UpdateFooterButtons()
		-- Hooked by Window.luau
	end

	--[[
		Adds a custom footer button to a specific Remote Info tab.

		@param TabName: The name of the tab to add the button to.
		@param Icon: The icon of the button (Lucide icon name).
		@param Title: The title text of the button.
		@param Options: The dropdown menu options for the button.
		@return: A function to remove the button.
	]]
	function Cobalt.UI.RemoteInfo:AddFooterButton(TabName: string, Icon: string, Title: string, Options: {})
		local TabRegistry = Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName]
		if not TabRegistry then
			TabRegistry = { DisableDefaults = false, Buttons = {} }
			Manager.Registry.UIHooks.RemoteInfo.Tabs[TabName] = TabRegistry
		end

		local ButtonDefinition: { [any]: any } = {
			Icon = Icon,
			Title = Title,
			Options = Options
		}

		table.insert(TabRegistry.Buttons, ButtonDefinition)
		
		if Cobalt.UI.RemoteInfo.UpdateFooterButtons then
			Cobalt.UI.RemoteInfo.UpdateFooterButtons()
		end

		return function()
			local Index = table.find(TabRegistry.Buttons, ButtonDefinition)
			if Index then
				table.remove(TabRegistry.Buttons, Index)
				
				if ButtonDefinition.Instance then
					ButtonDefinition.Instance.Parent = nil
				end
				
				if Cobalt.UI.RemoteInfo.UpdateFooterButtons then
					Cobalt.UI.RemoteInfo.UpdateFooterButtons()
				end
			end
		end
	end
    
    --[[
        Binds a function to be called when a remote is opened in the remote info tab.

        @param Callback: The function to be called.
        @return: A function to remove the binded callback.
    ]]
    function Cobalt.UI.RemoteInfo:BindToModalOpen(Callback: (CallInfo: CodeGen.CallInfo) -> (...any))
        table.insert(Manager.Registry.UIHooks.RemoteInfo.Open, Callback)

        return function()
            local Index = table.find(Manager.Registry.UIHooks.RemoteInfo.Open, Callback)
            if Index then
                table.remove(Manager.Registry.UIHooks.RemoteInfo.Open, Index)
            end
        end
    end

    --[[
        Adds an interceptor to conditionally prevent a remote info modal from opening.
        The callback should return `false` to block the modal from opening, or `true`/`nil` to allow it.

        @param Callback: The function to be called before opening the modal.
        @return: A function to remove the added interceptor.
    ]]
    function Cobalt.UI.RemoteInfo:InterceptModalOpen(Callback: (CallInfo: CodeGen.CallInfo) -> (boolean?))
        table.insert(Manager.Registry.UIHooks.RemoteInfo.Intercept, Callback)

        return function()
            local Index = table.find(Manager.Registry.UIHooks.RemoteInfo.Intercept, Callback)
            if Index then
                table.remove(Manager.Registry.UIHooks.RemoteInfo.Intercept, Index)
            end
        end
    end

    --[[
        Adds a custom context menu option to specific elements of the UI.
        
        @param MenuType: "RemoteList" | "CallList"
        @param Icon: The Lucide icon string
        @param Title: The string title
        @param Callback: The function to run when clicked. Passes either Log or CallInfo depending on MenuType.
        @return: A function that removes the registered option when called.
    ]]
    function Cobalt.UI.ContextMenu:AddOption(MenuType: "RemoteList" | "CallList", Icon: string, Title: string, Callback: (InteractionData: any) -> ())
        if not Manager.Registry.UIHooks.ContextMenus[MenuType] then
            warn(`[Cobalt] Invalid MenuType provided to ContextMenu:AddOption. Expected RemoteList | CallList, got {tostring(MenuType)}`)
            return function() end
        end

        local OptionDefinition = {
            Icon = Icon,
            Text = Title,
            Callback = Callback
        }

        table.insert(Manager.Registry.UIHooks.ContextMenus[MenuType], OptionDefinition)

        return function()
            local Index = table.find(Manager.Registry.UIHooks.ContextMenus[MenuType], OptionDefinition)
            if Index then
                table.remove(Manager.Registry.UIHooks.ContextMenus[MenuType], Index)
            end
        end
    end

    --[[
        Uses cobalt's built-in syntax highlighter to colorize Luau code in RichText.

        @param code: The Luau code to colorize.
        @return: The colorized Luau code.
    ]]
    function Cobalt.UI.ColorizeLuauCode(code: string)
        return Highlighter.Run(code)
    end

    -- Merge Interface functions
    for Idx, Value in Interface do
        Cobalt.UI[Idx] = Value
    end

    -- Spy Functions
    type InterceptorFunction = (Info: CodeGen.CallInfo, Instance: Instance, Type: "Incoming" | "Outgoing") -> (...any)
    --[[
        Intercepts executed calls.

        @param Type: The type of calls to intercept.
        @param Data: The data to intercept.
        @return: A function to remove the interceptor.
    ]]
    function Cobalt.Spy:InterceptExecutedCalls(Type: "Incoming" | "Outgoing" | "All", Data: {
        Callback: InterceptorFunction,
        Instance: Instance | nil,
    } | InterceptorFunction)
        Manager.HasInterceptors = true

        local Options = typeof(Data) == "table" and setmetatable(Data, { __mode = "v" }) or setmetatable({
            Callback = Data,
            Instance = nil,
        }, { __mode = "v" })

        local IsInstanceSpecific = Options.Instance ~= nil
        
        if IsInstanceSpecific then
            -- Ensure Instance specific
            local InstanceInterceptors = Manager.Registry.Interceptors.Instance[Options.Instance]
            if not InstanceInterceptors then
                Manager.Registry.Interceptors.Instance[Options.Instance] = {}
                InstanceInterceptors = Manager.Registry.Interceptors.Instance[Options.Instance]
            end

            -- Ensure Direction specific (Incoming, Outgoing, All)
            if not InstanceInterceptors[Type] then
                InstanceInterceptors[Type] = {}
            end

            table.insert(InstanceInterceptors[Type], Options.Callback)
        else
            -- Ensure Global Direction specific (Incoming, Outgoing, All)
            local GlobalInterceptors = Manager.Registry.Interceptors.Global[Type]
            if not GlobalInterceptors then
                Manager.Registry.Interceptors.Global[Type] = {}
                GlobalInterceptors = Manager.Registry.Interceptors.Global[Type]
            end

            table.insert(GlobalInterceptors, Options.Callback)
        end

        -- Cleanup function
        return function()
            if IsInstanceSpecific then
                if not Options.Instance then
                    return
                end

                local InstanceInterceptors = Manager.Registry.Interceptors.Instance[Options.Instance]
                if not InstanceInterceptors then
                    return
                end

                local Interceptors = InstanceInterceptors[Type]
                if not Interceptors then
                    return
                end

                local Index = table.find(Interceptors, Options.Callback)
                if Index then
                    table.remove(Interceptors, Index)
                end
            else
                local GlobalInterceptors = Manager.Registry.Interceptors.Global[Type]
                if not GlobalInterceptors then
                    return
                end

                local Index = table.find(GlobalInterceptors, Options.Callback)
                if Index then
                    table.remove(GlobalInterceptors, Index)
                end
            end
        end
    end

    --[[
        Clears the tracked logs, optionally filtering by instance or type.

        @param Instance: The optional instance to clear logs for.
        @param Type: The optional type to clear logs for (Incoming, Outgoing, All).
    ]]
    function Cobalt.Spy:ClearLogs(Instance: Instance?, Type: string?)
        wax.shared.ClearLogs(Instance, if Type == "All" then nil else Type)
    end

    --[[
        Appends mock execution data or external logs into the tracking system.

        @param Instance: The remote instance to append the log to.
        @param Type: The type of log (Incoming, Outgoing).
        @param Data: The execution data table payload.
    ]]
    function Cobalt.Spy:AppendLog(Instance: Instance, Type: "Incoming" | "Outgoing", Data: {})
        local Method = wax.shared.FunctionForClasses[Type][Instance.ClassName]
        local Log = wax.shared.Logs[Type][Instance] or wax.shared.NewLog(Instance, Type, Method, nil)
        
        Log:Call(Data)
        wax.shared.Communicator:Fire(Instance, Type, #Log.Calls)
    end

    --[[
        Gets the log for a specific instance and type.

        @param instance: The instance to get the log for.
        @param type: The type of log to get.
        @return: The log for the specific instance and type.
    ]]
    function Cobalt:GetLog(instance: Instance, type: "Incoming" | "Outgoing")
        return wax.shared.Logs[type][instance]
    end

    --[[
        Intercepts code generation.

        @param Type: The type of code generation to intercept.
        @param Callback: The callback to execute when code generation is intercepted. If callback returns a string, it will be used as the generated code instead of the default generated code. If callback returns nil, the default generated code will be used.
        @return: A function to remove the interceptor.
    ]]
    function Cobalt.CodeGen:InterceptGeneration(Type: "Call" | "Hook" | "InstancePath", Callback: (Info: any, ...any) -> (...any))
        Manager.HasCodeGenInterceptors = true
        
        local Interceptors = Manager.Registry.UIHooks.CodeGen[Type]
        assert(Interceptors, "Invalid Code Generation Type")

        table.insert(Interceptors, Callback)

        return function()
            local Index = table.find(Interceptors, Callback)
            if Index then
                table.remove(Interceptors, Index)
            end
        end
    end

    --[[
        Serializes data to a string.

        @param data: The data to serialize.
        @param options: The options to use for serialization.
        @return: The serialized data.
    ]]
    function Cobalt.CodeGen.Serialize(data, options)
        if typeof(data) == "table" then
            return wax.shared.LuaEncode(data, options)
        elseif typeof(data) == "Instance" then
            return CodeGen.GetFullPath(data, options)
        end

        return UIHelper.QuickSerializeArgument(data)      
    end

    -- Handle Cobalt.PluginData assignment
    setmetatable(Cobalt, {
        __newindex = function(_, Key, Value)
            --[[
            Example:

            ```lua
            Cobalt.PluginData = {
		        Name = "ByteNet",
		        Description = "Adds ByteNet support to Cobalt.",
                Author = "upio",
                Version = "1.0.0",
		        Game = "*" -- Can be place id string or table of place ids
	        }
            ```

            Case insensitive to allow camelCase and PascalCase
            ]]
            if Key:lower() == "plugindata" then
                local PluginData = Validate(Value, TemplatePluginData)
                local IsSupported = true
                
                -- Check if plugin is supported in this game
                if type(PluginData.Game) == "string" then
                    if PluginData.Game ~= "*" and tostring(game.PlaceId) ~= PluginData.Game and tostring(game.GameId) ~= PluginData.Game then
                        IsSupported = false
                    end
                elseif type(PluginData.Game) == "number" then
                    if game.PlaceId ~= PluginData.Game and game.GameId ~= PluginData.Game then
                        IsSupported = false
                    end
                elseif type(PluginData.Game) == "table" then
                    local Match = false
                    for _, id in pairs(PluginData.Game) do
                        if tostring(game.PlaceId) == tostring(id) or tostring(game.GameId) == tostring(id) then
                            Match = true
                            break
                        end
                    end
                    if not Match then IsSupported = false end
                end

                if not IsSupported then
                    PluginErrored(FilePath, "Plugin is not supported in this game.")
                    
                    -- Cancel Plugin Thread
                    if coroutine.status(PluginThread) ~= "dead" then
                        pcall(task.cancel, PluginThread)
                    end
                    return
                end

                -- Register Plugin
                table.insert(Manager.Registry.Plugins, {
                    FilePath = FilePath,
                    PluginData = PluginData,
                    PluginThread = PluginThread,
                })

                CurrentPluginData = PluginData
                return
            end

            return rawset(Cobalt, Key, Value)
        end,
    })
    
    return setmetatable({ Cobalt = Cobalt }, {
        __index = getfenv(PluginCallback)
    })
end

--[[
    Sets up all plugins.
]]
function Manager.SetupPlugins()
	for _, FilePath in PluginFiles:ListFiles() do
        -- Load Plugin
		local Plugin, CompileError = loadstring(
            PluginFiles:ReadFile(FilePath),
            `CobaltPlugin-{PluginFiles:GetFileName(FilePath)}`
        )
		if CompileError then
            PluginErrored(FilePath, CompileError)
			continue
		end

        -- Register Plugin
        local PluginThread = task.spawn(function()
            coroutine.yield()

            local Success, Error = pcall(Plugin)
            if not Success then
                PluginErrored(FilePath, Error)
            end
        end)

        -- Set Plugin Environement
        setfenv(Plugin, CreatePluginEnvironement(FilePath, Plugin, PluginThread))

        -- Start Plugin
        coroutine.resume(PluginThread)
	end

    Manager.Initialized = true
end

return Manager