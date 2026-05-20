using System.Text.Encodings.Web;
using System.Text.Json;

namespace DocxOpenXmlTools.Cli;

internal static class CliOptions
{
    public static bool IsHelpArgument(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized is "help" or "-h" or "--help" or "/?";
    }

    public static Dictionary<string, string> Parse(string[] args)
    {
        var options = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < args.Length; i++)
        {
            var key = args[i];
            if (!key.StartsWith("--", StringComparison.Ordinal))
            {
                throw new ArgumentException($"Unexpected argument: {key}");
            }

            if (i + 1 >= args.Length)
            {
                throw new ArgumentException($"Missing value for option: {key}");
            }

            options[key[2..]] = args[++i];
        }

        return options;
    }

    public static bool IsTrue(IReadOnlyDictionary<string, string> options, string name) =>
        options.TryGetValue(name, out var value)
        && bool.TryParse(value, out var parsed)
        && parsed;

    public static JsonSerializerOptions JsonOptions() => new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    public static JsonSerializerOptions JsonOptionsIndented() => new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };
}
