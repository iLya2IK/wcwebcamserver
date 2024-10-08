{
  This file is a part of example.
  look more in WCRESTWebCam.lpr
}

unit WCRESTWebCamJobs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, variants,
  httpdefs, httpprotocol,
  jsonscanner, jsonparser, fpjson,
  OGLFastNumList, ECommonObjs,
  ExtSqlite3DS, ExtSqlite3Funcs,
  db,
  wcApplication, wcHTTP2Con, HTTP2Consts, wcNetworking;

type

  TDBID = Cardinal;

  { TWCAddClient }

  TWCAddClient = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCAddRecord }

  TWCAddRecord = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCAddMsg }

  TWCAddMsg = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetRecordMeta }

  TWCGetRecordMeta = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetRecordData }

  TWCGetRecordData = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetRecordCount }

  TWCGetRecordCount = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetMsgs}

  TWCGetMsgs = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetMsgsAndSync}

  TWCGetMsgsAndSync = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetListOfDevices}

  TWCGetListOfDevices = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetStreams }

  TWCGetStreams = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCDeleteRecords }

  TWCDeleteRecords = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetConfig }

  TWCGetConfig = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCSetConfig }

  TWCSetConfig = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCHeartBit }

  TWCHeartBit = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCTest }

  TWCTest = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCGetServerTime }

  TWCGetServerTime = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCRawInputStream }

  TWCRawInputStream = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCRawOutputStream }

  TWCRawOutputStream = class(TWCMainClientJob)
  public
    procedure Execute; override;
  end;

  { TWCRawOutputSynchroJob }

  TWCRawOutputSynchroJob = class(TWCMainClientJob)
  private
    FSID : TDBID;
    FStage : integer;
    FLastFrameId : QWord;
  public
    constructor Create(aConn : TWCAppConnection; sID : TDBID); overload;
    procedure Execute; override;
  end;


  { TRESTWebCamUsersDB }

  TRESTWebCamUsersDB = class(TWCHTTPAppInitHelper)
  private
    FUsersDB : TExtSqlite3Dataset;
  public
    PREP_GetClient,
    PREP_AddClient, PREP_ReturnLastHsh,
    PREP_GetListOfDevices,
    PREP_AddRecord,

    PREP_AddMsg,
    PREP_AddSync,

    PREP_GetLastSync,

    PREP_GetRecordMeta,
    PREP_GetRecordData,
    PREP_GetRecordCount,
    PREP_DeleteRecord,
    PREP_DeleteRecordsFrom,
    PREP_GetMsgs,
    PREP_GetClientByHash,
    PREP_GetSessionByDevice,
    PREP_GetSessions,
    PREP_GetSessionsByCID,

    PREP_MaintainStep1,
    PREP_MaintainStep2,
    PREP_MaintainStep3,
    PREP_MaintainStepSelect4,
    PREP_MaintainStep4,
    PREP_MaintainStepUpdate4,
    PREP_MaintainStep5,
    PREP_MaintainStep6,
    PREP_MaintainStep7,
//    PREP_MaintainStep8,

    PREP_ConfSetFloat,
    PREP_ConfSetText,
    PREP_GetConf,

    PREP_GetCurrentTimeStamp,

    PREP_UpdateSession: TSqlite3Prepared;
    constructor Create;
    procedure DoHelp({%H-}aData : TObject); override;
    destructor Destroy; override;

    procedure Execute(const Str : String);

    procedure MaintainStep10s;
    procedure MaintainStep60s;
    procedure MaintainStep1hr;

    procedure CheckSSIDs(ids : TFastMapUInt);

    class function UsersDB : TRESTWebCamUsersDB;
  end;

  { TSessionHashFunc }

  TSessionHashFunc = class(TSqlite3Function)
  public
    constructor Create;
    procedure ScalarFunc(argc : integer); override;
  end;


  { TServerCurrentTimeStamp }

  TServerCurrentTimeStamp = class(TSqlite3Function)
  private
    FAutoInc : TThreadSafeAutoIncrementCardinal;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ScalarFunc(argc : integer); override;
  end;

  { TServerTSToSqliteTS }

  TServerTSToSqliteTS = class(TSqlite3Function)
  public
    constructor Create;
    procedure ScalarFunc(argc : integer); override;
  end;

  TDeviceId = record
    cid, sid : TDBID;
    device : String;
  end;

const
     cRawInputStream = '/input.raw';
     cRawOutputStream = '/output.raw';

implementation

uses wcutils, WCRESTWebCamAppHelper, sha1, base64, ExtSqliteUtils,
  WCRESTWebCamStreams, LazSysUtils;

const ERR_NO_ERROR          = 0;
      ERR_UNSPECIFIED       = 1;
      ERR_INTERNAL_UNK      = 2;
      ERR_DATABASE_FAIL     = 3;
      ERR_JSON_PARSER_FAIL  = 4;
      ERR_JSON_FAIL         = 5;
      ERR_NO_SUCH_SESSION   = 6;
      ERR_NO_SUCH_USER      = 7;
      ERR_NO_DEVICES        = 8;
      ERR_NO_SUCH_RECORD    = 9;
      ERR_NO_DATA_RETURNED  = 10;
      ERR_EMPTY_REQUEST     = 11;
      ERR_MALFORMED_REQUEST = 12;
      ERR_NO_CHANNEL        = 13;
      ERR_ERRORED_STREAM    = 14;
      ERR_NO_SUCH_DEVICE    = 15;

const BAD_JSON = '{"result":"BAD","code":1}';
      OK_JSON  = '{"result":"OK"}';
      JSON_EMPTY_OBJ = '{}';
      BAD_JSON_INTERNAL_UNK      = '{"result":"BAD","code":2}';
      BAD_JSON_DATABASE_FAIL     = '{"result":"BAD","code":3}';
      BAD_JSON_JSON_PARSER_FAIL  = '{"result":"BAD","code":4}';
      BAD_JSON_JSON_FAIL         = '{"result":"BAD","code":5}';
      BAD_JSON_NO_SUCH_SESSION   = '{"result":"BAD","code":6}';
      BAD_JSON_NO_SUCH_USER      = '{"result":"BAD","code":7}';
      BAD_JSON_NO_DEVICES        = '{"result":"BAD","code":8}';
      BAD_JSON_NO_SUCH_RECORD    = '{"result":"BAD","code":9}';
      BAD_JSON_NO_DATA_RETURNED  = '{"result":"BAD","code":10}';
      BAD_JSON_EMPTY_REQUEST     = '{"result":"BAD","code":11}';
      BAD_JSON_MALFORMED_REQUEST = '{"result":"BAD","code":12}';
      BAD_JSON_NO_SUCH_DEVICE    = '{"result":"BAD","code":15}';

      BAD_JSON_SCISSOR           = '{"result":"BAD","code":%d}';

      cOK = 'OK';

      cMSG       = 'msg';
      cMSGS      = 'msgs';
      cRECORDS   = 'records';
      cRESULT    = 'result';
      cNAME      = 'name';
      cPASS      = 'pass';
      cSHASH     = 'shash';
      cMETA      = 'meta';
      cREC       = 'record';
      cSTAMP     = 'stamp';
      cRID       = 'rid';
      cMID       = 'mid';
      cSYNC      = 'sync';
      cDEVICE    = 'device';
      cDEVICES   = 'devices';
      cTARGET    = 'target';
      cPARAMS    = 'params';
      cCONFIG    = 'config';
      cKIND      = 'kind';
      cDESCR     = 'descr';
      cMIVALUE   = 'miv';
      cMAVALUE   = 'mav';
      cDEFVALUE  = 'dv';
      cFVALUE    = 'fv';
      cSUBPROTO  = 'subproto';
      cDELTA     = 'delta';
      SessionHash_GUID = AnsiString('4343726B-7F18-4D21-9297-1CC52FFA6F04');

