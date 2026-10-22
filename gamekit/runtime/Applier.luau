--!nonstrict
-- GameKit installer runtime. Executed inside the Studio plugin (edit mode) through
-- execute_luau. The MCP server replaces the PAYLOAD line below with a JSON document
-- describing instances to create, then this chunk applies it as ONE undoable step.
--
-- Encoded values (anything JSON cannot express):
--   {"$v3":[x,y,z]} {"$v2":[x,y]} {"$c3":[r,g,b]} {"$hex":"#RRGGBB"}
--   {"$cf":[x,y,z,rx,ry,rz]} (degrees) {"$ud2":[xs,xo,ys,yo]} {"$ud":[s,o]}
--   {"$nr":[min,max]} {"$ns":n|[[t,v],...]} {"$cs":[r,g,b]|[[t,[r,g,b]],...]}
--   {"$enum":"Material.Neon"} {"$brick":"Bright red"} {"$ref":"Workspace/GameKit/Part"}
-- Plain strings assigned to Enum, Color3 ("#hex") and BrickColor properties are
-- converted automatically.

local PAYLOAD = "{}" -- @payload

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local spec = HttpService:JSONDecode(PAYLOAD)

local report = {
	ok = true,
	created = 0,
	replaced = 0,
	kept = 0,
	merged = 0,
	deleted = 0,
	warnings = {},
	roots = {},
}

local function warnOnce(message: string)
	if #report.warnings < 60 then
		table.insert(report.warnings, message)
	end
end

local function splitPath(path): { string }
	if type(path) == "table" then
		return path
	end
	local segments = {}
	local cleaned = string.gsub(path, "^game[%./]", "")
	for segment in string.gmatch(cleaned, "[^%./]+") do
		table.insert(segments, segment)
	end
	return segments
end

local function getRoot(name: string): Instance?
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	if ok and service then
		return service
	end
	return game:FindFirstChild(name)
end

local function resolve(path, create: boolean): Instance?
	local segments = splitPath(path)
	if #segments == 0 then
		return game
	end
	local current = getRoot(segments[1])
	if not current then
		return nil
	end
	for i = 2, #segments do
		local child = current:FindFirstChild(segments[i])
		if not child then
			if not create then
				return nil
			end
			child = Instance.new("Folder")
			child.Name = segments[i]
			child.Parent = current
			report.created += 1
		end
		current = child
	end
	return current
end

local pendingRefs = {}

local function decode(value)
	if type(value) ~= "table" then
		return value
	end
	if value["$v3"] then
		local v = value["$v3"]
		return Vector3.new(v[1], v[2], v[3])
	elseif value["$v2"] then
		local v = value["$v2"]
		return Vector2.new(v[1], v[2])
	elseif value["$c3"] then
		local v = value["$c3"]
		return Color3.fromRGB(v[1], v[2], v[3])
	elseif value["$hex"] then
		return Color3.fromHex(value["$hex"])
	elseif value["$cf"] then
		local v = value["$cf"]
		return CFrame.new(v[1], v[2], v[3])
			* CFrame.Angles(math.rad(v[4] or 0), math.rad(v[5] or 0), math.rad(v[6] or 0))
	elseif value["$ud2"] then
		local v = value["$ud2"]
		return UDim2.new(v[1], v[2], v[3], v[4])
	elseif value["$ud"] then
		local v = value["$ud"]
		return UDim.new(v[1], v[2])
	elseif value["$nr"] then
		local v = value["$nr"]
		return NumberRange.new(v[1], v[2] or v[1])
	elseif value["$ns"] then
		local v = value["$ns"]
		if type(v) == "number" then
			return NumberSequence.new(v)
		end
		local keys = {}
		for _, k in ipairs(v) do
			table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
		end
		return NumberSequence.new(keys)
	elseif value["$cs"] then
		local v = value["$cs"]
		if type(v[1]) == "number" then
			return ColorSequence.new(Color3.fromRGB(v[1], v[2], v[3]))
		end
		local keys = {}
		for _, k in ipairs(v) do
			table.insert(keys, ColorSequenceKeypoint.new(k[1], Color3.fromRGB(k[2][1], k[2][2], k[2][3])))
		end
		return ColorSequence.new(keys)
	elseif value["$enum"] then
		local enumName, itemName = string.match(value["$enum"], "^Enum%.([%w_]+)%.([%w_]+)$")
		if not enumName then
			enumName, itemName = string.match(value["$enum"], "^([%w_]+)%.([%w_]+)$")
		end
		return (Enum :: any)[enumName][itemName]
	elseif value["$brick"] then
		return BrickColor.new(value["$brick"] :: any)
	end
	return nil
end

-- Enum type of common properties, used when the current value cannot be read.
local ENUM_PROPS = {
	Font = "Font",
	Material = "Material",
	Shape = "PartType",
	TopSurface = "SurfaceType",
	BottomSurface = "SurfaceType",
	Face = "NormalId",
	SizingMode = "SurfaceGuiSizingMode",
	ZIndexBehavior = "ZIndexBehavior",
	FillDirection = "FillDirection",
	HorizontalAlignment = "HorizontalAlignment",
	VerticalAlignment = "VerticalAlignment",
	SortOrder = "SortOrder",
	ApplyStrokeMode = "ApplyStrokeMode",
	ScaleType = "ScaleType",
	AutomaticCanvasSize = "AutomaticSize",
	AutomaticSize = "AutomaticSize",
	TextXAlignment = "TextXAlignment",
	TextYAlignment = "TextYAlignment",
}

