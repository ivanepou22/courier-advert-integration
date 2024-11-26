tableextension 50505 "Sales Invoice Line CA" extends "Sales Invoice Line"
{
    fields
    {
        // Add changes to table fields here
        field(50501; pod_ref; Code[50]) { }
        field(50502; billing_model; Text[50]) { }
        field(50503; fragile; Boolean) { }
        field(50504; fragile_surcharge; Decimal) { }
        field(50505; delivery_fee; Decimal) { }
        field(50506; vat_fee; Decimal) { }
        field(50507; ucc_fee; Decimal) { }
        field(50508; total_delivery_fees; Decimal) { }
        field(50509; pay_mode; Text[50]) { }
        field(50510; txn_reference; Text[50]) { }
        field(50511; pod_date; Date) { }
        field(50512; sender_name; Text[200]) { }
        field(50513; sender_tel; Text[20]) { }
        field(50514; sender_address; Text[200]) { }
        field(50515; receiver_name; Text[200]) { }
        field(50516; receiver_tel; Text[20]) { }
        field(50517; receiver_address; Text[200]) { }
        field(50518; receiver_town; Code[50]) { }
        field(50519; receiver_district; Code[150]) { }
        field(50520; receiver_region; Code[150]) { }
        field(50521; no_of_pieces; Decimal) { }
        field(50522; package_weight; Decimal) { }
        field(50523; package_description; Text[230]) { }
        field(50524; package_type; Text[50]) { }
    }

    keys
    {
        // Add changes to keys here
        key(SK; pod_ref) { }
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
}