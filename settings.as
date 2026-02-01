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

// Define DebugLog here so all files can see it
void DebugLog(const string &in msg) {
    if (S_DebugMode) {
        print("[RaceSound] " + msg);
    }
}
