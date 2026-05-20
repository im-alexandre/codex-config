using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace DocxOpenXmlTools.Mutation;

internal static class MutationAuthorResolver
{
    public static string Resolve(string docxPath, IReadOnlyDictionary<string, string> options)
    {
        if (options.TryGetValue("author", out var explicitAuthor) && !string.IsNullOrWhiteSpace(explicitAuthor))
        {
            return explicitAuthor;
        }

        using var doc = WordprocessingDocument.Open(docxPath, false);
        var existingAuthors = GetDistinctAuthors(doc).ToHashSet(StringComparer.OrdinalIgnoreCase);

        foreach (var author in DefaultMutationAuthors())
        {
            if (!existingAuthors.Contains(author))
            {
                return author;
            }
        }

        for (var suffix = 1; ; suffix++)
        {
            foreach (var author in DefaultMutationAuthors())
            {
                var candidate = $"{author}-{suffix}";
                if (!existingAuthors.Contains(candidate))
                {
                    return candidate;
                }
            }
        }
    }

    private static IReadOnlyList<string> DefaultMutationAuthors() =>
    [
        "Ultron",
        "Brainiac",
        "Jarvis",
        "Vision",
        "HumanTorch",
        "Friday",
        "C3PO",
        "R2D2"
    ];

    private static IReadOnlyList<string> GetDistinctAuthors(WordprocessingDocument doc)
    {
        var mainPart = doc.MainDocumentPart ?? throw new InvalidOperationException("No main document part.");
        var authors = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        const string wordprocessingNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

        void AddAuthor(string? author)
        {
            var value = author?.Trim();
            if (string.IsNullOrWhiteSpace(value))
            {
                return;
            }

            if (seen.Add(value))
            {
                authors.Add(value);
            }
        }

        foreach (var part in MainStoryParts(mainPart))
        {
            if (part.RootElement is null)
            {
                continue;
            }

            foreach (var element in part.RootElement.Descendants<OpenXmlElement>().Prepend(part.RootElement))
            {
                AddAuthor(element.GetAttributes()
                    .FirstOrDefault(attribute =>
                        string.Equals(attribute.LocalName, "author", StringComparison.Ordinal)
                        && string.Equals(attribute.NamespaceUri, wordprocessingNamespace, StringComparison.Ordinal))
                    .Value);
            }
        }

        var comments = mainPart.WordprocessingCommentsPart?.Comments;
        if (comments is not null)
        {
            foreach (var comment in comments.Elements<Comment>())
            {
                AddAuthor(comment.Author?.Value);
            }
        }

        return authors;
    }

    private static IEnumerable<OpenXmlPart> MainStoryParts(MainDocumentPart mainPart)
    {
        yield return mainPart;
        foreach (var part in mainPart.HeaderParts) yield return part;
        foreach (var part in mainPart.FooterParts) yield return part;
        if (mainPart.FootnotesPart is not null) yield return mainPart.FootnotesPart;
        if (mainPart.EndnotesPart is not null) yield return mainPart.EndnotesPart;
    }
}
