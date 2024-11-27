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
                field("Courier Customer No."; Rec."Courier Customer No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Courier Customer No. field.';
                }
                field("Courier Resource No."; Rec."Courier Resource No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Courier Resource No. field.';
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