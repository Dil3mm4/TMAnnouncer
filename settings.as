[Setting category="General" name="Master Volume" min=0 max=100]
int S_VoiceVolume = 50;

[Setting category="General" name="Scale with In-game Sound Volume" description="Scale plugin volume with the game's Sound slider (not Music)."]
bool S_ScaleWithGame = false;

[Setting category="General" name="Sound Gain Multiplier" min=0.1 max=2.0]
float S_SoundMultiplier = 1.0;

[Setting category="Advanced" name="Crash Sensitivity" min=0.1 max=1.0]
float S_CarhitSensitivity = 0.6;

[Setting category="Advanced" name="Debug Mode"]
bool S_DebugMode = false;

[Setting category="Advanced" name="Show Debug Window" description="Show a live debug window with PB init and medal baseline state."]
bool S_ShowDebugWindow = false;

[Setting category="Features" name="Enable Crash Sounds"]
bool S_CarhitEnabled = true;

[Setting category="Features" name="Enable Checkpoint Sounds"]
bool S_CheckpointsEnabled = true;

[Setting category="Features" name="Always Play on Every Checkpoint" description="When disabled, sounds play at random intervals (every 2-4 checkpoints) to avoid being repetitive on long tracks."]
bool S_CheckpointsAlways = true;

[Setting category="Features" name="Enable Lap Sounds"]
bool S_LapsEnabled = true;

[Setting category="Features" name="Enable Medal Sounds"]
bool S_MedalsEnabled = true;

// Custom sounds is now auto-enabled when a pack other than Default is selected
bool S_CustomSoundsEnabled = false;

bool LastCustomSoundsEnabled = false;
const uint DEBUG_LOG_MAX_LINES = 300;
array<string> g_DebugWindowLines;

[SettingsTab name="Manual Sound Pack Guide" order="99"]
void RenderCustomSoundsGuide() {
    UI::TextWrapped("\\$ff0Custom Sounds\\$z lets you use your own .wav files instead of the built-in voice lines.");
    UI::TextWrapped("\\$888For an easier approach, see the \\$fffSound Packs\\$888 tab to download pre-made packs!");
    UI::Separator();

    UI::TextWrapped("\\$aaaFolder location:");
    UI::TextWrapped("\\$fff  OpenplanetNext/PluginStorage/TMTurboAnnouncer/CustomSounds/");
    UI::Text("");

    UI::TextWrapped("\\$f80Important:\\$z Create a named folder for your pack (e.g. 'MyPack'), then add category folders inside it.");
    UI::TextWrapped("\\$f80Do NOT\\$z put files directly in CustomSounds/carhit/ - this will clash with downloaded packs!");
    UI::Text("");

    UI::TextWrapped("\\$ff0Structure and examples:\\$z");
    UI::Text("");

    UI::TextWrapped("\\$aaa1. Crash sounds:");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/carhit/crash1.wav");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/carhit/ouch.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa2. Checkpoint sounds (generic, no PB comparison):");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/checkpoint/nice.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa3. Checkpoint sounds (faster than PB):");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/checkpoint-yes/great.wav");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/checkpoint-yes/faster.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa4. Checkpoint sounds (slower than PB):");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/checkpoint-no/slow.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa5. Lap sounds:");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/lap/lap.wav");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/lap/final.wav  \\$aaa<-- 'final' in name = final lap");
    UI::Text("");

    UI::TextWrapped("\\$aaa6. Medal sounds:");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/medal/author.wav  \\$aaa<-- 'author' in name");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/medal/gold.wav    \\$aaa<-- 'gold' in name");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/medal/silver.wav  \\$aaa<-- 'silver' in name");
    UI::TextWrapped("\\$fff   CustomSounds/MyPack/medal/bronze.wav  \\$aaa<-- 'bronze' in name");
    UI::Text("");

    UI::Separator();
    UI::TextWrapped("\\$f80Note:\\$z If a folder is empty, no sound plays for that category.");
    UI::TextWrapped("\\$f80Note:\\$z Only .wav files are supported.");
    UI::Text("");

    UI::TextWrapped("\\$888Custom sounds are automatically enabled when you select a pack other than Default in the Sound Packs tab.");
}

// Check if custom sounds setting changed and reload
void OnSettingsChanged() {
    if (S_CustomSoundsEnabled != LastCustomSoundsEnabled) {
        LastCustomSoundsEnabled = S_CustomSoundsEnabled;
        LoadSamples();
    }
}

// Define DebugLog here so all files can see it
void DebugLog(const string &in msg) {
    if (!S_DebugMode) {
        return;
    }

    string line = tostring(Time::Now) + " | " + msg;
    g_DebugWindowLines.InsertLast(line);
    if (g_DebugWindowLines.Length > DEBUG_LOG_MAX_LINES) {
        g_DebugWindowLines.RemoveAt(0);
    }

    print("[TMAnnouncer] " + msg);
}

