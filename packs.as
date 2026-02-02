// Sound Pack Download and Management System

// Download state
class PackDownloader {
    string PackName;
    string Author;
    string Version;
    string PackUrl;
    string DestPath;
    string FinalPackName; // The actual folder name (may include author suffix)

    int TotalFiles = 0;
    int DownloadedFiles = 0;
    int FailedFiles = 0;
    bool IsDownloading = false;
    bool IsDone = false;
    string LastError = "";
    string CurrentFile = "";

    // Rate limiting
    int ConcurrentDownloads = 0;
    int MAX_CONCURRENT = 3;
    int DELAY_BETWEEN_BATCHES_MS = 500;
    uint64 LastBatchTime = 0;

    array<string> MissingCategories;

    float get_Progress() {
        if (TotalFiles == 0) return 0;
        return float(DownloadedFiles + FailedFiles) / float(TotalFiles) * 100.0f;
    }

    string get_StatusText() {
        if (IsDone) {
            if (FailedFiles > 0)
                return "\\$fa0Done with " + FailedFiles + " errors";
            return "\\$0f0Download complete!";
        }
        if (IsDownloading)
            return "Downloading: " + DownloadedFiles + "/" + TotalFiles + " (" + Text::Format("%.0f", Progress) + "%)";
        return "";
    }
}

PackDownloader@ ActiveDownload = null;

// Installed packs persistence
class PackInfo {
    string Name;
    string Author;
    string Version;
    string FolderName; // Actual folder name on disk
}

class PacksConfig {
    string ActivePack = "Default";
    array<PackInfo@> InstalledPacks;

    PacksConfig() {
        PackInfo@ defaultPack = PackInfo();
        defaultPack.Name = "Default";
        defaultPack.Author = "TM Turbo Announcer";
        defaultPack.Version = "";
        defaultPack.FolderName = "Default";
        InstalledPacks.InsertLast(defaultPack);
    }

    PackInfo@ FindByFolderName(const string &in folderName) {
        for (uint i = 0; i < InstalledPacks.Length; i++) {
            if (InstalledPacks[i].FolderName == folderName)
                return InstalledPacks[i];
        }
        return null;
    }

    PackInfo@ FindByNameAndAuthor(const string &in name, const string &in author) {
        for (uint i = 0; i < InstalledPacks.Length; i++) {
            if (InstalledPacks[i].Name == name && InstalledPacks[i].Author == author)
                return InstalledPacks[i];
        }
        return null;
    }

    bool HasFolderName(const string &in folderName) {
        return FindByFolderName(folderName) !is null;
    }
}

PacksConfig@ g_PacksConfig = null;
string g_PacksConfigPath = "";

void InitPacksSystem() {
    g_PacksConfigPath = IO::FromStorageFolder("packs_config.json");
    LoadPacksConfig();
}

void LoadPacksConfig() {
    @g_PacksConfig = PacksConfig();

    if (IO::FileExists(g_PacksConfigPath)) {
        try {
            auto json = Json::FromFile(g_PacksConfigPath);
            g_PacksConfig.ActivePack = json.Get("activePack", "Default");

            auto installed = json.Get("installed", Json::Array());
            g_PacksConfig.InstalledPacks.Resize(0);

            for (uint i = 0; i < installed.Length; i++) {
                auto packJson = installed[i];
                PackInfo@ info = PackInfo();

                // Support both old format (string) and new format (object)
                if (packJson.GetType() == Json::Type::String) {
                    info.Name = string(packJson);
                    info.FolderName = info.Name;
                    info.Author = (info.Name == "Default") ? "TM Turbo Announcer" : "Unknown";
                    info.Version = "";
                } else {
                    info.Name = packJson.Get("name", "Unknown");
                    info.Author = packJson.Get("author", "Unknown");
                    info.Version = packJson.Get("version", "");
                    info.FolderName = packJson.Get("folderName", info.Name);
                }

                g_PacksConfig.InstalledPacks.InsertLast(info);
            }

            // Ensure Default is always present
            if (g_PacksConfig.FindByFolderName("Default") is null) {
                PackInfo@ defaultPack = PackInfo();
                defaultPack.Name = "Default";
                defaultPack.Author = "TM Turbo Announcer";
                defaultPack.Version = "";
                defaultPack.FolderName = "Default";
                g_PacksConfig.InstalledPacks.InsertLast(defaultPack);
            }

        } catch {
            warn("[TMAnnouncer] Failed to load packs config: " + getExceptionInfo());
        }
    }

    // Scan for packs on disk that might not be in config
    ScanInstalledPacks();
}

