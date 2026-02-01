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
    int NextCPToPlay = 0;

    const array<uint>@ GetActualPBCheckpoints() {
        auto ghostData = MLFeed::GetGhostData();
        if (ghostData is null) return null;
        for (uint i = 0; i < ghostData.Ghosts_V2.Length; i++) {
            auto ghost = ghostData.Ghosts_V2[i];
            if (ghost.IsPersonalBest) return ghost.Checkpoints;
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
            NextCPToPlay = 1;
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
                // Checkpoint sound logic with intervals
                bool shouldPlaySound = ShouldPlayCPSound(currentCp, int(CPsToFinishTotal));

                if (shouldPlaySound) {
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
        NextCPToPlay = 0;
        @LocalNativePlayer = null;
    }

    // CP sound interval logic:
    // - 2 CPs (0,1): play only on first (CP 1)
    // - 3 CPs (0,1,2): play on first (CP 1), 33% chance on second (CP 2)
    // - 4+ CPs: play every 2-4 CPs interval
    bool ShouldPlayCPSound(int currentCp, int totalCPs) {
        if (S_CheckpointsAlways) return true;

        int numCPs = totalCPs; // CPs before finish

        if (numCPs <= 2) {
            // Only play on first CP
            return currentCp == 1;
        } else if (numCPs == 3) {
            // Play on first, 33% on second
            if (currentCp == 1) return true;
            if (currentCp == 2) return Math::Rand(0, 3) == 0;
            return false;
        } else {
            // 4+ CPs: interval logic
            if (currentCp >= NextCPToPlay) {
                NextCPToPlay = currentCp + Math::Rand(2, 5); // next in 2-4 CPs
                return true;
            }
            return false;
        }
    }
}