var MAX_ALLOWED_CONFIG_KIND : integer;
var vUsersDB : TRESTWebCamUsersDB = nil;
var vServerDateTimeFormat : TFormatSettings;

function GenSessionHash(const aKey: AnsiString): AnsiString;
var
  Outstream : TStringStream;
  Encoder   : TBase64EncodingStream;
  sha1: TSHA1Digest;
begin
  sha1 := SHA1String(aKey + SessionHash_GUID);
  Outstream:=TStringStream.Create('');
  try
    Encoder:=TBase64EncodingStream.create(outstream);
    try
      Encoder.Write(PByte(@sha1)^, 20);
    finally
      Encoder.Free;
    end;
    Result:=Outstream.DataString;
  finally
    Outstream.free;
  end;
end;


function GetForeignClientId(acId : TDBID; const aDevice : String) : TDBID;
var
  Res : Array [0..0] of Variant;
begin
  try
    if Length(aDevice) > 0 then
    begin
      if vUsersDB.PREP_GetSessionByDevice.ExecToValue([acId, aDevice], @Res) = erOkWithData then
      begin
        Result := Res[0];
      end else
        Result := 0;
    end else
      Result := 0;
  except
    Result := 0;
  end;
end;

function GetClientIdUpdate(const sIP, sHash : String; needUpd : Boolean) : TDeviceId;
var
  Res : Array [0..2] of Variant;
begin
  Result.sid := 0;
  Result.cid := 0;
  try
    if Length(sHash) > 0 then
    begin
      if vUsersDB.PREP_GetClientByHash.ExecToValue([sHash, sIP], @Res) = erOkWithData then
      begin
        Result.sid    := Res[0];
        Result.cid    := Res[1];
        Result.device := Res[2];
        if needUpd then
          vUsersDB.PREP_UpdateSession.Execute([sHash]);
      end;
    end;
  except
    Result.sid := 0;
    Result.cid := 0;
  end;
end;

function GetClientId(const sIP, sHash : String) : TDeviceId;
begin
  Result := GetClientIdUpdate(sIP, sHash, true);
end;

function GetClientIdSilent(const sIP, sHash : String) : TDeviceId;
begin
  Result := GetClientIdUpdate(sIP, sHash, false);
end;

function HeartBit(const sIP, sHash : String) : String;
var
  accid : TDeviceId;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
      Result := OK_JSON
    else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function ServerTime(const sIP, sHash : String) : String;
var
  jsonObj : TJSONObject;
begin
  try
    Result := vUsersDB.PREP_GetCurrentTimeStamp.QuickQuery([], nil, false);

    if Length(Result) > 0 then
    begin
      jsonObj := TJSONObject.Create([cSTAMP,  Result,
                                     cRESULT, cOK]);
      try
        Result := jsonObj.AsJSON;
      finally
        jsonObj.Free;
      end;
    end else Result := BAD_JSON_NO_SUCH_USER;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function AddClient(const Name, Passw, aDevice, aMeta, aIP : String) : String;
var
  jsonObj : TJSONObject;
  cid : Array [0..0] of Variant;
begin
  try
    if assigned(vUsersDB.PREP_ReturnLastHsh) then
    begin
      cid[0] := 0;
      vUsersDB.PREP_ReturnLastHsh.Lock;
      try
        if vUsersDB.PREP_GetClient.ExecToValue([Name, Passw],
                                               @cid) = erOkWithData then
        begin
          vUsersDB.PREP_AddClient.Execute([cid[0], aDevice, aMeta, aIP]);
          Result := vUsersDB.PREP_ReturnLastHsh.QuickQuery([cid[0], aDevice], nil, false);
        end else
          Exit(BAD_JSON_NO_SUCH_USER);
      finally
        vUsersDB.PREP_ReturnLastHsh.UnLock;
      end;
    end else
      Result := vUsersDB.PREP_AddClient.QuickQuery([Name, Passw, aDevice, aMeta, aIP], nil, false);
    if Length(Result) > 0 then
    begin
      jsonObj := TJSONObject.Create([cSHASH,  Result,
                                     cRESULT, cOK]);
      try
        Result := jsonObj.AsJSON;
      finally
        jsonObj.Free;
      end;
    end else Result := BAD_JSON_NO_SUCH_USER;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function GetConfig(const sIP, sHash : String) : String;
var
  jArr : TJSONArray;
  jRes, jObj : TJSONObject;
  accid  : TDeviceId;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then begin
      jArr := TJSONArray.Create;
      jRes := TJSONObject.Create([cCONFIG, jArr,
                                  cRESULT, cOK]);
      vUsersDB.PREP_GetConf.Lock;
      try
        with vUsersDB.PREP_GetConf do
        if OpenDirect([accid.cid]) then
        begin
          repeat
            jObj := TJSONObject.Create([cKIND,    AsInt32[0],
                                        cDESCR,   AsString[1],
                                        cMIVALUE, AsDouble[2],
                                        cMAVALUE, AsDouble[3],
                                        cDEFVALUE,AsDouble[4],
                                        cFVALUE,  AsDouble[5]]);
            jArr.Add(jObj);
          until not Step;
        end;
        vUsersDB.PREP_GetConf.Close;
        Result := jRes.AsJSON;
      finally
        vUsersDB.PREP_GetConf.UnLock;
        jRes.Free;
      end;
    end
    else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function DoRawInputData(aStream : TWCRESTWebCamStream;
                        aRef : TWCRequestRefWrapper) : Integer;
begin
  if aRef is TWCHTTP2IncomingChunk then
  begin
    aStream.WriteData(TWCHTTP2IncomingChunk(aRef));
    Result := ERR_NO_ERROR;
  end else
    Result := ERR_INTERNAL_UNK;
end;

function RawInputData(const sIP, sHash, sSubProto : String; iDelta : Integer;
                             Ref : TWCRequestRefWrapper) : Integer;
var
  accid  : TDeviceId;
  aStream : TWCRESTWebCamStream;
  aHttp2Stream : TWCHTTP2Stream;
begin
  try
    if Ref is TWCHTTP2IncomingChunk then
      aHttp2Stream := TWCHTTP2IncomingChunk(Ref).Stream
    else
    if Ref is TWCHTTP2Stream then
      aHttp2Stream := TWCHTTP2Stream(Ref) else
      Exit(ERR_INTERNAL_UNK);

    if assigned(aHttp2Stream.ExtData) then
      aStream := TWCRESTWebCamStream(aHttp2Stream.ExtData) else
    begin
      accid := GetClientIdSilent(sIP, sHash);

      if accid.sid > 0 then begin
        aStream := TRESTWebCamStreams.AddStream(aHttp2Stream, accid.sid,
                                                              sSubProto, iDelta);
        aHttp2Stream.ExtData := aStream;
        aHttp2Stream.OwnExtData := false;
      end
      else
        Exit(ERR_NO_SUCH_SESSION);
    end;

    if Assigned(aStream) then
    begin
      if aStream.ErrorCode <> ERR_NO_ERROR then
        Result := ERR_ERRORED_STREAM else
        Result := DoRawInputData(aStream, Ref);
    end else
      Result := ERR_NO_CHANNEL;

  except
    on e : EDatabaseError do Result := ERR_DATABASE_FAIL;
    else Result := ERR_INTERNAL_UNK;
  end;
end;

