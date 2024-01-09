let
    CustomFunction = (SourceTable as table, CorrectionsListTable as table, IndexColumn as text, CorrectionHeader as text, CorrectionValue as text) =>
    let
        // Load Corrections Table
        tblCorrection = CorrectionsListTable,

        // Load Source Table
        tblSource = SourceTable,

        // Replace nulls in Source table with $null$ string to ensure all fields are captured
        ReplacedNullsOn = Table.ReplaceValue(tblSource,null,"$null$",Replacer.ReplaceValue,Table.ColumnNames(tblSource)),

        // Unpivot the Source Table
        UnpivotSource = Table.UnpivotOtherColumns(ReplacedNullsOn, {IndexColumn}, CorrectionHeader, CorrectionValue),

        // Merge Corrections into Source as tables in new column
        MergedCorrections = Table.NestedJoin(UnpivotSource, {IndexColumn, CorrectionHeader}, tblCorrection, {IndexColumn, CorrectionHeader}, "tblCorrection", JoinKind.LeftOuter),

        // Expand Corrections
        ExpandedCorrections = Table.ExpandTableColumn(MergedCorrections, "tblCorrection", {CorrectionValue}, {"tblCorrection.Value"}),

        // Apply the Corrections by adding a new Custom Column with the value of the Correction if it exists or the existing Source value otherwise
        AppliedCorrections = Table.AddColumn(ExpandedCorrections, "Custom", each if [tblCorrection.Value] = " " or [tblCorrection.Value] = null then [Value] else [tblCorrection.Value]),

        // Remove the Original Source Value, leaving only the new Custom one
        RemovedOriginal = Table.RemoveColumns(AppliedCorrections,{CorrectionValue, "tblCorrection.Value"}),

        // Create a list of Distinct Values to be used for the final Pivot, necessary to avoid error where CorrectionHeader is read literally
        DistinctValues = List.Distinct(List.Transform(Table.ToRecords(RemovedOriginal), each Record.Field(_, CorrectionHeader))),

        // Pivot final DATA back into a Table
        PivotFinal = Table.Pivot(RemovedOriginal, DistinctValues, CorrectionHeader, "Custom"),

        // Replace $null$ string with nulls now tha all operations are complete
        ReplaceNulls = Table.ReplaceValue(PivotFinal,"$null$",null,Replacer.ReplaceValue,Table.ColumnNames(PivotFinal))
    in
        ReplaceNulls
in
    CustomFunction