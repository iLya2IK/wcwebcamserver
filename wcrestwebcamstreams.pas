{
  This file is a part of example.
  look more in WCRESTWebCam.lpr
}

unit WCRESTWebCamStreams;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  ECommonObjs, OGLFastNumList, extmemorystream, AvgLvlTree,
  wcHTTP2Con, wcApplication, HTTP2Consts;

type

  { TWCRESTWebCamStreamChunk }

  TWCRESTWebCamStreamChunk = class
  private
    FData : TWCHTTP2IncomingChunk;
    FPosition : Int64;
    function GetMemory : Pointer;
    function GetSize : Int64;
  public
    constructor Create(aData : TWCHTTP2IncomingChunk);
    destructor Destroy; override;

    function Empty : Boolean;

    property Size : Int64 read GetSize;
    property Memory : Pointer read GetMemory;
    property Position : Int64 read FPosition write FPosition;
  end;

  { TWCRESTWebCamStreamFrame }

  TWCRESTWebCamStreamFrame = class(TNetReferencedObject)
  private
    FFrameData : Pointer;
    FFrameSize : Integer;
    FFrameID   : QWord;
  public
    constructor Create(aFrameID : QWord; aData : Pointer; sz : Integer);
    destructor Destroy; override;

    property FrameData : Pointer read FFrameData;
    property FrameSize : Integer read FFrameSize;
    property FrameID   : QWord read FFrameID;
  end;

  TWCRESTWebCamChunks = class(specialize TThreadSafeFastBaseSeq<TWCRESTWebCamStreamChunk>);

  { TWCRESTWebCamFrames }

  TWCRESTWebCamFrames = class(TNetReferenceList)
  private
    function IsActual(obj : TObject; data : Pointer) : Boolean;
  public
    function GetActualFrame(const lstFrame : QWord) : TWCRESTWebCamStreamFrame;
  end;

  TWCRESTWebCamFrameState = (fstWaitingStartOfFrame, fstWaitingData);

  { TWCRESTWebCamStream }

  TWCRESTWebCamStream = class(TThreadSafeObject)
  private
    FFrameBuffer : TExtMemoryStream;
    FFrameState  : TWCRESTWebCamFrameState;
    FFrameSize   : Cardinal;
    FFrameBufferSize : Cardinal;
    FFrameID : QWord;

    FErrorCode : Cardinal;

    FKey    : Cardinal;
    FHTTP2S : TWCHTTP2Stream;
    FChunks : TWCRESTWebCamChunks;
    FFrames : TWCRESTWebCamFrames;
    FActiveFrame : TWCRESTWebCamStreamFrame;
    function GetBufferFreeSize : Int64;
    function GetChunkCount : Integer;
    function GetErrorCode : Cardinal;
    function GetFrameID : QWord;
    function TopChunk : TWCRESTWebCamStreamChunk;
    procedure PushFrame(aStartAt : Int64);
    procedure TryConsumeFrames;
  public
    constructor Create(aRef : TWCHTTP2Stream; aSID : Cardinal);
    destructor Destroy; override;

    procedure  WriteData(aData : TWCHTTP2IncomingChunk);
    function GetCompletedFrame(lstFrame : QWord) : TWCRESTWebCamStreamFrame;

    procedure  DoError(aCode : Cardinal);

    procedure  DoIdle;

    property   HTTP2Stream : TWCHTTP2Stream read FHTTP2S;
    property   Key : Cardinal read FKey;

    property   BufferFreeSize : Int64 read GetBufferFreeSize;
    property   ChunkCount : Integer read GetChunkCount;
    property   FrameID : QWord read GetFrameID;

    property   ErrorCode : Cardinal read GetErrorCode;
  end;

  { TWCRESTWebCamStreams }

  TWCRESTWebCamStreams = class(specialize TThreadSafeFastBaseSeq<TWCRESTWebCamStream>)
  private
    FStreamTable : TAvgLvlTree;
    function IsStrmClosed(aStrm : TObject; {%H-}data : pointer) : Boolean;
    function IsSessionClosed(aStrm : TObject; data : pointer) : Boolean;
    function IsStrmSID(aStrm : TObject; {%H-}data : pointer) : Boolean;
    procedure AfterStrmExtract(aStrm: TObject);
    procedure DoRemoveClosedStreams;
    procedure DoIdleStreams;
    procedure IdleStream(obj : TObject);
    procedure FillSSIDMap(obj : TObject; data : Pointer);
    function  RemoveStreamFromTable(aKey : Cardinal) : TWCRESTWebCamStream;
    function  OnCompareMethod({%H-}Tree: TAvgLvlTree; Data1, Data2: Pointer): integer;
  public
    constructor Create;
    destructor Destroy; override;

    function AddStream(aRef : TWCHTTP2Stream; aSID : Cardinal) : TWCRESTWebCamStream;
    procedure RemoveStream(aSID : Cardinal);
    function  MapSSIDs : TFastMapUInt;
    procedure RemoveClosedSessions(ids : TFastMapUInt);
    function Stream(aSID : Cardinal) : TWCRESTWebCamStream;
    procedure Finalize;

    procedure DoIdle;
  end;

  { TRESTWebCamStreams }

  TRESTWebCamStreams = class(TWCHTTPAppInitHelper)
  private
    FWebCamStreams : TWCRESTWebCamStreams;
  public
    constructor Create;
    procedure DoHelp({%H-}aData : TObject); override;
    destructor Destroy; override;

    procedure MaintainStep10s;

    class function WebCamStreams : TRESTWebCamStreams;
    class function FindOrAddStream(aRef : TWCHTTP2Stream; aSID : Cardinal) : TWCRESTWebCamStream;
    class function AddStream(aRef : TWCHTTP2Stream; aSID : Cardinal) : TWCRESTWebCamStream;
    class function FindStream(aSID : Cardinal) : TWCRESTWebCamStream;
    class function MapSSIDs : TFastMapUInt;
    class procedure RemoveClosedSessions(ids : TFastMapUInt);
    class procedure Finalize;

    property Streams : TWCRESTWebCamStreams read FWebCamStreams;
  end;

  { TRESTWebCamStreamsFinalize }

  TRESTWebCamStreamsFinalize = class(TWCHTTPAppDoneHelper)
  public
    procedure DoHelp({%H-}aData : TObject); override;
  end;


