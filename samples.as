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

void UpdateVolume() {
    float master = 1.0f;
    auto app = GetApp();
    if (S_IngameSound && app.AudioPort !is null) {
        master = app.AudioPort.SoundVolume;
    }
    SoundVolumeValue = master * S_SoundMultiplier * (float(S_VoiceVolume) / 100.0f);
    if (SoundVolumeValue < 0.01) SoundVolumeValue = 0.01;
}

void LoadSamples() {
    DebugLog("Loading internal audio assets...");

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

    DebugLog("Assets loaded.");
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
        if (LapFinalSample !is null) Audio::Play(LapFinalSample, SoundVolumeValue);
    } else if (remaining >= 2 && remaining <= COUNT_LAP_NUMBERED) {
        if (LapNumberedSamples[remaining] !is null) Audio::Play(LapNumberedSamples[remaining], SoundVolumeValue);
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
