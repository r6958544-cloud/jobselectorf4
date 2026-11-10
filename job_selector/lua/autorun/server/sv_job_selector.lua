-- Серверная логика выбора профессии для Riverside Chicago RP.

if not SERVER then return end

local JOB_CHANGE_COOLDOWN = 45

util.AddNetworkString("JobSelector_SelectJob")
util.AddNetworkString("JobSelector_RequestCounts")
util.AddNetworkString("JobSelector_Counts")
util.AddNetworkString("JobSelector_JobCooldown")
util.AddNetworkString("JobSelector_JobSuccess")
util.AddNetworkString("JobSelector_JobDenied")
util.AddNetworkString("JobSelector_ChangeBlocked")

local function CountJobPlayers(job, excludePlayer)
    local count = 0

    for _, target in ipairs(player.GetAll()) do
        if target ~= excludePlayer and target.job == job then
            count = count + 1
        end
    end

    return count
end

JobSelector.CountJobPlayers = CountJobPlayers

local function RememberPreservedTools(ply)
    local result = {}

    for _, class in ipairs(JobSelector.PreservedTools) do
        if ply:HasWeapon(class) then
            result[class] = true
        end
    end

    return result
end

local function ApplyJobAmmo(ply, jobData)
    for ammoName, amount in pairs(jobData.ammo or {}) do
        local ammoId = game.GetAmmoID(ammoName)
        if ammoId and ammoId >= 0 then
            ply:SetAmmo(0, ammoId)
        end

        ply:GiveAmmo(amount, ammoName, true)
    end
end

local function ApplyLoadout(ply, job)
    local jobData = JobSelector.Jobs[job]
    if not jobData then return end

    local preservedTools = RememberPreservedTools(ply)
    ply:StripWeapons()

    for class, shouldGive in pairs(preservedTools) do
        if shouldGive then
            ply:Give(class)
        end
    end

    for _, class in ipairs(jobData.weapons or {}) do
        ply:Give(class)
    end

    ApplyJobAmmo(ply, jobData)

    -- Модель полиции устанавливается отдельным хуком через 2 секунды
    -- после респавна, чтобы не заменяться логикой гейммода.
end

JobSelector.ApplyLoadout = ApplyLoadout

function JobSelector.CanUseJob(ply, jobData)
    if not jobData or not jobData.requiresPermission then
        return true
    end

    local checker = JobSelector.ServerPermissionCheckers[jobData.requiresPermission]
    return checker ~= nil and checker(ply) == true
end

hook.Add("PlayerInitialSpawn", "JobSelector_DefaultCivil", function(ply)
    ply.job = "civil"
    ply:SetNWString("job", "civil")
    ply.JobSelectorPendingCivilSpawn = true
    ply.HadToolsBeforeRespawn = nil
end)

hook.Add("PlayerDeath", "JobSelector_RememberTools", function(ply)
    ply.HadToolsBeforeRespawn = RememberPreservedTools(ply)
end)

hook.Add("PlayerLoadout", "JobSelector_ApplyLoadout", function(ply)
    local job = ply.job or "civil"
    local jobData = JobSelector.Jobs[job]

    if not jobData or not JobSelector.CanUseJob(ply, jobData) then
        job = "civil"
        ply.job = job
        ply:SetNWString("job", job)
        jobData = JobSelector.Jobs[job]
    end

    ApplyLoadout(ply, job)
    ply.HadToolsBeforeRespawn = nil
    return true
end)

hook.Add("PlayerSpawn", "JobSelector_CivilSpawn", function(ply)
    if ply.job ~= "civil" or not ply.JobSelectorPendingCivilSpawn then return end

    ply.JobSelectorPendingCivilSpawn = false

    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end

        local points = JobSelector.CivilSpawnPoints
        local point = points[math.random(1, #points)]
        ply:SetPos(point)
    end)
end)

net.Receive("JobSelector_SelectJob", function(_, ply)
    local job = net.ReadString()
    local jobData = JobSelector.Jobs[job]
    if not jobData then return end
    if ply.job == job then return end

    for _, blocker in pairs(JobSelector.JobChangeBlockers) do
        local reason = blocker(ply)
        if reason then
            net.Start("JobSelector_ChangeBlocked")
                net.WriteString(reason)
            net.Send(ply)
            return
        end
    end

    if not JobSelector.CanUseJob(ply, jobData) then
        net.Start("JobSelector_JobDenied")
            net.WriteString(job)
        net.Send(ply)
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

    if ply:Alive() then
        ApplyLoadout(ply, job)
    end

    net.Start("JobSelector_JobSuccess")
        net.WriteString(job)
    net.Send(ply)
end)

net.Receive("JobSelector_RequestCounts", function(_, ply)
    local limited = {}

    for jobId, jobData in pairs(JobSelector.Jobs) do
        if jobData.maxSlots then
            limited[#limited + 1] = jobId
        end
    end

    net.Start("JobSelector_Counts")
        net.WriteUInt(#limited, 8)
        for _, jobId in ipairs(limited) do
            net.WriteString(jobId)
            net.WriteUInt(CountJobPlayers(jobId), 8)
        end
    net.Send(ply)
end)
