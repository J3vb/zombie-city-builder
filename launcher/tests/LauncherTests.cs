using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Runtime.Serialization.Json;
using System.Text;

namespace HoldTheGates
{
    internal sealed class FixtureTransport : ITransport
    {
        internal readonly Dictionary<string, byte[]> Assets = new Dictionary<string, byte[]>();
        internal int Requests;
        public void Download(Uri uri, Stream output, long limit, Action<long> progress)
        {
            Check(uri.AbsoluteUri.StartsWith(ReleaseFeed.Repository, StringComparison.Ordinal), "Unexpected repository");
            byte[] data;
            Requests++;
            if (!Assets.TryGetValue(uri.AbsoluteUri.Substring(ReleaseFeed.Repository.Length), out data))
                throw new IOException("Offline");
            using (var input = new MemoryStream(data))
                GithubTransport.CopyBounded(input, output, limit, progress);
        }

        public void Set(Release release, byte[] launcher, byte[] archive)
        {
            using (var json = new MemoryStream())
            {
                new DataContractJsonSerializer(typeof(Release)).WriteObject(json, release);
                Assets["latest/download/windows-update.json"] = json.ToArray();
            }
            string path = "download/v" + release.version + "/";
            Assets[path + ReleaseFeed.LauncherName] = launcher;
            Assets[path + ReleaseFeed.GameZip] = archive;
        }

        internal static void Check(bool ok, string what) { if (!ok) throw new InvalidOperationException(what); }
    }

