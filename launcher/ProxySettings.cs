using System;
using System.Net;

namespace HoldTheGates
{
    internal static class ProxySettings
    {
        // .NET Framework reads Windows Internet Options. Also honor a proxy supplied by the environment.
        public static IWebProxy For(Uri target)
        {
            return Resolve(target, Environment.GetEnvironmentVariable("HTTPS_PROXY")
                ?? Environment.GetEnvironmentVariable("ALL_PROXY"), Environment.GetEnvironmentVariable("NO_PROXY"),
                WebRequest.DefaultWebProxy);
        }

        internal static IWebProxy Resolve(Uri target, string configured, string bypass, IWebProxy windows)
        {
            if (String.IsNullOrWhiteSpace(configured)) return windows;
            foreach (string rule in (bypass ?? "").Split(','))
            {
                string host = rule.Trim().TrimStart('.');
                if (host == "*") return null;
                if (host.EndsWith(":443", StringComparison.Ordinal)) host = host.Substring(0, host.Length - 4);
                if (host.StartsWith("*.", StringComparison.Ordinal)) host = host.Substring(2);
                if (host.Length > 0 && (target.Host.Equals(host, StringComparison.OrdinalIgnoreCase)
                    || target.Host.EndsWith("." + host, StringComparison.OrdinalIgnoreCase))) return null;
            }
            Uri address;
            if (!Uri.TryCreate(configured, UriKind.Absolute, out address) ||
                (address.Scheme != "http" && address.Scheme != "https"))
                throw new InvalidOperationException("The configured HTTPS proxy address is invalid.");
            var clean = new UriBuilder(address) { UserName = "", Password = "" };
            var proxy = new WebProxy(clean.Uri);
            if (address.UserInfo.Length > 0)
            {
                string[] parts = address.UserInfo.Split(new[] { ':' }, 2);
                proxy.Credentials = new NetworkCredential(Uri.UnescapeDataString(parts[0]),
                    parts.Length > 1 ? Uri.UnescapeDataString(parts[1]) : "");
            }
            return proxy;
        }
    }
}