void RenderMenu() {
    if (UI::MenuItem(Icons::Bug + " TM Announcer Debug", "", S_ShowDebugWindow, S_DebugMode)) {
        S_ShowDebugWindow = !S_ShowDebugWindow;
    }
}

void RenderInterface() {
    if (!S_DebugMode || !S_ShowDebugWindow) {
        return;
    }

    const MLFeed::SharedGhostDataHook_V2@ ghostData = MLFeed::GetGhostData();
    const MLFeed::HookRaceStatsEventsBase_V4@ raceData = MLFeed::GetRaceData_V4();
    uint sortedGhostCount = ghostData is null ? 0 : ghostData.SortedGhosts.Length;
    uint loadedGhostCount = ghostData is null ? 0 : ghostData.LoadedGhosts.Length;
    uint localLoginId = MLFeed::LocalPlayersLoginIdValue;
    bool hasLocalLoginId = localLoginId != 0xFFFFFFFF;
    uint raceDataBestRaceCount = 0;
    if (raceData !is null && raceData.LocalPlayer !is null && raceData.LocalPlayer.BestRaceTimes !is null) {
        raceDataBestRaceCount = raceData.LocalPlayer.BestRaceTimes.Length;
    }

    uint nativeBestRaceCount = 0;
    auto app = GetApp();
    auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);
    if (playground !is null && playground.GameTerminals.Length > 0) {
        auto controlledPlayer = cast<CSmPlayer@>(playground.GameTerminals[0].ControlledPlayer);
        if (controlledPlayer !is null && controlledPlayer.ScriptAPI !is null) {
            auto scriptPlayer = cast<CSmScriptPlayer@>(controlledPlayer.ScriptAPI);
            if (scriptPlayer !is null && scriptPlayer.Score !is null) {
                nativeBestRaceCount = scriptPlayer.Score.BestRaceTimes.Length;
            }
        }
    }

    if (!UI::Begin("TM Announcer Debug", S_ShowDebugWindow)) {
        UI::End();
        return;
    }

    UI::Text("\\$ff0Runtime");
    UI::Separator();

    string pbFinish = "n/a";
    if (RaceLogic::CachedPBFinishTime > 0) {
        pbFinish = Time::Format(uint(RaceLogic::CachedPBFinishTime));
    }

    UI::Text("Map UID: " + RaceLogic::CurrentMapUid);
    UI::Text("IsRunning: " + tostring(RaceLogic::IsRunning) + " | StartTime: " + tostring(RaceLogic::LastStartTime));
    UI::Text("Laps: " + tostring(RaceLogic::LapsTotal) + " | CPsToFinish: " + tostring(RaceLogic::CPsToFinishTotal) + " | CPsPerLap: " + tostring(RaceLogic::CPsPerLap));
    UI::Text("Last CP: " + tostring(RaceLogic::LastCPCount) + " | Next CP Trigger: " + tostring(RaceLogic::NextCPToPlay));
    UI::Text("PB Init Pending: " + tostring(RaceLogic::PBInitPending) + " | Retries: " + tostring(RaceLogic::PBInitRetries) + "/" + tostring(RaceLogic::PBInitMaxRetries));
    UI::Text("PB Cached Finish: " + pbFinish + " | Cached CP Count: " + tostring(RaceLogic::CachedPBCheckpoints.Length));
    UI::Text("Medal Baseline Known: " + tostring(RaceLogic::MedalBaselineKnown) + " | Best Medal: " + tostring(RaceLogic::BestMedalEarned));
    UI::Text("Local LoginId: " + (hasLocalLoginId ? tostring(localLoginId) : "n/a") + " | Ghosts Sorted/Loaded: " + tostring(sortedGhostCount) + "/" + tostring(loadedGhostCount));
    UI::Text("BestRaceTimes length (Native/RaceData): " + tostring(nativeBestRaceCount) + "/" + tostring(raceDataBestRaceCount));

    UI::Separator();
    if (UI::Button(Icons::Refresh + " Refresh PB Cache")) {
        bool ok = RaceLogic::RefreshCachedPBData();
        DebugLog("Manual RefreshCachedPBData: " + tostring(ok));
    }
    UI::SameLine();
    if (UI::Button(Icons::Trash + " Clear Debug Log")) {
        g_DebugWindowLines.Resize(0);
    }

    UI::Separator();
    UI::Text("\\$ff0Events");
    UI::BeginChild("TMAnnouncerDebugLog", vec2(0, 260));
    for (uint i = 0; i < g_DebugWindowLines.Length; i++) {
        UI::Text(g_DebugWindowLines[i]);
    }
    UI::EndChild();

    UI::End();
}
