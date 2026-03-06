unit CrossSocket.WebSocket.Client;

interface

uses
  Classes,
  SysUtils,
  Math,
  TypInfo,
  // Actual Cross Socket WebSocket units
  Net.CrossWebSocketClient,
  Net.CrossWebSocketParser,
  Net.CrossSocket.Base,
  // Our WebSocket base types
  CrossSocket.WebSocket.Base;

type
  ICrossWebSocket = Net.CrossWebSocketClient.ICrossWebSocket;
  ICrossWebSocketMgr = Net.CrossWebSocketClient.ICrossWebSocketMgr;
  TWsMessageType = Net.CrossWebSocketParser.TWsMessageType;
  TCrossWebSocketStatus = CrossSocket.WebSocket.Base.TCrossWebSocketStatus;

  // **Receive buffer for message reassembly**
  TReceiveBuffer = record
    Buffer: TBytes;
    ExpectedLength: Integer;
    CurrentLength: Integer;
    HeaderReceived: Boolean;
  end;

  TCrossWebSocketConnectEvent = procedure(Sender: TObject) of object;
  TCrossWebSocketDisconnectEvent = procedure(Sender: TObject) of object;
  TCrossWebSocketErrorEvent = procedure(Sender: TObject; const ErrorMsg: string) of object;
  TCrossWebSocketHandleMessageEvent = procedure(Sender: TObject; ClientID: Int64; const aCmd: Int64; const aData: TBytes) of object;

  /// WebSocket Client WITH MESSAGE FRAMING AND COMMAND ID!
  TCrossSocketWebSocketClient = class(TComponent)
  private
    fWebSocket: ICrossWebSocket;
    fWebSocketMgr: ICrossWebSocketMgr;

    fUrl: string;
    fConnected: Boolean;
    fConnecting: Boolean;
    fLastError: string;
    fCurrentStatus: TCrossWebSocketStatus;

    // **Message framing**
    fUseMessageFraming: Boolean;
    fMaxMessageSize: Integer;
    fReceiveBuffer: TReceiveBuffer;

    fActive: Boolean;
    fMaskingKey: Cardinal;

    fAutoReconnect: Boolean;
    fReconnectInterval: Integer;
    fReconnectAttempts: Integer;
    fMaxReconnectAttempts: Integer;
    fReconnecting: Boolean;
    fUserDisconnected: Boolean;
    fLastReconnectTime: TDateTime;

    fOnConnect: TCrossWebSocketConnectEvent;
    fOnDisconnect: TCrossWebSocketDisconnectEvent;
    fOnError: TCrossWebSocketErrorEvent;
    fOnHandleMessage: TCrossWebSocketHandleMessageEvent;

    fInConnectEvent: Integer;
    fInDisconnectEvent: Integer;

    // **Message framing helpers**
    function CreateMessageFrame(const aCmd: Int64; const Data: TBytes): TBytes;
    procedure ProcessReceivedData(const Data: TBytes);
    procedure ResetReceiveBuffer;

    procedure SetActive(const Value: Boolean);
    procedure SetConnected(const Value: Boolean);
    procedure SetUrl(const Value: string);
    procedure SetAutoReconnect(const Value: Boolean);
    procedure SetReconnectInterval(const Value: Integer);
    procedure SetMaxReconnectAttempts(const Value: Integer);
    procedure SetMaskingKey(const Value: Cardinal);
    procedure SetUseMessageFraming(const Value: Boolean);
    procedure SetMaxMessageSize(const Value: Integer);

    procedure DoError(const ErrorMsg: string);
    procedure DoHandleMessage(const aCmd: Int64; const aData: TBytes);
    procedure DoConnect;
    procedure DoDisconnect;
    procedure HandleUnexpectedDisconnection;
    procedure AttemptReconnect;

  protected
    procedure InternalConnect;
    procedure InternalDisconnect;
    procedure InitializeDefaults;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Connect: Boolean;
    procedure Disconnect;
    function SendCommand(const aCmd: Int64; const aData: TBytes): Boolean;
    procedure Ping;
    function IsConnected: Boolean;
    function IsConnecting: Boolean;
    function IsReconnecting: Boolean;
    function GetLastError: string;
    function GetReconnectAttempts: Integer;
    procedure ResetReconnectAttempts;

  published
    property Active: Boolean read fActive write SetActive default False;
    property Url: string read fUrl write SetUrl;
    property Connected: Boolean read fConnected write SetConnected default False;
    property MaskingKey: Cardinal read fMaskingKey write SetMaskingKey default 0;

    // **Message framing properties**
    property UseMessageFraming: Boolean read fUseMessageFraming write SetUseMessageFraming default True;
    property MaxMessageSize: Integer read fMaxMessageSize write SetMaxMessageSize default 104857600; // 100MB

    property AutoReconnect: Boolean read fAutoReconnect write SetAutoReconnect default False;
    property ReconnectInterval: Integer read fReconnectInterval write SetReconnectInterval default 5000;
    property MaxReconnectAttempts: Integer read fMaxReconnectAttempts write SetMaxReconnectAttempts default 0;

    property Connecting: Boolean read fConnecting;
    property Reconnecting: Boolean read fReconnecting;
    property Status: TCrossWebSocketStatus read fCurrentStatus;

    property OnConnect: TCrossWebSocketConnectEvent read fOnConnect write fOnConnect;
    property OnDisconnect: TCrossWebSocketDisconnectEvent read fOnDisconnect write fOnDisconnect;
    property OnError: TCrossWebSocketErrorEvent read fOnError write fOnError;
    property OnHandleMessage: TCrossWebSocketHandleMessageEvent read fOnHandleMessage write fOnHandleMessage;
  end;

