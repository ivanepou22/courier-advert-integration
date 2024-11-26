pageextension 50507 "Sales Invoice List" extends "Sales Invoice List"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
        addafter(Dimensions)
        {
            action(GenerateCourierInvoice)
            {
                ApplicationArea = All;
                Caption = 'Generate Courier Invoice';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Image = GeneralPostingSetup;
                RunObject = report "Generate Courier Invoice";
            }
        }
    }

    var
        myInt: Integer;
}