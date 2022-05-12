{
  This file is a part of example.
  look more in WCRESTWebCam.lpr
}

unit WCMainWebCam;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  wcApplication,
  HTTP1Utils;

type

  { TWCPreThread }

  TWCPreThread = class(TWCPreAnalizeNoSessionNoClientJob)
  public
    function GenerateClientJob: TWCMainClientJob; override;
  end;

procedure InitializeJobsTree;
procedure DisposeJobsTree;

implementation

uses WCRESTWebCamJobs, AvgLvlTree;

var WCJobsTree : TStringToPointerTree;

procedure InitializeJobsTree;
begin
  WCJobsTree := TStringToPointerTree.Create(true);
  WCJobsTree.Values['/authorize.json']        := TWCAddClient;
  WCJobsTree.Values['/addRecord.json']        := TWCAddRecord;
  WCJobsTree.Values['/addMsgs.json']          := TWCAddMsg;
  WCJobsTree.Values['/getRecordMeta.json']    := TWCGetRecordMeta;
  WCJobsTree.Values['/getRecordData.json']    := TWCGetRecordData;
  WCJobsTree.Values['/getRecordCount.json']   := TWCGetRecordCount;
  WCJobsTree.Values['/deleteRecords.json']    := TWCDeleteRecords;
  WCJobsTree.Values['/getMsgs.json']          := TWCGetMsgs;
  WCJobsTree.Values['/getMsgsAndSync.json']   := TWCGetMsgsAndSync;
  WCJobsTree.Values['/getDevicesOnline.json'] := TWCGetListOfDevices;
  WCJobsTree.Values['/getConfig.json']        := TWCGetConfig;
  WCJobsTree.Values['/setConfig.json']        := TWCSetConfig;
  WCJobsTree.Values['/heartBit.json']         := TWCHeartBit;
end;

procedure DisposeJobsTree;
begin
  FreeAndNil(WCJobsTree);
end;

{ TWCPreThread }

function TWCPreThread.GenerateClientJob : TWCMainClientJob;
var ResultClass : TWCMainClientJobClass;
begin
  if CompareText(Request.Method, HTTPPOSTMethod)=0 then
  begin
    ResultClass := TWCMainClientJobClass(WCJobsTree.Values[Request.PathInfo]);
    if assigned(ResultClass) then
       Result := ResultClass.Create(Connection) else
    begin
      Application.SendError(Connection.Response, 404);
      Result := nil;
    end;
  end else begin
    if SameText('/test.json', Request.PathInfo) then
      Result := TWCTest.Create(Connection) else
    begin
      Application.SendError(Connection.Response, 405);
      Result := nil;
    end;
  end;
end;

end.
