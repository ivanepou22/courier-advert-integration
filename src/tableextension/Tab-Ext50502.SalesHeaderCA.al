tableextension 50502 "Sales Header CA" extends "Sales Header"
{
    fields
    {
        // Add changes to table fields here
        field(50500; "Courier Or Advert"; Boolean)
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

    procedure GenerateSalesInvoice(StartDate: Date; EndDate: Date; SectionType: Enum "Section Type"; PostingDate: Date)
    var
        SalesHeader: Record "Sales Header";
        SalesLines: Record "Sales Line";
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
                    createSalesInvoice(ResponseContent, PostingDate);
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

    procedure createSalesInvoice(ResponseContent: Text; PostingDate: Date)
    var
        ResponseObject: JsonObject;
        InsideResObject: JsonObject;
        ResJsonToken: JsonToken;
        InsideResJsonToken: JsonToken;
        InputResJsonToken: JsonToken;
        ResponseArray: JsonArray;
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        Customer: Record Customer;
        Resource: Record Resource;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        Message(ResponseContent);
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.TestField("Courier Customer No.");
        SalesReceivablesSetup.TestField("Courier Resource No.");

        Customer.Get(SalesReceivablesSetup."Courier Customer No.");
        Resource.Get(SalesReceivablesSetup."Courier Resource No.");

        IF Customer.Blocked IN [Customer.Blocked::All, Customer.Blocked::Invoice] THEN begin
            NoOfSalesInvErrors := NoOfSalesInvErrors + 1;
        end
        else begin
            IF SalesHeader."No." <> '' THEN
                FinalizeSalesOrderHeader;
            InsertSalesOrderHeader(PostingDate);
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
        WITH SalesHeader DO BEGIN
            IF CalcInvoiceDiscount THEN
                SalesCalcDiscount.RUN(SalesLine);
            GET("Document Type", "No.");
            COMMIT;
            CLEAR(SalesCalcDiscount);
            CLEAR(SalesPost);
            NoOfSalesInv := NoOfSalesInv + 1;
            IF PostInvoices THEN BEGIN
                CLEAR(SalesPost);
                IF NOT SalesPost.RUN(SalesHeader) THEN
                    NoOfSalesInvErrors := NoOfSalesInvErrors + 1;
            END;
        END;
    end;

    local procedure InsertSalesOrderHeader(PostingDate: Date);
    var
        lvCustomer: Record Customer;
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.TestField("Courier Customer No.");
        SalesReceivablesSetup.TestField("Courier Resource No.");

        WITH SalesHeader DO BEGIN
            INIT;
            "Document Type" := "Document Type"::Order;
            "Order Type" := "Order Type"::Newspaper;
            "No." := '';
            INSERT(TRUE);
            VALIDATE("Sell-to Customer No.", SalesReceivablesSetup."Courier Customer No.");

            IF "Bill-to Customer No." <> "Sell-to Customer No." THEN
                VALIDATE("Bill-to Customer No.", SalesReceivablesSetup."Courier Customer No.");
            VALIDATE("Posting Date", PostingDate);
            VALIDATE("Document Date", PostingDate);
            VALIDATE("Shipment Date", PostingDate);
            VALIDATE("Courier Or Advert", TRUE);
            Validate("Location Code", 'HQ');
            VALIDATE("Posting Description", 'Courier invoice for ' + FORMAT(PostingDate));
            lvCustomer.GET(SalesReceivablesSetup."Courier Customer No.");
            VALIDATE("Currency Code", lvCustomer."Currency Code");
            MODIFY;
            COMMIT;
            NextLineNo := 10000;
        END;
    end;

    // procedure GetStatement(requestId: Text; transactionType: Option " ",astm; fromDate: Date; toDate: Date; accountId: Text)
    // var
    //     XCountryCode: Text;
    //     XChannelId: Text;
    //     XSignature: Text;
    //     ServerUrl: Text;
    //     Request: HttpRequestMessage;
    //     Response: HttpResponseMessage;
    //     XIBMClientId: Text;
    //     XIBMClientSecret: Text;
    //     AccessToken: Text;
    //     TempBlob: Codeunit "Temp Blob";
    //     ResponseInstream: InStream;
    //     RequestJson: JsonToken;
    //     ResponseJson: JsonToken;
    //     Success: Boolean;
    //     TempFile: File;
    //     NewStream: InsTream;
    //     ToFileName: Variant;
    //     RequestBody: JsonObject;
    //     BanKIntegrationSetup: Record "Bank Integration Setup";
    //     FromDateText: Text;
    //     ToDateText: Text;
    //     Password: Text;
    // begin
    //     BanKIntegrationSetup.Get();
    //     BanKIntegrationSetup.TestField(XIBMClientId);
    //     BanKIntegrationSetup.TestField(XIBMClientSecret);
    //     BanKIntegrationSetup.TestField(StatementServerUrl);
    //     BanKIntegrationSetup.TestField(XCountryCode);
    //     BanKIntegrationSetup.TestField(XChannelId);

    //     AccessToken := GetToken();
    //     HttpMethod := HttpMethod::POST;
    //     XIBMClientId := BanKIntegrationSetup.XIBMClientId;
    //     XIBMClientSecret := BanKIntegrationSetup.XIBMClientSecret;
    //     ServerUrl := BanKIntegrationSetup.StatementServerUrl;
    //     XCountryCode := BanKIntegrationSetup.XCountryCode;
    //     XChannelId := BanKIntegrationSetup.XChannelId;

    //     FromDateText := CopyStr(Format(fromDate), 4, 2) + '/' + CopyStr(Format(fromDate), 1, 2) + '/20' + CopyStr(Format(fromDate), 7, 2);
    //     ToDateText := CopyStr(Format(toDate), 4, 2) + '/' + CopyStr(Format(toDate), 1, 2) + '/20' + CopyStr(Format(toDate), 7, 2);

    //     RequestBody.Add('requestId', requestId);
    //     RequestBody.Add('transactionType', Format(transactionType));
    //     RequestBody.Add('fromDate', FromDateText);
    //     RequestBody.Add('toDate', ToDateText);
    //     RequestBody.Add('accountId', accountId);

    //     XSignature := GenerateSignature(RequestBody);

    //     RequestBody.WriteTo(RequestContent);
    //     if RequestContent <> '' then RequestJson.ReadFrom(RequestContent);
    //     if HttpHandler.RequestJson(ServerUrl, HttpMethod, XIBMClientId, XIBMClientSecret, AccessToken, XCountryCode, XChannelId, XSignature, Password, RequestJson, ResponseJson) then begin
    //         if HttpHandler.IsLastHttpSuccess() then begin
    //             ResponseJson.WriteTo(ResponseContent);
    //             createStatementLines(ResponseContent);
    //         end
    //         else begin
    //             Error(StrSubstNo('Http Request Failed - %1: %2', HttpHandler.GetLastHttpStatusCode(), HttpHandler.GetLastHttpReasonPhrase()));
    //         end;
    //     end
    //     else begin
    //         Error(GetLastErrorText());
    //     end;
    // end;

    /// <summary>
    /// createStatementLines.
    /// </summary>
    /// <param name="ResponseContent">Text.</param>
    // procedure createStatementLines(ResponseContent: Text)
    // var
    //     ResponseObject: JsonObject;
    //     InsideResObject: JsonObject;
    //     ResJsonToken: JsonToken;
    //     InsideResJsonToken: JsonToken;
    //     InputResJsonToken: JsonToken;
    //     InsideResJsonText: Text;
    //     ResponseArray: JsonArray;
    //     ResponseArrayText: Text;
    //     StanbicStatement: Record "Stanbic Bank Statement";
    //     StanbicStatement1: Record "Stanbic Bank Statement";
    //     StanbicStatement2: Record "Stanbic Bank Statement";
    //     requestId: Text;
    //     accountId: Text;
    //     transactionType: Text;
    //     numberOfTransactions: Integer;
    //     accountStatus: Text;
    //     accountName: Text;
    //     accountType: Text;
    //     accountCurrency: Text;
    //     mobile: Text;
    //     statusCode: Text;
    //     statusDescription: Text;
    //     i: Integer;
    //     TransactID: Text;
    //     debitCreditType: Text[10];
    //     EntryNo: Integer;
    //     HttpHandler: Codeunit "MSLHttp HttpHandler";
    //     track: Integer;
    //     TransBalance: Decimal;
    // begin
    //     EntryNo := 100;
    //     if ResponseContent <> '' then begin
    //         ResponseObject.ReadFrom(ResponseContent);
    //         ResponseObject.Get('requestId', ResJsonToken);
    //         requestId := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('accountId', ResJsonToken);
    //         accountId := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('transactionType', ResJsonToken);
    //         transactionType := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('numberOfTransactions', ResJsonToken);
    //         numberOfTransactions := ResJsonToken.AsValue().AsInteger();
    //         ResponseObject.Get('accountStatus', ResJsonToken);
    //         accountStatus := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('accountName', ResJsonToken);
    //         accountName := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('accountType', ResJsonToken);
    //         accountType := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('accountCurrency', ResJsonToken);
    //         accountCurrency := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('mobile', ResJsonToken);
    //         mobile := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('statusCode', ResJsonToken);
    //         statusCode := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('statusDescription', ResJsonToken);
    //         statusDescription := ResJsonToken.AsValue().AsText();
    //         ResponseObject.Get('transactionHistory', ResJsonToken);
    //         if ResJsonToken.IsArray then begin
    //             ResJsonToken.WriteTo(ResponseArrayText);
    //             ResponseArray.ReadFrom(ResponseArrayText);

    //             for i := 0 To ResponseArray.Count - 1 do begin
    //                 TransBalance := 0;
    //                 StanbicStatement1.Reset();
    //                 StanbicStatement1.SetFilter("Entry No.", '<>%1', 0);
    //                 if StanbicStatement1.FindLast() then
    //                     EntryNo += StanbicStatement1."Entry No.";

    //                 ResponseArray.Get(i, InsideResJsonToken);
    //                 if InsideResJsonToken.IsObject then begin
    //                     InsideResJsonToken.WriteTo(InsideResJsonText);
    //                     InsideResObject.ReadFrom(InsideResJsonText);
    //                     InsideResObject.Get('transactionId', InputResJsonToken);
    //                     TransactID := InputResJsonToken.AsValue().AsText();
    //                     InsideResObject.Get('transactionBalance', InputResJsonToken);
    //                     TransBalance := HttpHandler.ConvertToDecimal(InputResJsonToken.AsValue().AsText());
    //                     StanbicStatement2.Reset();
    //                     StanbicStatement2.SetRange(TransactionId, TransactID);
    //                     StanbicStatement2.SetRange(transactionBalance, TransBalance);
    //                     if not StanbicStatement2.FindFirst() then begin
    //                         track += 1;
    //                         StanbicStatement.Init();
    //                         StanbicStatement."Entry No." := EntryNo;
    //                         StanbicStatement.requestId := requestId;
    //                         StanbicStatement.accountId := accountId;
    //                         StanbicStatement.transactionType := transactionType;
    //                         StanbicStatement.numberOfTransactions := numberOfTransactions;
    //                         StanbicStatement.accountStatus := accountStatus;
    //                         StanbicStatement.accountName := accountName;
    //                         StanbicStatement.accountType := accountType;
    //                         StanbicStatement.accountCurrency := accountCurrency;
    //                         StanbicStatement.mobile := mobile;
    //                         StanbicStatement.statusCode := statusCode;
    //                         StanbicStatement.statusDescription := statusDescription;
    //                         StanbicStatement.TransactionId := TransactID;
    //                         InsideResObject.Get('debitCreditType', InputResJsonToken);
    //                         if (InputResJsonToken.AsValue().AsText() = 'C') or (InputResJsonToken.AsValue().AsText() = 'c') then
    //                             StanbicStatement.debitCreditType := StanbicStatement.debitCreditType::Credit
    //                         else
    //                             if (InputResJsonToken.AsValue().AsText() = 'D') or (InputResJsonToken.AsValue().AsText() = 'd') then
    //                                 StanbicStatement.debitCreditType := StanbicStatement.debitCreditType::Debit;
    //                         InsideResObject.Get('transactionDate', InputResJsonToken);
    //                         StanbicStatement.transactionDate := HttpHandler.ConvertDate(InputResJsonToken.AsValue().AsText());
    //                         InsideResObject.Get('transactionRemark', InputResJsonToken);
    //                         StanbicStatement.transactionRemark := InputResJsonToken.AsValue().AsText();
    //                         InsideResObject.Get('transactionCurrency', InputResJsonToken);
    //                         StanbicStatement.transactionCurrency := InputResJsonToken.AsValue().AsText();
    //                         InsideResObject.Get('transactionAmount', InputResJsonToken);
    //                         StanbicStatement.transactionAmount := HttpHandler.ConvertToDecimal(InputResJsonToken.AsValue().AsText());
    //                         InsideResObject.Get('transactionBalance', InputResJsonToken);
    //                         StanbicStatement.transactionBalance := HttpHandler.ConvertToDecimal(InputResJsonToken.AsValue().AsText());
    //                         StanbicStatement.Insert();
    //                     end;
    //                 end;
    //             end;
    //             Message('%1 Transactions have been generated and %2 Transactions have been created.', numberOfTransactions, track);
    //         end;
    //     end;
    // end;
}