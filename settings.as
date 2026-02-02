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
    if (S_DebugMode) {
        print("[TMAnnouncer] " + msg);
    }
}