function SetConfig(const sIP, sHash, sConfig : String) : String;
var
  jArr : TJSONArray;
  jObj : TJSONObject;
  jD, jI : TJSONData;
  accid : TDeviceId;
  values_list : String;
  i, k : integer;
  fv : Double;
  fs : TFormatSettings;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then begin
      jD := GetJSON(sConfig);
      if Assigned(jD) then
      begin
        try
          if jD is TJSONArray then
          begin
            jArr := TJSONArray(jD);
            if jArr.Count > 0 then
            begin
              values_list := '';
              fs := DefaultFormatSettings;
              fs.DecimalSeparator := '.';
              for i := 0 to jArr.Count-1 do
              begin
                if jArr[i] is TJSONObject then
                begin
                  jObj := TJSONObject(jArr[i]);
                  jI := jObj.Find(cKIND);
                  if assigned(jI) and (jI is TJSONIntegerNumber) then k := jI.AsInteger else k := 0;
                  jI := jObj.Find(cFVALUE);
                  if assigned(jI) and (jI is TJSONNumber) then fv := jI.AsFloat else fv := 0.0;

                  if (k < 1) and (k > MAX_ALLOWED_CONFIG_KIND) then
                  begin
                    values_list := '';
                    break;
                  end;

                  if length(values_list) > 0 then values_list := values_list + ',';
                  values_list := values_list + Format('(%d, %d, %g)', [accid.cid, k, fv], fs);
                end;
              end;
              if Length(values_list) > 0 then
              begin
                vUsersDB.Execute('insert or replace into '+
                                 'confs (cid, kind, fv) values '+
                                  values_list + ';');
                Result := OK_JSON;
              end else
                Result := BAD_JSON_MALFORMED_REQUEST;
            end else
              Result := BAD_JSON_MALFORMED_REQUEST;
          end else
            Result := BAD_JSON_MALFORMED_REQUEST;
        finally
          jD.Free;
        end;
      end else
        Result := BAD_JSON_MALFORMED_REQUEST;
    end
    else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function GetListOfDevices(const sIP, sHash : String) : String;
var
  res : TJSONObject;
  devs : TJSONArray;
  accid : TDeviceId;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      devs := TJSONArray.Create;
      res := TJSONObject.Create([cRESULT, cOK, cDEVICES, devs]);
      try
        vUsersDB.PREP_GetListOfDevices.Lock;
        try
          with vUsersDB.PREP_GetListOfDevices do
          if OpenDirect([accid.cid]) then
          begin
            repeat
              devs.Add(TJSONObject.Create([cDEVICE, AsString[0],
                                           cMETA,   AsString[1]]));
            until not Step;
          end else
          begin
            FreeAndNil(res);
            Result := BAD_JSON_NO_DEVICES;
          end;
          vUsersDB.PREP_GetListOfDevices.Close;
        finally
          vUsersDB.PREP_GetListOfDevices.UnLock;
        end;
        if Assigned(res) then
          Result := res.AsJSON;
      finally
        if assigned(res) then res.Free;
      end;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function GetListOfStreams(const sIP, sHash : String) : String;
var
  res : TJSONObject;
  devs : TJSONArray;
  accid : TDeviceId;
  strm : TWCRESTWebCamStream;
  sid : Int64;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      devs := TJSONArray.Create;
      res := TJSONObject.Create([cRESULT, cOK, cDEVICES, devs]);
      try
        if TRESTWebCamStreams.HasStreams then
        begin
          vUsersDB.PREP_GetSessionsByCID.Lock;
          try
            with vUsersDB.PREP_GetSessionsByCID do
            if OpenDirect([accid.cid]) then
            begin
              repeat
                sid := AsInt64[0];
                TRESTWebCamStreams.Lock;
                try
                  strm := TRESTWebCamStreams.FindStream(sid);
                  if assigned(strm) then
                    devs.Add(TJSONObject.Create([cDEVICE, AsString[1],
                                                 cSUBPROTO, strm.SubProtocol,
                                                 cDELTA, strm.Delta]));
                finally
                  TRESTWebCamStreams.UnLock;
                end;
              until not Step;
            end else
            begin
              FreeAndNil(res);
              Result := BAD_JSON_NO_DEVICES;
            end;
            vUsersDB.PREP_GetSessionsByCID.Close;
          finally
            vUsersDB.PREP_GetSessionsByCID.UnLock;
          end;
        end;

        if Assigned(res) then
          Result := res.AsJSON;
      finally
        if assigned(res) then res.Free;
      end;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function GetRecordMeta(const sIP, sHash : String; recId : Integer) : String;
var
  jsonObj : TJSONObject;
  accid : TDeviceId;
  Res : Array [0..2] of Variant;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      if vUsersDB.PREP_GetRecordMeta.ExecToValue([accid.cid, recId],
                                                 @Res) = erOkWithData then
      begin
        jsonObj := TJSONObject.Create([cDEVICE,VarToStr(Res[0]),
                                       cMETA,  VarToStr(Res[1]),
                                       cSTAMP, VarToStr(Res[2]),
                                       cRESULT, cOK]);
        try
          Result := jsonObj.AsJSON;
        finally
          jsonObj.Free;
        end;
      end else
        Result := BAD_JSON_NO_SUCH_RECORD;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

procedure GetRecordData(Resp : TWCResponse;
                             const sIP, sHash : String; recId : Integer);
var
  ptr : TSqliteBlobPointer;
  accid : TDeviceId;
  Strm : TMemoryStream;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      vUsersDB.PREP_GetRecordData.Lock;
      try
        with vUsersDB.PREP_GetRecordData do
        if OpenDirect([accid.cid, recId]) then
        begin
          ptr := AsBlob[0];
          if Assigned(ptr.Data) then
          begin
            Strm := TMemoryStream.Create;
            Strm.WriteBuffer(ptr.Data^, ptr.SizeOfData);
            Strm.Position := 0; // important!
            Resp.ContentStream := Strm;
            Resp.FreeContentStream := true;
          end else
            Resp.Content := BAD_JSON_NO_DATA_RETURNED;
        end else
          Resp.Content := BAD_JSON_NO_SUCH_RECORD;
        vUsersDB.PREP_GetRecordData.Close;
      finally
        vUsersDB.PREP_GetRecordData.UnLock;
      end;
    end else
      Resp.Content := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Resp.Content := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Resp.Content := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Resp.Content := BAD_JSON_JSON_FAIL;
    else Resp.Content := BAD_JSON_INTERNAL_UNK;
  end;
end;

function GetRecordCount(const sIP, sHash, FromLastStamp : String) : String;
var
  jsonArr : TJSONArray;
  jsonObj, jsonRes : TJSONObject;
  accid : TDeviceId;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      jsonArr := TJSONArray.Create;
      jsonRes := TJSONObject.Create([cRECORDS, jsonArr]);
      try
        vUsersDB.PREP_GetRecordCount.Lock;
        try
          with vUsersDB.PREP_GetRecordCount do
          if OpenDirect([accid.cid, FromLastStamp]) then
          begin
            repeat
              jsonObj := TJSONObject.Create([cRID,    AsInt32[0],
                                             cDEVICE, AsString[1],
                                             cSTAMP,  AsString[2]]);
              jsonArr.Add(jsonObj);
            until not Step;
          end;
          vUsersDB.PREP_GetRecordCount.Close;
        finally
          vUsersDB.PREP_GetRecordCount.UnLock;
        end;
        jsonRes.Add(cRESULT, cOK);
        Result := jsonRes.AsJSON;
      finally
        jsonRes.Free;
      end;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function DeleteRecords(const sIP, sHash, sRecords : String) : String;
