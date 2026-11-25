using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace HoldTheGates
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            var store = new InstallStore(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "HoldTheGates"));
            string next = null;
            try
            {
                FileStream gate;
                try { gate = store.Lock(); }
                catch (IOException) { MessageBox.Show("The launcher is already open or its install folder is busy.", "Hold the Gates"); return; }
                using (var cancel = new System.Threading.CancellationTokenSource())
                using (gate)
                {
                    string running = Application.ExecutablePath;
                    var updater = new Updater(store, new ReleaseFeed(new GithubTransport(cancel.Token)));
                    var local = updater.LocalLauncher(running);
                    if (!String.Equals(local.Exe(true), running, StringComparison.OrdinalIgnoreCase))
                        next = local.Exe(true);
                    else
                    {
                        CreateShortcut(running);
                        using (var window = new LauncherWindow(store, updater, local.Version, cancel))
                        {
                            Application.Run(window);
                            next = window.NextLauncher;
                        }
                    }
                }
                if (next != null) Start(next);
            }
            catch (Exception error)
            {
                MessageBox.Show(error.Message, "Hold the Gates Launcher", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        internal static Process Start(string path)
        {
            return Process.Start(new ProcessStartInfo(path) {
                WorkingDirectory = Path.GetDirectoryName(path), UseShellExecute = false
            });
        }

        internal static bool GameRunning(InstallStore store)
        {
            string prefix = Path.Combine(store.Root, "games") + Path.DirectorySeparatorChar;
            foreach (var process in Process.GetProcessesByName("HoldTheGates"))
                using (process)
                    try
                    {
                        if (process.MainModule.FileName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return true;
                    }
                    catch (InvalidOperationException) { }
                    catch (System.ComponentModel.Win32Exception) { }
            return false;
        }

        private static void CreateShortcut(string path)
        {
            try
            {
                string menu = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
                dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell", true));
                try
                {
                    dynamic link = shell.CreateShortcut(Path.Combine(menu, "Hold the Gates.lnk"));
                    try
                    {
                        link.TargetPath = path;
                        link.WorkingDirectory = Path.GetDirectoryName(path);
                        link.IconLocation = path + ",0";
                        link.Description = "Play and update Hold the Gates";
                        link.Save();
                    }
                    finally { Marshal.FinalReleaseComObject(link); }
                }
                finally { Marshal.FinalReleaseComObject(shell); }
            }
            catch (COMException) { } // A managed Windows profile may disable Start menu shortcuts.
            catch (UnauthorizedAccessException) { }
        }
    }
}
