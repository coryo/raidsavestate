local _G, _M = getfenv(0), {}
setfenv(1, setmetatable(_M, {__index=_G}))

version = '0.0.2'

debugging = false

LAST_ROSTER = {}    -- (name, {entry})
FAILED_MOVES = {}   -- (name, failed)

-- since we have to wait for the roster update events, flag if we're currently loading and remember which state
loading = false
active_state = 1

permissions = false

do
	local f = CreateFrame'Frame'
	f:SetScript('OnEvent', function(self, event, ...) _M[event](self, ...) end)
    f:RegisterEvent'ADDON_LOADED'
    f:RegisterEvent'GROUP_ROSTER_UPDATE'
end

-- saved variables, (name, group number)
_G.RAID_SAVESTATE1 = {}
_G.RAID_SAVESTATE2 = {}
_G.RAID_SAVESTATE3 = {}

_G.SLASH_RAIDSAVESTATE1 = '/rss'
function _G.SlashCmdList.RAIDSAVESTATE(msg, editbox)
    if msg == "debug" or msg == "d" then
        debugging = not debugging
        print('debugging: '.. tostring(debugging))
    elseif msg == "cancel" or msg == "c" then
        loading = false
    end
end


function debug_print(str)
    if debugging then
        print("RaidSaveState: " .. str)
    end
end


_G.StaticPopupDialogs["CONFIRM_SAVE_STATE"] = {
    text = "Confirm save state?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function() save_state(active_state) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}


_G.StaticPopupDialogs["CONFIRM_LOAD_STATE"] = {
    text = "Confirm load state?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function() init_load_state(active_state) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

_G.StaticPopupDialogs["CONFIRM_CLEAR_STATE"] = {
    text = "Confirm clear state?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        _M['LOAD_STATE'..active_state].button:Disable()
        _M['CLEAR_STATE'..active_state].button:Disable()
        _G['RAID_SAVESTATE'..active_state] = {} end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}


SAVE_STATE1 = {
	FUNCTION = function() active_state = 1 StaticPopup_Show("CONFIRM_SAVE_STATE") end,
    TOOLTIP = 'Save raid state.',
    TEXT = "S1"
}
SAVE_STATE2 = {
	FUNCTION = function() active_state = 2 StaticPopup_Show("CONFIRM_SAVE_STATE") end,
    TOOLTIP = 'Save raid state.',
    TEXT = "S2"
}
SAVE_STATE3 = {
	FUNCTION = function() active_state = 3 StaticPopup_Show("CONFIRM_SAVE_STATE") end,
    TOOLTIP = 'Save raid state.',
    TEXT = "S3"
}

LOAD_STATE1 = {
	FUNCTION = function() active_state = 1 StaticPopup_Show("CONFIRM_LOAD_STATE") end,
    TOOLTIP = 'load save state 1',
    TEXT = "L"
}
LOAD_STATE2 = {
	FUNCTION = function() active_state = 2 StaticPopup_Show("CONFIRM_LOAD_STATE") end,
    TOOLTIP = 'load save state 2',
    TEXT = "L"
}
LOAD_STATE3 = {
	FUNCTION = function() active_state = 3 StaticPopup_Show("CONFIRM_LOAD_STATE") end,
    TOOLTIP = 'load save state 3',
    TEXT = "L"
}

CLEAR_STATE1 = {
	FUNCTION = function() active_state = 1 StaticPopup_Show("CONFIRM_CLEAR_STATE") end,
    TOOLTIP = 'clear save state 1',
    TEXT = "x"
}
CLEAR_STATE2 = {
	FUNCTION = function() active_state = 2 StaticPopup_Show("CONFIRM_CLEAR_STATE") end,
    TOOLTIP = 'clear save state 2',
    TEXT = "x"
}
CLEAR_STATE3 = {
	FUNCTION = function() active_state = 3 StaticPopup_Show("CONFIRM_CLEAR_STATE") end,
    TOOLTIP = 'clear save state 3',
    TEXT = "x"
}


function get_permissions()
    return UnitIsGroupAssistant("player") or UnitIsGroupLeader("player")
end


function GROUP_ROSTER_UPDATE()
    -- debug_print("GROUP_ROSTER_UPDATE")

    local current_permissions = get_permissions()
    if current_permissions ~= permissions then
        permissions = current_permissions
        update_ui_permissions()
    end

    if not UnitInRaid("player") then return end

    local current_roster = {}

    for i = 1, GetNumGroupMembers() do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
        if name then
            local entry = {}
            entry.index = i
            entry.name = name
            entry.rank = rank
            entry.subgroup = subgroup
            entry.level = level
            entry.class = class
            entry.fileName = fileName
            entry.zone = zone
            entry.online = online
            entry.isDead = isDead
            entry.role = role
            entry.isML = isML
            current_roster[name] = entry
        end
    end
    table.wipe(LAST_ROSTER)
    LAST_ROSTER = current_roster

    if loading then load_state(active_state) end
end

function ADDON_LOADED(_, arg1)
	if arg1 ~= 'raidsavestate' then
		return
    end

    local last_anchor, last_point = RaidFrame, "TOP"
    for state = 1,3 do

        local btn1 = CreateButton('SAVE_STATE'..state, RaidFrame)
        local btn2 = CreateButton('LOAD_STATE'..state, btn1)
        local btn3 = CreateButton('CLEAR_STATE'..state, btn2)
        btn1:SetPoint("TOP", last_anchor, last_point)
        btn2:SetPoint("TOP", last_anchor, last_point)
        btn3:SetPoint("TOP", last_anchor, last_point)
        last_anchor, last_point=btn1, "BOTTOM"
    end

    local current_permissions = get_permissions()
    permissions = current_permissions
    update_ui_permissions()

    GROUP_ROSTER_UPDATE()
end


function update_ui_permissions()
    for state = 1, 3 do
        local btn = _M['LOAD_STATE'..state].button
        local btn2 = _M['CLEAR_STATE'..state].button
        btn:Disable()
        btn2:Disable()
        for k,v in pairs(_G['RAID_SAVESTATE'..state]) do
            if permissions then
                btn:Enable()
            end
            btn2:Enable()
            break
        end
    end
 end


function CreateButton(key, anchor)
    local button = StateButton()
    _M[key].button = button
	button:SetScript('OnUpdate', function(self)
        button:SetParent(RaidFrame)
        button:SetPoint('LEFT', anchor, 'RIGHT')
        button:SetText(_M[key].TEXT)
        self:SetScript('OnUpdate', nil)
	end)
	button:SetScript('OnClick', function()
		_M[key].FUNCTION()
	end)
	button:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self)
		GameTooltip:AddLine(_M[key].TOOLTIP)
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
    end)
    return button
