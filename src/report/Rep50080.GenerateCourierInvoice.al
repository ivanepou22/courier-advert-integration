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
                SalesHeader.GenerateSalesInvoice(StartDate, EndDate, Section::invoice, PostingDate, DocumentType);
            end;

            trigger OnPreDataItem()
            begin
                if StartDate = 0D then
                    Error('Start Date is required');
                if EndDate = 0D then
                    Error('End Date is required');
                if StartDate > EndDate then
                    Error('Start Date must be before End Date');
                if PostingDate = 0D then
                    Error('Posting Date is required');
                if not (DocumentType in [DocumentType::Invoice, DocumentType::Order]) then
                    Error('Document Type must be either Invoice or Order');
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
                    field(DocumentType; DocumentType)
                    {
                        ApplicationArea = All;
                        Caption = 'Document Type';
                    }
                    field(PostingDate; PostingDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Posting Date';
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
        PostingDate: Date;
        DocumentType: Enum "Sales Document Type";
}