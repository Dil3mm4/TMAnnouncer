array<Audio::Sample@> CarhitSamples(VHitCount);
array<Audio::Sample@> CPSamples(VCPCount);
array<Audio::Sample@> CPYesSamples(VCPYesCount);
array<Audio::Sample@> CPNoSamples(VCPNoCount);
array<Audio::Sample@> LapSamples(VLapCount);
float SoundVolume;


void LoadSamples() {
    // Carhit
    for (int i = 1; i <= VHitCount; i++) {
        @CarhitSamples[i - 1] = Audio::LoadSample(Path + VoiceCarhit + tostring(i) + FileExt);
    }

    // Checkpoint
    for (int i = 1; i <= VCPCount; i++) {
        @CPSamples[i - 1] = Audio::LoadSample(Path + VoiceCheckpoint + tostring(i) + FileExt);
    }

    // CP Yes
    for (int i = 1; i <= VCPYesCount; i++) {
        @CPYesSamples[i - 1] = Audio::LoadSample(Path + VoiceCheckpointYes + tostring(i) + FileExt);
    }

    // CP No
    for (int i = 1; i <= VCPNoCount; i++) {
        @CPNoSamples[i - 1] = Audio::LoadSample(Path + VoiceCheckpointNo + tostring(i) + FileExt);
    }

    // Laps
    @LapSamples[0] = Audio::LoadSample(Path + VoiceLap + "final" + FileExt);
    for (int i = 2; i <= VLapCount; i++) {
        @LapSamples[i - 1] = Audio::LoadSample(Path + VoiceLap + tostring(i) + FileExt);
    }
}

void PlayCarhit() {
    if (!S_CarhitEnabled) return;
    sleep(DelayCarhitVoice);
    UpdateVolume();
    int Index = Math::Rand(0, VHitCount);
    Audio::Play(CarhitSamples[Index], SoundVolume);
}

void PlayCheckpoint() {
    if (!S_CheckpointsEnabled) return;
    sleep(DelayCheckpointVoice);
    UpdateVolume();
    int Index = Math::Rand(0, VCPCount);
    Audio::Play(CPSamples[Index], SoundVolume);
}

void PlayCheckpointYes() {
    if (!S_CheckpointsEnabled) return;
    sleep(DelayCheckpointVoice);
    UpdateVolume();
    int Index = Math::Rand(0, VCPYesCount);
    Audio::Play(CPYesSamples[Index], SoundVolume);
}

void PlayCheckpointNo() {
    if (!S_CheckpointsEnabled) return;
    sleep(DelayCheckpointVoice);
    UpdateVolume();
    int Index = Math::Rand(0, VCPNoCount);
    Audio::Play(CPNoSamples[Index], SoundVolume);
}

void PlayLap(int LapsRemaining, bool IsRaceStart) {
    if (!S_LapsEnabled) return;
    if (IsRaceStart) {
        sleep(DelayLapsVoice);
    }
    UpdateVolume();
    Audio::Play(LapSamples[LapsRemaining - 1], SoundVolume);
}

void UpdateVolume() {
    auto MasterSound = GetApp().SystemOverlay.MasterSoundVolume;

    // Sound volume ranges from -40 to 0
    // It can also be -100 at 0%
    // Update: this is measured in dB
    if (MasterSound <= -100.0) {
        MasterSound = -40.0;
    }

    if (!S_IngameSound) {
        MasterSound = 0.0;
    }

    SoundVolume = (40.0 + MasterSound) / 40 * S_SoundMultiplier * (S_VoiceVolume / 100.0);
}