array<Audio::Sample@> CarhitSamples;
array<Audio::Sample@> CPSamples;
array<Audio::Sample@> CPNoSamples;
array<Audio::Sample@> CPYesSamples;
array<Audio::Sample@> LapNumberedSamples;
Audio::Sample@ LapFinalSample;
Audio::Sample@ MedalAuthorSample;
Audio::Sample@ MedalGoldSample;
Audio::Sample@ MedalSilverSample;
Audio::Sample@ MedalBronzeSample;

float SoundVolumeValue = 1.0f;
string CustomSoundsPath = "";

void UpdateVolume() {
    // Plugin master volume (0-100 -> 0.0-1.0)
    float volume = float(S_VoiceVolume) / 100.0f;

    // Apply gain multiplier for fine-tuning
    volume *= S_SoundMultiplier;

    // Clamp to valid range
    if (volume < 0.01f) volume = 0.01f;
    if (volume > 2.0f) volume = 2.0f;

    SoundVolumeValue = volume;
}

// Create custom sounds folder structure if it doesn't exist
void EnsureCustomFoldersExist() {
    if (!IO::FolderExists(CustomSoundsPath))
        IO::CreateFolder(CustomSoundsPath);
    if (!IO::FolderExists(CustomSoundsPath + CUSTOM_FOLDER_CARHIT))
        IO::CreateFolder(CustomSoundsPath + CUSTOM_FOLDER_CARHIT);
    if (!IO::FolderExists(CustomSoundsPath + CUSTOM_FOLDER_CHECKPOINT))
        IO::CreateFolder(CustomSoundsPath + CUSTOM_FOLDER_CHECKPOINT);
    if (!IO::FolderExists(CustomSoundsPath + CUSTOM_FOLDER_CHECKPOINT_YES))
        IO::CreateFolder(CustomSoundsPath + CUSTOM_FOLDER_CHECKPOINT_YES);
    if (!IO::FolderExists(CustomSoundsPath + CUSTOM_FOLDER_CHECKPOINT_NO))
        IO::CreateFolder(CustomSoundsPath + CUSTOM_FOLDER_CHECKPOINT_NO);
    if (!IO::FolderExists(CustomSoundsPath + CUSTOM_FOLDER_LAP))
        IO::CreateFolder(CustomSoundsPath + CUSTOM_FOLDER_LAP);
    if (!IO::FolderExists(CustomSoundsPath + CUSTOM_FOLDER_MEDAL))
        IO::CreateFolder(CustomSoundsPath + CUSTOM_FOLDER_MEDAL);
    DebugLog("Custom folders structure ensured at: " + CustomSoundsPath);
}

// Load .wav files from a custom folder using absolute paths
array<Audio::Sample@> LoadCustomFolder(const string &in folderName) {
    array<Audio::Sample@> samples;
    string folderPath = CustomSoundsPath + folderName + "/";

    if (!IO::FolderExists(folderPath)) {
        DebugLog("Custom folder not found: " + folderName);
        return samples;
    }

    auto files = IO::IndexFolder(folderPath, false);
    for (uint i = 0; i < files.Length; i++) {
        string fullPath = files[i]; // IndexFolder returns full absolute paths
        if (fullPath.ToLower().EndsWith(".wav")) {
            auto sample = Audio::LoadSampleFromAbsolutePath(fullPath);
            if (sample !is null) {
                samples.InsertLast(sample);
                DebugLog("Loaded custom: " + fullPath);
            }
        }
    }

    DebugLog("Custom " + folderName + ": " + samples.Length + " files");
    return samples;
}

