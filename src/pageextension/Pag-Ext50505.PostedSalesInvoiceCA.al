pageextension 50505 "Posted Sales Invoice CA" extends "Posted Sales Invoice"
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