const ERR_WEBCAM_STREAM_BUFFER_OVERFLOW = 1;
      ERR_WEBCAM_STREAM_WRONG_HEADER = 2;
      ERR_WEBCAM_STREAM_FRAME_TO_BIG = 3;
      WEBCAM_FRAME_HEADER_SIZE  = Sizeof(Word) + Sizeof(Cardinal);
      WEBCAM_FRAME_START_SEQ : Word = $aaaa;

implementation

uses Math;

var vWebCamStreams : TRESTWebCamStreams = nil;

const WEBCAM_FRAME_BUFFER_SIZE = $100000;

{ TRESTWebCamStreamsFinalize }

procedure TRESTWebCamStreamsFinalize.DoHelp(aData : TObject);
begin
  TRESTWebCamStreams.Finalize;
end;

{ TWCRESTWebCamFrames }

function TWCRESTWebCamFrames.IsActual(obj : TObject; data : Pointer) : Boolean;
begin
  Result := TWCRESTWebCamStreamFrame(obj).FrameID > PQWord(data)^;
end;

function TWCRESTWebCamFrames.GetActualFrame(const lstFrame : QWord
  ) : TWCRESTWebCamStreamFrame;
begin
  Result := TWCRESTWebCamStreamFrame(FindValue(@IsActual, @lstFrame));
end;

{ TWCRESTWebCamStreamFrame }

constructor TWCRESTWebCamStreamFrame.Create(aFrameID : QWord;
  aData : Pointer; sz : Integer);
begin
  inherited Create;
  FFrameID := aFrameID;
  FFrameData := GetMem(sz);
  FFrameSize := sz;
  Move(aData^, FFrameData^, sz);
end;

destructor TWCRESTWebCamStreamFrame.Destroy;
begin
  FreeMemAndNil(FFrameData);

  inherited Destroy;
end;

{ TWCRESTWebCamStreamChunk }

function TWCRESTWebCamStreamChunk.GetMemory : Pointer;
begin
  Result := Pointer(FData.Data.Memory + FPosition);
end;

function TWCRESTWebCamStreamChunk.GetSize : Int64;
begin
  Result := FData.Data.Size - FPosition;
end;

constructor TWCRESTWebCamStreamChunk.Create(aData : TWCHTTP2IncomingChunk);
begin
  FData := aData;
  FData.IncReference;
end;

destructor TWCRESTWebCamStreamChunk.Destroy;
begin
  FData.DecReference;
  inherited Destroy;
end;

function TWCRESTWebCamStreamChunk.Empty : Boolean;
begin
  Result := Size = 0;
