[Setting category="Voice" name="Volume" min=0 max=100 description="Controls the announcer's voice volume."]
int S_VoiceVolume = 50;

[Setting category="Triggers" name="Car Crash" description="Watch the paintwork!"]
bool S_CarhitEnabled = true;

[Setting category="Triggers" name="Checkpoints" description="Pedal to the medal!"]
bool S_CheckpointsEnabled = true;

[Setting category="Triggers" name="Laps" description="Final Lap!"]
bool S_LapsEnabled = true;

[Setting category="Advanced" name="Heartbeat" description="Controls the plugin's update frequency. (in ms)"]
int S_Heartbeat = 300;

[Setting category="Advanced" name="Sound Gain Multiplier" description="Controls the gain of the announcer's voice."]
float S_SoundMultiplier = 0.5;

[Setting category="Advanced" name="Scale with Built-In Sound" description="When enabled, the built-in volume slider will affect the voice's volume."]
bool S_IngameSound = true;

[Setting category="Advanced" name="Carhit Sensitivity" min=0 max=1 description="Higher values will make the announcer detect crashes more often."]
float S_CarhitSensitivity = 0.6;