var
  jD   : TJSONData;
  jArr : TJSONArray;
  accid : TDeviceId;
  i, k, v : integer;
  hasneg : Boolean;
  values_list : String;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      jD := GetJSON(sRecords);
      if Assigned(jD) then
      begin
        try
          if jD is TJSONArray then
          begin
            jArr := TJSONArray(jD);
            if jArr.Count = 0 then
              Result := BAD_JSON_MALFORMED_REQUEST else
            if jArr.Count = 1 then
            begin
              if (jArr[0] is TJSONIntegerNumber) and
                 (jArr[0].AsInteger >= 0) then
              begin
                vUsersDB.PREP_DeleteRecord.Execute([accid.cid, jArr[0].AsInteger]);
                Result := OK_JSON;
              end else
                Result := BAD_JSON_MALFORMED_REQUEST;
            end else
            begin
              values_list := '';
              hasneg := false;
              k := High(integer);
              for i := 0 to jArr.Count-1 do
              begin
                if jArr[i] is TJSONIntegerNumber then
                begin
                  v := jArr[i].AsInteger;
                  if v < 0 then hasneg := true else
                  begin
                    if length(values_list) > 0 then values_list := values_list + ',';
                    values_list := values_list + Inttostr(v);
                    if k > v then
                      k := v;
                  end;
                end;
              end;
              if k < High(Integer) then
              begin
                if hasneg then
                begin
                  vUsersDB.PREP_DeleteRecordsFrom.Execute([accid.cid, k]);
                end;
                vUsersDB.Execute('delete from records where '+
                                 '(cid == ' +inttostr(accid.cid) +
                                 ') and (id in (' + values_list + '));');
                Result := OK_JSON;
              end else
                Result := BAD_JSON_MALFORMED_REQUEST;
            end;
          end else
          if jD is TJSONIntegerNumber then
          begin
            vUsersDB.PREP_DeleteRecord.Execute([accid.cid, jD.AsInteger]);
            Result := OK_JSON;
          end else
            Result := BAD_JSON_MALFORMED_REQUEST;
        finally
          jD.Free;
        end;
      end else
        Result := BAD_JSON_MALFORMED_REQUEST;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function GetMsgs(const sIP, sHash : String;
                             FromLastStamp : String;
                             DoSync : Boolean) : String;
var
  jsonArr : TJSONArray;
  jsonObj, jsonRes : TJSONObject;
  ParamsData : TJSONData;
  jsonStr : TJSONString;
  accid : TDeviceId;
  Str : String;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      jsonObj := nil;
      try
        if (Length(FromLastStamp) > 0) and
           (FromLastStamp[1] = '{') then
        begin
          jsonObj := TJSONObject(GetJSON(FromLastStamp));
        end;
      except
        if assigned(jsonObj) then FreeAndNil(jsonObj);
      end;

      if Assigned(jsonObj) then
      begin
        if jsonObj.Find(cMSG, jsonStr) and
           SameText(jsonStr.AsString, cSYNC) then
        begin
          // client trying to get msgs from the last sync
          FromLastStamp := vUsersDB.PREP_GetLastSync.QuickQuery([accid.cid,
                                                                 accid.device],
                                                                 nil, false);
        end else
          FromLastStamp := '';
        FreeAndNil(jsonObj);
      end;

      if DoSync then
        vUsersDB.PREP_AddSync.Execute([accid.cid, accid.device]);

      jsonArr := TJSONArray.Create;
      jsonRes := TJSONObject.Create([cMSGS, jsonArr,
                                     cRESULT, cOK]);
      try
        vUsersDB.PREP_GetMsgs.Lock;
        try
          with vUsersDB.PREP_GetMsgs do
          if OpenDirect([accid.cid, FromLastStamp, accid.device]) then
          begin
            //request format:
             //msg, device, params, stamp
            repeat
              Str := AsString[2];
              if Length(Str) > 0 then
                ParamsData := GetJSON(Str) else
                ParamsData := TJSONObject.Create;

              jsonObj := TJSONObject.Create([cMSG,    AsString[0],
                                             cDEVICE, AsString[1],
                                             cPARAMS, ParamsData,
                                             cSTAMP,  AsString[3]]);
              jsonArr.Add(jsonObj);
            until not Step;
          end;
          vUsersDB.PREP_GetMsgs.Close;
        finally
          vUsersDB.PREP_GetMsgs.UnLock;
        end;
        Result := jsonRes.AsJSON;
      finally
        jsonRes.Free;
      end;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function AddRecord(const sHash, sMeta : String;  Req : TWCRequest) : String;
var
  accid : TDeviceId;
  ptr : TSqliteBlobPointer;
begin
  try
    accid := GetClientId(Req.RemoteAddress, sHash);
    if accid.cid > 0 then
    begin
      if assigned(Req.ContentStream) then
      begin
        if Req.ContentStream is TCustomMemoryStream then
        begin
          ptr.Data := TCustomMemoryStream(Req.ContentStream).Memory;
          ptr.SizeOfData := TCustomMemoryStream(Req.ContentStream).Size;
          ptr.destr := nil; //static
          vUsersDB.PREP_AddRecord.Execute([accid.cid, accid.device, sMeta, @ptr]);
          Result := OK_JSON;
        end else
          Result := BAD_JSON_INTERNAL_UNK;
      end else
        Result := BAD_JSON_EMPTY_REQUEST;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function AddMsg(const sIP, sHash, sMsg, aTarget, aParams : String) : String;
var
  accid : TDeviceId;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      if SameText(sMsg, cSYNC) then
        vUsersDB.PREP_AddSync.Execute([accid.cid, accid.device])
      else
        vUsersDB.PREP_AddMsg.Execute([accid.cid, sMsg, accid.device, aTarget, aParams]);
      Result := OK_JSON;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

function AddMsgs(const sIP, sHash : String; arr : TJSONArray) : String;
var
  accid : TDeviceId;
  i : integer;
  sMsg, aTarget, aParams : String;
  jField : TJSONData;
begin
  try
    accid := GetClientId(sIP, sHash);
    if accid.cid > 0 then
    begin
      for i := 0 to arr.Count-1 do
      begin
        if arr[i] is TJSONObject then
        begin
          if TJSONObject(arr[i]).Find(cTARGET, jField) then
            aTarget := jField.AsString else
            aTarget := '';
          if TJSONObject(arr[i]).Find(cMSG, jField) then
            sMsg := jField.AsString else
            sMsg := '';
          if TJSONObject(arr[i]).Find(cPARAMS, jField) then
          begin
            aParams := jField.AsJSON;
          end else
            aParams := JSON_EMPTY_OBJ;
          if SameText(sMsg, cSYNC) then
            vUsersDB.PREP_AddSync.Execute([accid.cid, accid.device])
          else
            vUsersDB.PREP_AddMsg.Execute([accid.cid, sMsg, accid.device, aTarget, aParams]);
        end;
      end;
      Result := OK_JSON;
    end else
      Result := BAD_JSON_NO_SUCH_SESSION;
  except
    on e : EDatabaseError do Result := BAD_JSON_DATABASE_FAIL;
    on e : EJSONParser do Result := BAD_JSON_JSON_PARSER_FAIL;
    on e : EJSON do Result := BAD_JSON_JSON_FAIL;
    else Result := BAD_JSON_INTERNAL_UNK;
  end;
end;

{ TServerTSToSqliteTS }

constructor TServerTSToSqliteTS.Create;
begin
  inherited Create('sts_to_ts', 1, sqlteUtf8, sqlfScalar, true);
end;

procedure TServerTSToSqliteTS.ScalarFunc(argc : integer);
var
  S : String;
begin
  S := Copy(AsString(0), 1, 19);
  SetResult(S);
end;

{ TServerCurrentTimeStamp }

constructor TServerCurrentTimeStamp.Create;
begin
  inherited Create('servertimestamp', 0, sqlteUtf8, sqlfScalar, true);
  FAutoInc := TThreadSafeAutoIncrementCardinal.Create;
end;

destructor TServerCurrentTimeStamp.Destroy;
begin
  FAutoInc.Free;
  inherited Destroy;
end;