end;

{ TRESTWebCamStreams }

constructor TRESTWebCamStreams.Create;
begin
   FWebCamStreams := TWCRESTWebCamStreams.Create;
end;

procedure TRESTWebCamStreams.DoHelp(aData : TObject);
begin
  //
end;

destructor TRESTWebCamStreams.Destroy;
begin
  FWebCamStreams.Free;
  inherited Destroy;
end;

procedure TRESTWebCamStreams.MaintainStep10s;
begin
  FWebCamStreams.DoIdle;
end;

class function TRESTWebCamStreams.WebCamStreams : TRESTWebCamStreams;
begin
  if not assigned(vWebCamStreams) then
    vWebCamStreams := TRESTWebCamStreams.Create;
  Result := vWebCamStreams;
end;

class function TRESTWebCamStreams.FindOrAddStream(aRef : TWCHTTP2Stream;
  aSID : Cardinal) : TWCRESTWebCamStream;
begin
  WebCamStreams.Streams.Lock;
  try
    Result := FindStream(aSID);
    if not assigned(Result) then
      Result := WebCamStreams.Streams.AddStream(aRef, aSID);
  finally
    WebCamStreams.Streams.UnLock;
  end;
end;

class function TRESTWebCamStreams.AddStream(aRef : TWCHTTP2Stream;
  aSID : Cardinal) : TWCRESTWebCamStream;
begin
  WebCamStreams.Streams.Lock;
  try
    WebCamStreams.Streams.RemoveStream(aSID);
    Result := WebCamStreams.Streams.AddStream(aRef, aSID);
  finally
    WebCamStreams.Streams.UnLock;
  end;
end;

class function TRESTWebCamStreams.FindStream(aSID : Cardinal
  ) : TWCRESTWebCamStream;
begin
  Result := WebCamStreams.Streams.Stream(aSID);
end;

class function TRESTWebCamStreams.MapSSIDs : TFastMapUInt;
begin
  Result := WebCamStreams.Streams.MapSSIDs;
end;

class procedure TRESTWebCamStreams.RemoveClosedSessions(ids : TFastMapUInt);
begin
  WebCamStreams.Streams.RemoveClosedSessions(ids);
end;

class procedure TRESTWebCamStreams.Finalize;
begin
  WebCamStreams.Streams.Finalize;
end;

{ TWCRESTWebCamStream }

function TWCRESTWebCamStream.GetBufferFreeSize : Int64;
begin
  Result := FFrameBuffer.Size - FFrameBuffer.Position;
end;

function TWCRESTWebCamStream.GetChunkCount : Integer;
begin
  Result := FChunks.Count;
end;

function TWCRESTWebCamStream.GetErrorCode : Cardinal;
begin
  Lock;
  try
    Result := FErrorCode;
  finally
    UnLock;
  end;
end;

function TWCRESTWebCamStream.GetFrameID : QWord;
begin
  lock;
  try
    Result := FFrameID;
  finally
    UnLock;
  end;
end;

function TWCRESTWebCamStream.TopChunk : TWCRESTWebCamStreamChunk;
begin
  Result := FChunks.FirstValue;
end;

procedure TWCRESTWebCamStream.PushFrame(aStartAt : Int64);
begin
  //FFrames.CleanDead;

  if Assigned(FActiveFrame) then
    FActiveFrame.DecReference;
  Lock;
  try
    Inc(FFrameID);
    FActiveFrame := TWCRESTWebCamStreamFrame.Create(FFrameID,
                                                    Pointer(FFrameBuffer.Memory + aStartAt),
                                                    FFrameSize + WEBCAM_FRAME_HEADER_SIZE);
  finally
    UnLock;
  end;
  FFrames.Push_back(FActiveFrame);
end;

constructor TWCRESTWebCamStream.Create(aRef : TWCHTTP2Stream; aSID : Cardinal);
begin
  inherited Create;

  aRef.IncReference;
  FHTTP2S := aRef;
  FKey := aSID;

  FFrames := TWCRESTWebCamFrames.Create;
  FChunks := TWCRESTWebCamChunks.Create;

  FActiveFrame := nil;

  FFrameBuffer := TExtMemoryStream.Create(WEBCAM_FRAME_BUFFER_SIZE);
  FFrameState := fstWaitingStartOfFrame;
  FFrameBufferSize := 0;
  FFrameSize := 0;
  FFrameID := 0;
end;