void SavePacksConfig() {
    if (g_PacksConfig is null) return;

    auto json = Json::Object();
    json["activePack"] = g_PacksConfig.ActivePack;

    auto installed = Json::Array();
    for (uint i = 0; i < g_PacksConfig.InstalledPacks.Length; i++) {
        auto packJson = Json::Object();
        packJson["name"] = g_PacksConfig.InstalledPacks[i].Name;
        packJson["author"] = g_PacksConfig.InstalledPacks[i].Author;
        packJson["version"] = g_PacksConfig.InstalledPacks[i].Version;
        packJson["folderName"] = g_PacksConfig.InstalledPacks[i].FolderName;
        installed.Add(packJson);
    }
    json["installed"] = installed;

    Json::ToFile(g_PacksConfigPath, json);
}

void ScanInstalledPacks() {
    string basePath = IO::FromStorageFolder("CustomSounds/");
    if (!IO::FolderExists(basePath)) return;

    // Category folder names that should NOT be treated as packs
    array<string> reservedNames = {
        CUSTOM_FOLDER_CARHIT,
        CUSTOM_FOLDER_CHECKPOINT,
        CUSTOM_FOLDER_CHECKPOINT_YES,
        CUSTOM_FOLDER_CHECKPOINT_NO,
        CUSTOM_FOLDER_LAP,
        CUSTOM_FOLDER_MEDAL
    };

    auto folders = IO::IndexFolder(basePath, false);
    for (uint i = 0; i < folders.Length; i++) {
        string fullPath = folders[i];
        // IndexFolder returns full paths, check if it's a directory
        if (fullPath.EndsWith("/") || IO::FolderExists(fullPath)) {
            string folderName = Path::GetFileName(fullPath);

            // Skip empty names
            if (folderName.Length == 0) continue;

            // Skip reserved category folder names (user put files in wrong place)
            if (reservedNames.Find(folderName) >= 0) {
                warn("[TMAnnouncer] Ignoring '" + folderName + "' in CustomSounds - this is a category name, not a pack! Use CustomSounds/YourPackName/" + folderName + "/ instead.");
                continue;
            }

            // Check if already in config
            if (g_PacksConfig.FindByFolderName(folderName) is null) {
                PackInfo@ info = PackInfo();
                info.FolderName = folderName;
                info.Name = folderName;
                info.Author = "Unknown (manual)";
                info.Version = "";
                g_PacksConfig.InstalledPacks.InsertLast(info);
            }
        }
    }
}

// Analyze a pack and return missing categories
array<string> GetPackMissingCategories(const string &in folderName) {
    array<string> missing;

    // Default pack uses built-in assets, not custom files
    if (folderName == "Default") {
        return missing; // Always complete
    }

    string packPath = IO::FromStorageFolder("CustomSounds/" + folderName + "/");
    if (!IO::FolderExists(packPath)) {
        // Return all categories as missing
        missing.InsertLast(CUSTOM_FOLDER_CARHIT);
        missing.InsertLast(CUSTOM_FOLDER_CHECKPOINT);
        missing.InsertLast(CUSTOM_FOLDER_CHECKPOINT_YES);
        missing.InsertLast(CUSTOM_FOLDER_CHECKPOINT_NO);
        missing.InsertLast(CUSTOM_FOLDER_LAP);
        missing.InsertLast(CUSTOM_FOLDER_MEDAL);
        return missing;
    }

    array<string> categories = {
        CUSTOM_FOLDER_CARHIT,
        CUSTOM_FOLDER_CHECKPOINT,
        CUSTOM_FOLDER_CHECKPOINT_YES,
        CUSTOM_FOLDER_CHECKPOINT_NO,
        CUSTOM_FOLDER_LAP,
        CUSTOM_FOLDER_MEDAL
    };

    for (uint i = 0; i < categories.Length; i++) {
        string catPath = packPath + categories[i] + "/";
        if (!IO::FolderExists(catPath)) {
            missing.InsertLast(categories[i]);
            continue;
        }

        auto files = IO::IndexFolder(catPath, false);
        bool hasWav = false;
        for (uint j = 0; j < files.Length; j++) {
            if (files[j].ToLower().EndsWith(".wav")) {
                hasWav = true;
                break;
            }
        }
        if (!hasWav) {
            missing.InsertLast(categories[i]);
        }
    }

    return missing;
}