procedure TServerCurrentTimeStamp.ScalarFunc(argc : integer);
var
  V : Cardinal;
  S, C : String;
begin
  V := FAutoInc.ID;
  DateTimeToString(s, 'yyyy-mm-dd hh:nn:ss', NowUTC, []);
  S := S + '.0000';
  C := InttoStr(V mod 10000);
  Move(C[1], S[25 - Length(C)], Length(C));

  SetResult(S);
end;

{ TSessionHashFunc }

constructor TSessionHashFunc.Create;
begin
  inherited Create('gennewhash', 0, sqlteUtf8, sqlfScalar, true);
end;

procedure TSessionHashFunc.ScalarFunc(argc : integer);
var S : String;
begin
  S := GenSessionHash(IntToHex(Random(High(Int16))+1, 4) +
                      IntToHex(GetTickCount64, 16));
  SetResult(S);
end;

{ TRESTWebCamUsersDB }

constructor TRESTWebCamUsersDB.Create;
begin
  FUsersDB := TExtSqlite3Dataset.Create(nil);
end;

procedure TRESTWebCamUsersDB.DoHelp({%H-}aData : TObject);
begin
  try
    FUsersDB.FileName := Application.SitePath + TRESTJsonConfigHelper.Config.UsersDB;
    FUsersDB.AddFunction(TSessionHashFunc.Create);
    FUsersDB.AddFunction(TServerCurrentTimeStamp.Create);
    FUsersDB.AddFunction(TServerTSToSqliteTS.Create);
    FUsersDB.ExecSQL(
    'create table if not exists clients'+
      '(id integer primary key autoincrement, '+
       'name text unique,'+
       'pass text not null);');
    FUsersDB.ExecSQL(
    'create table if not exists sessions'+
      '(id integer primary key autoincrement, '+
       'cid integer references clients(id) on delete cascade not null,'+
       'device text,'+
       'metadata text,'+
       'ip text,'+
       'shash text default (gennewhash()),'+
       'req_total integer default 0,'+
       'req_permin integer default 0,'+
       'stamp double default (julianday(current_timestamp)));');
    FUsersDB.ExecSQL(
    'create table if not exists records'+
      '(id integer primary key autoincrement, '+
       'cid integer references clients(id) on delete cascade,'+
       'device text,'+
       'metadata text,'+
       'data blob,'+
       'stamp text default servertimestamp);');
    FUsersDB.ExecSQL(
    'create table if not exists msgs'+
      '(id integer primary key autoincrement, '+
       'cid integer references clients(id) on delete cascade,'+
       'msg text,'+
       'device text,'+
       'target text,'+
       'params text,'+
       'stamp text default servertimestamp);');
    // since 18.02.24 *BEGIN*
    FUsersDB.ExecSQL(
    'create table if not exists syncs'+
      '(cid integer references clients(id) on delete cascade,'+
       'device text,'+
       'stamp text default servertimestamp);');
    FUsersDB.ExecSQL(
    'create unique index if not exists syncs_index on syncs (cid, device);'
    );
    FUsersDB.ExecSQL(
    'insert or ignore into syncs (cid, device, stamp) '+
    'select cid, device, max(stamp) from msgs where msg == ''sync'' group by cid, device;'
    );
    FUsersDB.ExecSQL(
    'delete from msgs where msg == ''sync'';'
    );
    // since 18.02.24 *END*
    FUsersDB.ExecSQL(
    'create table if not exists confs'+
      '(cid integer references clients(id) on delete cascade,'+
       'kind integer,'+
       'fv real default 0.0,'+
       'unique (cid, kind) on conflict replace);');
    FUsersDB.ExecSQL(
    'create table if not exists conf_set'+
      '(knd integer unique,'+
       'descr text,'+
       'miv real default 0.0,'+
       'mav real default 0.0,'+
       'dv real default 0.0);');

    MAX_ALLOWED_CONFIG_KIND := 6;
    FUsersDB.ExecuteDirect('insert or ignore into conf_set (knd, descr, miv, mav, dv) values '+
                           '(1, ''old records timeout (days)'', 0.004, 168.0, 30.0), '+
                           '(2, ''dead sessions timeout (minutes)'', 3, 30, 10), '+
                           '(3, ''max requests for session'', 200, 10000, 1500), '+
                           '(4, ''max reqs per min for session'', 20, 200, 50), '+
                           '(5, ''broadcasts lifetime (hr)'', 1, 750, 125),'+
                           '(6, ''overall messages lifetime (days)'', 1, 120, 30);');

    PREP_GetCurrentTimeStamp := FUsersDB.AddNewPrep('select current_timestamp;');

    PREP_GetClient := FUsersDB.AddNewPrep(
                          'SELECT id FROM clients WHERE name == ?1 and pass == ?2;');
    PREP_GetListOfDevices := FUsersDB.AddNewPrep(
                          'SELECT device, metadata FROM '+
                          'sessions WHERE cid == ?1 group by device;');

    if (sqluGetVersionMagNum >= 3) and (sqluGetVersionMinNum >= 35) then
    begin
      PREP_AddClient := FUsersDB.AddNewPrep(
                          'INSERT OR IGNORE INTO sessions (cid, device, metadata, ip) '+
                          'SELECT id, ?3, ?4, ?5 FROM clients WHERE '+
                          'clients.name == ?1 and clients.pass == ?2 '+
                          'RETURNING shash;');
      PREP_ReturnLastHsh := nil;
    end else begin
      PREP_AddClient := FUsersDB.AddNewPrep(
                          'INSERT OR IGNORE INTO sessions (cid, device, metadata, ip) '+
                          'values (?1, ?2, ?3, ?4);');
      PREP_ReturnLastHsh := FUsersDB.AddNewPrep(
                          'SELECT shash from sessions where cid == ?1 and '+
                          'device == ?2 order by id desc limit 1;');
    end;
    PREP_AddMsg := FUsersDB.AddNewPrep('INSERT INTO msgs '+
                                       '(cid, msg, device, target, params, stamp) '+
                                       'values (?1, ?2, ?3, ?4, ?5, servertimestamp());');
    PREP_AddSync := FUsersDB.AddNewPrep('INSERT OR REPLACE INTO syncs '+
                                       '(cid, device, stamp) '+
                                       'VALUES (?1, ?2, servertimestamp());');
    {PREP_AddSync := FUsersDB.AddNewPrep('INSERT INTO msgs '+
                                       '(cid, msg, device, target, params, stamp) '+
                                       'values (?1, ''sync'', ?2, '''', '''', servertimestamp());');}
    PREP_GetLastSync := FUsersDB.AddNewPrep('select stamp from syncs '+
                                            'where (cid == ?1) and '+
                                                  '(device == ?2);');
    {PREP_GetLastSync := FUsersDB.AddNewPrep('select stamp from msgs '+
                                            'where (cid == ?1) and '+
                                            '(device == ?2) and '+
                                            '(msg == ''sync'') '+
                                            'order by stamp desc limit 1;'); }
    PREP_GetClientByHash := FUsersDB.AddNewPrep('select id, cid, device '+
                                            'from sessions where shash == ?1 and ip == ?2 '+
                                            'limit 1;');
    PREP_GetSessionByDevice := FUsersDB.AddNewPrep('select id '+
                                            'from sessions where cid == ?1 and '+
                                            'device == ?2 '+
                                            'order by id desc limit 1;');
    PREP_GetSessions := FUsersDB.AddNewPrep('select max(id),cid,device from sessions '+
                                            'group by cid, device;');
    PREP_GetSessionsByCID := FUsersDB.AddNewPrep('select max(id),device from sessions '+
                                            'where cid == ?1 '+
                                            'group by device;');

    PREP_AddRecord := FUsersDB.AddNewPrep('INSERT INTO records '+
                                          '(cid, device, metadata, data, stamp) '+
                                          'values (?1, ?2, ?3, ?4, servertimestamp());');

    // important to send both params:
    //   ?1 - client id, ?2 - record/msg id
    // to prevent accessing to frames of other users
    PREP_DeleteRecordsFrom := FUsersDB.AddNewPrep('DELETE FROM records '+
                                          'where (cid == ?1) and (id <= ?2);');
    PREP_DeleteRecord := FUsersDB.AddNewPrep('DELETE FROM records '+
                                          'where (cid == ?1) and (id == ?2);');
    PREP_GetRecordMeta := FUsersDB.AddNewPrep('SELECT device, metadata, stamp FROM '+
                                              'records where cid == ?1 and id = ?2 limit 1;');
    PREP_GetRecordData := FUsersDB.AddNewPrep('SELECT data FROM '+
                                              'records where cid == ?1 and id = ?2 limit 1;');
    //
    PREP_GetRecordCount := FUsersDB.AddNewPrep('Select * from (SELECT id, device, stamp FROM '+
                                               'records where (cid == ?1) and (stamp > ?2) '+
                                               'order by stamp asc limit 32) order by stamp asc;');
    PREP_GetMsgs        := FUsersDB.AddNewPrep('Select * from (SELECT msg, device, params, stamp FROM '+
                                               'msgs where (cid == ?1) and (stamp > ?2) and '+
                                               '(target in (?3, '''' )) and (device != ?3) '+ //and (msg!=''sync'')'+
                                               'order by stamp asc limit 32) order by stamp asc;');
    //

    {PREP_ConfSetFloat := FUsersDB.AddNewPrep('WITH new (cid, kind, fv, sv) AS ( VALUES(?1, ?2, ?3) ) '+
                        'INSERT OR REPLACE INTO confs (cid, kind, fv, sv) '+
                        'SELECT old.cid, old.kind, new.fv, old.sv '+
                        'FROM new LEFT JOIN confs AS old ON '+
                        'new.cid = old.cid and new.kind = old.kind;');
    PREP_ConfSetText := FUsersDB.AddNewPrep('WITH new (cid, kind, sv) AS ( VALUES(?1, ?2, ?3) ) '+
                        'INSERT OR REPLACE INTO confs (cid, kind, fv, sv) '+
                        'SELECT old.cid, old.kind, old.fv, new.sv '+
                        'FROM new LEFT JOIN confs AS old ON '+
                        'new.cid = old.cid and new.kind = old.kind;');}

    PREP_GetConf := FUsersDB.AddNewPrep('Select conf_set.knd, '+
                                               'conf_set.descr, '+
                                               'conf_set.miv, '+
                                               'conf_set.mav, '+
                                               'conf_set.dv, '+
                                               'ifnull(fv, conf_set.dv) as flv '+
                                        'from conf_set left join confs on '+
                                        'conf_set.knd == confs.kind '+
                                        'and cid == ?1 '+
                                        'order by conf_set.knd asc;');

    // cleanup 'old' records (conf.kind = 1) - launching every hour
    // the 'old' record = (cur_timestamp-record.timestamp) values greater than conf[1].fv
    //   conf[1].fv(min,max,default) = 1 hr, 1 month, 1 week
   //     (inital values - you can edit them in conf_set table)
    PREP_MaintainStep1 := FUsersDB.AddNewPrep('delete from records where id in '+
                                              '(select id from records as r1 left join confs '+
                                              'on confs.cid == r1.cid and confs.kind == 1 '+
                                              'inner join conf_set on conf_set.knd == 1 '+
                                              'where (julianday(current_timestamp) - julianday(sts_to_ts(r1.stamp))) > '+
                                                    'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav));');

    // cleanup 'dead' sessions (conf.kind = 2) - launching every 10s
    // the 'dead' session = (cur_timestamp-session.timestamp) values greater than conf[2].fv
    //   conf[2].fv(min,max,default) = 3 min, 30 min, 10 min
    //     (inital values - you can edit them in conf_set table)
    PREP_MaintainStep2 := FUsersDB.AddNewPrep('delete from sessions where id in '+
                                              '(select id from sessions as s1 left join confs '+
                                              'on confs.cid == s1.cid and confs.kind == 2 '+
                                              'inner join conf_set on conf_set.knd == 2 '+
                                              'where (julianday(current_timestamp) - s1.stamp) > '+
                                                    '(min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav)*0.0007));');

    // cleanup 'old' sessions (conf.kind = 3) - launching every 60s
    // the 'old' sessions = num of requests exceed conf[3].fv value
    //   conf[3].fv(min,max,default) = 200, 10000, 1500
    //     (inital values - you can edit them in conf_set table)
    PREP_MaintainStep3 := FUsersDB.AddNewPrep('delete from sessions where id in '+
                                              '(select id from sessions as s1 left join confs '+
                                              'on confs.cid == s1.cid and confs.kind == 3 '+
                                              'inner join conf_set on conf_set.knd == 3 '+
                                              'where s1.req_total > '+
                                                    'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav));');

    // cleanup 'fever' sessions (conf.kind = 4) - launching every 60s
    // the 'fever' sessions = num of requests per minute exceed conf[4].fv value
    //   conf[4].fv(min,max,default) = 20, 200, 50
    //     (inital values - you can edit them in conf_set table)
    PREP_MaintainStep4 := FUsersDB.AddNewPrep('delete from sessions where id in '+
                                              '(select id from sessions as s1 left join confs '+
                                              'on confs.cid == s1.cid and confs.kind == 4 '+
                                              'inner join conf_set on conf_set.knd == 4 '+
                                              'where s1.req_permin > '+
                                                    'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav));');
    PREP_MaintainStepSelect4 := FUsersDB.AddNewPrep('select ip from sessions as s1 left join confs '+
                                                    'on confs.cid == s1.cid and confs.kind == 4 '+
                                                    'inner join conf_set on conf_set.knd == 4 '+
                                                    'where s1.req_permin > '+
                                                       'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav);');
    PREP_MaintainStepUpdate4 := FUsersDB.AddNewPrep('update sessions set req_permin = 0;');

    // delete read messages every 10 sec
{    PREP_MaintainStep5 := FUsersDB.AddNewPrep('with syncs (stmp, cid, dev) as '+
                                              '(select max(julianday(sts_to_ts(stamp))), cid, device from '+
                                              ' msgs where msg==''sync'' group by cid, device) '+
                                              'delete from msgs where msgs.id in (select id from msgs '+
                                              'inner join syncs on '+
                                              '(msgs.cid = syncs.cid) and '+
                                              '((msgs.target = syncs.device) or '+
                                              ' (msgs.device = syncs.device) and (msgs.msg==''sync''))) '+
                                              'where (julianday(sts_to_ts(syncs.stamp)) - julianday(sts_to_ts(msgs.stamp))) > 0.003);');}
    PREP_MaintainStep5 := FUsersDB.AddNewPrep('delete from msgs where msgs.id in (select id from msgs '+
                                              'inner join syncs on '+
                                              '(msgs.cid = syncs.cid) and '+
                                              '(msgs.target = syncs.device) '+
                                              'where (julianday(sts_to_ts(syncs.stamp)) - julianday(sts_to_ts(msgs.stamp))) > 0.003);');
    // delete old broadcast messages every 60 sec
    //  max lifetime of all broadcast msgs is from 1hr to 750hr
{    PREP_MaintainStep6 := FUsersDB.AddNewPrep('delete from msgs  '+
//                                              ' where (target == '''') and (msg!=''sync'') and '+
//                                              '((julianday(current_timestamp) - stsjulianday(stamp)) > ' + //0.04);');
                                              'where id in '+
                                              '(select id from msgs as r1 left join confs '+
                                              'on confs.cid == r1.cid and confs.kind == 5 '+
                                              'inner join conf_set on conf_set.knd == 5 '+
                                              'where (target == '''') and (msg!=''sync'') and (julianday(current_timestamp) - julianday(sts_to_ts(r1.stamp))) > '+
                                                   'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav) * 0.04);');}
    PREP_MaintainStep6 := FUsersDB.AddNewPrep('delete from msgs  '+
                                                  'where id in '+
                                                  '(select id from msgs as r1 left join confs '+
                                                  'on confs.cid == r1.cid and confs.kind == 5 '+
                                                  'inner join conf_set on conf_set.knd == 5 '+
                                                  'where (target == '''') and (julianday(current_timestamp) - julianday(sts_to_ts(r1.stamp))) > '+
                                                       'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav) * 0.04);');

    // delete old messages every 1 hr
    //  max lifetime of all msgs is 30 days (except sync messages)
    PREP_MaintainStep7 := FUsersDB.AddNewPrep(
                                              'with sync_table as (select id, cid, device, max(stamp) from msgs where (msg == ''sync'') group by cid, device) ' +
                                              'delete from msgs  '+
//                                              '(msg!=''sync'') and '+
//                                              '((julianday(current_timestamp) - stsjulianday(stamp)) > 30.0);');
                                              'where id in '+
                                              '(select id from msgs as r1 left join confs '+
                                              'on confs.cid == r1.cid and confs.kind == 6 '+
                                              'inner join conf_set on conf_set.knd == 6 '+
                                              'where (id not in (select sync_table.id from sync_table)) and (julianday(current_timestamp) - julianday(sts_to_ts(r1.stamp))) > '+
                                                   'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav));');
    PREP_MaintainStep7 := FUsersDB.AddNewPrep(
                                              'delete from msgs  '+
                                              'where id in '+
                                              '(select id from msgs as r1 left join confs '+
                                              'on confs.cid == r1.cid and confs.kind == 6 '+
                                              'inner join conf_set on conf_set.knd == 6 '+
                                              'where (julianday(current_timestamp) - julianday(sts_to_ts(r1.stamp))) > '+
                                                       'min(max(ifnull(confs.fv, conf_set.dv), conf_set.miv), conf_set.mav));');

