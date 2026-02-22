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

    // Medal tracking: 0=none, 1=bronze, 2=silver, 3=gold, 4=author
    int BestMedalEarned = 0;
    // PB init retry state
    bool PBInitPending = false;
    int PBInitRetries = 0;
    const int PBInitMaxRetries = 10;
    uint64 PBInitLastAttemptTime = 0;
    const uint64 PBInitRetryInterval = 500; // ms

    // Prevent playing the same medal multiple times for the same StartTime
    int LastMedalPlayedStartTime = -1;

    // Detect best medal already earned from existing PB
    bool InitBestMedalFromPB() {
        auto app = GetApp();
        auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);
        if (playground is null || playground.Map is null) return false;

        // Try to get PB time from ghost data
        auto ghostData = MLFeed::GetGhostData();
        if (ghostData is null) return false;

        int pbTime = -1;
        for (uint i = 0; i < ghostData.Ghosts_V2.Length; i++) {
            auto ghost = ghostData.Ghosts_V2[i];
            // Only consider ghosts that are PBs or game ghosts AND have completed the track
            if ((ghost.IsPersonalBest || IsGameGhost(ghost.Nickname)) && ghost.Checkpoints.Length >= CPsToFinishTotal && CPsToFinishTotal > 0) {
                // Get the finish time (last checkpoint)
                pbTime = ghost.Checkpoints[ghost.Checkpoints.Length - 1];
                break;
            }
        }

        if (pbTime > 0) {
            BestMedalEarned = GetMedalForTime(playground.Map, pbTime);
            DebugLog("Initialized BestMedalEarned from PB: " + BestMedalEarned + " (time: " + pbTime + ")");
            return true;
        } else {
            BestMedalEarned = 0;
            DebugLog("InitBestMedalFromPB: no complete PB found");
            return false;
        }
    }

    // Checks if ghost nickname is a game-generated ghost (PB, medals, etc.)
    bool IsGameGhost(const string &in nick) {
        // Common game-generated ghost prefixes (skip empty prefix check)
        return nick.StartsWith("$7FA") || nick.StartsWith("$FD8") || nick.StartsWith("$5D8");
    }

    const array<uint>@ GetActualPBCheckpoints() {
        auto ghostData = MLFeed::GetGhostData();
        if (ghostData is null) return null;
        for (uint i = 0; i < ghostData.Ghosts_V2.Length; i++) {
            auto ghost = ghostData.Ghosts_V2[i];
            if ((ghost.IsPersonalBest || IsGameGhost(ghost.Nickname)) && ghost.Checkpoints.Length >= CPsToFinishTotal && CPsToFinishTotal > 0) {
                return ghost.Checkpoints;
            }
        }
        return null;
    }

    // Returns the medal earned for a given time: 4=author, 3=gold, 2=silver, 1=bronze, 0=none
    int GetMedalForTime(CGameCtnChallenge@ map, int finishTime) {
        if (finishTime <= 0) return 0;
        if (map.TMObjective_AuthorTime > 0 && finishTime <= map.TMObjective_AuthorTime) return 4;
        if (map.TMObjective_GoldTime > 0 && finishTime <= map.TMObjective_GoldTime) return 3;
        if (map.TMObjective_SilverTime > 0 && finishTime <= map.TMObjective_SilverTime) return 2;
        if (map.TMObjective_BronzeTime > 0 && finishTime <= map.TMObjective_BronzeTime) return 1;
        return 0;
    }

    void CheckTriggers() {
        auto app = GetApp();
        auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);

        if (playground is null || playground.GameTerminals.Length == 0 || playground.Map is null) {
            if (IsRunning) FullReset();
            return;
        }

        // If PB init is pending (MLFeed wasn't ready at race start), retry periodically
        if (PBInitPending && Time::Now > PBInitLastAttemptTime + PBInitRetryInterval) {
            PBInitLastAttemptTime = Time::Now;
            PBInitRetries++;
            if (InitBestMedalFromPB()) {
                PBInitPending = false;
            } else if (PBInitRetries >= PBInitMaxRetries) {
                PBInitPending = false;
                BestMedalEarned = 0;
                DebugLog("InitBestMedalFromPB: giving up after retries");
            }
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
            @LocalNativePlayer = null; // Reset to get fresh reference

            // Initialize best medal from existing PB (ghost data is loaded at race start)
            bool initOk = InitBestMedalFromPB();
            if (!initOk) {
                PBInitPending = true;
                PBInitRetries = 0;
                PBInitLastAttemptTime = Time::Now;
            } else {
                PBInitPending = false;
            }

            DebugLog("RACE START");
            return;
        }

        if (!IsRunning || !mlPlayer.IsSpawned) return;

        if (mlPlayer.CpCount > LastCPCount) {
            int currentCp = mlPlayer.CpCount;
            if (currentCp == int(CPsToFinishTotal)) {
                // Finish line reached
                int finishTime = mlPlayer.lastCpTime;
                int medal = GetMedalForTime(playground.Map, finishTime);

                // Only play if we earned a NEW (better) medal
                if (medal > BestMedalEarned) {
                    BestMedalEarned = medal;
                    // Play medal only once per StartTime
                    if (medal > 0 && LastMedalPlayedStartTime != LastStartTime) {
                        PlayMedal(medal);
                        LastMedalPlayedStartTime = LastStartTime;
                    }
                }
                IsRunning = false;
            } else if (LapsTotal > 1 && (currentCp % int(CPsPerLap) == 0)) {
                int lapsRemaining = int(LapsTotal) - (currentCp / int(CPsPerLap));
                PlayLap(lapsRemaining, (lapsRemaining == 1));
            } else {
                // Checkpoint sound logic with intervals
                bool shouldPlaySound = ShouldPlayCPSound(currentCp);

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
        BestMedalEarned = 0;
        @LocalNativePlayer = null;
        // reset PB init and medal-play state
        PBInitPending = false;
        PBInitRetries = 0;
        PBInitLastAttemptTime = 0;
        LastMedalPlayedStartTime = -1;
    }

    // CP sound interval logic:
    // NextCPToPlay starts at 0 (first CP). When currentCp matches, play sound
    // and set next trigger 2-4 CPs ahead.
    bool ShouldPlayCPSound(int currentCp) {
        if (S_CheckpointsAlways) return true;

        if (currentCp == NextCPToPlay) {
            NextCPToPlay = currentCp + Math::Rand(2, 5); // next in 2-4 CPs
            return true;
        }
        return false;
    }
}
