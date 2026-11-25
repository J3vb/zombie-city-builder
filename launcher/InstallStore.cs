using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;

namespace HoldTheGates
{
    internal sealed class Installed
    {
        public string Folder;
        public Version Version;
        public string Digest;
        public string Exe(bool launcher)
        {
            return Path.Combine(Folder, launcher ? ReleaseFeed.LauncherName : InstallStore.GameFiles[0]);
        }
    }

    internal sealed class InstallStore
    {
        internal static readonly string[] GameFiles = { "HoldTheGates.exe", "town_flow.dll", "godot-cpp-LICENSE.txt" };
        internal readonly string Root;
        private const string Receipt = "installed.txt";
        private const long MaxExpanded = 8L * 1024 * 1024 * 1024;
        public InstallStore(string root) { Root = Path.GetFullPath(root); }
        private string Parent(bool launcher) { return Path.Combine(Root, launcher ? "launchers" : "games"); }

        public FileStream Lock()
        {
            Directory.CreateDirectory(Root);
            return new FileStream(Path.Combine(Root, "launcher.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        }

        private static bool ManagedFolder(string folder)
        {
            Guid id;
            return Guid.TryParseExact(Path.GetFileName(folder), "N", out id)
                && (File.GetAttributes(folder) & FileAttributes.ReparsePoint) == 0;
        }

        private IEnumerable<Installed> Installs(bool launcher)
        {
            if (!Directory.Exists(Parent(launcher))) yield break;
            foreach (string folder in Directory.GetDirectories(Parent(launcher)))
            {
                if (!ManagedFolder(folder)) continue;
                var item = Read(folder, launcher);
                if (item != null) yield return item;
            }
        }

        private Installed Read(string folder, bool launcher)
        {
            try
            {
                string[] receipt = File.ReadAllLines(Path.Combine(folder, Receipt));
                string[] files = launcher ? new[] { ReleaseFeed.LauncherName } : GameFiles;
                if (receipt.Length != 2 + files.Length || !Release.IsVersion(receipt[0]) || !Hash.Valid(receipt[1])) return null;
                for (int i = 0; i < files.Length; i++)
                {
                    var info = new FileInfo(Path.Combine(folder, files[i]));
                    long size;
                    if (!long.TryParse(receipt[i + 2], out size) || size <= 0 || !info.Exists || info.Length != size) return null;
                }
                if (launcher && Hash.FileDigest(Path.Combine(folder, files[0])) != receipt[1]) return null;
                return new Installed { Folder = folder, Version = Version.Parse(receipt[0]), Digest = receipt[1] };
            }
            catch (IOException) { return null; }
        }

        public Installed Latest(bool launcher)
        {
            return Installs(launcher).OrderByDescending(item => item.Version).ThenBy(item => item.Folder, StringComparer.Ordinal).FirstOrDefault();
        }

        public Installed Commit(bool launcher, string version, string digest, Action<string> prepare)
        {
            string stage = Path.Combine(Root, "staging", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(stage);
            try
            {
                prepare(stage);
                string[] files = launcher ? new[] { ReleaseFeed.LauncherName } : GameFiles;
                var receipt = new List<string> { version, digest };
                foreach (string name in files)
                {
                    var file = new FileInfo(Path.Combine(stage, name));
                    if (!file.Exists || file.Length == 0) throw new InvalidDataException("Missing " + name + " in the update.");
                    receipt.Add(file.Length.ToString(System.Globalization.CultureInfo.InvariantCulture));
                }
                File.WriteAllLines(Path.Combine(stage, Receipt), receipt);
                string destination = Path.Combine(Parent(launcher), Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(Parent(launcher));
                Directory.Move(stage, destination);
                return new Installed { Folder = destination, Version = Version.Parse(version), Digest = digest };
            }
            finally { RemoveFlat(stage); }
        }

        public static void ExtractGame(string zip, string stage)
        {
            using (var file = File.OpenRead(zip))
            using (var archive = new ZipArchive(file, ZipArchiveMode.Read))
            {
                if (archive.Entries.Count != GameFiles.Length) throw new InvalidDataException("Unexpected game archive contents.");
                long remaining = MaxExpanded;
                foreach (string name in GameFiles)
                {
                    var entry = archive.GetEntry(name);
                    if (entry == null || entry.Length <= 0 || entry.Length > remaining)
                        throw new InvalidDataException("Missing or invalid game file: " + name);
                    using (var input = entry.Open())
                    using (var output = new FileStream(Path.Combine(stage, name), FileMode.CreateNew))
                    {
                        if (GithubTransport.CopyBounded(input, output, entry.Length, null) != entry.Length)
                            throw new InvalidDataException("Incomplete game file: " + name);
                    }
                    remaining -= entry.Length;
                }
            }
        }

        public void Tidy(bool gameRunning)
        {
            string staging = Path.Combine(Root, "staging");
            if (Directory.Exists(staging))
                foreach (string folder in Directory.GetDirectories(staging))
                    if (ManagedFolder(folder)) RemoveFlat(folder);
            foreach (bool launcher in new[] { true, false })
            {
                if (!launcher && gameRunning) continue;
                foreach (var item in Installs(launcher).OrderByDescending(x => x.Version).Skip(2))
                    RemoveFlat(item.Folder);
            }
        }

        private static void RemoveFlat(string folder)
        {
            try
            {
                if (!Directory.Exists(folder) || !ManagedFolder(folder)) return;
                foreach (string file in Directory.GetFiles(folder)) File.Delete(file);
                Directory.Delete(folder);
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }
}