// Load medal samples from custom folder with pattern matching
void LoadCustomMedals() {
    string folderPath = CustomSoundsPath + CUSTOM_FOLDER_MEDAL + "/";

    if (!IO::FolderExists(folderPath)) return;

    auto files = IO::IndexFolder(folderPath, false);
    for (uint i = 0; i < files.Length; i++) {
        string fullPath = files[i]; // IndexFolder returns full absolute paths
        string fileLower = fullPath.ToLower();
        if (!fileLower.EndsWith(".wav")) continue;

        if (fileLower.Contains("author")) {
            @MedalAuthorSample = Audio::LoadSampleFromAbsolutePath(fullPath);
            DebugLog("Custom medal author: " + fullPath);
        } else if (fileLower.Contains("gold")) {
            @MedalGoldSample = Audio::LoadSampleFromAbsolutePath(fullPath);
            DebugLog("Custom medal gold: " + fullPath);
        } else if (fileLower.Contains("silver")) {
            @MedalSilverSample = Audio::LoadSampleFromAbsolutePath(fullPath);
            DebugLog("Custom medal silver: " + fullPath);
        } else if (fileLower.Contains("bronze")) {
            @MedalBronzeSample = Audio::LoadSampleFromAbsolutePath(fullPath);
            DebugLog("Custom medal bronze: " + fullPath);
        }
    }
}

// Load lap samples from custom folder
void LoadCustomLaps() {
    string folderPath = CustomSoundsPath + CUSTOM_FOLDER_LAP + "/";

    if (!IO::FolderExists(folderPath)) return;

    auto files = IO::IndexFolder(folderPath, false);
    LapNumberedSamples.Resize(0);

    for (uint i = 0; i < files.Length; i++) {
        string fullPath = files[i]; // IndexFolder returns full absolute paths
        string fileLower = fullPath.ToLower();
        if (!fileLower.EndsWith(".wav")) continue;

        if (fileLower.Contains("final")) {
            @LapFinalSample = Audio::LoadSampleFromAbsolutePath(fullPath);
            DebugLog("Custom lap final: " + fullPath);
        } else {
            // Any other lap sound goes to numbered array
            auto sample = Audio::LoadSampleFromAbsolutePath(fullPath);
            if (sample !is null) {
                LapNumberedSamples.InsertLast(sample);
                DebugLog("Custom lap: " + fullPath);
            }
        }
    }
}

// Load default samples from plugin assets
void LoadDefaultSamples() {
    CarhitSamples.Resize(COUNT_CARHIT);
    for (int i = 1; i <= COUNT_CARHIT; i++)
        @CarhitSamples[i - 1] = Audio::LoadSample(ASSETS_PATH + VOICE_CARHIT + i + FILE_EXT);

    CPSamples.Resize(COUNT_CP_GENERIC);
    for (int i = 1; i <= COUNT_CP_GENERIC; i++)
        @CPSamples[i - 1] = Audio::LoadSample(ASSETS_PATH + VOICE_CHECKPOINT + i + FILE_EXT);

    CPNoSamples.Resize(COUNT_CP_NO);
    for (int i = 1; i <= COUNT_CP_NO; i++)
        @CPNoSamples[i - 1] = Audio::LoadSample(ASSETS_PATH + VOICE_CHECKPOINT_NO + i + FILE_EXT);

    CPYesSamples.Resize(COUNT_CP_YES);
    for (int i = 1; i <= COUNT_CP_YES; i++)
        @CPYesSamples[i - 1] = Audio::LoadSample(ASSETS_PATH + VOICE_CHECKPOINT_YES + i + FILE_EXT);

    @LapFinalSample = Audio::LoadSample(ASSETS_PATH + VOICE_LAP_FINAL + FILE_EXT);

    LapNumberedSamples.Resize(COUNT_LAP_NUMBERED + 1);
    for (int i = 2; i <= COUNT_LAP_NUMBERED; i++)
        @LapNumberedSamples[i] = Audio::LoadSample(ASSETS_PATH + VOICE_LAP + i + FILE_EXT);

    @MedalAuthorSample = Audio::LoadSample(ASSETS_PATH + VOICE_MEDAL_AUTHOR + FILE_EXT);
    @MedalGoldSample = Audio::LoadSample(ASSETS_PATH + VOICE_MEDAL_GOLD + FILE_EXT);
    @MedalSilverSample = Audio::LoadSample(ASSETS_PATH + VOICE_MEDAL_SILVER + FILE_EXT);
    @MedalBronzeSample = Audio::LoadSample(ASSETS_PATH + VOICE_MEDAL_BRONZE + FILE_EXT);
}

