using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace HoldTheGates
{
    internal sealed class LauncherWindow : Form
    {
        private readonly InstallStore store;
        private readonly Updater updater;
        private readonly Version version;
        private readonly CancellationTokenSource cancel;
        private readonly Label state = new Label();
        private readonly Label detail = new Label();
        private readonly Button play = new Button();
        private readonly Button check = new Button();
        private readonly ProgressBar progress = new ProgressBar();
        private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        private readonly Color pale = Color.FromArgb(245, 238, 220);
        private bool busy, closing, gameRunning;
        private DateTime nextCheck;
        private Installed game;
        public string NextLauncher { get; private set; }

        public LauncherWindow(InstallStore store, Updater updater, Version version, CancellationTokenSource cancel)
        {
            this.store = store; this.updater = updater; this.version = version; this.cancel = cancel;
            Text = "Hold the Gates Launcher";
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(690, 416);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            BackColor = Color.FromArgb(26, 40, 44);
            ForeColor = pale;
            Font = new Font("Segoe UI", 10);
            Controls.Add(new StationBanner { Dock = DockStyle.Top, Height = 210 });

            state.SetBounds(25, 226, 638, 33);
            state.Font = new Font(Font.FontFamily, 16, FontStyle.Bold);
            detail.SetBounds(27, 263, 634, 44);
            detail.ForeColor = Color.FromArgb(208, 217, 211);
            detail.AutoEllipsis = true;
            progress.SetBounds(27, 317, 636, 8);
            play.SetBounds(500, 350, 163, 42);
            check.SetBounds(27, 350, 157, 42);
            Style(play, "Play", Color.FromArgb(170, 76, 39));
            Style(check, "Check for updates", Color.FromArgb(53, 74, 80));
            Controls.AddRange(new Control[] { state, detail, progress, play, check });
            AcceptButton = play;
            play.Click += (s, e) => Play();
            check.Click += async (s, e) => await RefreshRelease();
            Shown += async (s, e) => { timer.Start(); await RefreshRelease(); };
            timer.Interval = 3000;
            timer.Tick += async (s, e) => {
                if (busy || closing) return;
                bool wasRunning = gameRunning;
                gameRunning = Program.GameRunning(store);
                Buttons();
                if ((wasRunning && !gameRunning) || DateTime.UtcNow >= nextCheck) await RefreshRelease();
            };
        }

        private void Style(Button button, string text, Color color)
        {
            button.Text = text; button.BackColor = color; button.ForeColor = pale;
            button.FlatStyle = FlatStyle.Flat; button.FlatAppearance.BorderSize = 0;
            button.Font = new Font(Font.FontFamily, 10, FontStyle.Bold);
        }

        private void Buttons()
        {
            check.Enabled = !busy && !gameRunning && !closing;
            play.Enabled = !busy && !gameRunning && game != null && !closing;
            play.Text = gameRunning ? "Game running" : "Play";
        }

        private void Play()
        {
            if (game == null || gameRunning) return;
            try
            {
                using (Program.Start(game.Exe(false))) { }
                gameRunning = true;
                Buttons();
            }
            catch (Exception error) { state.Text = "Could not start the game"; detail.Text = error.Message; }
        }

        private async Task RefreshRelease()
        {
            if (busy || closing) return;
            nextCheck = DateTime.UtcNow.AddMinutes(15);
            gameRunning = Program.GameRunning(store);
            game = store.Latest(false);
            if (gameRunning) { state.Text = "Game running"; detail.Text = "Updates resume when you exit the game."; Buttons(); return; }
            busy = true;
            Buttons();
            state.Text = "Checking for updates";
            detail.Text = game == null ? "Looking for the latest Windows release." : "Installed game   " + game.Version;
            progress.Visible = true;
            progress.Style = ProgressBarStyle.Marquee;
            var updates = new Progress<Tuple<string, long, long>>(item => {
                if (closing || !busy || IsDisposed) return;
                state.Text = item.Item1;
                detail.Text = item.Item3 == 0 ? "Preparing game files." : String.Format("{0:N1} of {1:N1} MB", item.Item2 / 1048576d, item.Item3 / 1048576d);
                progress.Style = item.Item3 == 0 ? ProgressBarStyle.Marquee : ProgressBarStyle.Continuous;
                if (item.Item3 != 0) progress.Value = (int)Math.Min(100, 100 * item.Item2 / item.Item3);
            });
            try
            {
                var handoff = await Task.Run(() => {
                    store.Tidy(false);
                    long lastPercent = -1;
                    return updater.Update(version, (label, done, total) => {
                        long percent = total == 0 ? -1 : done * 100 / total;
                        if (done == 0 || percent != lastPercent)
                            ((IProgress<Tuple<string,long,long>>)updates).Report(Tuple.Create(label, done, total));
                        lastPercent = percent;
                    });
                });
                if (handoff != null && !closing) { NextLauncher = handoff.Exe(true); closing = true; }
                game = store.Latest(false);
                state.Text = "Ready to play";
                detail.Text = game == null ? "Restarting the updated launcher." : "Game " + game.Version + "     •     Launcher " + version;
            }
            catch (Exception error)
            {
                game = store.Latest(false);
                state.Text = game == null ? "Install paused" : "Your installed game is ready";
                detail.Text = (game == null ? "Check for updates to retry. " : "Update check failed. ") + error.Message;
            }
            finally
            {
                busy = false;
                progress.Style = ProgressBarStyle.Continuous;
                progress.Visible = false;
                Buttons();
                if (closing) Close();
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (busy)
            {
                closing = true;
                cancel.Cancel();
                state.Text = "Closing launcher";
                e.Cancel = true;
            }
            base.OnFormClosing(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) timer.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class StationBanner : Panel
    {
        private readonly Bitmap station;
        public StationBanner()
        {
            DoubleBuffered = true;
            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("station.jpg"))
            using (var image = Image.FromStream(stream)) station = new Bitmap(image);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            float scale = Math.Max((float)Width / station.Width, (float)Height / station.Height);
            float height = scale * station.Height;
            e.Graphics.DrawImage(station, 0, (Height - height) * 0.42f, Width, height);
            using (var shade = new LinearGradientBrush(ClientRectangle, Color.FromArgb(246, 16, 29, 32), Color.FromArgb(18, 16, 29, 32), 0f))
                e.Graphics.FillRectangle(shade, ClientRectangle);
            using (var title = new Font("Segoe UI", 28, FontStyle.Bold))
                e.Graphics.DrawString("HOLD THE\nGATES", title, Brushes.FloralWhite, 22, Height / 2 - title.Height);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) station.Dispose();
            base.Dispose(disposing);
        }
    }
}