destructor TWCRESTWebCamStream.Destroy;
begin
  FHTTP2S.ExtData := nil;
  FHTTP2S.DecReference;

  FFrameBuffer.Free;
  FFrames.Clean;
  FFrames.Free;
  FChunks.Free;
  inherited Destroy;
end;

procedure TWCRESTWebCamStream.WriteData(aData : TWCHTTP2IncomingChunk);
begin
  FChunks.Push_back(TWCRESTWebCamStreamChunk.Create(aData));
  TryConsumeFrames;
end;

procedure TWCRESTWebCamStream.TryConsumeFrames;
var BP : Int64;

procedure TruncateFrameBuffer;
begin
  if (BP > 0) then
  begin
    if ((FFrameBufferSize - BP) > 0) then
    begin
      FFrameBufferSize := FFrameBufferSize - BP;
      Move(Pointer(FFrameBuffer.Memory + BP)^,
           FFrameBuffer.Memory^, FFrameBufferSize);
    end else
      FFrameBufferSize := 0;
    BP := 0;
  end;
end;

var W : Word;
    C : Cardinal;
    P : Int64;
begin
  Lock;
  try
    BP := 0;
    while true do
    begin
      if BufferFreeSize = 0 then
      begin
        DoError(ERR_WEBCAM_STREAM_BUFFER_OVERFLOW);
        Exit;
      end;

      if ChunkCount > 0 then
      begin
        FFrameBuffer.Position := FFrameBufferSize;
        P := TopChunk.Size;
        if P > BufferFreeSize then P := BufferFreeSize;
        FFrameBuffer.Write(TopChunk.Memory^, P);
        TopChunk.Position := P;
        if TopChunk.Empty then
          FChunks.PopValue.Free;
        FFrameBufferSize := FFrameBuffer.Position;
      end;

      FFrameBuffer.Position := BP;
      case FFrameState of
        fstWaitingStartOfFrame:
        begin
          FFrameSize := 0;
          if (FFrameBufferSize - BP) >= WEBCAM_FRAME_HEADER_SIZE then
          begin
            FFrameBuffer.Read(W, SizeOf(Word));
            if W = WEBCAM_FRAME_START_SEQ then
            begin
              FFrameBuffer.Read(C, SizeOf(Cardinal));
              if C > (WEBCAM_FRAME_BUFFER_SIZE - WEBCAM_FRAME_HEADER_SIZE) then
              begin
                DoError(ERR_WEBCAM_STREAM_FRAME_TO_BIG);
                Exit;
              end else
              begin
                FFrameSize := C;
                FFrameState := fstWaitingData;
              end;
            end else
            begin
              DoError(ERR_WEBCAM_STREAM_WRONG_HEADER);
              Exit;
            end;
          end else
          begin
            TruncateFrameBuffer;
            if ChunkCount = 0 then
              Exit;
          end;
        end;

        fstWaitingData:
        begin
          if (FFrameBufferSize - BP) >= (FFrameSize + WEBCAM_FRAME_HEADER_SIZE) then
          begin
            PushFrame(BP);
            Inc(BP, FFrameSize + WEBCAM_FRAME_HEADER_SIZE);
            FFrameState := fstWaitingStartOfFrame;
          end else
          begin
            TruncateFrameBuffer;
            if ChunkCount = 0 then
              Exit;
          end;
        end;
      end;
    end;
  finally
    UnLock;
  end;
end;

function TWCRESTWebCamStream.GetCompletedFrame(lstFrame : QWord) : TWCRESTWebCamStreamFrame;
begin
  if FrameID > lstFrame then
  begin
    Result := TWCRESTWebCamStreamFrame(FFrames.GetActualFrame(lstFrame));
    if assigned(Result) then
      Result.IncReference;
  end else
    Result := nil;
end;

procedure TWCRESTWebCamStream.DoError(aCode : Cardinal);
begin
  Lock;
  try
    FErrorCode := aCode;
  finally
    UnLock;
  end;
end;

procedure TWCRESTWebCamStream.DoIdle;
begin
  FFrames.CleanDead;
end;

{ TWCRESTWebCamStreams }

function OnWebCamStreamsKeyCompare(Item1, Item2: Pointer): Integer;
begin
  Result := CompareValue(PCardinal(Item1)^, TWCRESTWebCamStream(Item2).Key);;
end;

function TWCRESTWebCamStreams.IsStrmClosed(aStrm: TObject; {%H-}data: pointer): Boolean;
begin
  Result := TWCRESTWebCamStream(aStrm).HTTP2Stream.StreamState in [h2ssCLOSED,
                                                                   h2ssHLFCLOSEDRem,
                                                                   h2ssHLFCLOSEDLoc];
