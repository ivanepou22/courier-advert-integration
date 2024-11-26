tableextension 50500 "Sales & Receivables Setup CA" extends "Sales & Receivables Setup"
{
    fields
    {
        // Add changes to table fields here
        field(50500; "Courier Transaction Url"; Text[1000])
        {
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        // Add changes to keys here
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
}