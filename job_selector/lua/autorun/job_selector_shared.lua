-- Общая конфигурация Riverside Chicago RP.

JobSelector = JobSelector or {}

JobSelector.Jobs = {
    civil = {
        id = "civil",
        name = "Гражданский",
        description = "Обычный житель города без особых обязанностей.",
        maxSlots = nil,
        weapons = {
            "weapon_hands_sh",
        },
    },
}

JobSelector.JobOrder = { "civil" }
JobSelector.PreservedTools = { "weapon_physgun", "gmod_tool" }

JobSelector.CivilSpawnPoints = {
    Vector(1436.1588134765625, 672.12451171875, -103.96875),
}

JobSelector.PermissionCheckers = JobSelector.PermissionCheckers or {}
JobSelector.ServerPermissionCheckers = JobSelector.ServerPermissionCheckers or {}
JobSelector.OnJobSelected = JobSelector.OnJobSelected or {}
JobSelector.OnJobPrepare = JobSelector.OnJobPrepare or {}
JobSelector.OnJobLeft = JobSelector.OnJobLeft or {}
JobSelector.ExtraTabs = JobSelector.ExtraTabs or {}
JobSelector.JobChangeBlockers = JobSelector.JobChangeBlockers or {}

JobSelector.Locations = {
    {
        name = "Полицейский участок NYPD",
        pos = Vector(7768.701171875, 7904.3388671875, 200.03125),
    },
    {
        name = "Больница",
        pos = Vector(7418.798828125, 4934.18408203125, -55.96875),
    },
    {
        name = "Центр занятости",
        pos = Vector(-1189.947998046875, 4851.8974609375, -103.96875),
    },
}

JobSelector.UnitsPerMeter = 52.49
