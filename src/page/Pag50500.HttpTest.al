page 50500 "Http Test"
{
    PageType = Card;
    Caption = 'Http Test';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(ServerUrl; ServerUrl)
                {
                    Caption = 'Server Url';
                    ApplicationArea = All;
                }
                field(HttpMethod; HttpMethod)
                {
                    Caption = 'Http Method';
                }
                field(ContentType; ContentType)
                {
                    Caption = 'Content Type';

                    trigger OnValidate()
                    var
                    begin
                        ContentTypeEmpty := ContentType = ContentType::" ";
                    end;
                }
                field(Accept; Accept)
                {
                    Caption = 'Accept';
                }
                field(Username; Username)
                {
                }
                field(Password; Password)
                {
                    ExtendedDatatype = Masked;
                }
            }
            group(RequestContent)
            {
                Enabled = not ContentTypeEmpty;

                usercontrol(UserCtrlRequestContent;
                "Microsoft.Dynamics.Nav.Client.WebPageViewer")
                {
                    trigger ControlAddInReady(callbackUrl: Text)
                    begin
                        IsRequestContentReady := true;
                        FillRequestContent();
                    end;

                    trigger Callback(data: Text)
                    begin
                        RequestContent := data;
                    end;
                }
            }
            group(ResponseContent)
            {
                usercontrol(UserCtrlResponseContent;
                "Microsoft.Dynamics.Nav.Client.WebPageViewer")
                {
                    trigger ControlAddInReady(callbackUrl: Text)
                    begin
                        IsResponseContentReady := true;
                        FillResponseContent();
                    end;

                    trigger Callback(data: Text)
                    begin
                        ResponseContent := data;
                    end;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Send)
            {
                ApplicationArea = All;
                Promoted = true;
                Image = SendTo;

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    ResponseInstream: InStream;
                    RequestJson: JsonToken;
                    ResponseJson: JsonToken;
                    Success: Boolean;
                    TempFile: File;
                    NewStream: InsTream;
                    ToFileName: Variant;
                begin
                    ResponseContent := '';
                    if Accept = Accept::" " then Error('''Accept'' must not be empty');
                    if (ContentType = ContentType::"application/json") and (Accept = Accept::"application/json") then begin
                        if RequestContent <> '' then RequestJson.ReadFrom(RequestContent);
                        if HttpHandler.RequestJson(ServerUrl, HttpMethod, Username, Password, RequestJson, ResponseJson) then begin
                            if HttpHandler.IsLastHttpSuccess() then begin
                                ResponseJson.WriteTo(ResponseContent);
                                FillResponseContent();
                            end
                            else begin
                                Error(StrSubstNo('Http Request Failed - %1: %2', HttpHandler.GetLastHttpStatusCode(), HttpHandler.GetLastHttpReasonPhrase()));
                            end;
                        end
                        else begin
                            Error(GetLastErrorText());
                        end;
                    end
                    else begin
                        TempBlob.CreateInStream(ResponseInstream);
                        if HttpHandler.Request(ServerUrl, HttpMethod, Username, Password, RequestContent, ContentType, Accept, ResponseInstream) then begin
                            if HttpHandler.IsLastHttpSuccess() then begin
                                if (Accept = Accept::"application/json") or (Accept = Accept::"application/xml") or (Accept = Accept::"text/plain") then begin
                                    ResponseInstream.ReadText(ResponseContent);
                                    FillResponseContent();
                                end
                                else begin
                                    ToFileName := '';
                                    DownloadFromStream(ResponseInstream, 'Export', '', 'All Files (*.*)|*.*', ToFileName);
                                end;
                            end
                            else begin
                                Error(StrSubstNo('Http Request Failed - %1: %2', HttpHandler.GetLastHttpStatusCode(), HttpHandler.GetLastHttpReasonPhrase()));
                            end;
                        end
                        else begin
                            Error(GetLastErrorText());
                        end;
                    end;
                end;
            }
        }
    }
    var
        ServerUrl: Text[250];
        HttpMethod: Enum "Http Method";
        Username: Text[50];
        Password: Text[50];
        RequestContent: Text;
        ResponseContent: Text;
        HttpHandler: Record "Sales Header";
        IsRequestContentReady: Boolean;
        IsResponseContentReady: Boolean;
        ContentType: Enum "Content Type";
        ContentTypeEmpty: Boolean;
        Accept: Enum "Content Type";

    trigger OnAfterGetCurrRecord()
    begin
        if IsRequestContentReady then FillRequestContent();
        ContentTypeEmpty := ContentType = ContentType::" ";
    end;

    local procedure FillRequestContent()
    begin
        CurrPage.UserCtrlRequestContent.SetContent(StrSubstNo('<textarea Id="TxtRequestContent" maxlength="%2" style="width:100%;height:100%;resize: none; font-family:"Segoe UI", "Segoe WP", Segoe, device-segoe, Tahoma, Helvetica, Arial, sans-serif !important; font-size: 10.5pt !important;" OnChange="window.parent.WebPageViewerHelper.TriggerCallback(document.getElementById(''TxtRequestContent'').value)">%1</textarea>', RequestContent, MaxStrLen(RequestContent)));
    end;

    local procedure FillResponseContent()
    begin
        CurrPage.UserCtrlResponseContent.SetContent(StrSubstNo('<textarea Id="TxtResponseContent" maxlength="%2" style="width:100%;height:100%;resize: none; font-family:"Segoe UI", "Segoe WP", Segoe, device-segoe, Tahoma, Helvetica, Arial, sans-serif !important; font-size: 10.5pt !important;" OnChange="window.parent.WebPageViewerHelper.TriggerCallback(document.getElementById(''TxtResponseContent'').value)">%1</textarea>', ResponseContent, MaxStrLen(ResponseContent)));
    end;
}
