-- GameKit UIBinder (StarterPlayerScripts.GameKit.UIBinder)
-- Makes UI built with the build_ui tool come alive with NO extra code.
-- Put these attributes on any GuiObject inside PlayerGui:
--
--   GK_Bind   = "stat:Coins"      text follows a player stat (any PlayerData stat)
--               "state:Status"    text follows ReplicatedStorage.GameKit's "Status" attribute
--               "state:Timer"     (numbers are formatted, see GK_Format)
--               "player:DisplayName"
--   GK_Format = "Coins: {value}"  {value}=1.2K style, {raw}=exact, {time}=m:ss
--   GK_Bar    = "stat:Power/stat:Capacity"   a Frame whose width shows the ratio
--   GK_ShowIf = "state:RoundActive" or "!state:RoundActive" or "stat:Stage>1"
--   GK_Action = "toggle:ShopWindow" | "open:X" | "close:X" | "remote:EventName" | "remote:EventName:arg"
--
-- Buttons with GK_Action also get a small press animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))
local Net = require(kit:WaitForChild("Net"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

type Source = { kind: string, name: string }

local function parseSource(text: string): Source?
	local kind, name = string.match(text, "^%s*(%a+)%s*[:%.]%s*([%w_]+)%s*$")
	if not kind then
		return nil
	end
	kind = string.lower(kind)
	if kind == "leaderstats" then
		kind = "stat"
	end
	return { kind = kind, name = name }
end

local function readSource(source: Source): any
	if source.kind == "stat" then
		local value = player:GetAttribute(source.name)
		if value == nil then
			local stats = player:FindFirstChild("leaderstats")
			local holder = stats and stats:FindFirstChild(source.name)
			if holder and holder:IsA("ValueBase") then
				value = (holder :: any).Value
			end
		end
		return value
	elseif source.kind == "state" then
		return kit:GetAttribute(source.name)
	elseif source.kind == "player" then
		return (player :: any)[source.name]
	end
	return nil
end

local function watchSource(source: Source, callback: () -> ()): { RBXScriptConnection }
	local connections = {}
	if source.kind == "stat" then
		table.insert(connections, player:GetAttributeChangedSignal(source.name):Connect(callback))
		-- Also follow hand-made leaderstats values (games that don't use PlayerData).
		task.spawn(function()
			local stats = player:WaitForChild("leaderstats", 15)
			local holder = stats and stats:WaitForChild(source.name, 15)
			if holder and holder:IsA("ValueBase") then
				table.insert(connections, (holder :: any).Changed:Connect(callback))
				callback()
			end
		end)
	elseif source.kind == "state" then
		table.insert(connections, kit:GetAttributeChangedSignal(source.name):Connect(callback))
	end
	return connections
end

local function formatValue(format: string, value: any): string
	local raw = if value == nil then "" else tostring(value)
	local pretty = if type(value) == "number" then Util.formatNumber(value) else raw
	local time = if type(value) == "number" then Util.formatTime(value) else raw
	local text = string.gsub(format, "{value}", function()
		return pretty
	end)
	text = string.gsub(text, "{raw}", function()
		return raw
	end)
	text = string.gsub(text, "{time}", function()
		return time
	end)
	return text
end

local function bindText(gui: GuiObject)
	local source = parseSource(tostring(gui:GetAttribute("GK_Bind") or ""))
	if not source or not (gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")) then
		return
	end
	local label = gui :: any
	local function refresh()
		local format = gui:GetAttribute("GK_Format")
		local template: string = if type(format) == "string" and format ~= "" then format else "{value}"
		label.Text = formatValue(template, readSource(source))
	end
	watchSource(source, refresh)
	gui:GetAttributeChangedSignal("GK_Format"):Connect(refresh)
	refresh()
end

local function bindBar(gui: GuiObject)
	local spec = gui:GetAttribute("GK_Bar")
	if type(spec) ~= "string" then
		return
	end
	local left, right = string.match(spec, "^(.-)/(.-)$")
	local current = parseSource(left or spec)
	local maximum = if right then parseSource(right) else nil
	if not current then
		return
	end
	local function refresh()
		local value = tonumber(readSource(current)) or 0
		local max = if maximum then tonumber(readSource(maximum)) or 1 else 1
		local ratio = math.clamp(if max > 0 then value / max else 0, 0, 1)
		TweenService:Create(gui, TweenInfo.new(0.2), {
			Size = UDim2.new(ratio, 0, gui.Size.Y.Scale, gui.Size.Y.Offset),
		}):Play()
	end
	watchSource(current, refresh)
	if maximum then
		watchSource(maximum, refresh)
	end
	refresh()
end

local function bindShowIf(gui: GuiObject)
	local spec = gui:GetAttribute("GK_ShowIf")
	if type(spec) ~= "string" then
		return
	end
	local negate = string.sub(spec, 1, 1) == "!"
	local body = if negate then string.sub(spec, 2) else spec
	local left, op, right = string.match(body, "^(.-)%s*([<>=~]=?)%s*(.-)$")
	local source = parseSource(left or body)
	if not source then
		return
	end
	local function refresh()
		local value = readSource(source)
		local visible
		if op and right and right ~= "" then
			local a, b = tonumber(value) or 0, tonumber(right) or 0
			if op == ">" then
				visible = a > b
			elseif op == ">=" then
				visible = a >= b
			elseif op == "<" then
				visible = a < b
			elseif op == "<=" then
				visible = a <= b
			elseif op == "~=" then
				visible = a ~= b
			else
				visible = a == b
			end
		else
			visible = value ~= nil and value ~= false and value ~= 0 and value ~= ""
		end
		if negate then
			visible = not visible
		end
		gui.Visible = visible
	end
	watchSource(source, refresh)
	refresh()
end

local function findGui(name: string): GuiObject?
	local found = playerGui:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	if found and found:IsA("ScreenGui") then
		return found:FindFirstChildWhichIsA("GuiObject")
	end
	return nil
end

local function pressAnimation(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = button
	end
	local uiScale = scale :: UIScale
	button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.05), { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
end

local function bindAction(gui: GuiObject)
	local spec = gui:GetAttribute("GK_Action")
	if type(spec) ~= "string" or not gui:IsA("GuiButton") then
		return
	end
	local button = gui :: GuiButton
	pressAnimation(button)
	button.Activated:Connect(function()
		local verb, target, arg = string.match(spec, "^(%a+):?([^:]*):?(.*)$")
		verb = string.lower(verb or "")
		if verb == "toggle" or verb == "open" or verb == "close" then
			local window = findGui(target)
			if not window then
				warn(`[GameKit] GK_Action '{spec}': no GUI named '{target}'`)
				return
			end
			if verb == "toggle" then
				window.Visible = not window.Visible
			else
				window.Visible = verb == "open"
			end
		elseif verb == "remote" and target ~= "" then
			Net.send(target, if arg ~= "" then arg else nil)
		end
	end)
end

local bound: { [Instance]: boolean } = {}

local function bind(instance: Instance)
	if bound[instance] or not instance:IsA("GuiObject") then
		return
	end
	local gui = instance :: GuiObject
	if
		gui:GetAttribute("GK_Bind") == nil
		and gui:GetAttribute("GK_Bar") == nil
		and gui:GetAttribute("GK_ShowIf") == nil
		and gui:GetAttribute("GK_Action") == nil
	then
		return
	end
	bound[instance] = true
	bindText(gui)
	bindBar(gui)
	bindShowIf(gui)
	bindAction(gui)
	instance.Destroying:Connect(function()
		bound[instance] = nil
	end)
end

for _, descendant in playerGui:GetDescendants() do
	task.spawn(bind, descendant)
end
playerGui.DescendantAdded:Connect(function(descendant)
	-- Let the whole ScreenGui finish cloning before reading attributes.
	task.defer(bind, descendant)
end)
