pageextension 50503 "Sales Invoice CA" extends "Sales Invoice"
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
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}