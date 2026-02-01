// Trackmania Turbo Announcer plugin by TheGeekid

void Main() {
    Init();
    
    while (true) {
        Update();
        sleep(S_Heartbeat);
    }
}

void Init() {
    LoadSamples();
}

void Update() {
    CheckTriggers();
}