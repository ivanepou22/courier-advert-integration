tableextension 50500 "Sales & Receivables Setup CA" extends "Sales & Receivables Setup"
{
    fields
    {
        // Add changes to table fields here
        field(50500; "Courier Transaction Url"; Text[1000])
        {
            DataClassification = ToBeClassified;
        }
        field(50501; "Courier Customer No."; Code[50])
        {
            TableRelation = Customer."No.";
        }
        field(50502; "Courier Resource No."; Code[50])
        {
            TableRelation = Resource."No.";
        }
        field(50503; "Courier Transaction Update Url"; Text[1000])
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