string GetActivePackPath() {
    if (g_PacksConfig is null || g_PacksConfig.ActivePack == "Default") {
        return IO::FromStorageFolder("CustomSounds/Default/");
    }
    return IO::FromStorageFolder("CustomSounds/" + g_PacksConfig.ActivePack + "/");
}

// Download a pack from JSON manifest URL
void StartPackDownload(const string &in jsonUrl) {
    if (ActiveDownload !is null && ActiveDownload.IsDownloading) {
        UI::ShowNotification("Download already in progress!");
        return;
    }

    @ActiveDownload = PackDownloader();
    ActiveDownload.PackUrl = jsonUrl;
    ActiveDownload.IsDownloading = true;

    startnew(CoroutineDownloadPack);
}

void CoroutineDownloadPack() {
    if (ActiveDownload is null) return;

    // Fetch JSON manifest
    DebugLog("Fetching pack manifest from: " + ActiveDownload.PackUrl);

    Net::HttpRequest@ req = Net::HttpGet(ActiveDownload.PackUrl);
    while (!req.Finished()) yield();

    if (req.ResponseCode() != 200) {
        ActiveDownload.LastError = "Failed to fetch manifest (HTTP " + req.ResponseCode() + ")";
        ActiveDownload.IsDownloading = false;
        ActiveDownload.IsDone = true;
        return;
    }

    // Parse JSON
    Json::Value@ json = null;
    try {
        @json = Json::Parse(req.String());
    } catch {
        ActiveDownload.LastError = "Invalid JSON: " + getExceptionInfo();
        ActiveDownload.IsDownloading = false;
        ActiveDownload.IsDone = true;
        return;
    }

    if (json is null) {
        ActiveDownload.LastError = "Failed to parse JSON manifest";
        ActiveDownload.IsDownloading = false;
        ActiveDownload.IsDone = true;
        return;
    }

    // Extract pack info
    ActiveDownload.PackName = json.Get("packName", "UnnamedPack");
    ActiveDownload.Author = json.Get("author", "Unknown");
    ActiveDownload.Version = json.Get("version", "1.0");

    // Validate pack name (no special chars)
    if (ActiveDownload.PackName.Contains("/") || ActiveDownload.PackName.Contains("\\") ||
        ActiveDownload.PackName.Contains("..") || ActiveDownload.PackName.Contains(":")) {
        ActiveDownload.LastError = "Invalid pack name";
        ActiveDownload.IsDownloading = false;
        ActiveDownload.IsDone = true;
        return;
    }

    // Determine the final folder name, handling conflicts
    string finalFolderName = ActiveDownload.PackName;

    // Check for existing pack with same name
    PackInfo@ existingByName = null;
    for (uint i = 0; i < g_PacksConfig.InstalledPacks.Length; i++) {
        if (g_PacksConfig.InstalledPacks[i].Name == ActiveDownload.PackName) {
            @existingByName = g_PacksConfig.InstalledPacks[i];
            break;
        }
    }

    if (existingByName !is null) {
        if (existingByName.Author == ActiveDownload.Author) {
            // Same pack, same author - check version for overwrite behavior
            // If it's a major version change, overwrite directly
            // Otherwise we'll overwrite anyway (user initiated the download)
            finalFolderName = existingByName.FolderName;
            DebugLog("Overwriting existing pack: " + finalFolderName);
        } else {
            // Same pack name, different author - add author suffix
            finalFolderName = ActiveDownload.PackName + " (" + ActiveDownload.Author + ")";
            DebugLog("Pack name conflict, using: " + finalFolderName);
        }
    }

    ActiveDownload.FinalPackName = finalFolderName;

    // Create pack directory
    string packPath = IO::FromStorageFolder("CustomSounds/" + finalFolderName + "/");
    ActiveDownload.DestPath = packPath;

    if (!IO::FolderExists(packPath))
        IO::CreateFolder(packPath, true);

    // Get sounds object
    auto sounds = json.Get("sounds", Json::Object());
    if (sounds.GetType() != Json::Type::Object) {
        ActiveDownload.LastError = "Missing or invalid 'sounds' object";
        ActiveDownload.IsDownloading = false;
        ActiveDownload.IsDone = true;
        return;
    }

    // Valid categories
    array<string> validCategories = {
        CUSTOM_FOLDER_CARHIT,
        CUSTOM_FOLDER_CHECKPOINT,
        CUSTOM_FOLDER_CHECKPOINT_YES,
        CUSTOM_FOLDER_CHECKPOINT_NO,
        CUSTOM_FOLDER_LAP,
        CUSTOM_FOLDER_MEDAL
    };

    // Count total files and build download queue
    array<DownloadTask@> downloadQueue;

    auto categoryKeys = sounds.GetKeys();
    for (uint i = 0; i < categoryKeys.Length; i++) {
        string category = categoryKeys[i];

        // Skip comments (keys starting with _)
        if (category.StartsWith("_")) continue;

        // Validate category
        if (validCategories.Find(category) < 0) {
            warn("[TMAnnouncer] Unknown category in pack: " + category);
            continue;
        }

        // Create category folder
        string categoryPath = packPath + category + "/";
        if (!IO::FolderExists(categoryPath))
            IO::CreateFolder(categoryPath, true);

        auto files = sounds.Get(category, Json::Object());
        if (files.GetType() != Json::Type::Object) continue;

        auto fileKeys = files.GetKeys();
        for (uint j = 0; j < fileKeys.Length; j++) {
            string fileName = fileKeys[j];

            // Skip comments
            if (fileName.StartsWith("_")) continue;

            string url = string(files[fileName]);
            if (url.Length == 0) continue;

            // Validate filename
            if (fileName.Contains("/") || fileName.Contains("\\") || fileName.Contains("..")) {
                warn("[TMAnnouncer] Invalid filename skipped: " + fileName);
                continue;
            }

            DownloadTask@ task = DownloadTask();
            task.Url = url;
            task.DestPath = categoryPath + fileName;
            task.FileName = fileName;
            downloadQueue.InsertLast(task);
        }
    }

    ActiveDownload.TotalFiles = downloadQueue.Length;

    if (ActiveDownload.TotalFiles == 0) {
        ActiveDownload.LastError = "No valid files to download";
        ActiveDownload.IsDownloading = false;
        ActiveDownload.IsDone = true;
        return;
    }

    DebugLog("Starting download of " + ActiveDownload.TotalFiles + " files for pack: " + ActiveDownload.PackName);

    // Download files with rate limiting
    for (uint i = 0; i < downloadQueue.Length; i++) {
        // Rate limit: wait if we have too many concurrent downloads
        while (ActiveDownload.ConcurrentDownloads >= ActiveDownload.MAX_CONCURRENT) {
            yield();
        }

        // Add delay between batches to avoid rate limiting
        uint64 now = Time::Now;
        if (ActiveDownload.LastBatchTime > 0 && now - ActiveDownload.LastBatchTime < ActiveDownload.DELAY_BETWEEN_BATCHES_MS) {
            sleep(ActiveDownload.DELAY_BETWEEN_BATCHES_MS);
        }
        ActiveDownload.LastBatchTime = Time::Now;

        // Start download
        startnew(CoroutineDownloadFile, downloadQueue[i]);
        ActiveDownload.ConcurrentDownloads++;
    }

    // Wait for all downloads to complete
    while (ActiveDownload.DownloadedFiles + ActiveDownload.FailedFiles < ActiveDownload.TotalFiles) {
        yield();
    }

    // Check for missing categories
    CheckMissingCategories(packPath);

    // Add or update pack in config
    PackInfo@ existingPack = g_PacksConfig.FindByFolderName(ActiveDownload.FinalPackName);
    if (existingPack !is null) {
        // Update existing pack info
        existingPack.Version = ActiveDownload.Version;
    } else {
        // Add new pack
        PackInfo@ newPack = PackInfo();
        newPack.Name = ActiveDownload.PackName;
        newPack.Author = ActiveDownload.Author;
        newPack.Version = ActiveDownload.Version;
        newPack.FolderName = ActiveDownload.FinalPackName;
        g_PacksConfig.InstalledPacks.InsertLast(newPack);
    }
    SavePacksConfig();

    ActiveDownload.IsDownloading = false;
    ActiveDownload.IsDone = true;

    // Show popup if there are missing categories
    if (ActiveDownload.MissingCategories.Length > 0) {
        g_MissingCategoriesPackName = ActiveDownload.FinalPackName;
        g_ShowMissingCategoriesPopup = true;
        // Don't show notification yet, popup will handle it
    } else if (ActiveDownload.FailedFiles == 0) {
        UI::ShowNotification("\\$0f0Pack '" + ActiveDownload.PackName + "' downloaded successfully!");
    } else {
        UI::ShowNotification("\\$fa0Pack '" + ActiveDownload.PackName + "' downloaded with " + ActiveDownload.FailedFiles + " errors");
    }
}

