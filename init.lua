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
    Clothing  = 1,
    Cyberware = 2,
    Weapon    = 3,
}

local function _SortedKeys(tbl)
    local sortedKeys = {}
    for key, _ in next, tbl do
        table.insert(sortedKeys, tostring(key))
    end
    table.sort(sortedKeys)
    return sortedKeys
end

-- Search for ' Rule' when modifying the definition

---@class Rule
---@field enabled boolean
---@field itemKind ItemKind
---@field itemName string
---@field condition Condition
---@field group Group
---@field groupEnabled boolean
---@field stopsPropagation boolean

---The context on which rules are evaluated
---@class EvalContext
---@field GetActiveClothing  fun(self: EvalContext): table<string, boolean>
---@field GetActiveCyberware fun(self: EvalContext): table<string, boolean>
---@field GetEquippedWeapons fun(self: EvalContext): table<string, boolean>
---@field GetActiveWeapons   fun(self: EvalContext): table<string, boolean>
---@field GetActiveItems fun(self: EvalContext, itemKind: ItemKind): table<string, boolean>
---@field HasActiveItem  fun(self: EvalContext, itemKind: ItemKind, itemName: string): boolean

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
        ["a0_004__weapon_grip_device"]               = { enabled = true, group = Group.WeaponGrip },
        ["a0_004__weapon_grip_decal_01"]             = { enabled = true, group = Group.WeaponGrip },
        ["a0_004__weapon_grip_decal_02"]             = { enabled = true, group = Group.WeaponGrip },
        ["a0_008_ma__fpp_right_q001_injection_mark"] = { enabled = true, group = Group.InjectionMark },
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

function Mod:UpdateEntityComponents(entity)
    -- a0_004__weapon_grip_decal_02
    -- a0_004__weapon_grip_device
    -- a0_008_wa__fpp_right_q001_injection_mark
    -- a0_004__weapon_grip_decal_01
    for compName, compConfig in next, self._components do
        local component = entity:FindComponentByName(compName)
        if component then
            component:Toggle(compConfig.enabled and true or false)
            -- It seems like when playing the quest "The Ripperdoc", the quest uses
            --  `:Toggle()` to show the injection mark. Which means that `:TemporaryHide()`
            --  will hide it while it's performed which doesn't look good.
            -- component:TemporaryHide((not compConfig.enabled) and true or false)
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

---@return string[]
function Mod:GetClothingSlots()
    return EquipmentEx and _EquipmentExSlots or _VanillaSlots
end

---Clothing equipped by the puppet (the word 'Active' was chosen so
--- that it makes sense for weapons and to keep the Condition enum small).
---@param puppet gamePuppet
---@return table<string, boolean>
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

---Cyberware equipped by the puppet (the word 'Active' was chosen so
--- that it makes sense for weapons and to keep the Condition enum small).
---@param puppet gamePuppet
---@return table<string, boolean>
function Mod:GetActiveCyberwareForPuppet(puppet)
    local equipmentSystem = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
    local equipmentData = equipmentSystem.GetData(puppet)
    if not equipmentData then return {}; end

    local activeCyberware = {}

    local cyberwareEquipmentAreas = equipmentData:GetAllCyberwareEquipmentAreas()
    for _, equipmentArea in next, cyberwareEquipmentAreas do
        local slotCount = equipmentData:GetNumberOfSlots(equipmentArea)
        for slotIndex=0, slotCount-1 do
            local itemID = equipmentData:GetItemInEquipSlot(equipmentArea, slotIndex)
            -- Has Item in Slot
            if ItemID.IsValid(itemID) then
                local itemRecord = TweakDB:GetRecord(itemID.id)
                -- Is Visual Item
                if itemRecord and itemRecord:GetPlacementSlotsCount() > 0 then
                    local friendlyName = itemRecord:FriendlyName()
                    local entityName = itemRecord:EntityName()
                    local iconPath = itemRecord:IconPath()

                    activeCyberware[itemID.id.value] = true
                    if #friendlyName > 0 then
                        activeCyberware[friendlyName] = true
                    end
                    if #entityName.value > 0 then
                        activeCyberware[entityName.value] = true
                    end
                    if #iconPath > 0 then
                        activeCyberware[iconPath] = true
                    end
                end
            end
        end
    end

    return activeCyberware
