using System.Diagnostics;
using System.Text;
using System.Text.Json;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Xunit;

namespace DocxOpenXmlTools.Tests;

public sealed class DocxOpenXmlToolsCliTests
{
    [Fact]
    public async Task Validate_reports_no_openxml_errors_for_minimal_generated_docx()
    {
        var skillRoot = FindSkillRoot();
        var articleProject = Path.Combine(skillRoot, "src", "ArticleDocxBuilder", "ArticleDocxBuilder.csproj");
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var specPath = Path.Combine(tempDir.Path, "article_spec.json");
        var docxPath = Path.Combine(tempDir.Path, "article.docx");

        await File.WriteAllTextAsync(specPath, """
        {
          "title": "Teste Docx Utils",
          "subtitle": "Baseline automatizado",
          "authorLine": "Ultron",
          "resumo": "Documento minimo para validar Open XML.",
          "abstract": "Minimal document for Open XML validation.",
          "palavrasChave": ["teste"],
          "keywords": ["test"],
          "sections": [
            { "heading": "Introducao", "level": 1, "paragraphs": ["Paragrafo temporario de validacao."], "items": [] }
          ],
          "references": []
        }
        """);

        var buildResult = await RunProcessAsync("dotnet", $"run --project \"{articleProject}\" -- \"{specPath}\" \"{docxPath}\" Ultron", skillRoot);
        Assert.True(buildResult.ExitCode == 0, buildResult.CombinedOutput);
        Assert.True(File.Exists(docxPath), "O ArticleDocxBuilder nao gerou o DOCX temporario.");

        var validateResult = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- validate \"{docxPath}\"", skillRoot);
        Assert.True(validateResult.ExitCode == 0, validateResult.CombinedOutput);
        Assert.Contains("TrackRevisions: True", validateResult.CombinedOutput);
        Assert.Contains("OpenXmlValidationErrors: 0", validateResult.CombinedOutput);
        Assert.Contains("OpenXmlValidationErrorsActionable: 0", validateResult.CombinedOutput);
    }

    [Theory]
    [InlineData(new string[] { }, "Ultron")]
    [InlineData(new[] { "Ultron" }, "Brainiac")]
    [InlineData(new[] { "Ultron", "Brainiac", "Jarvis", "Vision", "HumanTorch", "Friday", "C3PO", "R2D2" }, "Ultron-1")]
    [InlineData(new[] { "Ultron", "Brainiac", "Jarvis", "Vision", "HumanTorch", "Friday", "C3PO", "R2D2", "Ultron-1" }, "Brainiac-1")]
    public async Task Mutating_command_without_author_uses_next_available_default_author(string[] existingAuthors, string expectedAuthor)
    {
        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "authors.docx");

        CreateDocxForAuthorSelection(docxPath, existingAuthors);
        var result = await RunInsertCommentAsync(tempDir.Path, docxPath);

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.Equal(expectedAuthor, ReadInsertedCommentAuthor(docxPath));
    }

    [Theory]
    [InlineData("NomeDoSubagent")]
    [InlineData("Ultron")]
    public async Task Mutating_command_with_explicit_author_preserves_author_even_when_existing(string author)
    {
        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "authors.docx");

        CreateDocxForAuthorSelection(docxPath, ["Ultron", author]);
        var result = await RunInsertCommentAsync(tempDir.Path, docxPath, author);

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.Equal(author, ReadInsertedCommentAuthor(docxPath));
    }

    [Fact]
    public async Task ListAuthors_is_not_exposed_in_cli_usage()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "authors.docx");
        CreateDocxForAuthorSelection(docxPath, []);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- list-authors \"{docxPath}\"", skillRoot);

        Assert.Equal(3, result.ExitCode);
        Assert.Contains("Unknown command: list-authors", result.CombinedOutput);
        Assert.DoesNotContain("list-authors", result.StandardOutput);
    }

    [Fact]
    public async Task Comments_outputs_json_when_requested_with_empty_orientation_and_author_filter()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "comments.docx");
        CreateDocxForAuthorSelection(
            docxPath,
            ["Alexandre Castro", "Outro Autor"],
            ["Comentario filtrado", "Comentario fora do filtro"]);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- comments \"{docxPath}\" --author \"Alexandre\" --format json", skillRoot);

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        using var json = JsonDocument.Parse(result.StandardOutput);
        var comments = json.RootElement.GetProperty("comments");
        Assert.Equal(1, comments.GetArrayLength());
        var comment = comments[0];
        Assert.Equal("0", comment.GetProperty("id").GetString());
        Assert.Equal("Alexandre Castro", comment.GetProperty("autor").GetString());
        Assert.Equal("Comentario filtrado", comment.GetProperty("conteudo").GetString());
        Assert.Equal("", comment.GetProperty("orientacao").GetString());
        Assert.True(comment.GetProperty("ancora").ValueKind == JsonValueKind.Null);
        Assert.True(comment.GetProperty("parentCommentId").ValueKind == JsonValueKind.Null);
    }

    [Fact]
    public async Task Comments_auto_outputs_terminal_table_on_cli_surface()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "comments.docx");
        CreateDocxForAuthorSelection(docxPath, ["Alexandre Castro", "Newton"], ["Comentario para terminal", "Segundo comentario"]);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- comments \"{docxPath}\"", skillRoot, new Dictionary<string, string?>
        {
            ["CODEX_MANAGED_BY_NPM"] = "1"
        });

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.Contains("┌", result.StandardOutput);
        Assert.Contains("│ (index) │ id", result.StandardOutput);
        Assert.Contains("Comentario para terminal", result.StandardOutput);
        Assert.Contains("Segundo comentario", result.StandardOutput);
        Assert.True(
            result.StandardOutput.Split(Environment.NewLine).Count(line => line.StartsWith("├", StringComparison.Ordinal)) >= 2,
            result.StandardOutput);
        Assert.All(
            result.StandardOutput.Split(Environment.NewLine, StringSplitOptions.RemoveEmptyEntries),
            line => Assert.True(line.Length <= 120, $"Linha com {line.Length} caracteres: {line}"));
    }

    [Fact]
    public async Task Comments_auto_outputs_markdown_on_app_surface()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "comments.docx");
        CreateDocxForAuthorSelection(docxPath, ["Alexandre Castro"], ["Comentario para app"]);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- comments \"{docxPath}\"", skillRoot, new Dictionary<string, string?>
        {
            ["CODEX_MANAGED_BY_NPM"] = "0"
        });

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.StartsWith("| id | autor | conteudo | orientacao |", result.StandardOutput);
        Assert.Contains("| 0 | Alexandre Castro | Comentario para app |  |", result.StandardOutput);
    }

    [Theory]
    [InlineData("1", "┌", "| id | autor | conteudo | orientacao |")]
    [InlineData("0", "| id | autor | conteudo | orientacao |", "┌")]
    public async Task Comments_explicit_auto_forces_format_from_surface(string managedByNpm, string expected, string unexpected)
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "comments.docx");
        CreateDocxForAuthorSelection(docxPath, ["Alexandre Castro"], ["Comentario auto"]);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- comments \"{docxPath}\" --format auto", skillRoot, new Dictionary<string, string?>
        {
            ["CODEX_MANAGED_BY_NPM"] = managedByNpm
        });

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.Contains(expected, result.StandardOutput);
        Assert.DoesNotContain(unexpected, result.StandardOutput);
    }

    [Fact]
    public async Task Comments_outputs_markdown_without_forced_wrap_and_escapes_pipes()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "comments.docx");
        var longText = "Comentario com | marcador e conteudo longo que deve permanecer em uma unica linha logica no Markdown sem quebra forcada por largura.";
        CreateDocxForAuthorSelection(docxPath, ["Alexandre Castro"], [longText]);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- comments \"{docxPath}\" --format markdown", skillRoot);

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        var lines = result.StandardOutput.Split(Environment.NewLine, StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(3, lines.Length);
        Assert.Equal("| id | autor | conteudo | orientacao |", lines[0]);
        Assert.Equal("| --- | --- | --- | --- |", lines[1]);
        Assert.Contains("Comentario com \\| marcador", lines[2]);
        Assert.Contains("sem quebra forcada por largura", lines[2]);
    }

    [Fact]
    public async Task Comments_outputs_raw_legacy_format()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "comments.docx");
        CreateDocxForAuthorSelection(docxPath, ["Alexandre Castro"], ["Comentario legado"]);

        var result = await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- comments \"{docxPath}\" --format raw", skillRoot);

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.Contains("comment id=\"0\" author=\"Alexandre Castro\"", result.StandardOutput);
        Assert.Contains("text=\"Comentario legado\"", result.StandardOutput);
    }

    [Fact]
    public async Task ReplaceTable_by_ordinal_preserves_table_and_cell_styles()
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");

        using var tempDir = new TempDirectory();
        var docxPath = Path.Combine(tempDir.Path, "tables.docx");
        var planPath = Path.Combine(tempDir.Path, "replace-table.json");
        var lockPath = Path.Combine(tempDir.Path, "replace-table.lock");
        var reportPath = Path.Combine(tempDir.Path, "replace-table.md");

        CreateDocxForTableReplacement(docxPath);
        await File.WriteAllTextAsync(planPath, """
        {
          "tables": [
            {
              "id": "tabela-2",
              "ordinal": 2,
              "rows": [
                ["Novo A1", "Novo A2"],
                ["Novo B1", "Novo B2"]
              ]
            }
          ]
        }
        """);

        var result = await RunProcessAsync(
            "dotnet",
            $"run --project \"{toolsProject}\" -- replace-table \"{docxPath}\" --plan \"{planPath}\" --lock \"{lockPath}\" --report \"{reportPath}\"",
            skillRoot);

        Assert.True(result.ExitCode == 0, result.CombinedOutput);
        Assert.Contains("APPLY tabela-2", result.StandardOutput);
        Assert.True(File.Exists(reportPath), "O relatorio de replace-table nao foi criado.");
        Assert.Contains("Replace Table Report", await File.ReadAllTextAsync(reportPath));

        using var document = WordprocessingDocument.Open(docxPath, false);
        var tables = document.MainDocumentPart!.Document.Body!.Elements<Table>().ToList();
        Assert.Equal(2, tables.Count);

        Assert.Equal("TabelaOriginal", tables[0].GetFirstChild<TableProperties>()?.TableStyle?.Val?.Value);
        Assert.Equal("TabelaOriginal", tables[1].GetFirstChild<TableProperties>()?.TableStyle?.Val?.Value);

        var secondTableRows = tables[1].Elements<TableRow>().ToList();
        Assert.Equal(2, secondTableRows.Count);
        Assert.Equal("Novo A1", GetCellText(secondTableRows[0], 0));
        Assert.Equal("Novo A2", GetCellText(secondTableRows[0], 1));
        Assert.Equal("Novo B1", GetCellText(secondTableRows[1], 0));
        Assert.Equal("Novo B2", GetCellText(secondTableRows[1], 1));

        foreach (var paragraph in tables[1].Descendants<Paragraph>())
        {
            Assert.Equal("dados-original", paragraph.ParagraphProperties?.ParagraphStyleId?.Val?.Value);
        }
    }

    private static string FindSkillRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "scripts", "install-docx-utils.ps1")) &&
                Directory.Exists(Path.Combine(directory.FullName, "src", "DocxOpenXmlTools")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new InvalidOperationException("Nao foi possivel localizar a raiz da skill docx-utils.");
    }

    private static async Task<ProcessResult> RunProcessAsync(
        string fileName,
        string arguments,
        string workingDirectory,
        IReadOnlyDictionary<string, string?>? environment = null)
    {
        using var process = new Process();
        process.StartInfo = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        if (environment is not null)
        {
            foreach (var item in environment)
            {
                process.StartInfo.Environment[item.Key] = item.Value;
            }
        }

        process.Start();
        var stdout = await process.StandardOutput.ReadToEndAsync();
        var stderr = await process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();

        return new ProcessResult(process.ExitCode, stdout, stderr);
    }

    private static async Task<ProcessResult> RunInsertCommentAsync(string tempDir, string docxPath, string? author = null)
    {
        var skillRoot = FindSkillRoot();
        var toolsProject = Path.Combine(skillRoot, "src", "DocxOpenXmlTools", "DocxOpenXmlTools.csproj");
        var planPath = Path.Combine(tempDir, "comments.json");
        var lockPath = Path.Combine(tempDir, "comments.lock");

        await File.WriteAllTextAsync(planPath, """
        {
          "comments": [
            {
              "id": "comentario-teste",
              "anchorPrefix": "Paragrafo alvo",
              "commentText": "Comentario teste"
            }
          ]
        }
        """);

        var authorArgs = string.IsNullOrWhiteSpace(author) ? "" : $" --author \"{author}\"";
        return await RunProcessAsync("dotnet", $"run --project \"{toolsProject}\" -- insert-comments \"{docxPath}\" --plan \"{planPath}\" --lock \"{lockPath}\"{authorArgs}", skillRoot);
    }

    private static void CreateDocxForAuthorSelection(
        string docxPath,
        IReadOnlyList<string> existingAuthors,
        IReadOnlyList<string>? commentTexts = null)
    {
        var now = DateTime.UtcNow;

        using var document = WordprocessingDocument.Create(docxPath, WordprocessingDocumentType.Document);
        var mainPart = document.AddMainDocumentPart();
        mainPart.Document = new Document(new Body());

        var body = mainPart.Document.Body!;
        body.Append(new Paragraph(new Run(new Text("Paragrafo alvo para comentario."))));

        var commentsPart = mainPart.AddNewPart<WordprocessingCommentsPart>();
        commentsPart.Comments = new Comments();

        for (var i = 0; i < existingAuthors.Count; i++)
        {
            var comment = new Comment
            {
                Id = i.ToString(),
                Author = existingAuthors[i],
                Date = now
            };
            var text = commentTexts is not null && i < commentTexts.Count
                ? commentTexts[i]
                : $"Comentario existente {i}";
            comment.Append(new Paragraph(new Run(new Text(text))));
            commentsPart.Comments.Append(comment);
        }

        mainPart.Document.Save();
        commentsPart.Comments.Save();
    }

    private static string ReadInsertedCommentAuthor(string docxPath)
    {
        using var document = WordprocessingDocument.Open(docxPath, false);
        var comment = document.MainDocumentPart?.WordprocessingCommentsPart?.Comments?
            .Elements<Comment>()
            .FirstOrDefault(comment => comment.InnerText.Contains("Comentario teste", StringComparison.Ordinal));

        Assert.NotNull(comment);
        return comment.Author?.Value ?? "";
    }

    private static void CreateDocxForTableReplacement(string docxPath)
    {
        using var document = WordprocessingDocument.Create(docxPath, WordprocessingDocumentType.Document);
        var mainPart = document.AddMainDocumentPart();
        mainPart.Document = new Document(new Body());

        var body = mainPart.Document.Body!;
        body.Append(new Paragraph(new Run(new Text("Antes da primeira tabela."))));
        body.Append(CreateStyledTable(
            "TabelaOriginal",
            "dados-original",
            [
                ["Tabela 1 - Celula A1", "Tabela 1 - Celula A2"],
                ["Tabela 1 - Celula B1", "Tabela 1 - Celula B2"]
            ]));
        body.Append(new Paragraph(new Run(new Text("Entre tabelas para ancoragem."))));
        body.Append(CreateStyledTable(
            "TabelaOriginal",
            "dados-original",
            [
                ["Tabela 2 - Celula A1", "Tabela 2 - Celula A2"],
                ["Tabela 2 - Celula B1", "Tabela 2 - Celula B2"]
            ]));
        body.Append(new Paragraph(new Run(new Text("Depois da segunda tabela."))));

        mainPart.Document.Save();
    }

    private static Table CreateStyledTable(string tableStyleId, string cellStyleId, IReadOnlyList<IReadOnlyList<string>> rows)
    {
        var table = new Table();
        table.Append(new TableProperties(
            new TableStyle { Val = tableStyleId },
            new TableWidth { Width = "9000", Type = TableWidthUnitValues.Dxa },
            new TableJustification { Val = TableRowAlignmentValues.Center },
            new TableLayout { Type = TableLayoutValues.Fixed }));

        var grid = new TableGrid();
        var columnCount = rows.Select(row => row.Count).DefaultIfEmpty(0).Max();
        for (var i = 0; i < columnCount; i++)
        {
            grid.Append(new GridColumn { Width = "4500" });
        }
        table.Append(grid);

        foreach (var rowValues in rows)
        {
            var row = new TableRow();
            for (var i = 0; i < columnCount; i++)
            {
                var cell = new TableCell(new TableCellProperties(new TableCellWidth
                {
                    Width = "4500",
                    Type = TableWidthUnitValues.Dxa
                }));
                var paragraph = new Paragraph(new ParagraphProperties(new ParagraphStyleId { Val = cellStyleId }));
                paragraph.Append(new Run(new Text(i < rowValues.Count ? rowValues[i] : "") { Space = SpaceProcessingModeValues.Preserve }));
                cell.Append(paragraph);
                row.Append(cell);
            }

            table.Append(row);
        }

        return table;
    }

    private static string GetCellText(TableRow row, int cellIndex)
    {
        return row.Elements<TableCell>()
            .ElementAt(cellIndex)
            .Descendants<Text>()
            .Select(text => text.Text)
            .Aggregate(string.Empty, (current, text) => current + text);
    }

    private sealed record ProcessResult(int ExitCode, string StandardOutput, string StandardError)
    {
        public string CombinedOutput => StandardOutput + Environment.NewLine + StandardError;
    }

    private sealed class TempDirectory : IDisposable
    {
        public TempDirectory()
        {
            Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "docx-utils-test-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path);
        }

        public string Path { get; }

        public void Dispose()
        {
            if (Directory.Exists(Path))
            {
                Directory.Delete(Path, recursive: true);
            }
        }
    }
}