class DownloadTask {
    string Url;
    string DestPath;
    string FileName;
}

void CoroutineDownloadFile(ref@ data) {
    DownloadTask@ task = cast<DownloadTask@>(data);
    if (task is null || ActiveDownload is null) return;

    ActiveDownload.CurrentFile = task.FileName;

    // Skip if file already exists
    if (IO::FileExists(task.DestPath)) {
        DebugLog("Skipping existing file: " + task.FileName);
        ActiveDownload.DownloadedFiles++;
        ActiveDownload.ConcurrentDownloads--;
        return;
    }

    int retries = 3;
    int retryDelay = 1000; // Start with 1 second

    while (retries > 0) {
        try {
            Net::HttpRequest@ req = Net::HttpGet(task.Url);
            while (!req.Finished()) yield();

            int code = req.ResponseCode();

            if (code == 200) {
                req.SaveToFile(task.DestPath);
                DebugLog("Downloaded: " + task.FileName);
                ActiveDownload.DownloadedFiles++;
                ActiveDownload.ConcurrentDownloads--;
                return;
            } else if (code == 429) {
                // Rate limited! Wait and retry
                warn("[TMAnnouncer] Rate limited, waiting " + retryDelay + "ms before retry...");
                sleep(retryDelay);
                retryDelay *= 2; // Exponential backoff
                retries--;
            } else {
                warn("[TMAnnouncer] Failed to download " + task.FileName + " (HTTP " + code + ")");
                retries--;
                if (retries > 0) sleep(retryDelay);
            }
        } catch {
            warn("[TMAnnouncer] Exception downloading " + task.FileName + ": " + getExceptionInfo());
            retries--;
            if (retries > 0) sleep(retryDelay);
        }
    }

    ActiveDownload.FailedFiles++;
    ActiveDownload.ConcurrentDownloads--;
}