end

---Equipped weapons (currently held by the puppet, and in the loadout)
---@param puppet gamePuppet
---@return table<string, boolean>
function Mod:GetEquippedWeaponsForPuppet(puppet)
    local equipmentSystem = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
    local equipmentData = equipmentSystem.GetData(puppet)
    if not equipmentData then return {}; end

    local equippedWeapons = self:GetActiveWeaponsForPuppet(puppet)

    local equipmentArea = gamedataEquipmentArea.Weapon
    local slotCount = equipmentData:GetNumberOfSlots(equipmentArea)
    for slotIndex=0, slotCount-1 do
        local itemID = equipmentData:GetItemInEquipSlot(equipmentArea, slotIndex)
        -- Has Item in Slot
        if ItemID.IsValid(itemID) then
            local itemRecord = TweakDB:GetRecord(itemID.id)
            if itemRecord then
                local friendlyName = itemRecord:FriendlyName()
                if #friendlyName > 0 then
                    equippedWeapons[friendlyName] = true
                end
            end
        end
    end

    return equippedWeapons
end

---Active weapons (currently held by the puppet, not in the loadout)
---@param puppet gamePuppet
---@return table<string, boolean>
function Mod:GetActiveWeaponsForPuppet(puppet)
    if not puppet.GetActiveWeapon then return {}; end

    local activeWeapons = {}
    local weaponObject = puppet:GetActiveWeapon()
    if weaponObject then
        local weaponRecord = weaponObject:GetWeaponRecord()
        if weaponRecord then
            local weaponName = weaponRecord:FriendlyName()
            activeWeapons[weaponName] = true
        end
    end

    return activeWeapons
end

---Creates a new EvalContext based on puppet
---@param puppet gamePuppet
---@return EvalContext
function Mod:CreateRuleEvalContextForPuppet(puppet)
    local context = { _mod = self, _puppet = puppet }

    function context:GetActiveClothing()
        if self._activeClothing then return self._activeClothing; end
        self._activeClothing = self._mod:GetActiveClothingForPuppet(self._puppet)
        return self._activeClothing
    end

    function context:GetActiveCyberware()
        if self._activeCyberware then return self._activeCyberware; end
        self._activeCyberware = self._mod:GetActiveCyberwareForPuppet(self._puppet)
        return self._activeCyberware
    end

    function context:GetEquippedWeapons()
        if self._equippedWeapons then return self._equippedWeapons; end
        self._equippedWeapons = self._mod:GetEquippedWeaponsForPuppet(self._puppet)
        return self._equippedWeapons
    end

    function context:GetActiveWeapons()
        if self._activeWeapons then return self._activeWeapons; end
        self._activeWeapons = self._mod:GetActiveWeaponsForPuppet(self._puppet)
        return self._activeWeapons
    end

    function context:GetActiveItems(itemKind)
        if itemKind == ItemKind.Clothing then
            return self:GetActiveClothing()
        elseif itemKind == ItemKind.Cyberware then
            return self:GetActiveCyberware()
        elseif itemKind == ItemKind.Weapon then
            return self:GetActiveWeapons()
        end
        return {}
    end

    function context:HasActiveItem(itemKind, itemName)
        return self:GetActiveItems(itemKind)[itemName] and true or false
    end

    return context
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
---@return Rule rule allows for `local rule = Mod:AddRule(Mod:CreateDefaultRule())`
function Mod:AddRule(rule, index)
    if index then
        table.insert(self._rules, index, rule)
    else
        table.insert(self._rules, rule)
    end
    return rule
end