{    PREP_MaintainStep8 := FUsersDB.AddNewPrep(
                                              'with sync_table as (select id, cid, device, max(stamp) from '+
                                              'msgs where (msg == ''sync'') group by cid, device) ' +
                                              'delete from msgs where '+
                                              '(msg == ''sync'') and (id not in (select sync_table.id from sync_table)) and '+
                                              '(julianday(current_timestamp) - julianday(sts_to_ts(stamp))) > 0.04;');}

    PREP_UpdateSession := FUsersDB.AddNewPrep('update sessions '+
                                                      'set stamp = julianday(current_timestamp), '+
                                                          'req_permin = req_permin + 1, '+
                                                          'req_total = req_total + 1 '+
                                                      'where shash == ?1');
  except
    on E : Exception do
    begin
      Application.DoError(E.ToString);
      Application.NeedShutdown := true;
    end;
  end;
end;

destructor TRESTWebCamUsersDB.Destroy;
begin
  FUsersDB.Free;
  inherited Destroy;
end;

procedure TRESTWebCamUsersDB.Execute(const Str : String);
begin
  FUsersDB.ExecuteDirect(Str);
end;

procedure TRESTWebCamUsersDB.MaintainStep10s;
begin
  PREP_MaintainStep2.Execute;
  PREP_MaintainStep5.Execute;