void CheckMissingCategories(const string &in packPath) {
    if (ActiveDownload is null) return;

    ActiveDownload.MissingCategories.Resize(0);

    array<string> categories = {
        CUSTOM_FOLDER_CARHIT,
        CUSTOM_FOLDER_CHECKPOINT,
        CUSTOM_FOLDER_CHECKPOINT_YES,
        CUSTOM_FOLDER_CHECKPOINT_NO,
        CUSTOM_FOLDER_LAP,
        CUSTOM_FOLDER_MEDAL
    };

    for (uint i = 0; i < categories.Length; i++) {
        string catPath = packPath + categories[i] + "/";
        if (!IO::FolderExists(catPath)) {
            ActiveDownload.MissingCategories.InsertLast(categories[i]);
            continue;
        }

        auto files = IO::IndexFolder(catPath, false);
        bool hasWav = false;
        for (uint j = 0; j < files.Length; j++) {
            if (files[j].ToLower().EndsWith(".wav")) {
                hasWav = true;
                break;
            }
        }
        if (!hasWav) {
            ActiveDownload.MissingCategories.InsertLast(categories[i]);
        }
    }
}

void DeletePack(const string &in folderName) {
    if (folderName == "Default") {
        UI::ShowNotification("\\$f00Cannot delete the Default pack!");
        return;
    }

    string packPath = IO::FromStorageFolder("CustomSounds/" + folderName + "/");
    if (IO::FolderExists(packPath)) {
        IO::DeleteFolder(packPath, true);
    }

    // Find and remove from config
    for (uint i = 0; i < g_PacksConfig.InstalledPacks.Length; i++) {
        if (g_PacksConfig.InstalledPacks[i].FolderName == folderName) {
            g_PacksConfig.InstalledPacks.RemoveAt(i);
            break;
        }
    }

    // If active pack was deleted, switch to Default
    if (g_PacksConfig.ActivePack == folderName) {
        g_PacksConfig.ActivePack = "Default";
        S_CustomSoundsEnabled = false;
        LoadSamples(); // Reload with Default pack
    }

    SavePacksConfig();
    UI::ShowNotification("Pack '" + folderName + "' deleted");
}

