using System.Text.Json.Nodes;
using TerroirEngine.Tasting.Practice;

namespace TerroirEngine.Tests;

/// <summary>The exam date the player sets on Tasting practice (learning-core design §4.4): validated in the sim, never in the UI.</summary>
public class ExamDateTests
{
    private static readonly DateOnly Today = new(2026, 10, 5);

    [Fact]
    public void ExamDate_FutureDate_IsStoredAndCounted()
    {
        var (rec, err) = PracticeProgress.TrySetExamDate(new JsonObject(), "2027-06-12", Today);
        Assert.Null(err);
        var s = PracticeProgress.Summary(rec, Today);
        Assert.Equal("2027-06-12", (string?)s["examDate"]);
        Assert.Equal(250, (int?)s["daysToExam"]);
    }

    [Theory]
    [InlineData("2027-02-30", "That date does not exist.")]
    [InlineData("2026-10-05", "Pick a date after today.")]
    [InlineData("2025-01-01", "Pick a date after today.")]
    [InlineData("2032-01-01", "Pick a date within the next five years.")]
    public void ExamDate_InvalidDate_IsRefusedAndRecordUnchanged(string date, string message)
    {
        var start = PracticeProgress.SetExamDate(new JsonObject(), new DateOnly(2027, 1, 20));
        var (rec, err) = PracticeProgress.TrySetExamDate(start, date, Today);
        Assert.Equal(message, err);
        Assert.Equal("2027-01-20", (string?)rec["examDate"]);
    }

    [Fact]
    public void ExamDate_EmptyString_Clears()
    {
        var start = PracticeProgress.SetExamDate(new JsonObject(), new DateOnly(2027, 1, 20));
        var (rec, err) = PracticeProgress.TrySetExamDate(start, "", Today);
        Assert.Null(err);
        Assert.Null(rec["examDate"]);
        Assert.Null((int?)PracticeProgress.Summary(rec, Today)["daysToExam"]);
    }
}
