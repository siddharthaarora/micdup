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
    /// Downloads the update zip and launches a helper script that replaces files after this process exits.
    /// Returns true if the app should exit for the update to proceed.
    /// </summary>
    public async Task<bool> DownloadAndApplyUpdateAsync(GitHubRelease release)
    {
        try
        {
            var asset = release.Assets?.FirstOrDefault(a =>
                a.Name.Contains("win-x64", StringComparison.OrdinalIgnoreCase) &&
                a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));

            if (asset == null)
            {
                Log.Warning("No compatible release asset found for win-x64");
                return false;
            }

            Log.Information("Downloading update from {Url}", asset.BrowserDownloadUrl);

            var tempZip = Path.Combine(Path.GetTempPath(), $"micdup-update-{Guid.NewGuid():N}.zip");
            var tempExtract = Path.Combine(Path.GetTempPath(), $"micdup-update-{Guid.NewGuid():N}");

            using (var downloadStream = await _httpClient.GetStreamAsync(asset.BrowserDownloadUrl))
            using (var fileStream = File.Create(tempZip))
            {
                await downloadStream.CopyToAsync(fileStream);
            }

            Log.Information("Download complete, extracting...");
            ZipFile.ExtractToDirectory(tempZip, tempExtract, overwriteFiles: true);

            // Clean up the zip immediately
            try { File.Delete(tempZip); } catch { }

            var currentExe = Environment.ProcessPath
                ?? Process.GetCurrentProcess().MainModule?.FileName;

            if (string.IsNullOrEmpty(currentExe))
            {
                Log.Error("Could not determine current executable path");
                return false;
            }

            var currentDir = Path.GetDirectoryName(currentExe)!;
            var pid = Environment.ProcessId;

            // Write a batch script that waits for us to exit, then copies all new files over
            var scriptPath = Path.Combine(Path.GetTempPath(), $"micdup-update-{Guid.NewGuid():N}.cmd");
            var script = $"""
                @echo off
                echo Waiting for MicDup to exit...
                :waitloop
                tasklist /fi "PID eq {pid}" 2>nul | find "{pid}" >nul
                if not errorlevel 1 (
                    timeout /t 1 /nobreak >nul
                    goto waitloop
                )
                timeout /t 2 /nobreak >nul
                echo Copying update files...
                set RETRIES=0
                :copyloop
                xcopy /s /y /q "{tempExtract}\*" "{currentDir}\"
                if errorlevel 1 (
                    set /a RETRIES+=1
                    if %RETRIES% GEQ 5 (
                        echo Update failed after 5 retries. Starting app without update.
                        goto startapp
                    )
                    echo Copy failed, retrying in 2 seconds...
                    timeout /t 2 /nobreak >nul
                    goto copyloop
                )
                :startapp
                echo Starting updated MicDup...
                start "" "{currentExe}" --updated
                echo Cleaning up...
                rd /s /q "{tempExtract}" 2>nul
                del "%~f0"
                """;

            File.WriteAllText(scriptPath, script);

            Process.Start(new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c \"{scriptPath}\"",
                WindowStyle = ProcessWindowStyle.Hidden,
                CreateNoWindow = true
            });

            Log.Information("Update script launched, shutting down for update...");
            return true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to download and apply update");
            return false;
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