end


function StateButton()
	local button = CreateFrame('Button', nil, RaidFrame, "UIPanelButtonTemplate")
	button:SetWidth(28)
	button:SetHeight(26)
	button:SetHighlightTexture[[Interface\Buttons\ButtonHilight-Square]]
	button:GetHighlightTexture():ClearAllPoints()
	button:GetHighlightTexture():SetWidth(24)
	button:GetHighlightTexture():SetHeight(23)
	return button
end


function save_state(slot)
    table.wipe(_G['RAID_SAVESTATE'..slot])
    for name, entry in pairs(LAST_ROSTER) do
        _G['RAID_SAVESTATE'..slot][entry.name] = entry.subgroup
    end
    update_ui_permissions()
end


function get_players_in_group(group_number)
    local out = {}
    for name, entry in pairs(LAST_ROSTER) do
        if #out == 5 then break end
        if entry.subgroup == group_number then
            table.insert(out, name)
        end
    end
    return out
end


function init_load_state(slot)
    debug_print(format('init_load_state(%d)', slot))
    loading = true
    table.wipe(FAILED_MOVES)
    for i = 1, 3 do
        _M['LOAD_STATE'..i].button:Disable()
        _M['CLEAR_STATE'..i].button:Disable()
    end
    load_state(slot)
end


function finish_load_state(slot)
    debug_print(format('finish_load_state(%d)', slot))
    loading = false

    local failed_count = 0
    for k,v in pairs(FAILED_MOVES) do
        failed_count = failed_count + 1
    end

    if failed_count > 0 then
        local target_groups = _G['RAID_SAVESTATE'..slot]
        debug_print("The following actions failed:")
        for name, _ in pairs(FAILED_MOVES) do
            debug_print(format('  %s to group %d', name, target_groups[name]))
        end
    end

    table.wipe(FAILED_MOVES)

    update_ui_permissions()
end


-- we have to return after every Set or Swap RaidSubgroup and wait for the GROUP_ROSTER_UPDATE before calling again.
function load_state(slot)
    if InCombatLockdown() then
        debug_print("in combat lockdown, aborting.")
        finish_load_state(slot)
    end

    local target_groups = _G['RAID_SAVESTATE'..slot]

    for name, target_group in pairs(target_groups) do

        local entry = LAST_ROSTER[name]

        if entry and not FAILED_MOVES[name] then -- unit is in the current raid, and we haven't previously failed to move them
            if entry.subgroup ~= target_group then  -- unit is not in it's desired group
                local players_in_target_group = get_players_in_group(target_group)

                -- move to the right group

                -- first see if we can find a swap
                local swap_entry;
                for _, player_in_target_group in pairs(players_in_target_group) do
                    -- target player is not in their target group
                    if (player_in_target_group ~= name) and (target_groups[player_in_target_group] ~= target_group) then
                        swap_entry = LAST_ROSTER[player_in_target_group]
                        -- AND their target group is the first players current group
                        if (target_groups[player_in_target_group] == entry.subgroup) then
                            break
                        end
                    end
                end

                -- do the swap and return if we found a candidate
                if swap_entry then
                    if not InCombatLockdown() then
                        debug_print(format(
                            'RaidSaveState: swapping %s (%d, group %d) to %s (%d, group %d)',
                            entry.name, entry.index, entry.subgroup, swap_entry.name, swap_entry.index, target_group
                        ))
                        SwapRaidSubgroup(entry.index, swap_entry.index)
                    end
                    return
                end

                -- can we just insert them into the group
                if #players_in_target_group < 5 then
                    if not InCombatLockdown() then
                        debug_print(format('RaidSaveState: moving %s to group %d', name, target_group))
                        SetRaidSubgroup(entry.index, target_group)
                    end
                    return
                end

                debug_print(format('RaidSaveState: unable to find a swap for %s in group %d.', entry.name, target_group))
                FAILED_MOVES[name] = true
            end
        end
    end

    finish_load_state(slot)
end