procedure Register;

implementation

uses
  Windows,
  DateUtils;

const
  MESSAGE_HEADER_SIZE = 4; // 4 bytes for message length
  COMMAND_ID_SIZE = 8;     // 8 bytes for command ID (Int64)

{ TCrossSocketWebSocketClient }

constructor TCrossSocketWebSocketClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fInConnectEvent := 0;
  fInDisconnectEvent := 0;

  InitializeDefaults;

  fWebSocketMgr := TCrossWebSocketMgr.Create(1);
end;

procedure TCrossSocketWebSocketClient.InitializeDefaults;
begin
  fUrl := 'ws://localhost:8080';
  fConnected := False;
  fConnecting := False;
  fCurrentStatus := wsUnknown;
  fActive := False;
  fMaskingKey := 0;

  // **Message framing defaults**
  fUseMessageFraming := True;
  fMaxMessageSize := 104857600; // 100MB
  ResetReceiveBuffer;

  fAutoReconnect := False;
  fReconnectInterval := 5000;
  fMaxReconnectAttempts := 0;
  fReconnectAttempts := 0;
  fReconnecting := False;
  fUserDisconnected := False;
  fLastReconnectTime := 0;
end;

destructor TCrossSocketWebSocketClient.Destroy;
begin
  try
    if fConnected or fConnecting then
    begin
      try
        InternalDisconnect;
      except
        fConnected := False;
        fConnecting := False;
        fReconnecting := False;
      end;
    end;

    if fWebSocket <> nil then
    begin
      try
        fWebSocket.Close;
        fWebSocket := nil;
      except
        fWebSocket := nil;
      end;
    end;

    if fWebSocketMgr <> nil then
    begin
      try
        fWebSocketMgr.CancelAll;
        fWebSocketMgr := nil;
      except
        fWebSocketMgr := nil;
      end;
    end;

  except
    fWebSocket := nil;
    fWebSocketMgr := nil;
  end;

  inherited Destroy;
end;

// =============================================================================
// **MESSAGE FRAMING WITH COMMAND ID IMPLEMENTATION**
// =============================================================================

procedure TCrossSocketWebSocketClient.ResetReceiveBuffer;
begin
  SetLength(fReceiveBuffer.Buffer, 0);
  fReceiveBuffer.ExpectedLength := 0;
  fReceiveBuffer.CurrentLength := 0;
  fReceiveBuffer.HeaderReceived := False;
end;

function TCrossSocketWebSocketClient.CreateMessageFrame(const aCmd: Int64; const Data: TBytes): TBytes;
var
  DataLen: Cardinal;
  TotalLen: Cardinal;
begin
  if not fUseMessageFraming then
  begin
    // Without framing, just send cmdID + data
    SetLength(Result, COMMAND_ID_SIZE + Length(Data));
    PInt64(@Result[0])^ := aCmd;
    if Length(Data) > 0 then
      Move(Data[0], Result[COMMAND_ID_SIZE], Length(Data));
    Exit;
  end;

  // Calculate total payload size (cmdID + data)
  DataLen := COMMAND_ID_SIZE + Length(Data);
  TotalLen := MESSAGE_HEADER_SIZE + DataLen;

  SetLength(Result, TotalLen);

  // Write length header (4 bytes, little-endian) - total payload size
  PCardinal(@Result[0])^ := DataLen;

  // Write command ID (8 bytes)
  PInt64(@Result[MESSAGE_HEADER_SIZE])^ := aCmd;

  // Copy data
  if Length(Data) > 0 then
    Move(Data[0], Result[MESSAGE_HEADER_SIZE + COMMAND_ID_SIZE], Length(Data));
