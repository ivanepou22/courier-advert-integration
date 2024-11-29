tableextension 50502 "Sales Header CA" extends "Sales Header"
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
            Editable = false;
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

    var
        LastHttpSuccess: Boolean;
        LastHttpStatusCode: Integer;
        LastHttpReasonPhrase: Text;
        LastHttpIsBlockedByEnvironment: Boolean;
        RequestContent: Text;
        ResponseContent: Text;
        CalcInvoiceDiscount: Boolean;
        SalesCalcDiscount: Codeunit "Sales-Calc. Discount";
        NoOfSalesInvErrors: Integer;
        NoOfSalesInv: Integer;
        SalesPost: Codeunit "Sales-Post";
        PostInvoices: Boolean;
        NextLineNo: Integer;
        SalesHeaderOrder: Record "Sales Header";

    procedure GenerateSalesInvoice(StartDate: Date; EndDate: Date; SectionType: Enum "Section Type"; PostingDate: Date; DocumentType: Enum "Sales Document Type")
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        GeneralLedgerSetup: Record "General Ledger Setup";
        AuthTokenSecret: Text;
        ObjectJson: JsonObject;
        BodyJson: JsonObject;
        RequestJson: JsonToken;
        ResponseJson: JsonToken;
        ServerUrl: Text;
        HttpMethod: Enum "Http Method";
    begin
        ServerUrl := '';
        SalesReceivablesSetup.Get();
        GeneralLedgerSetup.Get();

        SalesReceivablesSetup.TestField("Courier Transaction Url");
        GeneralLedgerSetup.TestField("Courier Username");
        GeneralLedgerSetup.TestField("Courier Password");

        if StartDate = 0D then
            Error('Start date is not set');

        if EndDate = 0D then
            Error('End date is not set');

        // AuthTokenSecret := GenerateToken(GeneralLedgerSetup."Courier Username", GeneralLedgerSetup."Courier Password", '')

        if SectionType = SectionType::invoice then begin
            Clear(ObjectJson);
            clear(BodyJson);

            ObjectJson.Add('section', Format(SectionType));
            ObjectJson.Add('startdate', StartDate);
            ObjectJson.Add('enddate', EndDate);

            BodyJson.Add('object', ObjectJson);

            BodyJson.WriteTo(RequestContent);
            ServerUrl := SalesReceivablesSetup."Courier Transaction Url";
            HttpMethod := Enum::"Http Method"::POST;
            if RequestContent <> '' then RequestJson.ReadFrom(RequestContent);
            if RequestJson(ServerUrl, HttpMethod, '', '', RequestJson, ResponseJson) then begin
                if IsLastHttpSuccess() then begin
                    ResponseJson.WriteTo(ResponseContent);
                    createSalesInvoice(ResponseContent, PostingDate, StartDate, EndDate, DocumentType);
                end
                else begin
                    Error(StrSubstNo('Http Request Failed - %1: %2', GetLastHttpStatusCode(), GetLastHttpReasonPhrase()));
                end;
            end
            else begin
                Error(GetLastErrorText());
            end;
        end;
    end;

    procedure createSalesInvoice(ResponseContent: Text; PostingDate: Date; StartDate: Date; EndDate: Date; DocumentType: Enum "Sales Document Type")
    var
        ResponseObject: JsonObject;
        ResponseArray: JsonArray;
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        Customer: Record Customer;
        Resource: Record Resource;
        SalesLine: Record "Sales Line";
        Success: Boolean;
        SuccessText: Text;
        SuccessToken: JsonToken;
        ResponseToken: JsonToken;
        ResponseArrayText: Text;
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.TestField("Courier Customer No.");
        SalesReceivablesSetup.TestField("Courier Resource No.");

        Customer.Get(SalesReceivablesSetup."Courier Customer No.");
        Resource.Get(SalesReceivablesSetup."Courier Resource No.");

        IF Customer.Blocked IN [Customer.Blocked::All, Customer.Blocked::Invoice] THEN begin
            NoOfSalesInvErrors := NoOfSalesInvErrors + 1;
        end
        else begin
            if ResponseContent <> '' then begin
                ResponseObject.ReadFrom(ResponseContent);
                ResponseObject.SelectToken('success', SuccessToken);
                SuccessText := SuccessToken.AsValue().AsText();
                if SuccessText = '1' then
                    Success := true;
                if Success then begin
                    ResponseObject.SelectToken('details', ResponseToken);
                    if ResponseToken.IsArray then begin
                        ResponseToken.WriteTo(ResponseArrayText);
                        ResponseArray.ReadFrom(ResponseArrayText);
                        if ResponseArray.Count <> 0 then begin
                            IF SalesHeaderOrder."No." <> '' THEN
                                FinalizeSalesOrderHeader;
                            InsertSalesOrderHeader(PostingDate, DocumentType, StartDate, EndDate);
                            CreateSalesOrderLines(ResponseContent, PostingDate, SalesHeaderOrder."No.", DocumentType);
                        end else begin
                            Message('No Transactions were found for the specified date range: [%1] - [%2]', StartDate, EndDate);
                        end
                    end
                end;
            end;
        end;
    end;

    procedure CreateSalesOrderLines(ResponseContent: Text; PostingDate: Date; salesOrderNo: Code[20]; DocumentType: Enum "Sales Document Type")
    var
        SalesLine: Record "Sales Line";
        LineNo: Integer;
        ResponseObject: JsonObject;
        ResponseArray: JsonArray;
        Success: Boolean;
        SuccessText: Text;
        ResponseToken: JsonToken;
        SuccessToken: JsonToken;
        ResponseArrayText: Text;
        i: Integer;
        SalesLine1: Record "Sales Line";
        SalesLine2: Record "Sales Line";
        PodRef: Text;
        DetailObjectText: Text;
        DetailObject: JsonObject;
        DetailObjectToken: JsonToken;
        SalesSetup: Record "Sales & Receivables Setup";
        CurrencyExchRate: Record "Currency Exchange Rate";
        SalesLineNumber: Integer;
        TransactionNo: Code[50];
    begin
        LineNo := 1100;
        Success := false;
        SalesLineNumber := 0;
        if ResponseContent <> '' then begin
            SalesSetup.Get();
            SalesSetup.TestField("Courier Resource No.");
            ResponseObject.ReadFrom(ResponseContent);
            ResponseObject.SelectToken('success', SuccessToken);
            SuccessText := SuccessToken.AsValue().AsText();
            if SuccessText = '1' then
                Success := true;

            if Success then begin
                ResponseObject.SelectToken('details', ResponseToken);
                if ResponseToken.IsArray then begin
                    ResponseToken.WriteTo(ResponseArrayText);
                    ResponseArray.ReadFrom(ResponseArrayText);
                    for i := 0 to ResponseArray.Count - 1 do begin
                        ResponseArray.Get(i, ResponseToken);
                        if ResponseToken.IsObject then begin
                            ResponseToken.WriteTo(DetailObjectText);
                            DetailObject.ReadFrom(DetailObjectText);
                            DetailObject.SelectToken('pod_ref', ResponseToken);
                            PodRef := ResponseToken.AsValue().AsText();
                            SalesLine1.Reset();
                            SalesLine1.SetRange("Document Type", DocumentType);
                            SalesLine1.SetRange(pod_ref, PodRef);
                            if not SalesLine1.FindFirst() then begin
                                SalesLine2.Reset();
                                SalesLine2.SetRange("Document Type", DocumentType);
                                SalesLine2.SetRange("Document No.", salesOrderNo);
                                SalesLine2.SetRange(pod_ref, PodRef);
                                if SalesLine2.FindLast() then begin
                                    LineNo += 1;
                                end;

                                SalesLine.Init();
                                SalesLine.Type := SalesLine.Type::Resource;
                                SalesLine."Document Type" := DocumentType;
                                SalesLine."Document No." := salesOrderNo;
                                SalesLine."Line No." := LineNo;
                                SalesLine."No." := SalesSetup."Courier Resource No.";
                                SalesLine.Validate("No.");

                                SalesLine.Validate(Quantity, 1);

                                DetailObject.SelectToken('total_delivery_fees', DetailObjectToken);
                                SalesLine.Validate("Unit Price", DetailObjectToken.AsValue().AsDecimal());

                                IF SalesHeader."Currency Code" <> '' THEN BEGIN
                                    SalesHeader.TESTFIELD("Currency Factor");
                                    SalesLine."Unit Price" :=
                                      ROUND(
                                        CurrencyExchRate.ExchangeAmtLCYToFCY(
                                        PostingDate, SalesHeader."Currency Code",
                                        SalesLine."Unit Price", SalesHeader."Currency Factor"));
                                END;
                                SalesLine.VALIDATE("Dimension Set ID", SalesHeader."Dimension Set ID");

                                DetailObject.SelectToken('pod_ref', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then begin
                                    SalesLine.pod_ref := DetailObjectToken.AsValue().AsText();
                                    TransactionNo := DetailObjectToken.AsValue().AsText();
                                end else
                                    SalesLine.pod_ref := '';

                                DetailObject.SelectToken('billing_model', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.billing_model := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.billing_model := '';

                                DetailObject.SelectToken('fragile', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then begin
                                    if DetailObjectToken.AsValue().AsText() = '1' then
                                        SalesLine.fragile := true
                                    else
                                        SalesLine.fragile := false;
                                end else
                                    SalesLine.fragile := false;

                                DetailObject.SelectToken('fragile_surcharge', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.fragile_surcharge := DetailObjectToken.AsValue().AsDecimal()
                                else
                                    SalesLine.fragile_surcharge := 0;

                                DetailObject.SelectToken('delivery_fee', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.delivery_fee := DetailObjectToken.AsValue().AsDecimal()
                                else
                                    SalesLine.delivery_fee := 0;

                                DetailObject.SelectToken('vat_fee', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.vat_fee := DetailObjectToken.AsValue().AsDecimal()
                                else
                                    SalesLine.vat_fee := 0;

                                DetailObject.SelectToken('ucc_fee', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.ucc_fee := DetailObjectToken.AsValue().AsDecimal()
                                else
                                    SalesLine.ucc_fee := 0;

                                DetailObject.SelectToken('total_delivery_fees', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.total_delivery_fees := DetailObjectToken.AsValue().AsDecimal()
                                else
                                    SalesLine.total_delivery_fees := 0;

                                DetailObject.SelectToken('pay_mode', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.pay_mode := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.pay_mode := '';

                                DetailObject.SelectToken('txn_reference', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.txn_reference := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.txn_reference := '';

                                DetailObject.SelectToken('pod_date', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.pod_date := DetailObjectToken.AsValue().AsDate()
                                else
                                    SalesLine.pod_date := 0D;

                                DetailObject.SelectToken('sender_name', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.sender_name := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.sender_name := '';

                                DetailObject.SelectToken('sender_tel', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.sender_tel := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.sender_tel := '';

                                DetailObject.SelectToken('sender_address', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.sender_address := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.sender_address := '';

                                DetailObject.SelectToken('receiver_name', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.receiver_name := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.receiver_name := '';

                                DetailObject.SelectToken('receiver_tel', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.receiver_tel := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.receiver_tel := '';

                                DetailObject.SelectToken('receiver_address', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.receiver_address := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.receiver_address := '';

                                DetailObject.SelectToken('receiver_town', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.receiver_town := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.receiver_town := '';

                                DetailObject.SelectToken('receiver_district', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.receiver_district := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.receiver_district := '';

                                DetailObject.SelectToken('receiver_region', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.receiver_region := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.receiver_region := '';

                                DetailObject.SelectToken('no_of_pieces', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.no_of_pieces := DetailObjectToken.AsValue().AsInteger()
                                else
                                    SalesLine.no_of_pieces := 0;

                                DetailObject.SelectToken('package_weight', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.package_weight := DetailObjectToken.AsValue().AsDecimal()
                                else
                                    SalesLine.package_weight := 0;

                                DetailObject.SelectToken('package_description', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.package_description := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.package_description := '';

                                DetailObject.SelectToken('package_type', DetailObjectToken);
                                if not DetailObjectToken.AsValue().IsNull() then
                                    SalesLine.package_type := DetailObjectToken.AsValue().AsText()
                                else
                                    SalesLine.package_type := '';

                                SalesLine.Insert();
                                UpdateTransaction(TransactionNo, Enum::"Section Type"::invoice);
                                LineNo += 1;
                                SalesLineNumber += 1;
                            end;
                        end;
                    end;
                    if salesOrderNo <> '' then begin
                        Message('Sales Order: %1 has been created and %2 Line(s) were(was) created', salesOrderNo, SalesLineNumber);
                    end
                end;
            end else
                Error('Resquest was not successful please try again');
        end;
    end;

    procedure UpdateTransaction(TransactionNo: Code[50]; SectionType: Enum "Section Type")
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        GeneralLedgerSetup: Record "General Ledger Setup";
        AuthTokenSecret: Text;
        ObjectJson: JsonObject;
        BodyJson: JsonObject;
        RequestJson: JsonToken;
        ResponseJson: JsonToken;
        ServerUrl: Text;
        HttpMethod: Enum "Http Method";
    begin
        ServerUrl := '';
        SalesReceivablesSetup.Get();
        GeneralLedgerSetup.Get();

        SalesReceivablesSetup.TestField("Courier Transaction Update Url");
        GeneralLedgerSetup.TestField("Courier Username");
        GeneralLedgerSetup.TestField("Courier Password");

        // AuthTokenSecret := GenerateToken(GeneralLedgerSetup."Courier Username", GeneralLedgerSetup."Courier Password", '')

        if SectionType = SectionType::invoice then begin
            Clear(ObjectJson);
            clear(BodyJson);

            ObjectJson.Add('section', Format(SectionType));
            ObjectJson.Add('awbno', TransactionNo);

            BodyJson.Add('object', ObjectJson);

            BodyJson.WriteTo(RequestContent);
            ServerUrl := SalesReceivablesSetup."Courier Transaction Update Url";
            HttpMethod := Enum::"Http Method"::POST;
            if RequestContent <> '' then RequestJson.ReadFrom(RequestContent);
            if RequestJson(ServerUrl, HttpMethod, GeneralLedgerSetup."Courier Username", GeneralLedgerSetup."Courier Password", RequestJson, ResponseJson) then begin
                if IsLastHttpSuccess() then begin
                    ResponseJson.WriteTo(ResponseContent);
                end
                else begin
                    Error(StrSubstNo('Http Request Failed - %1: %2', GetLastHttpStatusCode(), GetLastHttpReasonPhrase()));
                end;
            end
            else begin
                Error(GetLastErrorText());
            end;
        end;
    end;

    local procedure GenerateToken(Username: Text; Password: Text; authUrl: Text): Text
    var
        myInt: Integer;
    begin

    end;

    [TryFunction]
    procedure RequestJson(
        Url: Text[250];
Method: Enum "Http Method";
UserName: Text[50];
Password: Text[50];
RequestBody: JsonToken;
var Response: JsonToken
)
    var
        RequestBodyIsEmpty: Boolean;
        ContentText: Text;
        RequestMessage: HttpRequestMessage;
        ReponseInStream: InStream;
        TempBlob: Codeunit "Temp Blob";
    begin
        RequestBodyIsEmpty := true;
        if RequestBody.IsObject() then
            RequestBodyIsEmpty := RequestBody.AsObject().Keys.Count = 0
        else
            if RequestBody.IsValue() then
                RequestBodyIsEmpty := RequestBody.AsValue().IsNull
            else
                if RequestBody.IsArray() then RequestBodyIsEmpty := RequestBody.AsArray().Count = 0;
        if not RequestBodyIsEmpty then begin
            RequestBody.WriteTo(ContentText);
        end;
        TempBlob.CreateInStream(ReponseInStream);
        Request(Url, Method, UserName, Password, ContentText, Enum::"Content Type"::"application/json", Enum::"Content Type"::"application/json", ReponseInStream);
        Response.ReadFrom(ReponseInStream);
    end;

    [TryFunction]
    procedure Request(Url: Text[250];
    Method: Enum "Http Method";
    UserName: Text[50];
    Password: Text[50];
    RequestBody: Text;
    ContentType: Enum "Content Type";
    Accept: Enum "Content Type";
    var ReponseInStream: InStream)
    var
        Client: HttpClient;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        AuthText: text;
        Base64Convert: Codeunit "Base64 Convert";
        ResponseHeaders: HttpHeaders;
    begin
        RequestMessage.SetRequestUri(Url);
        RequestMessage.Method(Format(Method));
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('User-Agent', 'Dynamics 365 Business Central');
        if UserName <> '' then begin
            AuthText := StrSubstNo('%1:%2', UserName, Password);
            RequestHeaders.Add('Authorization', StrSubstNo('Basic %1', Base64Convert.ToBase64(AuthText)));
        end;
        if RequestBody <> '' then begin
            RequestMessage.Content.WriteFrom(RequestBody);
            RequestMessage.Content.GetHeaders(ContentHeaders);
            if ContentHeaders.Contains('Content-Type') then ContentHeaders.Remove('Content-Type');
            ContentHeaders.Add('Content-Type', ContentType.Names.Get(ContentType.Ordinals.IndexOf(ContentType.AsInteger)));
        end;
        if Accept <> Accept::" " then begin
            ResponseHeaders := ResponseMessage.Headers();
            ResponseHeaders.Add('Accept', Accept.Names.Get(Accept.Ordinals.IndexOf(Accept.AsInteger)));
        end;
        Client.Send(RequestMessage, ResponseMessage);
        if (ResponseMessage.IsSuccessStatusCode) then begin
            LastHttpSuccess := true;
            ResponseHeaders := ResponseMessage.Headers;
            ResponseMessage.Content.ReadAs(ReponseInStream);
        end
        else begin
            LastHttpSuccess := false;
            LastHttpStatusCode := ResponseMessage.HttpStatusCode;
            LastHttpReasonPhrase := ResponseMessage.ReasonPhrase;
            LastHttpIsBlockedByEnvironment := ResponseMessage.IsBlockedByEnvironment();
        end;
    end;

    procedure IsLastHttpSuccess(): Boolean
    begin
        exit(LastHttpSuccess);
    end;

    procedure GetLastHttpStatusCode(): Integer
    var
    begin
        exit(LastHttpStatusCode)
    end;

    procedure GetLastHttpReasonPhrase(): Text
    begin
        exit(LastHttpReasonPhrase)
    end;

    procedure GetLastIsBlockedByEnvironment(): Boolean
    begin
        exit(LastHttpIsBlockedByEnvironment)
    end;

    local procedure FinalizeSalesOrderHeader();
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        SalesSetup.GET;
        CalcInvoiceDiscount := SalesSetup."Calc. Inv. Discount";
        WITH SalesHeaderOrder DO BEGIN
            IF CalcInvoiceDiscount THEN
                SalesCalcDiscount.RUN(SalesLine);
            GET("Document Type", "No.");
            COMMIT;
            CLEAR(SalesCalcDiscount);
            CLEAR(SalesPost);
            NoOfSalesInv := NoOfSalesInv + 1;
            IF PostInvoices THEN BEGIN
                CLEAR(SalesPost);
                IF NOT SalesPost.RUN(SalesHeaderOrder) THEN
                    NoOfSalesInvErrors := NoOfSalesInvErrors + 1;
            END;
        END;
    end;

    local procedure InsertSalesOrderHeader(PostingDate: Date; DocumentType: Enum "Sales Document Type"; StartDate: Date; EndDate: Date);
    var
        lvCustomer: Record Customer;
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.TestField("Courier Customer No.");
        SalesReceivablesSetup.TestField("Courier Resource No.");

        WITH SalesHeaderOrder DO BEGIN
            INIT;
            "Document Type" := DocumentType;
            // "Order Type" := "Order Type"::Newspaper;
            "No." := '';
            INSERT(TRUE);
            VALIDATE("Sell-to Customer No.", SalesReceivablesSetup."Courier Customer No.");

            IF "Bill-to Customer No." <> "Sell-to Customer No." THEN
                VALIDATE("Bill-to Customer No.", SalesReceivablesSetup."Courier Customer No.");
            VALIDATE("Posting Date", PostingDate);
            VALIDATE("Document Date", PostingDate);
            VALIDATE("Shipment Date", PostingDate);
            VALIDATE("Order Date", PostingDate);
            VALIDATE("Courier Or Advert", TRUE);
            Validate("Date Range Filter", StrSubstNo('%1..%2', StartDate, EndDate));
            Validate("Location Code", 'HQ');
            VALIDATE("Posting Description", 'Courier invoice for ' + FORMAT(PostingDate));
            lvCustomer.GET(SalesReceivablesSetup."Courier Customer No.");
            VALIDATE("Currency Code", lvCustomer."Currency Code");
            MODIFY;
            COMMIT;
            NextLineNo := 10000;
        END;
    end;
}