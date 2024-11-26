pageextension 50501 "Sales & Receivables Setup CA" extends "Sales & Receivables Setup"
{
    layout
    {
        // Add changes to page layout here
        addbefore("Number Series")
        {
            group(CourierAndAdverts)
            {
                Caption = 'Courier And Adverts';
                field("Courier Transaction Url"; Rec."Courier Transaction Url")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Courier Transaction Url field.';
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