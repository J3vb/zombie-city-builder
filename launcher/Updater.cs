using System;
using System.Diagnostics;
using System.IO;

namespace HoldTheGates
{
    internal sealed class Updater
    {
        private readonly InstallStore store;
        private readonly ReleaseFeed feed;
        public Updater(InstallStore store, ReleaseFeed feed) { this.store = store; this.feed = feed; }

        public static Version LauncherVersion(string path)
        {
            string version = FileVersionInfo.GetVersionInfo(path).ProductVersion;
            if (!Release.IsVersion(version)) throw new InvalidDataException("Invalid launcher version.");
            return Version.Parse(version);
        }

        // A browser download also serves as a durable entry point if its installed copy is newer.
        public Installed LocalLauncher(string running)
        {
            Version version = LauncherVersion(running);
            var installed = store.Latest(true);
            if (installed != null && installed.Version >= version) return installed;
            return store.Commit(true, version.ToString(), Hash.FileDigest(running),
                stage => File.Copy(running, Path.Combine(stage, ReleaseFeed.LauncherName)));
        }

        // Return the new launcher first so it can install its own release's game format.
        public Installed Update(Version running, Action<string, long, long> report)
        {
            var release = feed.Latest();
            if (release.Number > running)
            {
                return store.Commit(true, release.version, release.launcher_sha256, stage => {
                    string path = Path.Combine(stage, ReleaseFeed.LauncherName);
                    report("Updating launcher", 0, release.launcher_bytes);
                    feed.Fetch(release, true, path, n => report("Updating launcher", n, release.launcher_bytes));
                    if (LauncherVersion(path) != release.Number)
                        throw new InvalidDataException("The launcher version does not match the release.");
                });
            }
            var game = store.Latest(false);
            if (game != null && game.Version >= release.Number)
            {
                if (game.Version == release.Number && game.Digest != release.game_sha256)
                    throw new InvalidDataException("This release changed after installation.");
                return null;
            }
            store.Commit(false, release.version, release.game_sha256, stage => {
                string zip = Path.Combine(stage, "download.zip");
                report("Downloading game", 0, release.game_bytes);
                feed.Fetch(release, false, zip, n => report("Downloading game", n, release.game_bytes));
                report("Installing game", 0, 0);
                InstallStore.ExtractGame(zip, stage);
                File.Delete(zip);
            });
            return null;
        }
    }
}