end;

procedure TCrossSocketWebSocketClient.ProcessReceivedData(const Data: TBytes);
var
  dataOffset: Integer;
  bytesToCopy: Integer;
  completeMessage: TBytes;
  expectedLen: Cardinal;
  cmdID: Int64;
  cmdData: TBytes;
begin
  if not fUseMessageFraming then
  begin
    // No framing - extract cmdID and data directly
    if Length(Data) < COMMAND_ID_SIZE then
    begin
      DoError('Message too short - missing command ID');
      Exit;
    end;

    cmdID := PInt64(@Data[0])^;
    SetLength(cmdData, Length(Data) - COMMAND_ID_SIZE);
    if Length(cmdData) > 0 then
      Move(Data[COMMAND_ID_SIZE], cmdData[0], Length(cmdData));

    DoHandleMessage(cmdID, cmdData);
    Exit;
  end;

  dataOffset := 0;

  while dataOffset < Length(Data) do
  begin
    // Step 1: Read header if not received yet
    if not fReceiveBuffer.HeaderReceived then
    begin
      bytesToCopy := MESSAGE_HEADER_SIZE - fReceiveBuffer.CurrentLength;
      if bytesToCopy > (Length(Data) - dataOffset) then
        bytesToCopy := Length(Data) - dataOffset;

      if Length(fReceiveBuffer.Buffer) < MESSAGE_HEADER_SIZE then
        SetLength(fReceiveBuffer.Buffer, MESSAGE_HEADER_SIZE);

      Move(Data[dataOffset], fReceiveBuffer.Buffer[fReceiveBuffer.CurrentLength], bytesToCopy);
      Inc(fReceiveBuffer.CurrentLength, bytesToCopy);
      Inc(dataOffset, bytesToCopy);

      // Check if header complete
      if fReceiveBuffer.CurrentLength = MESSAGE_HEADER_SIZE then
      begin
        expectedLen := PCardinal(@fReceiveBuffer.Buffer[0])^;

        // Validate message size (must be at least cmdID size)
        if (expectedLen < COMMAND_ID_SIZE) or (expectedLen > Cardinal(fMaxMessageSize)) then
        begin
          DoError(Format('Server sent invalid message size: %d bytes', [expectedLen]));
          ResetReceiveBuffer;
          Exit;
        end;

        fReceiveBuffer.HeaderReceived := True;
        fReceiveBuffer.ExpectedLength := expectedLen;
        fReceiveBuffer.CurrentLength := 0;
        SetLength(fReceiveBuffer.Buffer, expectedLen);
      end;
    end
    // Step 2: Read message body
    else
    begin
      bytesToCopy := fReceiveBuffer.ExpectedLength - fReceiveBuffer.CurrentLength;
      if bytesToCopy > (Length(Data) - dataOffset) then
        bytesToCopy := Length(Data) - dataOffset;

      Move(Data[dataOffset], fReceiveBuffer.Buffer[fReceiveBuffer.CurrentLength], bytesToCopy);
      Inc(fReceiveBuffer.CurrentLength, bytesToCopy);
      Inc(dataOffset, bytesToCopy);

      // Check if message complete
      if fReceiveBuffer.CurrentLength = fReceiveBuffer.ExpectedLength then
      begin
        // Extract complete message
        SetLength(completeMessage, fReceiveBuffer.ExpectedLength);
        Move(fReceiveBuffer.Buffer[0], completeMessage[0], fReceiveBuffer.ExpectedLength);

        // Reset buffer for next message
        ResetReceiveBuffer;

        // Extract cmdID (first 8 bytes)
        cmdID := PInt64(@completeMessage[0])^;

        // Extract data (remaining bytes)
        SetLength(cmdData, Length(completeMessage) - COMMAND_ID_SIZE);
        if Length(cmdData) > 0 then
          Move(completeMessage[COMMAND_ID_SIZE], cmdData[0], Length(cmdData));

        // Fire OnHandleMessage with cmdID and data
        DoHandleMessage(cmdID, cmdData);

        // Continue processing remaining data
        Continue;
      end;
    end;
  end;
end;

// =============================================================================
// CONNECTION METHODS
// =============================================================================

function TCrossSocketWebSocketClient.Connect: Boolean;
begin
  Result := False;
  if fConnected or fConnecting then
    Exit;

  try
    fUserDisconnected := False;
    fCurrentStatus := wsConnecting;
    ResetReceiveBuffer;
    InternalConnect;
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      fCurrentStatus := wsDisconnected;
      DoError(E.Message);
    end;
  end;