---@param evalContext EvalContext
---@param rule Rule
---@return boolean applied whether rule was applied
function Mod:ApplyRule(evalContext, rule)
    if not rule.enabled then return false; end

    local conditionsMet = false
    if rule.condition == Condition.Always then
        conditionsMet = true
    elseif rule.condition == Condition.IfActive then
        conditionsMet = evalContext:HasActiveItem(rule.itemKind, rule.itemName)
    elseif rule.condition == Condition.IfNotActive then
        conditionsMet = not evalContext:HasActiveItem(rule.itemKind, rule.itemName)
    end

    if not conditionsMet then return false; end

    self:ToggleComponentsByGroup(rule.group, rule.groupEnabled, false)
    return true
end

---@param puppet gamePuppet
---@param evalContext EvalContext|nil default: `Mod:CreateRuleEvalContextForPuppet(puppet)`
---@return boolean applied whether at least one rule was applied (puppet probably needs to be updated)
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

    self:UpdateEntityComponents(player)
end

---@param itemID ItemID
---@return boolean
function Mod:IsWeaponGripItemID(itemID)
    return itemID.id.value:find("^Items.AdvancedPowerGrip") ~= nil
end

---`Mod:UpdatePlayer()` just toggles components on the player.
---Inventory and Photo puppets do not use components to display the weapon grip.
---The function basically checks the state of `Group.WeaponGrip` and changes the
--- appearance of the item to show/hide it
function Mod:UpdatePlayerTPP()
    local puppets = {}
    table.insert(puppets, self._inventoryPuppet)
    table.insert(puppets, self._photoPuppet)

    if #puppets <= 0 then return; end

    local transactionSystem = Game.GetTransactionSystem()
    local isWeaponGripEnabled = self:IsGroupEnabled(Group.WeaponGrip)

    for _, puppet in next, puppets do
        -- NOTE: Apparently the game only shows one of the hand cyberwares.
        --       You can have both Johnny's tattoo and the Coprocessor but
        --        only one will show in the Inventory or Photo Mode
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

function Mod:UpdatePlayerAll()
    self:UpdatePlayer()
    self:UpdatePlayerTPP()
end

local function Event_UpdatePlayerAll()
    Mod:UpdatePlayerAll()
end

local function Event_AutoApplyRulesForPlayer()
    if Mod.autoApplyRules then
        if Mod:ApplyRulesForPlayer() then
            Mod:UpdatePlayerAll()
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
    Observe("gameWardrobeSystem", "SetActiveClothingSetIndex", Event_AutoApplyRulesForPlayer)
    Observe("RipperDocGameController", "OnUninitialize", Event_AutoApplyRulesForPlayer)

    Observe("gameuiInventoryGameController", "OnInitialize", Event_UpdatePlayerAll)
    Observe("gameuiInventoryGameController", "RefreshedEquippedItemData", Event_UpdatePlayerAll)
    Observe("gameuiPhotoModeMenuController", "OnShow", Event_UpdatePlayerAll)

    Observe("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", function()
        if Mod.autoApplyRules then
            Mod:ApplyRulesForPlayer()
        end
        Mod:UpdatePlayerAll()
    end)

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
                    Mod:UpdatePlayerAll()
                end
            end
            ImGui.SameLine()
            if BetterUI.FitButtonN(1, "Update Player") then
                Mod:UpdatePlayerAll()
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
                        Mod:UpdatePlayerAll()
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
            local evalContext = player and Mod:CreateRuleEvalContextForPuppet(player) or nil

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
                    local activeItems
                    if not evalContext then
                        activeItems = {}
                    elseif rule.itemKind == ItemKind.Weapon then
                        activeItems = evalContext:GetEquippedWeapons()
                    else
                        activeItems = evalContext:GetActiveItems(rule.itemKind)
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

                        for _, itemName in next, _SortedKeys(activeItems) do
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
                    Mod:UpdatePlayerAll()
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
                self:UpdatePlayerAll()
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
