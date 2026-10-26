-- GameKit Hazards (ServerScriptService.GameKit.Hazards)
--   Tag "KillPart"   : touching it kills (lava, spikes, void).
--   Tag "DamagePart" : removes the number attribute "Damage" (default 20) per touch.
--   Tag "HealPart"   : restores the number attribute "Heal" (default 25) per touch.
-- Parts NAMED like Config.Hazards.KillPartNames (e.g. "Lava", "KillBrick") also kill,
-- so a part renamed "Lava" just works.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local kit = ReplicatedStorage:WaitForChild("GameKit")
local Util = require(kit:WaitForChild("Util"))

local config = Util.config("Hazards", {
	KillPartNames = { "KillPart", "KillBrick", "Lava" },
	DefaultDamage = 20,
	DefaultHeal = 25,
	TouchCooldown = 0.5,
})

local cooldown = Util.cooldown(config.TouchCooldown)
local connected: { [Instance]: boolean } = {}

local function hook(part: BasePart, kind: string)
	if connected[part] then
		return
	end
	connected[part] = true
	part.Touched:Connect(function(hit)
		local _, _, humanoid = Util.playerFromHit(hit)
		if not humanoid then
			return
		end
		if kind == "kill" then
			humanoid.Health = 0
		elseif cooldown(humanoid) then
			if kind == "damage" then
				local damage = part:GetAttribute("Damage")
				humanoid:TakeDamage(if type(damage) == "number" then damage else config.DefaultDamage)
			else
				local heal = part:GetAttribute("Heal")
				humanoid.Health =
					math.min(humanoid.MaxHealth, humanoid.Health + (if type(heal) == "number" then heal else config.DefaultHeal))
			end
		end
	end)
	part.Destroying:Connect(function()
		connected[part] = nil
	end)
end

local function hookTag(tag: string, kind: string)
	Util.onTag(tag, function(instance)
		if instance:IsA("BasePart") then
			hook(instance, kind)
		end
	end)
end

hookTag("KillPart", "kill")
hookTag("DamagePart", "damage")
hookTag("HealPart", "heal")

local killNames: { [string]: boolean } = {}
for _, name in ipairs(config.KillPartNames) do
	killNames[name] = true
end

local function checkName(instance: Instance)
	if instance:IsA("BasePart") and killNames[instance.Name] and not CollectionService:HasTag(instance, "KillPart") then
		hook(instance, "kill")
	end
end

for _, descendant in workspace:GetDescendants() do
	checkName(descendant)
end
workspace.DescendantAdded:Connect(checkName)