end;

procedure TCrossSocketWebSocketClient.InternalConnect;
begin
  if fConnected then
    Exit;

  try
    fConnecting := True;
    fConnected := False;

    fWebSocket := fWebSocketMgr.CreateWebSocket(fUrl);

    if fMaskingKey <> 0 then
      fWebSocket.MaskingKey := fMaskingKey;

    fWebSocket
      .OnOpen(
        procedure
        begin
          if InterlockedExchange(fInConnectEvent, 1) = 1 then
            Exit;

          try
            fConnected := True;
            fConnecting := False;
            fReconnectAttempts := 0;
            fReconnecting := False;
            fCurrentStatus := wsConnected;
            ResetReceiveBuffer;
            DoConnect;
          finally
            InterlockedExchange(fInConnectEvent, 0);
          end;
        end)
      .OnMessage(
        procedure(const AMessageType: TWsMessageType; const AMessageData: TBytes)
        begin
          // **Process with message framing**
          ProcessReceivedData(AMessageData);
        end)
      .OnClose(
        procedure
        begin
          if InterlockedExchange(fInDisconnectEvent, 1) = 1 then
            Exit;

          try
            if fConnected then
            begin
              fConnected := False;
              fConnecting := False;
              fCurrentStatus := wsDisconnected;
              ResetReceiveBuffer;
              DoDisconnect;
              HandleUnexpectedDisconnection;
            end;
          finally
            InterlockedExchange(fInDisconnectEvent, 0);
          end;
        end);

    fWebSocket.Open;

  except
    on E: Exception do
    begin
      fLastError := 'Connection failed: ' + E.Message;
      fConnecting := False;
      raise;
    end;
  end;
end;

procedure TCrossSocketWebSocketClient.Disconnect;
begin
  fUserDisconnected := True;
  fCurrentStatus := wsDisconnected;
  InternalDisconnect;
end;

procedure TCrossSocketWebSocketClient.InternalDisconnect;
begin
  if not fConnected and not fConnecting then
    Exit;

  try
    fConnected := False;
    fConnecting := False;
    fReconnecting := False;
    ResetReceiveBuffer;

    if fWebSocket <> nil then
    begin
      try
        fWebSocket.Close;
      except
        fWebSocket := nil;
        if InterlockedExchange(fInDisconnectEvent, 1) = 0 then
        begin
          try
            DoDisconnect;
          finally
            InterlockedExchange(fInDisconnectEvent, 0);
          end;
        end;
      end;
    end
    else
    begin
      if InterlockedExchange(fInDisconnectEvent, 1) = 0 then
      begin
        try
          fCurrentStatus := wsDisconnected;
          DoDisconnect;
        finally
          InterlockedExchange(fInDisconnectEvent, 0);
        end;
      end;
    end;

  except
    on E: Exception do
    begin
      fLastError := 'Disconnect error: ' + E.Message;
      fWebSocket := nil;
      fConnected := False;
      fConnecting := False;
      fReconnecting := False;
    end;
  end;
end;

// =============================================================================
// SEND METHOD
// =============================================================================

function TCrossSocketWebSocketClient.SendCommand(const aCmd: Int64; const aData: TBytes): Boolean;
begin
  Result := True;
  if not IsConnected or (fWebSocket = nil) then
  begin
    Result := False;
    Exit;
  end;

  try
    TThread.CreateAnonymousThread(
      procedure
      var
        framedData: TBytes;
      begin
        try
          framedData := CreateMessageFrame(aCmd, aData);
          fWebSocket.Send(framedData);
        except
          on E: Exception do
          begin
            fLastError := E.Message;
            DoError('Send failed: ' + E.Message);
          end;
        end;
      end).Start;
  except
    Result := False;
  end;
end;

procedure TCrossSocketWebSocketClient.Ping;
begin
  if IsConnected and (fWebSocket <> nil) then
    fWebSocket.Ping;
end;

// =============================================================================
// RECONNECTION
// =============================================================================

procedure TCrossSocketWebSocketClient.HandleUnexpectedDisconnection;
begin
  if fAutoReconnect and
     not fUserDisconnected and
     ((fMaxReconnectAttempts = 0) or (fReconnectAttempts < fMaxReconnectAttempts)) then
  begin
    fReconnecting := True;
    fCurrentStatus := wsConnecting;

    TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(fReconnectInterval);
        AttemptReconnect;
      end).Start;
  end;
end;

