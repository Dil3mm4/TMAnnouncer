void Main() {
    print("[RaceSound] INITIALIZING...");
    LoadSamples();
    LastCustomSoundsEnabled = S_CustomSoundsEnabled;
    while (true) {
        OnSettingsChanged();
        RaceLogic::CheckTriggers();
        yield();
    }
}
