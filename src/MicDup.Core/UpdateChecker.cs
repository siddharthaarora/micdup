using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http.Headers;
using System.Reflection;
using Newtonsoft.Json;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Checks GitHub Releases for updates and performs in-place self-update.
/// </summary>
public class UpdateChecker
{
    private const string GitHubApiUrl = "https://api.github.com/repos/siddharthaarora/micdup/releases/latest";
    private const string UserAgent = "MicDup-AutoUpdate";

    private static readonly HttpClient _httpClient = new();

    static UpdateChecker()
    {
        _httpClient.DefaultRequestHeaders.UserAgent.Add(
            new ProductInfoHeaderValue(UserAgent, GetCurrentVersion()));
    }

    /// <summary>
    /// Gets the current app version from the assembly.
    /// </summary>
    public static string GetCurrentVersion()
    {
        var attr = Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>();
        return attr?.InformationalVersion ?? "0.0.0";
    }

    /// <summary>
    /// Checks GitHub for a newer release. Returns release info if update available, null otherwise.
    /// </summary>
    public async Task<GitHubRelease?> CheckForUpdateAsync()
    {
        try
        {
            var response = await _httpClient.GetAsync(GitHubApiUrl);
            response.EnsureSuccessStatusCode();

            var json = await response.Content.ReadAsStringAsync();
            var release = JsonConvert.DeserializeObject<GitHubRelease>(json);

            if (release == null || release.Draft || release.Prerelease)
                return null;

            var currentVersion = ParseVersion(GetCurrentVersion());
            var remoteVersion = ParseVersion(release.TagName);

            if (remoteVersion == null || currentVersion == null)
                return null;

            if (remoteVersion > currentVersion)
            {
                Log.Information("Update available: {Current} → {Remote}", currentVersion, remoteVersion);
                return release;
            }

            Log.Debug("App is up to date ({Version})", currentVersion);
            return null;
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to check for updates");
            return null;
        }
    }