void LoadSamples() {
    DebugLog("Loading audio assets...");

    // Initialize custom sounds path and create folder structure
    CustomSoundsPath = IO::FromStorageFolder("CustomSounds/");
    EnsureCustomFoldersExist();

    if (S_CustomSoundsEnabled) {
        // Custom mode: load ONLY from custom folders, no fallback
        DebugLog("Custom sounds enabled. Loading from: " + CustomSoundsPath);

        CarhitSamples = LoadCustomFolder(CUSTOM_FOLDER_CARHIT);
        CPSamples = LoadCustomFolder(CUSTOM_FOLDER_CHECKPOINT);
        CPYesSamples = LoadCustomFolder(CUSTOM_FOLDER_CHECKPOINT_YES);
        CPNoSamples = LoadCustomFolder(CUSTOM_FOLDER_CHECKPOINT_NO);

        // Laps
        LapNumberedSamples.Resize(0);
        @LapFinalSample = null;
        LoadCustomLaps();

        // Medals
        @MedalAuthorSample = null;
        @MedalGoldSample = null;
        @MedalSilverSample = null;
        @MedalBronzeSample = null;
        LoadCustomMedals();

        DebugLog("Custom assets loaded.");
    } else {
        // Default mode: load built-in assets
        LoadDefaultSamples();
        DebugLog("Default assets loaded.");
    }

    DebugLog("All assets loaded.");
}

void PlayRandom(array<Audio::Sample@>@ samples, const string &in category) {
    UpdateVolume();
    if (samples.Length == 0) return;
    int idx = Math::Rand(0, int(samples.Length));
    if (samples[idx] !is null) {
        DebugLog("ACTION: Playing " + category);
        Audio::Play(samples[idx], SoundVolumeValue);
    }
}

void PlayCarhit() { if (S_CarhitEnabled) PlayRandom(CarhitSamples, "Crash"); }
void PlayGenericCP() { if (S_CheckpointsEnabled) PlayRandom(CPSamples, "Generic CP"); }

void PlaySplit(bool faster) {
    if (!S_CheckpointsEnabled) return;
    PlayRandom(faster ? CPYesSamples : CPNoSamples, faster ? "Faster Split" : "Slower Split");
}

void PlayLap(int remaining, bool isFinal) {
    if (!S_LapsEnabled) return;
    UpdateVolume();
    if (isFinal) {
        if (LapFinalSample !is null) {
            DebugLog("ACTION: Playing Final Lap");
            Audio::Play(LapFinalSample, SoundVolumeValue);
        }
    } else if (LapNumberedSamples.Length > 0) {
        // For custom sounds: play random from available lap sounds
        // For default: use indexed access (remaining maps to index)
        if (S_CustomSoundsEnabled && LapNumberedSamples.Length > 0) {
            int idx = Math::Rand(0, int(LapNumberedSamples.Length));
            if (LapNumberedSamples[idx] !is null) {
                DebugLog("ACTION: Playing Lap (custom)");
                Audio::Play(LapNumberedSamples[idx], SoundVolumeValue);
            }
        } else if (remaining >= 2 && remaining < int(LapNumberedSamples.Length) && LapNumberedSamples[remaining] !is null) {
            DebugLog("ACTION: Playing Lap " + remaining);
            Audio::Play(LapNumberedSamples[remaining], SoundVolumeValue);
        }
    }
}

// Medal enum: 0=none, 1=bronze, 2=silver, 3=gold, 4=author
void PlayMedal(int medal) {
    if (!S_MedalsEnabled) return;
    UpdateVolume();
    Audio::Sample@ sample = null;
    string medalName = "";
    switch (medal) {
        case 4: @sample = MedalAuthorSample; medalName = "Author"; break;
        case 3: @sample = MedalGoldSample; medalName = "Gold"; break;
        case 2: @sample = MedalSilverSample; medalName = "Silver"; break;
        case 1: @sample = MedalBronzeSample; medalName = "Bronze"; break;
    }
    if (sample !is null) {
        DebugLog("ACTION: Playing Medal " + medalName);
        Audio::Play(sample, SoundVolumeValue);
    }
}
