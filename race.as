namespace RaceLogic {
    string CurrentMapUid = "";
    int LastStartTime = -1;
    int LastCPCount = -1;
    bool IsRunning = false;
    float LastTickSpeed = 0.;
    uint64 LastCrashCheckTime = 0;
    CSmPlayer@ LocalNativePlayer;

    uint LapsTotal = 1;
    uint CPsPerLap = 0;
    uint CPsToFinishTotal = 0;

    const array<uint>@ GetActualPBCheckpoints() {
        auto ghostData = MLFeed::GetGhostData();
        if (ghostData is null) return null;
        for (uint i = 0; i < ghostData.Ghosts_V2.Length; i++) {
            auto ghost = ghostData.Ghosts_V2[i];
            bool isPB = ghost.IsPersonalBest || ghost.Nickname == "Record personale" || ghost.Nickname == "Personal Best";
            if (isPB) return ghost.Checkpoints;
        }
        return null;
    }

    void CheckTriggers() {
        auto app = GetApp();
        auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);

        if (playground is null || playground.GameTerminals.Length == 0 || playground.Map is null) {
            if (IsRunning) FullReset();
            return;
        }

        auto terminal = playground.GameTerminals[0];
        if (terminal.UISequence_Current != CGamePlaygroundUIConfig::EUISequence::Playing) {
            if (IsRunning) IsRunning = false;
            return;
        }

        auto raceData = MLFeed::GetRaceData_V4();
        if (raceData is null) return;

        if (raceData.Map != CurrentMapUid) {
            CurrentMapUid = raceData.Map;
            FullReset();
            return;
        }

        auto mlPlayer = raceData.LocalPlayer;
        if (mlPlayer is null) return;

        if (int(mlPlayer.StartTime) != LastStartTime) {
            LastStartTime = int(mlPlayer.StartTime);
            LapsTotal = playground.Map.TMObjective_IsLapRace ? playground.Map.TMObjective_NbLaps : 1;
            CPsToFinishTotal = raceData.CPsToFinish;
            if (LapsTotal > 0) CPsPerLap = CPsToFinishTotal / LapsTotal;
            else CPsPerLap = CPsToFinishTotal;

            LastCPCount = 0;
            IsRunning = true;
            LastTickSpeed = 0;
            DebugLog("RACE START");
            return;
        }

        if (!IsRunning || !mlPlayer.IsSpawned) return;

        if (mlPlayer.CpCount > LastCPCount) {
            int currentCp = mlPlayer.CpCount;
            if (currentCp == int(CPsToFinishTotal)) {
                PlayLap(0, true);
                IsRunning = false;
            } else if (LapsTotal > 1 && (currentCp % int(CPsPerLap) == 0)) {
                int lapsRemaining = int(LapsTotal) - (currentCp / int(CPsPerLap));
                PlayLap(lapsRemaining, (lapsRemaining == 1));
            } else {
                auto pbCheckpoints = GetActualPBCheckpoints();
                bool soundPlayed = false;
                int ghostIdx = currentCp - 1;

                if (pbCheckpoints !is null && ghostIdx >= 0 && ghostIdx < int(pbCheckpoints.Length)) {
                    uint pbTime = pbCheckpoints[ghostIdx];
                    if (pbTime > 0) {
                        bool faster = uint(mlPlayer.lastCpTime) <= pbTime;
                        PlaySplit(faster);
                        soundPlayed = true;
                    }
                }
                if (!soundPlayed) PlayGenericCP();
            }
            LastCPCount = currentCp;
        }

        if (Time::Now > LastCrashCheckTime + 100) {
            if (mlPlayer.CurrentRaceTime > 0 && UpdateNativePlayer()) {
                auto api = cast<CSmScriptPlayer@>(LocalNativePlayer.ScriptAPI);
                if (api !is null) {
                    if (LastTickSpeed > 30.0 && api.Speed < LastTickSpeed * (1.0 - S_CarhitSensitivity)) {
                        PlayCarhit();
                        LastTickSpeed = 0;
                    } else {
                        LastTickSpeed = api.Speed;
                    }
                }
            }
            LastCrashCheckTime = Time::Now;
        }
    }

    bool UpdateNativePlayer() {
        if (LocalNativePlayer !is null) return true;
        auto playground = GetApp().CurrentPlayground;
        if (playground is null || playground.GameTerminals.Length == 0) return false;
        @LocalNativePlayer = cast<CSmPlayer@>(playground.GameTerminals[0].ControlledPlayer);
        return LocalNativePlayer !is null;
    }

    void FullReset() {
        IsRunning = false;
        LastStartTime = -1;
        LastCPCount = 0;
        @LocalNativePlayer = null;
    }
}
