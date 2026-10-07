Config = {
    ServerName  = "Your Server Name",
    WEBHOOK_URL = "",

    ViewAce = "duty.view",
    KickAce = "duty.kickoff",

    MaxFieldLength   = 20,
    Call911Cooldown  = 30,

    BlipsEnabled     = true,
    BlipRefreshMs    = 3000,

    GetPostal = function(coords)
        return 'Unknown'
    end,

    AllowedDepartments = {
        { name = "LAPD",    dutyAce = "duty.lapd" },
        { name = "BCSO",    dutyAce = "duty.bcso" },
        { name = "ARMY",    dutyAce = "duty.army" },
        { name = "MARINES", dutyAce = "duty.marines" },
        { name = "DHS",     dutyAce = "duty.dhs" },
        { name = "CIA",     dutyAce = "duty.cia" },
    }
}
