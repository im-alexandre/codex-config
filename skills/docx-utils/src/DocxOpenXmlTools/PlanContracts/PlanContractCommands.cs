using System.Text;
using DocxOpenXmlTools.Cli;

namespace DocxOpenXmlTools.PlanContracts;

internal static class PlanContractCommands
{
    public static int PrintPlanContracts(string[] args)
    {
        var targetCommand = args.Length >= 1 && !args[0].StartsWith("-", StringComparison.Ordinal)
            ? args[0].Trim().ToLowerInvariant()
            : null;
        var optionOffset = targetCommand is null ? 0 : 1;
        var contractOptions = CliOptions.Parse(args.Skip(optionOffset).ToArray());
        var format = contractOptions.TryGetValue("format", out var formatValue) && !string.IsNullOrWhiteSpace(formatValue)
            ? formatValue.Trim().ToLowerInvariant()
            : "markdown";
        return PlanContractSupport.PrintPlanContracts(targetCommand, format);
    }

    public static int ValidatePlan(string[] args)
    {
        if (args.Length == 0 || string.IsNullOrWhiteSpace(args[0]) || args[0].StartsWith("-", StringComparison.Ordinal) || CliOptions.IsHelpArgument(args[0]))
        {
            PrintValidatePlanUsage();
            return 1;
        }

        var targetCommand = args[0].Trim().ToLowerInvariant();
        var validationOptions = CliOptions.Parse(args.Skip(1).ToArray());

        if (!validationOptions.TryGetValue("plan", out var planPathValue) || string.IsNullOrWhiteSpace(planPathValue))
        {
            Console.Error.WriteLine("--plan is required");
            return 4;
        }

        var planPath = Path.GetFullPath(planPathValue);
        if (!File.Exists(planPath))
        {
            Console.Error.WriteLine($"Plan not found: {planPath}");
            return 5;
        }

        var planJson = File.ReadAllText(planPath, Encoding.UTF8);
        PlanValidationResult validation = targetCommand switch
        {
            "create-docx" => PlanContractSupport.ValidateCreateDocxPlan(planJson),
            "insert-blocks" => PlanContractSupport.ValidateInsertBlocksPlan(planJson),
            "replace-blocks" => PlanContractSupport.ValidateInsertBlocksPlan(planJson),
            "replace-table" => PlanContractSupport.ValidateReplaceTablePlan(planJson),
            _ => new PlanValidationResult(false, [$"Unsupported plan target for validate-plan: `{targetCommand}`. Use `create-docx`, `insert-blocks`, `replace-blocks` or `replace-table`."])
        };

        if (!validation.IsValid)
        {
            PrintPlanValidationErrors(validation.Errors);
            return 6;
        }

        Console.WriteLine($"Plan valid for {targetCommand}: {planPath}");
        return 0;
    }

    private static void PrintValidatePlanUsage()
    {
        Console.WriteLine("Uso:");
        Console.WriteLine("  docx-utils validate-plan <comando> --plan <json>");
        Console.WriteLine("  Comandos suportados: create-docx, insert-blocks, replace-blocks, replace-table.");
    }

    private static void PrintPlanValidationErrors(IReadOnlyList<string> errors)
    {
        foreach (var error in errors)
        {
            Console.Error.WriteLine(error);
        }
    }
}
