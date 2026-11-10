-- Изолированная серверная система полиции.

if not SERVER then return end

local TABLE_NAME = "riverside_police_whitelist"
local POLICE_MODEL = "models/kerry/nypd_v2/male_04.mdl"
local JOB_CHANGE_COOLDOWN = 45

util.AddNetworkString("RiversidePolice_RequestWhitelist")
util.AddNetworkString("RiversidePolice_Whitelist")
util.AddNetworkString("RiversidePolice_AddWhitelist")
util.AddNetworkString("RiversidePolice_RemoveWhitelist")
util.AddNetworkString("RiversidePolice_WhitelistMessage")
util.AddNetworkString("JobSelector_JobDenied")

local function HasWhitelistManagerAccess(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end

    local group = ply.GetUserGroup and ply:GetUserGroup() or ""
    return string.lower(group) == "policewl"
end

local function IsValidSteamID64(steamID64)
    return isstring(steamID64)
        and #steamID64 == 17
        and string.match(steamID64, "^7656119%d%d%d%d%d%d%d%d%d%d$") ~= nil
end

local function IsWhitelisted(steamID64)
    if not IsValidSteamID64(steamID64) then return false end

    local result = sql.QueryValue(string.format(
        "SELECT steamid64 FROM %s WHERE steamid64 = %s LIMIT 1",
        TABLE_NAME,
        sql.SQLStr(steamID64)
    ))

    return result ~= nil
end

local function CanUsePolice(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return IsWhitelisted(ply:SteamID64() or "")
end

local function UpdatePermissionNWVars(ply)
    if not IsValid(ply) then return end
    ply:SetNWBool("RiversidePolice_Allowed", CanUsePolice(ply))
    ply:SetNWBool("RiversidePolice_CanManageWhitelist", HasWhitelistManagerAccess(ply))
end

local function SendWhitelist(ply)
    if not HasWhitelistManagerAccess(ply) then return end

    local rows = sql.Query(string.format(
        "SELECT steamid64, added_by, added_at FROM %s ORDER BY added_at DESC",
        TABLE_NAME
    )) or {}

    net.Start("RiversidePolice_Whitelist")
        net.WriteUInt(math.min(#rows, 65535), 16)
        for i = 1, math.min(#rows, 65535) do
            local onlineName = "Оффлайн"

            for _, target in ipairs(player.GetAll()) do
                if target:SteamID64() == rows[i].steamid64 then
                    onlineName = target:Nick()
                    break
                end
            end

            net.WriteString(rows[i].steamid64 or "")
            net.WriteString(onlineName)
            net.WriteString(rows[i].added_by or "")
            net.WriteUInt(tonumber(rows[i].added_at) or 0, 32)
        end
    net.Send(ply)
end

local function ForcePoliceRespawn(ply)
    if not IsValid(ply) then return end

    ply.RiversidePolicePendingSpawn = true

    if ply:Alive() then
        ply:Kill()
    end

    timer.Simple(0.1, function()
        if IsValid(ply) and not ply:Alive() then
            ply:Spawn()
        end
    end)
end

local function SendDenied(ply, job)
    net.Start("JobSelector_JobDenied")
        net.WriteString(job)
    net.Send(ply)
end

hook.Add("Initialize", "RiversidePolice.CreateDatabase", function()
    sql.Query(string.format([[CREATE TABLE IF NOT EXISTS %s (
        steamid64 TEXT PRIMARY KEY,
        added_by TEXT NOT NULL,
        added_at INTEGER NOT NULL
    )]], TABLE_NAME))
end)

hook.Add("PlayerInitialSpawn", "RiversidePolice.UpdatePermission", function(ply)
    timer.Simple(0, function()
        UpdatePermissionNWVars(ply)
    end)
end)

-- Регдолл и выход из него могут вызывать PlayerSpawn без настоящей смерти.
-- Поэтому позиция полиции применяется только после реальной смерти или
-- принудительного перехода в профессию.
hook.Add("PlayerDeath", "RiversidePolice.MarkRealRespawn", function(ply)
    if ply.job == "police" then
        ply.RiversidePolicePendingSpawn = true
    end
end)

JobSelector.ServerPermissionCheckers.police = CanUsePolice

-- Переопределяет только выбор профессии, чтобы старый Civil-обработчик
-- не мог перезаписать выбранную профессию полиции.
net.Receive("JobSelector_SelectJob", function(_, ply)
    local job = net.ReadString()
    local jobData = JobSelector.Jobs and JobSelector.Jobs[job]
    if not jobData or ply.job == job then return end

    for _, blocker in pairs(JobSelector.JobChangeBlockers or {}) do
        local reason = blocker(ply)
        if reason then
            net.Start("JobSelector_ChangeBlocked")
                net.WriteString(reason)
            net.Send(ply)
            return
        end
    end

    if jobData.requiresPermission and not CanUsePolice(ply) then
        SendDenied(ply, job)
        return
    end

    local now = CurTime()
    if ply.NextJobChangeAllowed and now < ply.NextJobChangeAllowed then
        net.Start("JobSelector_JobCooldown")
            net.WriteFloat(ply.NextJobChangeAllowed - now)
        net.Send(ply)
        return
    end

    local oldJob = ply.job or "civil"
    ply.job = job
    ply:SetNWString("job", job)
    ply.NextJobChangeAllowed = now + JOB_CHANGE_COOLDOWN

    if oldJob == "police" or job == "police" then
        ForcePoliceRespawn(ply)
    elseif ply:Alive() and JobSelector.ApplyLoadout then
        JobSelector.ApplyLoadout(ply, job)
    end

    net.Start("JobSelector_JobSuccess")
        net.WriteString(job)
    net.Send(ply)
end)

hook.Add("PlayerSpawn", "RiversidePolice.SpawnAndDelayedModel", function(ply)
    if ply.job ~= "police" or not ply.RiversidePolicePendingSpawn then return end

    ply.RiversidePolicePendingSpawn = false

    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() or ply.job ~= "police" then return end

        local points = JobSelector.PoliceSpawnPoints
        ply:SetPos(points[math.random(1, #points)])
    end)

    timer.Simple(1.3, function()
        if not IsValid(ply) or not ply:Alive() or ply.job ~= "police" then return end

        -- Используем стандартный pipeline player_manager, как C-меню.
        -- Если модель не зарегистрирована player_manager, оставляем fallback.
        if player_manager and player_manager.SetPlayerModel then
            player_manager.SetPlayerModel(ply, POLICE_MODEL)
        else
            ply:SetModel(POLICE_MODEL)
        end

        -- Сбрасываем абсолютно все bodygroup-слоты модели в дефолтное
        -- значение 0. Skin, material, кости и аксессуары не изменяются.
        local function ResetAllBodygroups()
            if not IsValid(ply) or not ply:Alive() or ply.job ~= "police" then return end

            for groupID = 0, ply:GetNumBodyGroups() - 1 do
                ply:SetBodygroup(groupID, 0)
            end
        end

        ResetAllBodygroups()

        -- Повторяем после следующего тика, чтобы перекрыть изменения,
        -- которые могли применить player_manager или другой аддон.
        timer.Simple(0, ResetAllBodygroups)
    end)
end)

net.Receive("RiversidePolice_RequestWhitelist", function(_, ply)
    SendWhitelist(ply)
end)

net.Receive("RiversidePolice_AddWhitelist", function(_, ply)
    if not HasWhitelistManagerAccess(ply) then return end

    local steamID64 = string.Trim(net.ReadString() or "")
    if not IsValidSteamID64(steamID64) then
        net.Start("RiversidePolice_WhitelistMessage")
            net.WriteBool(false)
            net.WriteString("Нужен корректный SteamID64 из 17 цифр.")
        net.Send(ply)
        return
    end

    sql.Query(string.format(
        "INSERT OR REPLACE INTO %s (steamid64, added_by, added_at) VALUES (%s, %s, %d)",
        TABLE_NAME,
        sql.SQLStr(steamID64),
        sql.SQLStr(ply:SteamID64() or ply:Nick()),
        os.time()
    ))

    for _, target in ipairs(player.GetAll()) do
        if target:SteamID64() == steamID64 then
            UpdatePermissionNWVars(target)
        end
    end

    net.Start("RiversidePolice_WhitelistMessage")
        net.WriteBool(true)
        net.WriteString("Игрок добавлен в whitelist полиции.")
    net.Send(ply)

    SendWhitelist(ply)
end)

net.Receive("RiversidePolice_RemoveWhitelist", function(_, ply)
    if not HasWhitelistManagerAccess(ply) then return end

    local steamID64 = string.Trim(net.ReadString() or "")
    if not IsValidSteamID64(steamID64) then return end

    sql.Query(string.format(
        "DELETE FROM %s WHERE steamid64 = %s",
        TABLE_NAME,
        sql.SQLStr(steamID64)
    ))

    for _, target in ipairs(player.GetAll()) do
        if target:SteamID64() == steamID64 then
            UpdatePermissionNWVars(target)
        end
    end

    net.Start("RiversidePolice_WhitelistMessage")
        net.WriteBool(true)
        net.WriteString("Игрок удалён из whitelist полиции.")
    net.Send(ply)

    SendWhitelist(ply)
end)
