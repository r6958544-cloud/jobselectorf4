-- Общая конфигурация изолированной системы полиции.

local function RegisterPoliceJob()
    JobSelector = JobSelector or {}
    JobSelector.Jobs = JobSelector.Jobs or {}
    JobSelector.JobOrder = JobSelector.JobOrder or {}
    JobSelector.PermissionCheckers = JobSelector.PermissionCheckers or {}
    JobSelector.ServerPermissionCheckers = JobSelector.ServerPermissionCheckers or {}
    JobSelector.ExtraTabs = JobSelector.ExtraTabs or {}

    JobSelector.Jobs.police = {
        id = "police",
        name = "Полицейский",
        description = "Сотрудник New York Police Department. Следит за порядком, реагирует на вызовы и обеспечивает безопасность жителей города.",
        maxSlots = nil,
        requiresPermission = "police",
        weapons = {
            "weapon_hands_sh",
            "weapon_glock17",
            "weapon_handcuffs",
            "weapon_handcuffs_key",
            "weapon_medkit_sh",
            "weapon_bigbandage_sh",
            "weapon_morphine",
            "weapon_taser",
        },
        ammo = {
            ["9x19 mm Parabellum"] = 50,
            ["Taser Cartridge"] = 5,
        },
    }

    local exists = false
    for _, id in ipairs(JobSelector.JobOrder) do
        if id == "police" then
            exists = true
            break
        end
    end

    if not exists then
        table.insert(JobSelector.JobOrder, 1, "police")
    end

    JobSelector.PoliceSpawnPoints = {
        Vector(8662.185546875, 7320.47021484375, 200.03125),
    }
end

if JobSelector and JobSelector.Jobs then
    RegisterPoliceJob()
else
    timer.Simple(0, RegisterPoliceJob)
end