    /// <summary>
    /// Downloads the update zip, extracts the new exe, and performs an in-place replacement.
    /// Returns true if the app should restart.
    /// </summary>
    public async Task<bool> DownloadAndApplyUpdateAsync(GitHubRelease release)
    {
        try
        {
            // Find the win-x64 zip asset
            var asset = release.Assets?.FirstOrDefault(a =>
                a.Name.Contains("win-x64", StringComparison.OrdinalIgnoreCase) &&
                a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));

            if (asset == null)
            {
                Log.Warning("No compatible release asset found for win-x64");
                return false;
            }

            Log.Information("Downloading update from {Url}", asset.BrowserDownloadUrl);

            // Download zip to temp
            var tempZip = Path.Combine(Path.GetTempPath(), $"micdup-update-{Guid.NewGuid():N}.zip");
            var tempExtract = Path.Combine(Path.GetTempPath(), $"micdup-update-{Guid.NewGuid():N}");

            try
            {
                using (var downloadStream = await _httpClient.GetStreamAsync(asset.BrowserDownloadUrl))
                using (var fileStream = File.Create(tempZip))
                {
                    await downloadStream.CopyToAsync(fileStream);
                }

                Log.Information("Download complete, extracting...");

                // Extract zip
                ZipFile.ExtractToDirectory(tempZip, tempExtract, overwriteFiles: true);

                // Find the new exe in the extracted files
                var newExePath = FindExecutable(tempExtract);
                if (newExePath == null)
                {
                    Log.Error("Could not find MicDup.exe in the update package");
                    return false;
                }

                // Perform in-place replacement
                var currentExe = Environment.ProcessPath
                    ?? Process.GetCurrentProcess().MainModule?.FileName;

                if (string.IsNullOrEmpty(currentExe))
                {
                    Log.Error("Could not determine current executable path");
                    return false;
                }

                var currentDir = Path.GetDirectoryName(currentExe)!;
                var oldExe = currentExe + ".old";

                // Delete any previous .old file
                if (File.Exists(oldExe))
                    File.Delete(oldExe);

                // Rename running exe to .old (Windows allows this on locked files)
                File.Move(currentExe, oldExe);
                Log.Information("Renamed current exe to {OldExe}", oldExe);

                // Copy new exe into place
                File.Copy(newExePath, currentExe);
                Log.Information("Copied new exe to {CurrentExe}", currentExe);

                // Start the new process with --updated flag
                Process.Start(new ProcessStartInfo
                {
                    FileName = currentExe,
                    Arguments = "--updated",
                    UseShellExecute = true
                });

                Log.Information("Started updated process, shutting down current...");
                return true; // Signal caller to exit
            }
            finally
            {
                // Cleanup temp files
                try { if (File.Exists(tempZip)) File.Delete(tempZip); } catch { }
                try { if (Directory.Exists(tempExtract)) Directory.Delete(tempExtract, true); } catch { }
            }
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to download and apply update");

            // Attempt to restore if we renamed but failed to copy
            TryRestoreFromBackup();
            return false;
        }
    }

    /// <summary>
    /// Cleans up the .old backup file from a previous update. Call on startup.
    /// </summary>
    public static void CleanupOldVersion()
    {
        try
        {
            var currentExe = Environment.ProcessPath
                ?? Process.GetCurrentProcess().MainModule?.FileName;

            if (string.IsNullOrEmpty(currentExe))
                return;

            var oldExe = currentExe + ".old";
            if (File.Exists(oldExe))
            {
                File.Delete(oldExe);
                Log.Information("Cleaned up old version: {OldExe}", oldExe);
            }
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Could not clean up old version (may still be locked)");
        }
    }

    private static string? FindExecutable(string extractDir)
    {
        // Look for MicDup.exe in extracted files (could be at root or one level deep)
        var candidates = Directory.GetFiles(extractDir, "MicDup.exe", SearchOption.AllDirectories);
        return candidates.FirstOrDefault();
    }

    private static void TryRestoreFromBackup()
    {
        try
        {
            var currentExe = Environment.ProcessPath
                ?? Process.GetCurrentProcess().MainModule?.FileName;

            if (string.IsNullOrEmpty(currentExe))
                return;

            var oldExe = currentExe + ".old";
            if (File.Exists(oldExe) && !File.Exists(currentExe))
            {
                File.Move(oldExe, currentExe);
                Log.Information("Restored from backup after failed update");
            }
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to restore from backup");
        }
    }

    private static Version? ParseVersion(string versionStr)
    {
        var cleaned = versionStr.TrimStart('v', 'V');
        // Strip any suffix after a hyphen (e.g. "1.1.0-beta" → "1.1.0")
        var hyphenIdx = cleaned.IndexOf('-');
        if (hyphenIdx >= 0)
            cleaned = cleaned[..hyphenIdx];

        return Version.TryParse(cleaned, out var version) ? version : null;
    }
}

/// <summary>
/// Represents a GitHub release from the API.
/// </summary>
public class GitHubRelease
{
    [JsonProperty("tag_name")]
    public string TagName { get; set; } = "";

    [JsonProperty("name")]
    public string Name { get; set; } = "";

    [JsonProperty("body")]
    public string Body { get; set; } = "";

    [JsonProperty("draft")]
    public bool Draft { get; set; }

    [JsonProperty("prerelease")]
    public bool Prerelease { get; set; }

    [JsonProperty("assets")]
    public List<GitHubReleaseAsset>? Assets { get; set; }
}

/// <summary>
/// Represents a release asset (downloadable file).
/// </summary>
public class GitHubReleaseAsset
{
    [JsonProperty("name")]
    public string Name { get; set; } = "";

    [JsonProperty("browser_download_url")]
    public string BrowserDownloadUrl { get; set; } = "";

    [JsonProperty("size")]
    public long Size { get; set; }
}