end;

function TWCRESTWebCamStreams.IsSessionClosed(aStrm : TObject; data : pointer
  ) : Boolean;
begin
  Result := TFastMapUInt(data).Value[TWCRESTWebCamStream(aStrm).Key] > 0;
end;

function TWCRESTWebCamStreams.IsStrmSID(aStrm : TObject; data : pointer
  ) : Boolean;
begin
  Result := TWCRESTWebCamStream(aStrm).Key = PCardinal(data)^;
end;

procedure TWCRESTWebCamStreams.AfterStrmExtract(aStrm : TObject);
begin
  RemoveStreamFromTable(TWCRESTWebCamStream(aStrm).Key);
end;

procedure TWCRESTWebCamStreams.DoRemoveClosedStreams;
begin
  ExtractObjectsByCriteria(@IsStrmClosed, @AfterStrmExtract, nil);
end;

procedure TWCRESTWebCamStreams.RemoveClosedSessions(ids : TFastMapUInt);
begin
  ExtractObjectsByCriteria(@IsSessionClosed, @AfterStrmExtract, ids);
end;

procedure TWCRESTWebCamStreams.DoIdleStreams;
begin
  DoForAll(@IdleStream);
end;

procedure TWCRESTWebCamStreams.IdleStream(obj : TObject);
begin
  TWCRESTWebCamStream(obj).DoIdle;
end;

procedure TWCRESTWebCamStreams.FillSSIDMap(obj : TObject; data : Pointer);
begin
   TFastMapUInt(data).AddKeySorted(TWCRESTWebCamStream(obj).Key, 0);
end;

function TWCRESTWebCamStreams.RemoveStreamFromTable(aKey : Cardinal
  ) : TWCRESTWebCamStream;
var R : TAvgLvlTreeNode;
begin
  Lock;
  try
    R := FStreamTable.FindKey(@aKey,
                              @OnWebCamStreamsKeyCompare);
    if not assigned(R) then Exit(nil);
    Result := TWCRESTWebCamStream(R.Data);
    FStreamTable.FreeAndDelete(R);
  finally
    UnLock;
  end;
end;

function TWCRESTWebCamStreams.OnCompareMethod(Tree : TAvgLvlTree; Data1,
  Data2 : Pointer) : integer;
begin
  Result := CompareValue(TWCRESTWebCamStream(Data1).Key,
                           TWCRESTWebCamStream(Data2).Key);
end;

constructor TWCRESTWebCamStreams.Create;
begin
  inherited Create;
  FStreamTable := TAvgLvlTree.CreateObjectCompare(@OnCompareMethod);
  FStreamTable.OwnsObjects := true;
end;

destructor TWCRESTWebCamStreams.Destroy;
begin
  Finalize;
  inherited Destroy;
end;

function TWCRESTWebCamStreams.AddStream(aRef : TWCHTTP2Stream; aSID : Cardinal
  ) : TWCRESTWebCamStream;
begin
  Lock;
  try
    Result := TWCRESTWebCamStream.Create(aRef, aSID);

    FStreamTable.Add( Result );
    Push_back( Result );
  finally
    UnLock;
  end;
end;

procedure TWCRESTWebCamStreams.RemoveStream(aSID : Cardinal);
begin
  ExtractObjectsByCriteria(@IsStrmSID, @AfterStrmExtract, @aSID);
end;

function TWCRESTWebCamStreams.MapSSIDs : TFastMapUInt;
begin
  Result := TFastMapUInt.Create;
  Result.Sorted := true;
  DoForAllEx(@FillSSIDMap, Result);
end;

function TWCRESTWebCamStreams.Stream(aSID : Cardinal) : TWCRESTWebCamStream;
var R : TAvgLvlTreeNode;
begin
  Lock;
  try
    R := FStreamTable.FindKey(@aSID, @OnWebCamStreamsKeyCompare);
    if not assigned(R) then Exit(nil);
    Result := TWCRESTWebCamStream(R.Data);
  finally
    UnLock;
  end;
end;

procedure TWCRESTWebCamStreams.Finalize;
begin
  ExtractAll;
  if assigned(FStreamTable) then FreeAndNil(FStreamTable);
end;

procedure TWCRESTWebCamStreams.DoIdle;
begin
  DoRemoveClosedStreams;
  DoIdleStreams;
end;

end.

