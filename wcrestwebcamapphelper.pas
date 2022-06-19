{
  This file is a part of example.
  look more in WCRESTWebCam.lpr
}

unit WCRESTWebCamAppHelper;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  wcApplication,
  wcHTTP2Con,
  ECommonObjs, OGLFastNumList;

type

  { TRESTJsonConfigInitHelper }

  TRESTJsonConfigInitHelper = class(TWCHTTPAppConfigInitHelper)
  public
    procedure  DoHelp(AData : TObject); override;
  end;

  { TRESTJsonConfigHelper }

  TRESTJsonConfigHelper = class(TWCHTTPAppConfigRecordHelper)
  private
    FUsersDB : TThreadUtf8String;
    function GetUsersDb : UTF8String;
  public
    constructor Create;
    procedure  DoHelp(AData : TObject); override;
    destructor Destroy; override;

    property   UsersDB : UTF8String read GetUsersDb;

    class function Config : TRESTJsonConfigHelper;
  end;

  { TRESTJsonIdleHelper }

  TRESTJsonIdleHelper = class(TWCHTTPAppIdleHelper)
  private
    MTick10s, MTick60s : QWord;
    MinutTimer : Byte;
  public
    constructor Create;
    procedure DoHelp(aData : TObject); override;
  end;

  { THTTP2WebCamServerHelper }

  THTTP2WebCamServerHelper = class(TWCHTTP2ServerHelper)
  public
    procedure ConfigureStream(aStrm : TWCHTTP2Stream); override;
  end;

implementation

uses wcConfig, WCRESTWebCamJobs, WCRESTWebCamStreams, HTTP2HTTP1Conv, extuhpack;

const CFG_RESTJSON_SEC = $2000;
      CFG_RESTJSON_DB  = $2001;

      cUsersDb = 'users.db';

      RESTJSON_CFG_CONFIGURATION : TWCConfiguration = (
        (ParentHash:CFG_ROOT_HASH;   Hash:CFG_RESTJSON_SEC; Name:'RESTServer'),
        (ParentHash:CFG_RESTJSON_SEC; Hash:CFG_RESTJSON_DB; Name:'UsersDB')
        );

var vRJServerConfigHelper : TRESTJsonConfigHelper = nil;

{ THTTP2WebCamServerHelper }

procedure THTTP2WebCamServerHelper.ConfigureStream(aStrm : TWCHTTP2Stream);
var i : integer;
    p : PHPackHeaderTextItem;
    h2 : THTTP2Header;
begin
  inherited ConfigureStream(aStrm);
  for i := 0 to aStrm.Request.Headers.Count-1 do
  begin
    P := aStrm.Request.Headers[i];
    h2 := HTTP2HeaderType(P^.HeaderName);
    if h2 = hh2Path then
    begin
      if (Length(p^.HeaderValue) > Length(cRawInputStream)) and
         SameStr(Copy(p^.HeaderValue, 1, Length(cRawInputStream)),
                                      cRawInputStream) then
      begin
        aStrm.ChunkedRequest := true;
      end;
      break;
    end;
  end;
end;

{ TRESTJsonIdleHelper }

constructor TRESTJsonIdleHelper.Create;
begin
  MTick10s := GetTickCount64;
  MTick60s := MTick10s;
  MinutTimer := 0;
end;

procedure TRESTJsonIdleHelper.DoHelp(aData : TObject);
var ids : TFastMapUInt;
begin
  With TWCTimeStampObj(aData) do
  begin
    //every 10 sec
    if (Tick > MTick10s) and ((Tick - MTick10s) > 10000) then
    begin
      TRESTWebCamUsersDB.UsersDB.MaintainStep10s;
      TRESTWebCamStreams.WebCamStreams.MaintainStep10s;
      ids := TRESTWebCamStreams.MapSSIDs;
      try
        if ids.Count > 0 then
        begin
          TRESTWebCamUsersDB.UsersDB.CheckSSIDs(ids);
          TRESTWebCamStreams.RemoveClosedSessions(ids);
        end;
      finally
        ids.Free;
      end;
      MTick10s := Tick;
    end;
    //every 60 sec
    if (Tick > MTick60s) and ((Tick - MTick60s) > 60000) then
    begin
      TRESTWebCamUsersDB.UsersDB.MaintainStep60s;
      MTick60s := Tick;
      Inc(MinutTimer);
    end;
    //every hour
    if (MinutTimer >= 60) then
    begin
      MinutTimer := 0;
      TRESTWebCamUsersDB.UsersDB.MaintainStep1hr;
    end;
  end;
end;

{ TRESTJsonConfigInitHelper }

procedure TRESTJsonConfigInitHelper.DoHelp(AData : TObject);
var
  RJSection : TWCConfigRecord;
begin
  AddWCConfiguration(RESTJSON_CFG_CONFIGURATION);

  with TWCConfig(AData) do begin
    RJSection := Root.AddSection(HashToConfig(CFG_RESTJSON_SEC)^.NAME_STR);
    RJSection.AddValue(CFG_RESTJSON_DB, wccrString);
  end;
end;

{ TRESTJsonConfigHelper }

function TRESTJsonConfigHelper.GetUsersDb : UTF8String;
begin
  Result := FUsersDB.Value;
end;

constructor TRESTJsonConfigHelper.Create;
begin
  FUsersDB := TThreadUtf8String.Create(cUsersDb);
end;

procedure TRESTJsonConfigHelper.DoHelp(AData : TObject);
begin
  case TWCConfigRecord(AData).HashName of
    CFG_RESTJSON_DB :
      FUsersDB.Value := TWCConfigRecord(AData).Value;
  end;
end;

destructor TRESTJsonConfigHelper.Destroy;
begin
  FUsersDB.Free;
  inherited Destroy;
end;

class function TRESTJsonConfigHelper.Config : TRESTJsonConfigHelper;
begin
  if not assigned(vRJServerConfigHelper) then
    vRJServerConfigHelper := TRESTJsonConfigHelper.Create;
  Result := vRJServerConfigHelper;
end;

end.

