pageextension 50500 "General Ledger Setup CA" extends "General Ledger Setup"
{
    layout
    {
        // Add changes to page layout here
        addbefore("Background Posting")
        {
            group(CourierAndAdverts)
            {
                Caption = 'Courier And Adverts';
                field("Courier Username"; Rec."Courier Username")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Courier Username field.';
                }
                field("Courier Password"; Rec."Courier Password")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Courier Password field.';
                }
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