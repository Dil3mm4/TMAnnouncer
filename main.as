void Main() {
    print("[TMAnnouncer] INITIALIZING...");
    LoadSamples();
    LastCustomSoundsEnabled = S_CustomSoundsEnabled;
    while (true) {
        OnSettingsChanged();
        RaceLogic::CheckTriggers();
        yield();
    }
}
