pageextension 50504 "Sales Order CA" extends "Sales Order"
{
    layout
    {
        // Add changes to page layout here
        addafter("Due Date")
        {
            field("Courier Or Advert"; Rec."Courier Or Advert")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Courier Or Advert field.';
            }
            field("Date Range Filter"; Rec."Date Range Filter")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Date Range Filter field.';
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}