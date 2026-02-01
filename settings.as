[Setting category="General" name="Master Volume" min=0 max=100]
int S_VoiceVolume = 50;

[Setting category="General" name="Scale with In-game Volume"]
bool S_IngameSound = true;

[Setting category="General" name="Sound Gain Multiplier"]
float S_SoundMultiplier = 0.5;

[Setting category="Advanced" name="Crash Sensitivity" min=0.1 max=1.0]
float S_CarhitSensitivity = 0.6;

[Setting category="Advanced" name="Debug Mode"]
bool S_DebugMode = false;

[Setting category="Features" name="Enable Crash Sounds"]
bool S_CarhitEnabled = true;

[Setting category="Features" name="Enable Checkpoint Sounds"]
bool S_CheckpointsEnabled = true;

[Setting category="Features" name="Always Play on Every Checkpoint"]
bool S_CheckpointsAlways = false;

[Setting category="Features" name="Enable Lap Sounds"]
bool S_LapsEnabled = true;

[Setting category="Features" name="Enable Medal Sounds"]
bool S_MedalsEnabled = true;

[Setting category="Custom Sounds" name="Enable Custom Sounds"]
bool S_CustomSoundsEnabled = false;

bool LastCustomSoundsEnabled = false;

[SettingsTab name="Custom Sounds Guide"]
void RenderCustomSoundsGuide() {
    UI::TextWrapped("\\$ff0Custom Sounds\\$z lets you use your own .wav files instead of the built-in voice lines.");
    UI::Separator();

    UI::TextWrapped("\\$aaaFolder location:");
    UI::TextWrapped("\\$fff  OpenplanetNext/PluginStorage/TMTurboAnnouncer/CustomSounds/");
    UI::Text("");

    UI::TextWrapped("\\$ff0Structure and examples:\\$z");
    UI::Text("");

    UI::TextWrapped("\\$aaa1. Crash sounds:");
    UI::TextWrapped("\\$fff   CustomSounds/carhit/crash1.wav");
    UI::TextWrapped("\\$fff   CustomSounds/carhit/ouch.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa2. Checkpoint sounds (generic, no PB comparison):");
    UI::TextWrapped("\\$fff   CustomSounds/checkpoint/nice.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa3. Checkpoint sounds (faster than PB):");
    UI::TextWrapped("\\$fff   CustomSounds/checkpoint-yes/great.wav");
    UI::TextWrapped("\\$fff   CustomSounds/checkpoint-yes/faster.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa4. Checkpoint sounds (slower than PB):");
    UI::TextWrapped("\\$fff   CustomSounds/checkpoint-no/slow.wav");
    UI::Text("");

    UI::TextWrapped("\\$aaa5. Lap sounds:");
    UI::TextWrapped("\\$fff   CustomSounds/lap/lap.wav");
    UI::TextWrapped("\\$fff   CustomSounds/lap/final.wav  \\$aaa<-- 'final' in name = final lap");
    UI::Text("");

    UI::TextWrapped("\\$aaa6. Medal sounds:");
    UI::TextWrapped("\\$fff   CustomSounds/medal/author.wav  \\$aaa<-- 'author' in name");
    UI::TextWrapped("\\$fff   CustomSounds/medal/gold.wav    \\$aaa<-- 'gold' in name");
    UI::TextWrapped("\\$fff   CustomSounds/medal/silver.wav  \\$aaa<-- 'silver' in name");
    UI::TextWrapped("\\$fff   CustomSounds/medal/bronze.wav  \\$aaa<-- 'bronze' in name");
    UI::Text("");

    UI::Separator();
    UI::TextWrapped("\\$f80Note:\\$z If a folder is empty, no sound plays for that category.");
    UI::TextWrapped("\\$f80Note:\\$z Only .wav files are supported.");    UI::Text("");

    if (S_CustomSoundsEnabled) {
        if (UI::Button("Reload Custom Sounds")) {
            LoadSamples();
            UI::ShowNotification("Custom sounds reloaded!");
        }
    } else {
        UI::TextWrapped("\$888Enable Custom Sounds to reload assets.");
    }}

// Check if custom sounds setting changed and reload
void OnSettingsChanged() {
    if (S_CustomSoundsEnabled != LastCustomSoundsEnabled) {
        LastCustomSoundsEnabled = S_CustomSoundsEnabled;
        LoadSamples();
    }
}

// Define DebugLog here so all files can see it
void DebugLog(const string &in msg) {
    if (S_DebugMode) {
        print("[RaceSound] " + msg);
    }
}