    internal static class LauncherTests
    {
        private static int Main(string[] args)
        {
            string root = Path.Combine(Path.GetTempPath(), "htg-launcher-test-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            try
            {
                if (args.Length == 2 && args[0] == "--bundle") CheckBundle(root, args[1]);
                else Run(root);
                Console.WriteLine("PASS " + (args.Length == 0 ? "install, launcher handoff, update, interrupted download, offline and retry" : "released Windows bundle"));
                return 0;
            }
            catch (Exception error) { Console.Error.WriteLine(error); return 1; }
            finally { Directory.Delete(root, true); }
        }

        private static byte[] Zip(string version, bool complete)
        {
            using (var memory = new MemoryStream())
            {
                using (var zip = new ZipArchive(memory, ZipArchiveMode.Create, true))
                    foreach (string name in complete ? InstallStore.GameFiles : new[] { "HoldTheGates.exe", "unexpected.txt" })
                        using (var writer = new StreamWriter(zip.CreateEntry(name).Open()))
                            writer.Write(version + " " + name);
                return memory.ToArray();
            }
        }

        private static Release Describe(string version, byte[] launcher, byte[] game)
        {
            return new Release { schema = 1, version = version, launcher_bytes = launcher.Length,
                launcher_sha256 = Digest(launcher), game_bytes = game.Length, game_sha256 = Digest(game) };
        }

        private static string Digest(byte[] data)
        {
            using (var hash = System.Security.Cryptography.SHA256.Create())
                return BitConverter.ToString(hash.ComputeHash(data)).Replace("-", "").ToLowerInvariant();
        }

        private static void MustFail(Action action)
        {
            try { action(); }
            catch (IOException) { return; }
            catch (InvalidDataException) { return; }
            throw new Exception("An incomplete or invalid update was accepted.");
        }

        private static void Run(string root)
        {
            var github = new Uri("https://github.com/");
            var windows = new System.Net.WebProxy("http://windows.invalid:8000");
            FixtureTransport.Check(ProxySettings.Resolve(github, null, null, windows) == windows, "Lost Windows proxy settings");
            const string configured = "http://proxy.invalid:8080";
            FixtureTransport.Check(ProxySettings.Resolve(github, configured, "localhost", windows).GetProxy(github).Host == "proxy.invalid", "Ignored configured HTTPS proxy");
            FixtureTransport.Check(ProxySettings.Resolve(github, configured, ".github.com:443", windows) == null, "Ignored proxy bypass list");
            var store = new InstallStore(Path.Combine(root, "install"));
            using (store.Lock()) MustFail(() => { using (store.Lock()) { } });
            var transport = new FixtureTransport();
            var updater = new Updater(store, new ReleaseFeed(transport));
            string exe = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ReleaseFeed.LauncherName);
            string old = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "test-old", ReleaseFeed.LauncherName);
            byte[] oldExe = File.ReadAllBytes(old), newExe = File.ReadAllBytes(exe);
            string next = Updater.LauncherVersion(exe).ToString();
            var zero = new Version(0, 0, 0);
            var current = Version.Parse(next);
            var first = updater.LocalLauncher(old);
            FixtureTransport.Check(first.Version == zero && first.Exe(true) != old, "Persistent launcher not installed");
            var oldGame = Zip("old", true);
            transport.Set(Describe("0.0.0", oldExe, oldGame), oldExe, oldGame);
            updater.Update(zero, (s, n, t) => { });
            var before = store.Latest(false);
            FixtureTransport.Check(before.Version == zero, "First install failed");
            var newGame = Zip("new", true);
            var release = Describe(next, newExe, newGame);
            var brokenLauncher = (byte[])newExe.Clone();
            brokenLauncher[10] ^= 1;
            transport.Set(release, brokenLauncher, newGame);
            MustFail(() => updater.Update(zero, (s, n, t) => { }));
            FixtureTransport.Check(store.Latest(true).Version == zero, "Bad launcher became active");
            transport.Set(release, newExe, newGame);
            var handoff = updater.Update(zero, (s, n, t) => { });
            FixtureTransport.Check(handoff.Version == current && Updater.LauncherVersion(handoff.Exe(true)) == current, "Wrong handoff");
            FixtureTransport.Check(updater.LocalLauncher(old).Folder == handoff.Folder, "Old download did not forward to the installed launcher");
            FixtureTransport.Check(store.Latest(false).Folder == before.Folder, "Game changed before the new launcher ran");
            transport.Set(release, newExe, newGame.Take(newGame.Length / 2).ToArray());
            MustFail(() => updater.Update(current, (s, n, t) => { }));
            var corrupt = (byte[])newGame.Clone(); corrupt[9] ^= 1;
            transport.Set(release, newExe, corrupt);
            MustFail(() => updater.Update(current, (s, n, t) => { }));
            var malformed = Zip(next, false);
            transport.Set(Describe(next, newExe, malformed), newExe, malformed);
            MustFail(() => updater.Update(current, (s, n, t) => { }));
            FixtureTransport.Check(store.Latest(false).Folder == before.Folder && File.Exists(before.Exe(false)), "Lost last playable installation");
            transport.Set(release, newExe, newGame);
            updater.Update(current, (s, n, t) => { });
            var installed = store.Latest(false);
            FixtureTransport.Check(File.ReadAllText(installed.Exe(false)).StartsWith("new"), "Retry did not install the new build");
            int calls = transport.Requests;
            updater.Update(current, (s, n, t) => { });
            FixtureTransport.Check(transport.Requests == calls + 1, "Downloaded an already installed release");
            transport.Assets.Clear();
            MustFail(() => updater.Update(current, (s, n, t) => { }));
            FixtureTransport.Check(store.Latest(false).Folder == installed.Folder, "Lost the offline game");
            transport.Set(Describe("0.0.0", oldExe, oldGame), oldExe, oldGame);
            updater.Update(current, (s, n, t) => { });
            FixtureTransport.Check(store.Latest(false).Version == current, "Downgraded an installed release");
            File.Delete(Path.Combine(installed.Folder, "town_flow.dll"));
            transport.Set(release, newExe, newGame);
            updater.Update(current, (s, n, t) => { });
            FixtureTransport.Check(store.Latest(false).Version == current, "Missing game file was not repaired");
        }

        private static void CheckBundle(string root, string bundle)
        {
            string manifest = Path.Combine(bundle, "windows-update.json");
            Release release;
            using (var input = File.OpenRead(manifest))
                release = (Release)new DataContractJsonSerializer(typeof(Release)).ReadObject(input);
            release.Validate();
            byte[] exe = File.ReadAllBytes(Path.Combine(bundle, ReleaseFeed.LauncherName));
            byte[] zip = File.ReadAllBytes(Path.Combine(bundle, ReleaseFeed.GameZip));
            var transport = new FixtureTransport();
            transport.Set(release, exe, zip);
            var store = new InstallStore(root);
            var updater = new Updater(store, new ReleaseFeed(transport));
            var handoff = updater.Update(new Version(0, 0, 0), (s, n, t) => { });
            FixtureTransport.Check(handoff != null && Updater.LauncherVersion(handoff.Exe(true)) == release.Number, "Cannot activate published launcher");
            updater.Update(release.Number, (s, n, t) => { });
            var game = store.Latest(false);
            FixtureTransport.Check(game.Version == release.Number && File.Exists(game.Exe(false)), "Cannot install published ZIP");
        }
    }
}