end;

procedure TRESTWebCamUsersDB.MaintainStep60s;
var ip : string;
begin
  PREP_MaintainStep3.Execute;


  PREP_MaintainStepSelect4.Lock;
  try
    //get list of fever sessions
    with PREP_MaintainStepSelect4 do
    if OpenDirect([]) then
    begin
      ip := AsString[0];
      Application.CoolDownIP(ip, 5); //cooldown for 5 minutes
    end;
    PREP_MaintainStepSelect4.Close;
  finally
    PREP_MaintainStepSelect4.UnLock;
  end;

  PREP_MaintainStep4.Execute;
  PREP_MaintainStepUpdate4.Execute;

  PREP_MaintainStep6.Execute;
end;

procedure TRESTWebCamUsersDB.MaintainStep1hr;
begin
  PREP_MaintainStep1.Execute;
  PREP_MaintainStep7.Execute;
  //PREP_MaintainStep8.Execute;
end;

procedure TRESTWebCamUsersDB.CheckSSIDs(ids : TFastMapUInt);
var i : integer;
begin
  for i := 0 to ids.Count-1 do
    ids.List^[i].UIntValue := 1;

  PREP_GetSessions.Lock;
  try
    //get list of all sessions
    with PREP_GetSessions do
    if OpenDirect([]) then
      repeat
        ids.Value[AsInt64[0]] := 0;
      until not Step;
    PREP_GetSessions.Close;
  finally
    PREP_GetSessions.UnLock;
  end;
end;

class function TRESTWebCamUsersDB.UsersDB : TRESTWebCamUsersDB;
begin
  if not assigned(vUsersDB) then
    vUsersDB := TRESTWebCamUsersDB.Create;
  Result := vUsersDB;
end;

{ TWCHeartBit }

procedure TWCHeartBit.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH],
                             Request.Content, Params, ['']) then
    Response.Content := HeartBit(Request.RemoteAddress, Params[0]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetServerTime }

procedure TWCGetServerTime.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH],
                             Request.Content, Params, ['']) then
    Response.Content := ServerTime(Request.RemoteAddress, Params[0]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetMsgs }

procedure TWCGetMsgs.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cSTAMP],
                             Request.Content, Params, ['', '']) then
    Response.Content := GetMsgs(Request.RemoteAddress, Params[0], Params[1], false) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetMsgsAndSync }

procedure TWCGetMsgsAndSync.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cSTAMP],
                             Request.Content, Params, ['', '']) then
    Response.Content := GetMsgs(Request.RemoteAddress, Params[0], Params[1], true) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetListOfDevices }

procedure TWCGetListOfDevices.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH],
                             Request.Content, Params, ['']) then
    Response.Content := GetListOfDevices(Request.RemoteAddress, Params[0]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetStreams }

procedure TWCGetStreams.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH],
                             Request.Content, Params, ['']) then
    Response.Content := GetListOfStreams(Request.RemoteAddress, Params[0]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetRecordMeta }

procedure TWCGetRecordMeta.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cRID],
                             Request.Content, Params, ['', 0]) then
    Response.Content := GetRecordMeta(Request.RemoteAddress, Params[0], Params[1]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetRecordData }

procedure TWCGetRecordData.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cRID],
                             Request.Content, Params, ['', 0]) then
    GetRecordData(Response, Request.RemoteAddress, Params[0], Params[1])
  else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetRecordCount }

procedure TWCGetRecordCount.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cSTAMP],
                             Request.Content, Params, ['', '']) then
    Response.Content := GetRecordCount(Request.RemoteAddress, Params[0], Params[1]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCDeleteRecords }

procedure TWCDeleteRecords.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cRECORDS],
                             Request.Content, Params, ['', '[]']) then
    Response.Content := DeleteRecords(Request.RemoteAddress,
                                      Params[0], Params[1]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCAddMsg }

