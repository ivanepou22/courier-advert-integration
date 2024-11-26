tableextension 50501 "General Ledger Setup CA" extends "General Ledger Setup"
{
    fields
    {
        // Add changes to table fields here
        field(50500; "Courier Username"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50501; "Courier Password"; Text[100])
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