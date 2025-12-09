--[[
Copyright (c) 2025 [Marco4413](https://github.com/Marco4413/CP77-HideGripAndInjection)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local BetterUI = require "BetterUI"
local Enum = require "Enum"

---@enum Group
local Group = Enum.New{
    None          = 1,
    All           = 2,
    WeaponGrip    = 3,
    InjectionMark = 4,
}

---@enum Condition
local Condition = Enum.New{
    Always      = 1,
    IfActive    = 2,
    IfNotActive = 3,
}

---@enum ItemKind
local ItemKind = Enum.New{
    Clothing = 1,
    Weapon   = 2,
}

-- Search for ' Rule' when modifying the definition

---@class Rule
---@field enabled boolean
---@field itemKind ItemKind
---@field itemName string
---@field condition Condition
---@field group Group
---@field groupEnabled boolean
---@field stopsPropagation boolean

local Mod = {
    Enum = Enum,
    Group = Group,
    Condition = Condition,
    ItemKind  = ItemKind,

    showUI = false,
    autoApplyRules = false,
    _configInitialized = false,
    _components = {},
    ---@type Rule[]
    _rules = {},

    _inventoryPuppet = nil,
    _photoPuppet = nil,
}

function Mod.Log(...)
    print(table.concat{"[ ", os.date("%x %X"), " ][ HideGripAndInjection ]: ", ...})
end

function Mod:ResetConfig()
    self.autoApplyRules = false

    self._components = {
        ["a0_004__weapon_grip_decal_02"]             = { enabled = true, group = Group.WeaponGrip },
        ["a0_004__weapon_grip_device"]               = { enabled = true, group = Group.WeaponGrip },
        ["a0_004__weapon_grip_decal_01"]             = { enabled = true, group = Group.WeaponGrip },
        ["a0_008_wa__fpp_right_q001_injection_mark"] = { enabled = true, group = Group.InjectionMark },
    }

    self._rules = {}
    local alwaysAllRule = self:AddRule(self:CreateDefaultRule())
    alwaysAllRule.enabled          = true
    alwaysAllRule.condition        = Condition.Always
    alwaysAllRule.group            = Group.All
    alwaysAllRule.groupEnabled     = true
    alwaysAllRule.stopsPropagation = false
end

function Mod:GetComponentsForConfig()
    local components = {}
    for compName, compConfig in next, self._components do
        components[compName] = compConfig.enabled
    end
    return components
end

---@param rule Rule
---@return table
function Mod:GetRuleForConfig(rule)
    return {
        enabled          = rule.enabled,
        itemKind         = ItemKind[rule.itemKind],
        itemName         = rule.itemName,
        condition        = Condition[rule.condition],
        group            = Group[rule.group],
        groupEnabled     = rule.groupEnabled,
        stopsPropagation = rule.stopsPropagation,
    }
end

function Mod:GetRulesForConfig()
    local rules = {}
    for i=1, #self._rules do
        table.insert(rules, self:GetRuleForConfig(self._rules[i]))
    end
    return rules
end

---@param ruleConfig table
---@return Rule|nil
function Mod:GetRuleFromConfig(ruleConfig)
    local rule = self:CreateDefaultRule()

    if type(ruleConfig.enabled) == "boolean" then
        rule.enabled = ruleConfig.enabled
    end

    if type(ruleConfig.itemKind) == "string" and ItemKind[ruleConfig.itemKind] then
        rule.itemKind = ItemKind[ruleConfig.itemKind]
    end

    if type(ruleConfig.itemName) == "string" then
        rule.itemName = ruleConfig.itemName
    end

    if type(ruleConfig.condition) == "string" and Condition[ruleConfig.condition] then
        rule.condition = Condition[ruleConfig.condition]
    end

    if type(ruleConfig.group) == "string" and Group[ruleConfig.group] then
        rule.group = Group[ruleConfig.group]
    end

    if type(ruleConfig.groupEnabled) == "boolean" then
        rule.groupEnabled = ruleConfig.groupEnabled
    end

    if type(ruleConfig.stopsPropagation) == "boolean" then
        rule.stopsPropagation = ruleConfig.stopsPropagation
    end

    return rule
end

function Mod:SaveConfig()
    local file = io.open("data/config.json", "w")
    file:write(json.encode({
        autoApplyRules = self.autoApplyRules,
        components = self:GetComponentsForConfig(),
        rules = self:GetRulesForConfig(),
    }))
    io.close(file)
end

function Mod:LoadConfig()
    local ok = pcall(function ()
        local file = io.open("data/config.json", "r")
        local configText = file:read("*a")
        io.close(file)

        local config = json.decode(configText)
        if not config then return; end

        if type(config.autoApplyRules) == "boolean" then
            self.autoApplyRules = config.autoApplyRules
        end

        if type(config.components) == "table" then
            for compName, compConfig in next, self._components do
                compConfig.enabled = config.components[compName] and true or false
            end
        end

        if type(config.rules) == "table" then
            self._rules = {}
            for i=1, #config.rules do
                local rule = self:GetRuleFromConfig(config.rules[i])
                if rule then self:AddRule(rule); end
            end
        end
    end)
    if not ok then self:SaveConfig(); end
end

function Mod:UpdateEntity(entity)
    -- a0_004__weapon_grip_decal_02
    -- a0_004__weapon_grip_device
    -- a0_008_wa__fpp_right_q001_injection_mark
    -- a0_004__weapon_grip_decal_01
    for compName, compConfig in next, self._components do
        local component = entity:FindComponentByName(compName)
        if component then
            component:Toggle(compConfig.enabled and true or false)
        end
    end
end

function Mod:IsGroupEnabled(group)
    if group == Group.None then return false; end
    for _, compConfig in next, self._components do
        if group == Group.All or compConfig.group == group then
            return compConfig.enabled
        end
    end
    return false
end

local _VanillaSlots = {
    "AttachmentSlots.Outfit",
    "AttachmentSlots.Torso",
    "AttachmentSlots.Chest",
}

local _EquipmentExSlots = {
    "AttachmentSlots.Outfit",
    "AttachmentSlots.Torso",
    "AttachmentSlots.Chest",
    "OutfitSlots.TorsoOuter",
    "OutfitSlots.TorsoMiddle",
    "OutfitSlots.TorsoInner",
    "OutfitSlots.TorsoUnder",
    "OutfitSlots.TorsoAux",
    "OutfitSlots.BodyOuter",
    "OutfitSlots.BodyMiddle",
    "OutfitSlots.BodyInner",
    "OutfitSlots.BodyUnder",
}

function Mod:GetClothingSlots()
    return EquipmentEx and _EquipmentExSlots or _VanillaSlots
end

function Mod:GetActiveClothingForPuppet(puppet)
    local activeClothing = {}

    local transactionSystem = Game.GetTransactionSystem()

    local slots = self:GetClothingSlots()
    for _, slot in next, slots do
        local item = transactionSystem:GetItemInSlot(puppet, slot)
        if item then
            local itemAppearance = transactionSystem:GetItemAppearance(puppet, item:GetItemID())
            if itemAppearance then
                local itemAppearanceName = itemAppearance.value:match("[^&]+")
                activeClothing[itemAppearanceName] = true
            end
        end
    end

    return activeClothing
end

function Mod:GetActiveWeaponsForPuppet(puppet)
    if not puppet.GetActiveWeapon then return {}; end

    local activeWeapons = {}
    local weapon = puppet:GetActiveWeapon()
    if weapon then
        local weaponName = weapon:GetWeaponRecord():FriendlyName()
        activeWeapons[weaponName] = true
    end

    return activeWeapons
end

function Mod:CreateRuleEvalContextForPuppet(puppet)
    return {
        activeClothing = self:GetActiveClothingForPuppet(puppet),
        activeWeapons  = self:GetActiveWeaponsForPuppet(puppet),
    }
end

---@return Rule
function Mod:CreateDefaultRule()
    return {
        enabled          = true,
        itemKind         = ItemKind.Clothing,
        itemName         = "",
        condition        = Condition.IfActive,
        group            = Group.WeaponGrip,
        groupEnabled     = false,
        stopsPropagation = false,
    }
end

---@param rule Rule
---@param index integer|nil last index by default
---@return Rule
function Mod:AddRule(rule, index)
    if index then
        table.insert(self._rules, index, rule)
    else
        table.insert(self._rules, rule)
    end
    return rule
end

---@class EvalContext
---@field activeClothing table<string, boolean>
---@field activeWeapons table<string, boolean>

---@param evalContext EvalContext
---@param rule Rule
function Mod:ApplyRule(evalContext, rule)
    if not rule.enabled then return false; end

    local activeItems = {}
    if rule.itemKind == ItemKind.Clothing then
        activeItems = evalContext.activeClothing
    elseif rule.itemKind == ItemKind.Weapon then
        activeItems = evalContext.activeWeapons
    end

    local isItemActive = activeItems[rule.itemName] and true or false
    local isRuleApplied = false
    if rule.condition == Condition.Always then
        isRuleApplied = true
    elseif rule.condition == Condition.IfActive then
        isRuleApplied = isItemActive
    elseif rule.condition == Condition.IfNotActive then
        isRuleApplied = not isItemActive
    end

    if not isRuleApplied then return false; end

    self:ToggleComponentsByGroup(rule.group, rule.groupEnabled, false)
    return true
end

---@param puppet gamePuppet
---@param evalContext EvalContext|nil
---@return boolean
function Mod:ApplyRulesForPuppet(puppet, evalContext)
    if not evalContext then
        evalContext = self:CreateRuleEvalContextForPuppet(puppet)
    end

    -- Rule evaluation
    local rulesApplied = 0
    for i=1, #self._rules do
        local rule = self._rules[i]
        if self:ApplyRule(evalContext, rule) then
            rulesApplied = rulesApplied + 1
            if rule.stopsPropagation then
                break
            end
        end
    end

    return rulesApplied > 0
end

function Mod:ApplyRulesForPlayer()
    local player = Game.GetPlayer()
    if not player then return false; end

    return self:ApplyRulesForPuppet(player)
end

---@param group Group
---@param enabled boolean|nil default: toggle
function Mod:ToggleComponentsByGroup(group, enabled)
    if group == Group.None then return; end
    for _, compConfig in next, self._components do
        if group == Group.All or compConfig.group == group then
            if enabled == nil then enabled = not compConfig.enabled; end
            compConfig.enabled = enabled
        end
    end
end

function Mod:UpdatePlayer()
    local player = Game.GetPlayer()
    if not player then return; end

    self:UpdateEntity(player)
end

function Mod:IsWeaponGripItemID(itemID)
    return itemID.id.value:find("^Items.AdvancedPowerGrip") ~= nil
end

function Mod:UpdatePlayerTPP()
    -- TODO: Check if the mod works on vehicles TPP
    local puppets = {}
    table.insert(puppets, self._inventoryPuppet)
    table.insert(puppets, self._photoPuppet)

    if #puppets <= 0 then return; end

    local transactionSystem = Game.GetTransactionSystem()
    local isWeaponGripEnabled = self:IsGroupEnabled(Group.WeaponGrip)

    for _, puppet in next, puppets do
        -- TODO: Test with multiple hand cyberwares
        local item = transactionSystem:GetItemInSlot(puppet, "AttachmentSlots.RightHand")
        if item then
            local itemID = item:GetItemID()
            local isWeaponGrip = self:IsWeaponGripItemID(itemID)

            if isWeaponGrip then
                if isWeaponGripEnabled then
                    transactionSystem:ResetItemAppearance(puppet, itemID)
                else
                    transactionSystem:ChangeItemAppearanceByName(puppet, itemID, "")
                end
            end
        end
    end
end

local function Event_UpdatePlayerAll()
    Mod:UpdatePlayer()
    Mod:UpdatePlayerTPP()
end

local function Event_AutoApplyRulesForPlayer()
    if Mod.autoApplyRules then
        if Mod:ApplyRulesForPlayer() then
            Event_UpdatePlayerAll()
        end
    end
end

local function Event_OnInit()
    Mod:ResetConfig()
    Mod:LoadConfig()
    Mod._configInitialized = true

    Observe("PlayerPuppet", "OnWeaponEquipEvent", Event_AutoApplyRulesForPlayer)
    Observe("PlayerPuppet", "OnItemEquipped", Event_AutoApplyRulesForPlayer)
    Observe("PlayerPuppet", "OnItemUnequipped", Event_AutoApplyRulesForPlayer)
    Observe("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", Event_AutoApplyRulesForPlayer)
    Observe("gameWardrobeSystem", "SetActiveClothingSetIndex", Event_AutoApplyRulesForPlayer)

    Observe("gameuiInventoryGameController", "OnInitialize", Event_UpdatePlayerAll)
    Observe("gameuiInventoryGameController", "RefreshedEquippedItemData", Event_UpdatePlayerAll)
    Observe("gameuiPhotoModeMenuController", "OnShow", Event_UpdatePlayerAll)

    -- Thanks psiberx! https://github.com/psiberx/cp2077-codeware/blob/main/scripts/Player/PlayerSystem.reds
    -- It's the same as what Codeware does.
    local n_gameuiInventoryPuppetPreviewGameController = CName.new("gameuiInventoryPuppetPreviewGameController");
    ObserveAfter("inkPuppetPreviewGameController", "OnPreviewInitialized", function(this)
        if this:GetClassName() == n_gameuiInventoryPuppetPreviewGameController then
            Mod._inventoryPuppet = this:GetGamePuppet()
        end
    end)

    ObserveAfter("PhotoModePlayerEntityComponent", "SetupInventory", function(this)
        Mod._photoPuppet = this.fakePuppet
    end)
end

local function Event_OnShutdown()
    if Mod._configInitialized then
        Mod:SaveConfig()
    end
end

local function Event_OnDraw()
    if not Mod.showUI then return; end
    if ImGui.Begin("Hide Grip And Injection") then
        if ImGui.CollapsingHeader("General", ImGuiTreeNodeFlags.DefaultOpen) then
            ImGui.PushID("General")
            if BetterUI.FitButtonN(2, "Apply Rules") then
                if Mod:ApplyRulesForPlayer() then
                    Event_UpdatePlayerAll()
                end
            end
            ImGui.SameLine()
            if BetterUI.FitButtonN(1, "Update Player") then
                Event_UpdatePlayerAll()
            end
            Mod.autoApplyRules = ImGui.Checkbox("Auto Apply Rules", Mod.autoApplyRules)
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Group Toggles") then
            ImGui.PushID("GroupToggles")
            for name, value in Enum.SortedIterator(Mod.Group) do
                if value ~= Group.None then
                    local isGroupEnabled = Mod:IsGroupEnabled(value)
                    local newIsGroupEnabled = ImGui.Checkbox(Enum.ToHumanCase(name), isGroupEnabled)
                    if newIsGroupEnabled ~= isGroupEnabled then
                        Mod:ToggleComponentsByGroup(value)
                        Event_UpdatePlayerAll()
                    end
                end
            end
            ImGui.PopID()
        end

        if ImGui.CollapsingHeader("Edit Rules") then
            ImGui.PushID("EditRules")
            ImGui.TextWrapped(table.concat{
                "Rules are evaluated in order. Once a rule which has 'Stops Propagation' enabled",
                " is applied, rule evaluation stops."
            })
            ImGui.Separator()

            local player = Game.GetPlayer()
            local activeClothing = player and Mod:GetActiveClothingForPuppet(player) or {}
            local activeWeapons  = player and Mod:GetActiveWeaponsForPuppet(player)  or {}

            if #Mod._rules <= 0 then
                if BetterUI.ButtonAdd() then
                    Mod:AddRule(Mod:CreateDefaultRule())
                end
                ImGui.Separator()
            end

            for i=1, #Mod._rules do
                ImGui.PushID(tostring(i))

                if BetterUI.ButtonAdd() then
                    Mod:AddRule(Mod:CreateDefaultRule(), i+1)
                end

                ImGui.SameLine()
                if BetterUI.ButtonRemove() then
                    table.remove(Mod._rules, i)
                    i = i - 1
                end

                local rule = Mod._rules[i]
                ImGui.SameLine()
                rule.enabled = ImGui.Checkbox("Rule Enabled", rule.enabled)

                local hasOrderButtons = false
                if i > 1 then
                    hasOrderButtons = true
                    if BetterUI.SquareButton("<") then
                        local tmp = Mod._rules[i-1]
                        Mod._rules[i-1] = Mod._rules[i]
                        Mod._rules[i]   = tmp
                    end
                end
                if i < #Mod._rules then
                    if hasOrderButtons then
                        ImGui.SameLine()
                    end

                    hasOrderButtons = true
                    if BetterUI.SquareButton(">") then
                        local tmp = Mod._rules[i+1]
                        Mod._rules[i+1] = Mod._rules[i]
                        Mod._rules[i]   = tmp
                    end
                end

                ImGui.PushID("Group")
                if rule.group ~= Group.None then
                    rule.groupEnabled = ImGui.Checkbox("Enable", rule.groupEnabled)
                    ImGui.SameLine()
                end
                rule.group = Enum.ImCombo(Group, rule.group)
                ImGui.PopID()

                ImGui.PushID("Condition")
                rule.condition = Enum.ImCombo(Condition, rule.condition)
                if rule.condition ~= Condition.Always then
                    ImGui.SameLine()
                    ImGui.PushID("ItemKind")
                    rule.itemKind = Enum.ImCombo(ItemKind, rule.itemKind)
                    ImGui.PopID()

                    ImGui.SameLine()
                    ImGui.PushID("ItemName")
                    local activeItems = {}
                    if rule.itemKind == ItemKind.Clothing then
                        activeItems = activeClothing
                    elseif rule.itemKind == ItemKind.Weapon then
                        activeItems = activeWeapons
                    end

                    local EMPTY_ITEM_LABEL = "{Empty Item}"
                    local extraActiveItems = { rule.itemName, EMPTY_ITEM_LABEL }

                    local maxTextWidth = 0
                    for _, itemName in next, extraActiveItems do
                        local width = ImGui.CalcTextSize(rule.itemName)
                        if width > maxTextWidth then
                            maxTextWidth = width
                        end
                    end
                    for itemName, _ in next, activeItems do
                        local width = ImGui.CalcTextSize(itemName)
                        if width > maxTextWidth then
                            maxTextWidth = width
                        end
                    end

                    local width = maxTextWidth + 40 -- magic number representing the drop-down button

                    ImGui.SetNextItemWidth(width)
                    if ImGui.BeginCombo("", #rule.itemName > 0 and rule.itemName or EMPTY_ITEM_LABEL) then
                        if ImGui.Selectable(EMPTY_ITEM_LABEL) then
                            rule.itemName = ""
                        end

                        for itemName, _ in next, activeItems do
                            if ImGui.Selectable(itemName) then
                                rule.itemName = itemName
                            end
                        end
                        ImGui.EndCombo()
                    end
                    ImGui.PopID()
                end
                ImGui.PopID()

                rule.stopsPropagation = ImGui.Checkbox("Stops Propagation", rule.stopsPropagation)

                ImGui.PopID()
                ImGui.Separator()
            end

            if BetterUI.FitButtonN(1, "Apply Rules") then
                if Mod:ApplyRulesForPlayer() then
                    Event_UpdatePlayerAll()
                end
            end
            ImGui.PopID()
        end

        ImGui.Separator()

        ImGui.Text("Config |")
        ImGui.SameLine()

        if BetterUI.FitButtonN(3, "Load") then Mod:LoadConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(2, "Save") then Mod:SaveConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(1, "Reset") then Mod:ResetConfig(); end
        ImGui.Separator()
    end
end

local function Event_OnOverlayOpen()
    Mod.showUI = true
end

local function Event_OnOverlayClose()
    Mod.showUI = false
end

function Mod:Init()
    local function _InputAsHotkey(cb)
        return function(pressed)
            if not pressed then cb(); end
        end
    end

    for name, value in Enum.SortedIterator(Group) do
        if value ~= Group.None then
            local inputId          = table.concat{ "toggle_", Enum.ToSnakeCase(name) }
            local inputDescription = table.concat{ "Toggle ", Enum.ToHumanCase(name) }
            registerInput(inputId, inputDescription, _InputAsHotkey(function()
                self:ToggleComponentsByGroup(value)
                Event_UpdatePlayerAll()
            end))
        end
    end

    registerForEvent("onInit", Event_OnInit)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw", Event_OnDraw)
    registerForEvent("onOverlayOpen", Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return Mod:Init()
