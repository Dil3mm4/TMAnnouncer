CSmPlayer@ LocalPlayer;
CGameManialinkLabel@ TimeDiff;
CGameManialinkLabel@ LapsCounter;
int LandmarkIdx = -1;
int LapsRemaining = -1;
bool RaceHasStarted = false;
int CPIntervalCountdown = -1;
float LastTickSpeed = 0.;

void CheckTriggers() {
    if (!RacePlaying()) {
        RaceReset();
        return;
    }
    if (!FindLocalPlayer()) return;
    if (!FindControls()) return;

    if (TriggerRaceStart()) {
        CPIntervalCountdown = 0;

        LapsRemaining = GetLapsRemaining();
        if (LapsRemaining != -1) {
            PlayLap(LapsRemaining, true);
        }
    }

    if (TriggerCheckpoint()) {
        // Check for new lap
        int CurrentLapsRemaining = GetLapsRemaining();
        if (LapsRemaining != CurrentLapsRemaining) {
            LapsRemaining = CurrentLapsRemaining;
            if (LapsRemaining != -1) {
                PlayLap(LapsRemaining, false);
            }
        } else {
            // Play normal checkpoint sound
            if (CPIntervalCountdown == 0) {
                bool IsNeutral = TimeDiff.Value.StartsWith("0");
                bool IsAhead = TimeDiff.Value.StartsWith("-") || TimeDiff.Value == "";
                if (IsNeutral) {
                    PlayCheckpoint();
                } else if (IsAhead) {
                    PlayCheckpointYes();
                } else {
                    PlayCheckpointNo();
                }
                CPIntervalCountdown = Math::Rand(CPIntervalMin, CPIntervalMax) - 1;
            } else {
                CPIntervalCountdown -= 1;
            }
        }
    }

    if (TriggerCarhit()) {
        PlayCarhit();
    }
}

bool RacePlaying() {
    CGameManiaAppPlayground@ Playground = GetApp().Network.ClientManiaAppPlayground;
    return !(Playground is null) && Playground.UI.UISequence == CGamePlaygroundUIConfig::EUISequence::Playing;
}

bool FindLocalPlayer() {
    CGamePlayground@ Playground = GetApp().CurrentPlayground;
    if (Playground is null) return false;

    MwFastBuffer<CGameTerminal@> Terminals = Playground.GameTerminals;
    if (Terminals.Length == 0) return false;

    auto Player = cast<CSmPlayer@>(Terminals[0].ControlledPlayer);
    if (Player is null) {
        // Not yet loaded
        return false;
    }

    @LocalPlayer = Player;
    return true;
}

bool FindControls() {
    MwFastBuffer<CGameUILayer@> Layers = GetApp().Network.ClientManiaAppPlayground.UILayers;
    bool Found = false;
    @LapsCounter = null;

    // Searching for a specific UI module
    for (uint i = 0; i < Layers.Length; i++) {
        auto Layer = Layers[i];

        if (Layer.ManialinkPageUtf8.SubStr(0, 100).Contains("UIModule_Race_Checkpoint")) {
        MwFastBuffer<CGameManialinkControl@> Controls = Layer.LocalPage.ControlsCache;
            for (uint j = 0; j < Controls.Length; j++) {
                auto Control = Controls[j];
                if (Control.ControlId == "label-race-diff") {
                    @TimeDiff = cast<CGameManialinkLabel@>(Control);
                    Found = true;
                }
            }
        }

        if (Layer.ManialinkPageUtf8.SubStr(0, 100).Contains("UIModule_Race_LapsCounter")) {
        MwFastBuffer<CGameManialinkControl@> Controls = Layer.LocalPage.ControlsCache;
            for (uint j = 0; j < Controls.Length; j++) {
                auto Control = Controls[j];
                if (Control.ControlId == "label-laps-counter") {
                    @LapsCounter = cast<CGameManialinkLabel@>(Control);
                }
            }
        }
    }

    // Assuming both will be found if one of them is
    // Since both are Race UI modules, that is quite likely
    return Found;
}

bool TriggerRaceStart() {
    int RaceTime = cast<CSmScriptPlayer@>(LocalPlayer.ScriptAPI).CurrentRaceTime;
    if (!RaceHasStarted && RaceTime >= 0)  {
        RaceHasStarted = true;
        return true;
    }
    if (RaceTime < 0) {
        RaceHasStarted = false;
        RaceReset();
    }
    return false;
}

bool TriggerCheckpoint() {
    int CurrentLandmarkIdx = LocalPlayer.CurrentLaunchedRespawnLandmarkIndex;

    // Sometimes invalid index values in the map editor, discard them
    if (CurrentLandmarkIdx < 0) {
        return false;
    }

    if (LandmarkIdx != CurrentLandmarkIdx) {
        bool PreviousLandmarkValid = LandmarkIdx != -1;
        LandmarkIdx = CurrentLandmarkIdx;
        return PreviousLandmarkValid && RaceHasStarted;
    }
    return false;
}

int GetLapsRemaining() {
    if (LapsCounter is null) return -1;
    if (!LapsCounter.Parent.Visible) return -1;

    // Super hacky method to parse the lap counter, compose strings are a mess
    string LapsText = LapsCounter.Value;
    int Len = LapsText.Length;
    int CurrentLap = Text::ParseInt(LapsText.SubStr(Len-4, Len-4));
    int TotalLap = Text::ParseInt(LapsText.SubStr(Len-1, Len-1));
    int LapsRemaining = TotalLap - CurrentLap + 1;
    if (LapsRemaining < 1 || LapsRemaining > 5 || CurrentLap < 1 || TotalLap < 1) {
        // Hacky method fail, no laps or too many laps
        return -1;
    }
    return LapsRemaining;
}

void RaceReset() {
    LandmarkIdx = -1;
    LapsRemaining = -1;
    CPIntervalCountdown = -1;
    LastTickSpeed = 0.;
}

bool TriggerCarhit() {
    auto ScriptAPI = cast<CSmScriptPlayer@>(LocalPlayer.ScriptAPI);
    float TickSpeed = ScriptAPI.Speed;
    uint DisplaySpeed = ScriptAPI.DisplaySpeed;
    bool HitOccured = false;

    // Speed is always positive, no need to worry about negative values
    // However, we still need to check that the display speed is non-zero (in case of a respawn)
    if ((LastTickSpeed > 30.) && (DisplaySpeed != 0) && (TickSpeed / LastTickSpeed < S_CarhitSensitivity)) {
        HitOccured = RaceHasStarted;
        LastTickSpeed = 0.;
    }

    LastTickSpeed = TickSpeed;
    return HitOccured;
}