// UI Input state
string g_PackUrlInput = "";
string g_PackToDelete = "";
bool g_ShowDeleteConfirm = false;
bool g_ShowMissingCategoriesPopup = false;
string g_MissingCategoriesPackName = "";

[SettingsTab name="Sound Packs" order="1"]
void RenderSoundPacksTab() {
    // Initialize if needed
    if (g_PacksConfig is null) {
        InitPacksSystem();
    }

    UI::TextWrapped("\\$ff0Download and manage sound packs from the internet.");
    UI::Separator();

    // Custom Sounds status
    UI::Text("\\$aaaCustom Sounds: " + (S_CustomSoundsEnabled ? "\\$0f0Enabled" : "\\$888Disabled (using built-in)"));
    UI::TextWrapped("\\$888Select a pack other than Default to enable custom sounds automatically.");
    UI::Text("");

    // Reload button
    if (S_CustomSoundsEnabled) {
        if (UI::Button(Icons::Refresh + " Reload Sounds")) {
            LoadSamples();
            UI::ShowNotification("Sounds reloaded!");
        }
    }

    UI::Separator();

    // Download section
    UI::Text("\\$aaaDownload New Pack:");
    UI::SetNextItemWidth(400);
    g_PackUrlInput = UI::InputText("Pack JSON URL", g_PackUrlInput);

    bool canDownload = g_PackUrlInput.Length > 0 &&
                       (ActiveDownload is null || !ActiveDownload.IsDownloading);

    UI::BeginDisabled(!canDownload);
    if (UI::Button(Icons::Download + " Download Pack")) {
        StartPackDownload(g_PackUrlInput);
    }
    UI::EndDisabled();

    // Download progress
    if (ActiveDownload !is null && ActiveDownload.IsDownloading) {
        UI::Text(ActiveDownload.StatusText);
        if (ActiveDownload.CurrentFile.Length > 0) {
            UI::Text("\\$888Current: " + ActiveDownload.CurrentFile);
        }
        UI::ProgressBar(ActiveDownload.Progress / 100.0f);
    }

    // Show errors
    if (ActiveDownload !is null && ActiveDownload.LastError.Length > 0) {
        UI::Text("\\$f00Error: " + ActiveDownload.LastError);
    }

    // Show missing categories warning
    if (ActiveDownload !is null && ActiveDownload.IsDone && ActiveDownload.MissingCategories.Length > 0) {
        UI::Text("\\$fa0Warning: Missing sounds for: " + string::Join(ActiveDownload.MissingCategories, ", "));
    }

    UI::Separator();

    // Installed packs section
    UI::Text("\\$aaaInstalled Packs:");

    for (uint i = 0; i < g_PacksConfig.InstalledPacks.Length; i++) {
        PackInfo@ pack = g_PacksConfig.InstalledPacks[i];
        string folderName = pack.FolderName;
        bool isActive = (folderName == g_PacksConfig.ActivePack);

        // Check for missing categories
        array<string> missingCats = GetPackMissingCategories(folderName);
        bool hasMissing = missingCats.Length > 0;

        // Build display name
        string displayName = pack.Name;
        if (pack.FolderName == "Default") {
            displayName = "Default (TM Turbo Announcer)";
        } else if (pack.Author.Length > 0 && pack.Author != "Unknown" && pack.Author != "Unknown (manual)") {
            displayName = pack.Name + " by " + pack.Author;
        }
        if (pack.Version.Length > 0) {
            displayName += " v" + pack.Version;
        }

        if (UI::RadioButton(displayName, isActive)) {
            if (!isActive) {
                g_PacksConfig.ActivePack = folderName;

                // Auto-enable/disable custom sounds based on selection
                if (folderName == "Default") {
                    S_CustomSoundsEnabled = false;
                } else {
                    S_CustomSoundsEnabled = true;
                }
                LastCustomSoundsEnabled = S_CustomSoundsEnabled;

                SavePacksConfig();
                LoadSamples(); // Reload samples with new pack
                UI::ShowNotification("Switched to pack: " + pack.Name);
            }
        }

        // Show missing indicator with tooltip
        if (hasMissing) {
            UI::SameLine();
            UI::Text("\\$fa0(missing files)");
            if (UI::IsItemHovered()) {
                UI::BeginTooltip();
                UI::Text("\\$fffMissing sound categories:");
                for (uint m = 0; m < missingCats.Length; m++) {
                    UI::Text("\\$888  - " + missingCats[m]);
                }
                UI::Text("");
                UI::Text("\\$888These categories will have no sounds.");
                UI::EndTooltip();
            }
        }

        // Delete button (not for Default)
        if (folderName != "Default") {
            UI::SameLine();
            UI::PushID("del_" + folderName);
            if (UI::Button(Icons::Trash)) {
                g_PackToDelete = folderName;
                g_ShowDeleteConfirm = true;
            }
            UI::PopID();
        }
    }

    // Delete confirmation popup
    if (g_ShowDeleteConfirm) {
        UI::OpenPopup("Delete Pack?");
    }

    if (UI::BeginPopupModal("Delete Pack?", g_ShowDeleteConfirm)) {
        UI::Text("Are you sure you want to delete '" + g_PackToDelete + "'?");
        UI::Text("This cannot be undone.");
        UI::Separator();

        if (UI::Button("Yes, Delete")) {
            DeletePack(g_PackToDelete);
            g_ShowDeleteConfirm = false;
            UI::CloseCurrentPopup();
        }
        UI::SameLine();
        if (UI::Button("Cancel")) {
            g_ShowDeleteConfirm = false;
            UI::CloseCurrentPopup();
        }
        UI::EndPopup();
    }

    // Missing categories popup after download
    if (g_ShowMissingCategoriesPopup) {
        UI::OpenPopup("Pack Missing Files");
    }

    if (UI::BeginPopupModal("Pack Missing Files", g_ShowMissingCategoriesPopup)) {
        UI::TextWrapped("\\$fa0Warning: The downloaded pack is missing sound files for some categories.");
        UI::Text("");
        UI::Text("\\$fffPack: \\$fff" + (ActiveDownload !is null ? ActiveDownload.PackName : g_MissingCategoriesPackName));
        UI::Text("");
        UI::Text("\\$fffMissing categories:");
        if (ActiveDownload !is null) {
            for (uint m = 0; m < ActiveDownload.MissingCategories.Length; m++) {
                UI::Text("\\$f80  " + Icons::ExclamationTriangle + " " + ActiveDownload.MissingCategories[m]);
            }
        }
        UI::Text("");
        UI::TextWrapped("\\$888These categories will not play any sounds. The pack creator may have omitted them intentionally, or there was a download error.");
        UI::Separator();

        if (UI::Button(Icons::Check + " Acknowledge & Keep")) {
            g_ShowMissingCategoriesPopup = false;
            UI::ShowNotification("\\$fa0Pack '" + (ActiveDownload !is null ? ActiveDownload.PackName : g_MissingCategoriesPackName) + "' kept with missing categories");
            UI::CloseCurrentPopup();
        }
        UI::SameLine();
        if (UI::Button(Icons::Trash + " Cancel & Delete Pack")) {
            g_ShowMissingCategoriesPopup = false;
            DeletePack(g_MissingCategoriesPackName);
            UI::CloseCurrentPopup();
        }
        UI::EndPopup();
    }

    UI::Separator();

    // Help section
    UI::Text("\\$888Tip: See 'Manual Sound Pack Guide' tab for creating packs manually.");
    UI::Text("\\$888Example JSON schema: example_pack.json in plugin folder");
}
