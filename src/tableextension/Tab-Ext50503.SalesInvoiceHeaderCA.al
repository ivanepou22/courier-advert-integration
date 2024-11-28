tableextension 50503 "Sales Invoice Header CA" extends "Sales Invoice Header"
{
    fields
    {
        // Add changes to table fields here
        field(50500; "Courier Or Advert"; Boolean)
        {
            DataClassification = ToBeClassified;
        }
        field(50501; "Date Range Filter"; Text[50])
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