local function convertFor(instance: Instance, property: string, value)
	if type(value) == "table" then
		return decode(value)
	end
	if type(value) == "string" then
		local ok, current = pcall(function()
			return (instance :: any)[property]
		end)
		local kind = if ok then typeof(current) else "nil"
		if kind == "EnumItem" then
			return (current.EnumType :: any)[value]
		elseif kind == "Color3" and string.sub(value, 1, 1) == "#" then
			return Color3.fromHex(value)
		elseif kind == "BrickColor" then
			return BrickColor.new(value :: any)
		elseif ENUM_PROPS[property] then
			local found, item = pcall(function()
				return (Enum :: any)[ENUM_PROPS[property]][value]
			end)
			if found and item then
				return item
			end
		end
	end
	return value
end

local function applyProps(instance: Instance, node)
	if node.props then
		for property, raw in pairs(node.props) do
			if type(raw) == "table" and raw["$ref"] then
				table.insert(pendingRefs, { instance = instance, property = property, path = raw["$ref"] })
			else
				local ok, err = pcall(function()
					(instance :: any)[property] = convertFor(instance, property, raw)
				end)
				if not ok then
					warnOnce(instance:GetFullName() .. "." .. property .. ": " .. tostring(err))
				end
			end
		end
	end
	if node.attrs then
		for name, raw in pairs(node.attrs) do
			local ok, err = pcall(function()
				instance:SetAttribute(name, decode(raw) or raw)
			end)
			if not ok then
				warnOnce(instance:GetFullName() .. " attribute " .. name .. ": " .. tostring(err))
			end
		end
	end
	if node.tags then
		for _, tag in ipairs(node.tags) do
			CollectionService:AddTag(instance, tag)
		end
	end
	if node.source and instance:IsA("LuaSourceContainer") then
		local ok, err = pcall(function()
			(instance :: any).Source = node.source
		end)
		if not ok then
			warnOnce(instance:GetFullName() .. ".Source: " .. tostring(err))
		end
	end
end

local build

-- Creates `node` under `parent`. `mode` decides what happens when a child with the
-- same name already exists: replace it, keep it untouched, or merge into it.
local function place(node, parent: Instance, mode: string): Instance?
	local existing = parent:FindFirstChild(node.name)
	if existing and existing.ClassName ~= node.className then
		if mode == "keep" then
			report.kept += 1
			return existing
		end
		existing:Destroy()
		existing = nil
		report.replaced += 1
	end
	if existing then
		if mode == "keep" then
			report.kept += 1
			return existing
		elseif mode == "merge" then
			applyProps(existing, node)
			report.merged += 1
			if node.children then
				for _, child in ipairs(node.children) do
					place(child, existing, mode)
				end
			end
			return existing
		end
		existing:Destroy()
		report.replaced += 1
	end
	return build(node, parent)
end

build = function(node, parent: Instance): Instance?
	local ok, instance = pcall(Instance.new, node.className)
	if not ok then
		warnOnce("Cannot create " .. tostring(node.className) .. " '" .. tostring(node.name) .. "': " .. tostring(instance))
		return nil
	end
	instance.Name = node.name
	applyProps(instance, node)
	if node.children then
		for _, child in ipairs(node.children) do
			build(child, instance)
		end
	end
	instance.Parent = parent
	report.created += 1
	return instance
end

local function run()
	if spec.deletes then
		for _, path in ipairs(spec.deletes) do
			local target = resolve(path, false)
			if target and target ~= game and target.Parent ~= game then
				target:Destroy()
				report.deleted += 1
			end
		end
	end
	for _, item in ipairs(spec.items or {}) do
		local parent = resolve(item.parent, true)
		if not parent then
			warnOnce("Parent not found: " .. HttpService:JSONEncode(item.parent))
		else
			local instance = place(item.node, parent, item.mode or "replace")
			if instance then
				table.insert(report.roots, instance:GetFullName())
			end
		end
	end
	for _, ref in ipairs(pendingRefs) do
		local target = resolve(ref.path, false)
		if target then
			local ok, err = pcall(function()
				(ref.instance :: any)[ref.property] = target
			end)
			if not ok then
				warnOnce("Reference " .. ref.property .. ": " .. tostring(err))
			end
		else
			warnOnce("Reference target not found: " .. tostring(ref.path))
		end
	end
end

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording(spec.label or "GameKit")
end)
if not recording then
	pcall(function()
		ChangeHistoryService:SetWaypoint("Before " .. (spec.label or "GameKit"))
	end)
end

local ok, err = pcall(run)
report.ok = ok
if not ok then
	report.error = tostring(err)
end

if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
else
	pcall(function()
		ChangeHistoryService:SetWaypoint(spec.label or "GameKit")
	end)
end

return HttpService:JSONEncode(report)