procedure TWCAddMsg.Execute;
var
  d   : TJSONData;
  arr : TJSONArray;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cMSG, cTARGET, cPARAMS, cMSGS],
                                   Request.Content, Params, ['', '', '', JSON_EMPTY_OBJ, '']) then
  begin
    try
      if Length(Params[0]) > 0 then
      begin
        d := nil; arr := nil;
        if (Length(Params[4]) > 0) then
        begin
          try
            d := GetJSON(Params[4]);
            if d is TJSONArray then arr := TJSONArray(d);
          except
            on e : EJSONParser do if assigned(d) then FreeAndNil(d);
            on e : EJSON do       if assigned(d) then FreeAndNil(d);
          end;
        end;
        try
          if Assigned(arr) then
            Response.Content := AddMsgs(Request.RemoteAddress, Params[0], arr)
          else
            Response.Content := AddMsg(Request.RemoteAddress, Params[0],
                                                              Params[1],
                                                              Params[2],
                                                              Params[3]);
        finally
          if assigned(d) then FreeAndNil(d);
        end;
      end else
        Response.Content := BAD_JSON_MALFORMED_REQUEST;
    except
      Response.Content := BAD_JSON_INTERNAL_UNK;
    end;
  end else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCAddRecord }

procedure TWCAddRecord.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cMETA],
                             Params, ['', '']) then
    Response.Content := AddRecord(Params[0], Params[1], Request)
  else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCAddClient }

procedure TWCAddClient.Execute;
var
  S : String;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cNAME, cPASS, cDEVICE, cMETA],
                             Request.Content, Params, ['', '', '', JSON_EMPTY_OBJ]) then
  begin
    if (Length(Params[0]) > 0) and
       (Length(Params[1]) > 0) and
       (Length(Params[2]) > 0) then
    begin
      S :=  AddClient(Params[0], Params[1], Params[2], Params[3],
                                               Request.RemoteAddress);
      Response.Content := S;
    end else begin
      Response.Content := BAD_JSON_MALFORMED_REQUEST;
    end;
  end else Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCSetConfig }

procedure TWCSetConfig.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cCONFIG],
                             Request.Content, Params, ['','']) then
  begin
    if Length(Params[1]) > 0 then
      Response.Content := SetConfig(Request.RemoteAddress, Params[0], Params[1]) else
      Response.Content := BAD_JSON_MALFORMED_REQUEST;
  end else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCGetConfig }

procedure TWCGetConfig.Execute;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH],
                             Request.Content, Params, ['']) then
    Response.Content := GetConfig(Request.RemoteAddress, Params[0]) else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCRawInputStream }

procedure TWCRawInputStream.Execute;

procedure CloseStream;
var http2strm : TWCHTTP2Stream;
begin
  if Request.WCContent.RequestRef is TWCHTTP2Stream then
    http2strm := TWCHTTP2Stream(Request.WCContent.RequestRef) else
  if Request.WCContent.RequestRef is TWCHTTP2IncomingChunk then
    http2strm := TWCHTTP2IncomingChunk(Request.WCContent.RequestRef).Stream else
    http2strm := nil;
  if assigned(http2strm) then begin
    http2strm.IncReference;
    http2strm.ResetStream(H2E_REFUSED_STREAM);
  end;
end;

var Res : Integer;
begin
  ResponseReadyToSend := false; // prevent to send response

  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cSUBPROTO, cDELTA],
                             Params, ['','',0]) then
  begin
    if (Length(Params[0]) > 0) then
    begin
      Res := RawInputData(Request.RemoteAddress, Params[0], Params[1], Params[2],
                                                 Request.WCContent.RequestRef);

      if Res <> ERR_NO_ERROR then
        CloseStream;
    end else
      CloseStream;
  end else
      CloseStream;

  inherited Execute;
end;

{ TWCRawOutputStream }

procedure TWCRawOutputStream.Execute;
var
  accid : TDeviceId;
  fid : TDBID;
  S : String;
begin
  if DecodeParamsWithDefault(Request.QueryFields, [cSHASH, cDEVICE],
                             Params, ['', '']) then
  begin
    if (Length(Params[0]) > 0) and
       (Length(Params[1]) > 0) then
    begin
      try
        accid := GetClientId(Request.RemoteAddress, Params[0]);
        if accid.cid > 0 then
        begin
          fid := GetForeignClientId(accid.cid, Params[1]);
          if fid > 0 then
          begin
            Application.WCServer.AddSortedJob(TWCRawOutputSynchroJob.Create(Connection, fid));
            ReleaseConnection;
            ResponseReadyToSend := false; // prevent to send response
            S := '';
          end else
            S := BAD_JSON_NO_SUCH_DEVICE;
        end else
          S := BAD_JSON_NO_SUCH_SESSION;
      except
        on e : EDatabaseError do S := BAD_JSON_DATABASE_FAIL;
        on e : EJSONParser do S := BAD_JSON_JSON_PARSER_FAIL;
        on e : EJSON do S := BAD_JSON_JSON_FAIL;
        else S := BAD_JSON_INTERNAL_UNK;
      end;
      if Length(S) > 0 then
        Response.Content := S;
    end else
      Response.Content := BAD_JSON_MALFORMED_REQUEST;
  end else
    Response.Content := BAD_JSON_MALFORMED_REQUEST;
  inherited Execute;
end;

{ TWCRawOutputSynchroJob }

constructor TWCRawOutputSynchroJob.Create(aConn : TWCAppConnection; sID : TDBID
  );
begin
  inherited Create(aConn);
  FSID := sID;
  FStage := 0;
  FLastFrameId := 0;
end;

procedure TWCRawOutputSynchroJob.Execute;
var aStrm  : TWCRESTWebCamStream;
    aFrame : TWCRESTWebCamStreamFrame;
    aDelta, aRDelta : Integer;

procedure SendResponse;
begin
  try
    if not Response.HeadersSent then
      Response.SendHeaders;

    Response.SendRawData(aFrame.FrameData, aFrame.FrameSize);

  except
    //maybe connection dropped or other write error
    on e : Exception do
      Application.DoError(e.Message);
  end;
end;

begin
  ResponseReadyToSend := false;
  if FStage = 0 then
  begin
    Response.Code:=200;
    Response.CacheControl:='no-cache';
    Response.KeepStreamAlive:=true;
    FStage := 1;
  end;
  try
    try
      if FStage = 1 then
      begin
        FStage := 2; // set here to react on exceptions and exits
        if not Connection.RefCon.ConnectionAvaible then Exit;
        //get stream
        aStrm := TRESTWebCamStreams.FindStream(FSID);
        if Assigned(aStrm) then
        begin
          aDelta := aStrm.Delta;
          if aDelta < 400 then aDelta := 400;
          if aDelta > 60000 then aDelta := 60000;
          aRDelta := aDelta div 2;
          if aRDelta > 10000 then aRDelta := 10000;
          //get frame
          aFrame := aStrm.GetCompletedFrame(FLastFrameId);
          if Assigned(aFrame) then
          begin
            //send new data
            SendResponse;

            if (aFrame.FrameID > (FLastFrameId + 1)) then
            begin
              aDelta := aDelta div 2;
              // possible data lost
            end;

            FLastFrameId := aFrame.FrameID;

            aFrame.DecReference;
            RestartJob(aDelta, GetTickCount64);
          end else
            RestartJob(aRDelta, GetTickCount64);
          FStage := 1;
        end else
          FStage := 2;
      end;
    except
      FStage := 2;
    end;
  finally
    if FStage = 2 then
      Response.CloseStream;
  end;
end;

{ TWCTest }

procedure TWCTest.Execute;
var
  b : RawByteString;
begin
  SetLength(b, 987);
  FillChar(b[1], 987, $ff);
  Response.Content := b;
  inherited Execute;
end;

initialization
  TJSONData.CompressedJSON := true;
  vServerDateTimeFormat := DefaultFormatSettings;
  vServerDateTimeFormat.LongDateFormat:= 'dd.mm.yy';
  vServerDateTimeFormat.LongTimeFormat:= 'hh:nn:ss';
end.

