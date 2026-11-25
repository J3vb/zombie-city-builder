using System;
using System.IO;
using System.Net;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace HoldTheGates
{
    [DataContract]
    internal sealed class Release
    {
        [DataMember] public int schema { get; set; }
        [DataMember] public string version { get; set; }
        [DataMember] public string launcher_sha256 { get; set; }
        [DataMember] public string game_sha256 { get; set; }
        [DataMember] public long launcher_bytes { get; set; }
        [DataMember] public long game_bytes { get; set; }
        public Version Number { get { return Version.Parse(version); } }

        public static bool IsVersion(string value)
        {
            Version parsed;
            return value != null && Version.TryParse(value, out parsed) && parsed.Build >= 0
                && parsed.Revision == -1 && parsed.ToString(3) == value;
        }

        public void Validate()
        {
            if (schema != 1 || !IsVersion(version) || !Hash.Valid(launcher_sha256) || !Hash.Valid(game_sha256)
                || launcher_bytes <= 0 || launcher_bytes > 64L * 1024 * 1024
                || game_bytes <= 0 || game_bytes > 4L * 1024 * 1024 * 1024)
                throw new InvalidDataException("The release contains invalid update information.");
        }
    }

    internal static class Hash
    {
        public static bool Valid(string value)
        {
            return value != null && Regex.IsMatch(value, @"\A[0-9a-f]{64}\z");
        }

        public static string FileDigest(string path)
        {
            using (var input = File.OpenRead(path))
            using (var digest = SHA256.Create())
                return BitConverter.ToString(digest.ComputeHash(input)).Replace("-", "").ToLowerInvariant();
        }
    }

    internal interface ITransport
    {
        void Download(Uri uri, Stream destination, long limit, Action<long> progress);
    }

    internal sealed class GithubTransport : ITransport
    {
        private readonly System.Threading.CancellationToken token;
        public GithubTransport(System.Threading.CancellationToken token) { this.token = token; }

        public void Download(Uri uri, Stream destination, long limit, Action<long> progress)
        {
            for (int hop = 0; hop < 6; hop++)
            {
                if (uri.Scheme != "https" || !uri.IsDefaultPort || uri.UserInfo.Length != 0 ||
                    !(uri.Host == "github.com" || uri.Host.EndsWith(".githubusercontent.com", StringComparison.OrdinalIgnoreCase)))
                    throw new InvalidDataException("GitHub returned an unexpected download location.");
                var request = (HttpWebRequest)WebRequest.Create(uri);
                request.Proxy = ProxySettings.For(uri);
                request.UserAgent = "HoldTheGatesLauncher/1";
                request.AllowAutoRedirect = false;
                request.Timeout = 20000;
                request.ReadWriteTimeout = 30000;
                using (token.Register(request.Abort))
                using (var response = (HttpWebResponse)request.GetResponse())
                {
                    int status = (int)response.StatusCode;
                    if (status >= 300 && status < 400)
                    {
                        uri = new Uri(uri, response.Headers["Location"]);
                        continue;
                    }
                    if (status != 200 || response.ContentLength > limit)
                        throw new InvalidDataException("The release download has an unexpected size or status.");
                    using (var input = response.GetResponseStream())
                        CopyBounded(input, destination, limit, progress);
                    return;
                }
            }
            throw new IOException("GitHub redirected the download too many times.");
        }

        public static long CopyBounded(Stream input, Stream output, long limit, Action<long> progress)
        {
            byte[] buffer = new byte[81920];
            long total = 0;
            int read;
            while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
            {
                total += read;
                if (total > limit) throw new InvalidDataException("The download is larger than expected.");
                output.Write(buffer, 0, read);
                if (progress != null) progress(total);
            }
            return total;
        }
    }

    internal sealed class ReleaseFeed
    {
        internal const string Repository = "https://github.com/J3vb/zombie-city-builder/releases/";
        internal const string LauncherName = "HoldTheGatesLauncher.exe";
        internal const string GameZip = "HoldTheGates-Windows-x64.zip";
        private readonly ITransport transport;
        public ReleaseFeed(ITransport transport) { this.transport = transport; }

        public Release Latest()
        {
            using (var memory = new MemoryStream())
            {
                transport.Download(new Uri(Repository + "latest/download/windows-update.json"), memory, 16384, null);
                memory.Position = 0;
                var release = (Release)new DataContractJsonSerializer(typeof(Release)).ReadObject(memory);
                if (release == null) throw new InvalidDataException("The release information is empty.");
                release.Validate();
                return release;
            }
        }

        public void Fetch(Release release, bool launcher, string path, Action<long> progress)
        {
            long bytes = launcher ? release.launcher_bytes : release.game_bytes;
            string digest = launcher ? release.launcher_sha256 : release.game_sha256;
            var uri = new Uri(Repository + "download/v" + release.version + "/" + (launcher ? LauncherName : GameZip));
            using (var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                transport.Download(uri, output, bytes, progress);
                if (output.Length != bytes) throw new InvalidDataException("The download was interrupted.");
            }
            if (Hash.FileDigest(path) != digest) throw new InvalidDataException("The download failed its SHA-256 check.");
        }
    }
}
