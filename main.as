void Main() {
    print("[RaceSound] INITIALIZING...");
    LoadSamples();
    while (true) {
        RaceLogic::CheckTriggers();
        yield();
    }
}