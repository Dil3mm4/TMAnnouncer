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
    bool MedalBaselineKnown = false;
    array<uint> CachedPBCheckpoints;
    int CachedPBFinishTime = -1;

    // PB init retry state
    bool PBInitPending = false;
    int PBInitRetries = 0;
    const int PBInitMaxRetries = 10;
    uint64 PBInitLastAttemptTime = 0;
    const uint64 PBInitRetryInterval = 500; // ms

    // Prevent playing the same medal multiple times for the same StartTime
    int LastMedalPlayedStartTime = -1;

    void CacheGhostData(const MLFeed::GhostInfo_V2@ ghost, int finishTime) {
        CachedPBCheckpoints.Resize(ghost.Checkpoints.Length);
        for (uint i = 0; i < ghost.Checkpoints.Length; i++) {
            CachedPBCheckpoints[i] = ghost.Checkpoints[i];
        }
        CachedPBFinishTime = finishTime;
    }

    int ResolveGhostFinishTime(const MLFeed::GhostInfo_V2@ ghost) {
        if (ghost.Result_Time > 0) {
            return ghost.Result_Time;
        }
        if (CPsToFinishTotal > 0 && ghost.Checkpoints.Length >= CPsToFinishTotal) {
            uint cpFinish = ghost.Checkpoints[CPsToFinishTotal - 1];
            if (cpFinish > 0) {
                return int(cpFinish);
            }
        }
        return -1;
    }

    bool GhostMatchesCriteria(const MLFeed::GhostInfo_V2@ ghost, bool requirePersonalBest, bool requireLocalPlayer, bool requireLocalLoginId, uint localLoginId) {
        if (ghost is null) {
            return false;
        }
        if (requirePersonalBest && !ghost.IsPersonalBest) {
            return false;
        }
        if (requireLocalPlayer && !ghost.IsLocalPlayer) {
            return false;
        }
        if (requireLocalLoginId && ghost.IdUint != localLoginId) {
            return false;
        }
        return true;
    }

    bool TryFindBestGhostInList(
        const array<MLFeed::GhostInfo_V2@>@ ghosts,
        bool requirePersonalBest,
        bool requireLocalPlayer,
        bool requireLocalLoginId,
        uint localLoginId,
        MLFeed::GhostInfo_V2@ &out bestGhost,
        int &out bestFinishTime,
        uint &out validCandidates
    ) {
        @bestGhost = null;
        bestFinishTime = -1;
        validCandidates = 0;

        for (uint i = 0; i < ghosts.Length; i++) {
            auto ghost = ghosts[i];
            if (!GhostMatchesCriteria(ghost, requirePersonalBest, requireLocalPlayer, requireLocalLoginId, localLoginId)) {
                continue;
            }

            int finishTime = ResolveGhostFinishTime(ghost);
            if (finishTime <= 0) {
                continue;
            }

            validCandidates++;
            if (bestFinishTime < 0 || finishTime < bestFinishTime) {
                bestFinishTime = finishTime;
                @bestGhost = ghost;
            }
        }

        return bestGhost !is null;
    }

    bool TryCacheBestGhostByCriteria(const MLFeed::SharedGhostDataHook_V2@ ghostData, bool requirePersonalBest, bool requireLocalPlayer, bool requireLocalLoginId, uint localLoginId, const string &in sourceTag) {
        MLFeed::GhostInfo_V2@ bestSortedGhost = null;
        MLFeed::GhostInfo_V2@ bestLoadedGhost = null;
        int sortedFinishTime = -1;
        int loadedFinishTime = -1;
        uint sortedCandidates = 0;
        uint loadedCandidates = 0;

        bool hasSorted = TryFindBestGhostInList(
            ghostData.SortedGhosts,
            requirePersonalBest,
            requireLocalPlayer,
            requireLocalLoginId,
            localLoginId,
            bestSortedGhost,
            sortedFinishTime,
            sortedCandidates
        );
        bool hasLoaded = TryFindBestGhostInList(
            ghostData.LoadedGhosts,
            requirePersonalBest,
            requireLocalPlayer,
            requireLocalLoginId,
            localLoginId,
            bestLoadedGhost,
            loadedFinishTime,
            loadedCandidates
        );

        if (!hasSorted && !hasLoaded) {
            return false;
        }

        bool useSorted = hasSorted && (!hasLoaded || sortedFinishTime <= loadedFinishTime);
        MLFeed::GhostInfo_V2@ selectedGhost = useSorted ? bestSortedGhost : bestLoadedGhost;
        int selectedTime = useSorted ? sortedFinishTime : loadedFinishTime;

        CacheGhostData(selectedGhost, selectedTime);
        DebugLog(
            "PB source selected: "
            + sourceTag
            + " (" + Time::Format(uint(CachedPBFinishTime)) + ")"
            + " | selectedFrom=" + (useSorted ? "SortedGhosts" : "LoadedGhosts")
            + " | candidates sorted/loaded=" + tostring(sortedCandidates) + "/" + tostring(loadedCandidates)
        );
        return true;
    }

    bool RefreshCachedPBData() {
        const MLFeed::SharedGhostDataHook_V2@ ghostData = MLFeed::GetGhostData();
        CachedPBCheckpoints.Resize(0);
        CachedPBFinishTime = -1;

        if (ghostData is null || CPsToFinishTotal == 0) {
            return false;
        }
        uint localLoginId = MLFeed::LocalPlayersLoginIdValue;
        bool hasLocalLoginId = localLoginId != 0xFFFFFFFF;

        // Primary path: PB flag + local login-id when available.
        if (hasLocalLoginId && TryCacheBestGhostByCriteria(ghostData, true, false, true, localLoginId, "PersonalBest+LocalLoginId")) {
            return true;
        }

        // Fallback 1: PB flag + local-player marker.
        if (TryCacheBestGhostByCriteria(ghostData, true, true, false, localLoginId, "PersonalBest+IsLocalPlayer")) {
            return true;
        }

        // Fallback 2: local login-id match (covers cases where PB flags are missing).
        if (hasLocalLoginId && TryCacheBestGhostByCriteria(ghostData, false, false, true, localLoginId, "LocalLoginId")) {
            return true;
        }

        // Fallback 3: local-player ghost marker.
        if (TryCacheBestGhostByCriteria(ghostData, false, true, false, localLoginId, "IsLocalPlayer")) {
            return true;
        }

        return false;
    }

    // Detect best medal already earned from existing PB
    bool InitBestMedalFromPB() {
        auto app = GetApp();
        auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);
        if (playground is null || playground.Map is null) {
            return false;
        }

        if (!RefreshCachedPBData()) {
            BestMedalEarned = 0;
            DebugLog("InitBestMedalFromPB: no usable complete ghost found");
            return false;
        }

        BestMedalEarned = GetMedalForTime(playground.Map, CachedPBFinishTime);
        DebugLog("Initialized BestMedalEarned from PB: " + BestMedalEarned + " (time: " + CachedPBFinishTime + ")");
        return true;
    }

    const array<uint>@ GetActualPBCheckpoints() {
        if (CachedPBCheckpoints.Length >= CPsToFinishTotal && CPsToFinishTotal > 0) {
            return CachedPBCheckpoints;
        }

        if (RefreshCachedPBData()) {
            return CachedPBCheckpoints;
        }

        return null;
    }

    string MedalName(int medal) {
        switch (medal) {
            case 4: return "Author";
            case 3: return "Gold";
            case 2: return "Silver";
            case 1: return "Bronze";
        }
        return "None";
    }

    // Returns the medal earned for a given time: 4=author, 3=gold, 2=silver, 1=bronze, 0=none
    int GetMedalForTime(CGameCtnChallenge@ map, int finishTime) {
        if (finishTime <= 0) {
            return 0;
        }
        if (map.TMObjective_AuthorTime > 0 && finishTime <= map.TMObjective_AuthorTime) {
            return 4;
        }
        if (map.TMObjective_GoldTime > 0 && finishTime <= map.TMObjective_GoldTime) {
            return 3;
        }
        if (map.TMObjective_SilverTime > 0 && finishTime <= map.TMObjective_SilverTime) {
            return 2;
        }
        if (map.TMObjective_BronzeTime > 0 && finishTime <= map.TMObjective_BronzeTime) {
            return 1;
        }
        return 0;
    }

    void CheckTriggers() {
        auto app = GetApp();
        auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);

        if (playground is null || playground.GameTerminals.Length == 0 || playground.Map is null) {
            if (IsRunning) {
                FullReset();
            }
            return;
        }

        // If PB init is pending (MLFeed wasn't ready at race start), retry periodically
        if (PBInitPending && Time::Now > PBInitLastAttemptTime + PBInitRetryInterval) {
            PBInitLastAttemptTime = Time::Now;
            PBInitRetries++;
            DebugLog("PB init retry " + tostring(PBInitRetries) + "/" + tostring(PBInitMaxRetries));
            if (InitBestMedalFromPB()) {
                PBInitPending = false;
                MedalBaselineKnown = true;
                DebugLog("PB init retry succeeded");
            } else if (PBInitRetries >= PBInitMaxRetries) {
                PBInitPending = false;
                BestMedalEarned = 0;
                MedalBaselineKnown = false;
                DebugLog("InitBestMedalFromPB: giving up after retries (" + tostring(PBInitRetries) + "/" + tostring(PBInitMaxRetries) + ")");
            }
        }

        auto terminal = playground.GameTerminals[0];
        if (terminal.UISequence_Current != CGamePlaygroundUIConfig::EUISequence::Playing) {
            if (IsRunning) {
                IsRunning = false;
            }
            return;
        }

        auto raceData = MLFeed::GetRaceData_V4();
        if (raceData is null) {
            return;
        }

        if (raceData.Map != CurrentMapUid) {
            CurrentMapUid = raceData.Map;
            DebugLog("Map changed, resetting state for map " + CurrentMapUid);
            FullReset();
            return;
        }

        auto mlPlayer = raceData.LocalPlayer;
        if (mlPlayer is null) {
            return;
        }

        if (int(mlPlayer.StartTime) != LastStartTime) {
            LastStartTime = int(mlPlayer.StartTime);
            LapsTotal = playground.Map.TMObjective_IsLapRace ? playground.Map.TMObjective_NbLaps : 1;
            CPsToFinishTotal = raceData.CPsToFinish;
            if (LapsTotal > 0) {
                CPsPerLap = CPsToFinishTotal / LapsTotal;
            } else {
                CPsPerLap = CPsToFinishTotal;
            }
            CachedPBCheckpoints.Resize(0);
            CachedPBFinishTime = -1;

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
                MedalBaselineKnown = false;
                DebugLog("PB init pending at race start: waiting for MLFeed ghost data");
            } else {
                PBInitPending = false;
                MedalBaselineKnown = true;
                DebugLog("PB init completed at race start: baseline medal = " + MedalName(BestMedalEarned));
            }

            DebugLog(
                "RACE START"
                + " | map=" + CurrentMapUid
                + " | laps=" + tostring(LapsTotal)
                + " | cpsToFinish=" + tostring(CPsToFinishTotal)
            );
            return;
        }

        if (!IsRunning || !mlPlayer.IsSpawned) {
            return;
        }

        if (mlPlayer.CpCount > LastCPCount) {
            int currentCp = mlPlayer.CpCount;
            bool canCheckLapTrigger = LapsTotal > 1 && CPsPerLap > 0;
            if (currentCp == int(CPsToFinishTotal)) {
                // Finish line reached
                int finishTime = mlPlayer.lastCpTime;
                int medal = GetMedalForTime(playground.Map, finishTime);
                DebugLog(
                    "Finish reached: time=" + Time::Format(uint(finishTime))
                    + " | medal=" + MedalName(medal)
                    + " | baselineKnown=" + tostring(MedalBaselineKnown)
                    + " | bestBefore=" + MedalName(BestMedalEarned)
                );

                // If we could not initialize from PB data, learn the baseline silently
                // from the first completed run to avoid false medal announcements.
                if (!MedalBaselineKnown) {
                    BestMedalEarned = medal;
                    MedalBaselineKnown = true;
                    DebugLog("Medal baseline learned from current run: " + medal + " (no medal sound)");
                } else {
                    // Only play if we earned a NEW (better) medal
                    if (medal > BestMedalEarned) {
                        int previousBest = BestMedalEarned;
                        BestMedalEarned = medal;
                        DebugLog("New best medal: " + MedalName(previousBest) + " -> " + MedalName(medal));
                        // Play medal only once per StartTime
                        if (medal > 0 && LastMedalPlayedStartTime != LastStartTime) {
                            DebugLog("Playing medal sound for " + MedalName(medal));
                            PlayMedal(medal);
                            LastMedalPlayedStartTime = LastStartTime;
                        } else if (medal <= 0) {
                            DebugLog("Skipping medal sound because medal is None");
                        } else {
                            DebugLog("Skipping medal sound because this run already played one");
                        }
                    } else {
                        DebugLog("No medal improvement at finish");
                    }
                }
                IsRunning = false;
            } else if (canCheckLapTrigger && (currentCp % int(CPsPerLap) == 0)) {
                int lapsRemaining = int(LapsTotal) - (currentCp / int(CPsPerLap));
                DebugLog("Lap checkpoint reached: laps remaining " + tostring(lapsRemaining));
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
                            int deltaMs = int(mlPlayer.lastCpTime) - int(pbTime);
                            DebugLog(
                                "CP " + tostring(currentCp)
                                + ": split " + Time::Format(uint(mlPlayer.lastCpTime))
                                + " vs PB " + Time::Format(pbTime)
                                + " (" + tostring(deltaMs) + " ms)"
                                + " -> " + (faster ? "faster/equal" : "slower")
                            );
                            PlaySplit(faster);
                            soundPlayed = true;
                        } else {
                            DebugLog("CP " + tostring(currentCp) + ": PB checkpoint is 0, using generic checkpoint sound");
                        }
                    } else if (pbCheckpoints is null) {
                        DebugLog("CP " + tostring(currentCp) + ": PB checkpoints unavailable, using generic checkpoint sound");
                    } else {
                        DebugLog(
                            "CP " + tostring(currentCp)
                            + ": PB checkpoint index " + tostring(ghostIdx)
                            + " out of range (len=" + tostring(pbCheckpoints.Length) + "), using generic checkpoint sound"
                        );
                    }

                    if (!soundPlayed) {
                        PlayGenericCP();
                    }
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
        if (LocalNativePlayer !is null) {
            return true;
        }

        auto playground = GetApp().CurrentPlayground;
        if (playground is null || playground.GameTerminals.Length == 0) {
            return false;
        }

        @LocalNativePlayer = cast<CSmPlayer@>(playground.GameTerminals[0].ControlledPlayer);
        return LocalNativePlayer !is null;
    }

    void FullReset() {
        IsRunning = false;
        LastStartTime = -1;
        LastCPCount = 0;
        NextCPToPlay = 0;
        BestMedalEarned = 0;
        MedalBaselineKnown = false;
        CachedPBCheckpoints.Resize(0);
        CachedPBFinishTime = -1;
        @LocalNativePlayer = null;

        // Reset PB init and medal-play state
        PBInitPending = false;
        PBInitRetries = 0;
        PBInitLastAttemptTime = 0;
        LastMedalPlayedStartTime = -1;
    }

    // CP sound interval logic:
    // NextCPToPlay starts at 0 (first CP). When currentCp matches, play sound
    // and set next trigger 2-4 CPs ahead.
    bool ShouldPlayCPSound(int currentCp) {
        if (S_CheckpointsAlways) {
            return true;
        }

        if (currentCp == NextCPToPlay) {
            NextCPToPlay = currentCp + Math::Rand(2, 5); // next in 2-4 CPs
            return true;
        }

        return false;
    }
}