procedure TCrossSocketWebSocketClient.AttemptReconnect;
begin
  if not fAutoReconnect or fUserDisconnected or fConnected then
    Exit;

  if (fLastReconnectTime > 0) and
     (MilliSecondsBetween(Now, fLastReconnectTime) < fReconnectInterval) then
    Exit;

  fLastReconnectTime := Now;
  Inc(fReconnectAttempts);

  try
    Connect;
  except
    on E: Exception do
    begin
      DoError('Reconnection failed: ' + E.Message);

      if (fMaxReconnectAttempts = 0) or (fReconnectAttempts < fMaxReconnectAttempts) then
      begin
        TThread.CreateAnonymousThread(
          procedure
          begin
            Sleep(fReconnectInterval);
            AttemptReconnect;
          end).Start;
      end
      else
      begin
        fReconnecting := False;
        fCurrentStatus := wsDisconnected;
      end;
    end;
  end;
end;

// =============================================================================
// PROPERTY SETTERS
// =============================================================================

procedure TCrossSocketWebSocketClient.SetActive(const Value: Boolean);
begin
  if fActive <> Value then
  begin
    fActive := Value;
    SetConnected(Value);
  end;
end;

procedure TCrossSocketWebSocketClient.SetConnected(const Value: Boolean);
begin
  if fConnected <> Value then
  begin
    if Value then
      Connect
    else
      Disconnect;
  end;
end;

procedure TCrossSocketWebSocketClient.SetUrl(const Value: string);
begin
  if fUrl <> Value then
  begin
    if not (fConnected or fConnecting) then
      fUrl := Value;
  end;
end;

procedure TCrossSocketWebSocketClient.SetAutoReconnect(const Value: Boolean);
begin
  fAutoReconnect := Value;
end;

procedure TCrossSocketWebSocketClient.SetReconnectInterval(const Value: Integer);
begin
  if Value >= 1000 then
    fReconnectInterval := Value;
end;

procedure TCrossSocketWebSocketClient.SetMaxReconnectAttempts(const Value: Integer);
begin
  if Value >= 0 then
    fMaxReconnectAttempts := Value;
end;

procedure TCrossSocketWebSocketClient.SetMaskingKey(const Value: Cardinal);
begin
  fMaskingKey := Value;
  if fWebSocket <> nil then
    fWebSocket.MaskingKey := Value;
end;

procedure TCrossSocketWebSocketClient.SetUseMessageFraming(const Value: Boolean);
begin
  if fConnected or fConnecting then
    raise Exception.Create('Cannot change UseMessageFraming while connected');
  fUseMessageFraming := Value;
  ResetReceiveBuffer;
end;

procedure TCrossSocketWebSocketClient.SetMaxMessageSize(const Value: Integer);
begin
  if Value < 1024 then
    raise Exception.Create('MaxMessageSize must be at least 1024 bytes');
  fMaxMessageSize := Value;
end;

// =============================================================================
// STATUS METHODS
// =============================================================================

function TCrossSocketWebSocketClient.IsConnected: Boolean;
begin
  Result := fConnected and (fWebSocket <> nil) and (fWebSocket.Status = Net.CrossWebSocketClient.wsConnected);
end;

function TCrossSocketWebSocketClient.IsConnecting: Boolean;
begin
  Result := fConnecting or (fCurrentStatus = wsConnecting);
end;

function TCrossSocketWebSocketClient.IsReconnecting: Boolean;
begin
  Result := fReconnecting;
end;

function TCrossSocketWebSocketClient.GetLastError: string;
begin
  Result := fLastError;
end;

function TCrossSocketWebSocketClient.GetReconnectAttempts: Integer;
begin
  Result := fReconnectAttempts;
end;

procedure TCrossSocketWebSocketClient.ResetReconnectAttempts;
begin
  fReconnectAttempts := 0;
end;

// =============================================================================
// EVENT METHODS
// =============================================================================

procedure TCrossSocketWebSocketClient.DoError(const ErrorMsg: string);
begin
  if Assigned(fOnError) then
    fOnError(Self, ErrorMsg);
end;

procedure TCrossSocketWebSocketClient.DoHandleMessage(const aCmd: Int64; const aData: TBytes);
begin
  if Assigned(fOnHandleMessage) then
    fOnHandleMessage(Self, 0, aCmd, aData); // ClientID = 0 for client-side
end;

procedure TCrossSocketWebSocketClient.DoConnect;
begin
  if Assigned(fOnConnect) then
    fOnConnect(Self);
end;

procedure TCrossSocketWebSocketClient.DoDisconnect;
begin
  if Assigned(fOnDisconnect) then
    fOnDisconnect(Self);
end;

procedure Register;
begin
  RegisterComponents('Cross Socket', [TCrossSocketWebSocketClient]);
end;

end.
