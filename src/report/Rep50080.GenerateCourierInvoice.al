report 50080 "Generate Courier Invoice"
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    ProcessingOnly = true;
    Caption = 'Generate Courier Invoice';

    dataset
    {
        dataitem("Sales & Receivables Setup"; "Sales & Receivables Setup")
        {
            trigger OnAfterGetRecord()
            var
                SalesHeader: Record "Sales Header";
            begin
                SalesHeader.GenerateSalesInvoice(StartDate, EndDate, Section::invoice);
            end;

            trigger OnPreDataItem()
            begin
                if StartDate = 0D then
                    Error('Start Date is required');
                if EndDate = 0D then
                    Error('End Date is required');
                if StartDate > EndDate then
                    Error('Start Date must be before End Date');
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(GroupName)
                {
                    field(Section; Section)
                    {
                        ApplicationArea = All;
                    }
                    field(StartDate; StartDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Start Date';
                    }
                    field(EndDate; EndDate)
                    {
                        ApplicationArea = All;
                        Caption = 'End Date';
                    }
                }
            }
        }
    }
    var
        StartDate: Date;
        EndDate: Date;
        Section: Enum "Section Type";
}