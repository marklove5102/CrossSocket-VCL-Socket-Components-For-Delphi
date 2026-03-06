unit CrossSocket.Client;

interface

uses
  Classes,
  SysUtils,
  ExtCtrls,
  Math,
  TypInfo,
  // Actual Cross Socket units
  Net.CrossSocket,
  Net.CrossSocket.Base,
  Net.SocketAPI;

type
  TCrossSocketConnectionState = (
    csUnknown,
    csConnecting,
    csHandshaking,
    csConnected,
    csDisconnecting,
    csDisconnected,
    csClosed,
    csError
  );

  TCrossSocketReconnectStrategy = (rsLinear, rsExponential);

  // **Receive buffer for message reassembly**
  TReceiveBuffer = record
    Buffer: TBytes;
    ExpectedLength: Integer;
    CurrentLength: Integer;
    HeaderReceived: Boolean;
  end;

  // Event types
  TCrossSocketConnectEvent = procedure(Sender: TObject) of object;
  TCrossSocketDataReceivedEvent = procedure(Sender: TObject; const Data: TBytes) of object;
  TCrossSocketDataSentEvent = procedure(Sender: TObject; const Data: TBytes) of object;
  TCrossSocketDisconnectEvent = procedure(Sender: TObject) of object;
  TCrossSocketErrorEvent = procedure(Sender: TObject; const ErrorMsg: string) of object;
  TCrossSocketHandleCommandEvent = procedure(Sender: TObject; ClientID: Int64; const aCmd: Int64; const aData: TBytes) of object;

  TCrossSocketStateChangeEvent = procedure(Sender: TObject;
    OldState, NewState: TCrossSocketConnectionState;
    const StateDescription: string) of object;

  TCrossSocketReconnectingEvent = procedure(Sender: TObject; AttemptNumber: Integer) of object;
  TCrossSocketReconnectFailedEvent = procedure(Sender: TObject; AttemptNumber: Integer; const ErrorMsg: string) of object;

  /// Cross Socket Client Component - WITH MESSAGE FRAMING AND COMMAND ID!
  TCrossSocketClient = class(TComponent)
  private
    // Core Cross Socket objects
    fCrossSocket: ICrossSocket;
    fConnection: ICrossConnection;

    // Connection properties
    fHost: string;
    fPort: Integer;
    fURI: string;
    fConnected: Boolean;
    fConnecting: Boolean;
    fLastError: string;
    fCurrentState: TCrossSocketConnectionState;

    // **Message framing**
    fUseMessageFraming: Boolean;
    fMaxMessageSize: Integer;
    fReceiveBuffer: TReceiveBuffer;

    // Additional properties
    fActive: Boolean;
    fConnectionTimeout: Integer;
    fDescription: string;
    fKeepAlive: Boolean;
    fLogLevel: Integer;
    fMessageReceived: Boolean;
    fMessageSent: Boolean;
    fName: string;
    fNoDelay: Boolean;
    fReceiveBufferSize: Integer;
    fReconnectStrategy: TCrossSocketReconnectStrategy;
    fSendBufferSize: Integer;
    fThreadPoolSize: Integer;
    fTotalBytesReceived: Int64;
    fTotalBytesSent: Int64;
    fVersion: string;

    // Reconnection properties
    fAutoReconnect: Boolean;
    fReconnectInterval: Integer;
    fReconnectTimer: TTimer;
    fReconnectAttempts: Integer;
    fMaxReconnectAttempts: Integer;
    fReconnecting: Boolean;
    fUserDisconnected: Boolean;
    fReconnectState: Boolean;

    // EVENTS
    fOnConnect: TCrossSocketConnectEvent;
    fOnDataReceived: TCrossSocketDataReceivedEvent;
    fOnDataSent: TCrossSocketDataSentEvent;
    fOnDisconnect: TCrossSocketDisconnectEvent;
    fOnError: TCrossSocketErrorEvent;
    fOnHandleCommand: TCrossSocketHandleCommandEvent;
    fOnStateChange: TCrossSocketStateChangeEvent;
    fOnReconnecting: TCrossSocketReconnectingEvent;
    fOnReconnectFailed: TCrossSocketReconnectFailedEvent;

    fInConnectEvent: Boolean;
    fInDisconnectEvent: Boolean;
    fInDataSentEvent: Boolean;

    // **Message framing helpers**
    function CreateMessageFrame(const aCmd: Int64; const Data: TBytes): TBytes;
    procedure ProcessReceivedData(const Data: TBytes);
    procedure ResetReceiveBuffer;

    // Property setters
    procedure SetActive(const Value: Boolean);
    procedure SetConnectionTimeout(const Value: Integer);
    procedure SetDescription(const Value: string);
    procedure SetKeepAlive(const Value: Boolean);
    procedure SetLogLevel(const Value: Integer);
    procedure SetName(const Value: string);
    procedure SetNoDelay(const Value: Boolean);
    procedure SetReceiveBufferSize(const Value: Integer);
    procedure SetReconnectStrategy(const Value: TCrossSocketReconnectStrategy);
    procedure SetSendBufferSize(const Value: Integer);
    procedure SetThreadPoolSize(const Value: Integer);
    procedure SetVersion(const Value: string);
    procedure SetConnected(const Value: Boolean);
    procedure SetHost(const Value: string);
    procedure SetPort(const Value: Integer);
    procedure SetURI(const Value: string);
    procedure SetAutoReconnect(const Value: Boolean);
    procedure SetReconnectInterval(const Value: Integer);
    procedure SetMaxReconnectAttempts(const Value: Integer);
    procedure SetUseMessageFraming(const Value: Boolean);
    procedure SetMaxMessageSize(const Value: Integer);

    function GetConnectionStateDescription: string;

    procedure DoError(const ErrorMsg: string);
    procedure DoDataReceived(const Data: TBytes);
    procedure DoDataSent(const Data: TBytes);
    procedure DoHandleCommand(const aCmd: Int64; const aData: TBytes);
    procedure DoConnect;
    procedure DoDisconnect;
    procedure DoStateChange(NewState: TCrossSocketConnectionState);
    procedure OnReconnectTimer(Sender: TObject);
    procedure StartReconnectTimer;
    procedure StopReconnectTimer;
    procedure DoReconnecting(AttemptNumber: Integer);
    procedure DoReconnectFailed(AttemptNumber: Integer; const ErrorMsg: string);
    procedure UpdateBytesReceived(const Bytes: Int64);
    procedure UpdateBytesSent(const Bytes: Int64);

    // Cross Socket event handlers
    procedure OnCrossSocketConnected(const Sender: TObject; const AConnection: ICrossConnection);
    procedure OnCrossSocketDisconnected(const Sender: TObject; const AConnection: ICrossConnection);
    procedure OnCrossSocketReceived(const Sender: TObject; const AConnection: ICrossConnection; const ABuf: Pointer; const ALen: Integer);
    procedure OnCrossSocketSent(const Sender: TObject; const AConnection: ICrossConnection; const ABuf: Pointer; const ALen: Integer);

  protected
    procedure InternalConnect;
    procedure InternalDisconnect;
    procedure HandleUnexpectedDisconnection;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Connect: Boolean;
    function ConnectSync: Boolean;
    procedure Disconnect;
    function SendCommand(const aCmd: Int64; const aData: TBytes): Boolean;
    function IsConnected: Boolean;
    function IsConnecting: Boolean;
    function IsReconnecting: Boolean;
    function GetLastError: string;
    function GetReconnectAttempts: Integer;
    procedure ResetReconnectAttempts;
    function GetTotalBytesReceived: Int64;
    function GetTotalBytesSent: Int64;
    procedure ResetByteCounters;
    function GetServerIP: string;
    function GetConnectionStateAsString: string;

  published
    property Active: Boolean read fActive write SetActive default False;
    property Host: string read fHost write SetHost;
    property Port: Integer read fPort write SetPort default 80;
    property URI: string read fURI write SetURI;
    property Connected: Boolean read fConnected write SetConnected default False;
    property ConnectionTimeout: Integer read fConnectionTimeout write SetConnectionTimeout default 30000;
    property Description: string read fDescription write SetDescription;

    // **Message framing properties**
    property UseMessageFraming: Boolean read fUseMessageFraming write SetUseMessageFraming default True;
    property MaxMessageSize: Integer read fMaxMessageSize write SetMaxMessageSize default 104857600; // 100MB default

    property KeepAlive: Boolean read fKeepAlive write SetKeepAlive default True;
    property LogLevel: Integer read fLogLevel write SetLogLevel default 1;
    property Name: string read fName write SetName;
    property NoDelay: Boolean read fNoDelay write SetNoDelay default True;
    property ReceiveBufferSize: Integer read fReceiveBufferSize write SetReceiveBufferSize default 8192;
    property ThreadPoolSize: Integer read fThreadPoolSize write SetThreadPoolSize default 4;
    property Version: string read fVersion write SetVersion;
    property SendBufferSize: Integer read fSendBufferSize write SetSendBufferSize default 8192;

    property Connecting: Boolean read fConnecting;
    property AutoReconnect: Boolean read fAutoReconnect write SetAutoReconnect default False;
    property ReconnectInterval: Integer read fReconnectInterval write SetReconnectInterval default 5000;
    property MaxReconnectAttempts: Integer read fMaxReconnectAttempts write SetMaxReconnectAttempts default 0;
    property ReconnectStrategy: TCrossSocketReconnectStrategy read fReconnectStrategy write SetReconnectStrategy default rsLinear;
    property Reconnecting: Boolean read fReconnecting;
    property MessageReceived: Boolean read fMessageReceived;
    property MessageSent: Boolean read fMessageSent;
    property TotalBytesReceived: Int64 read fTotalBytesReceived;
    property TotalBytesSent: Int64 read fTotalBytesSent;
    property ConnectionState: TCrossSocketConnectionState read fCurrentState;
    property ConnectionStateDescription: string read GetConnectionStateDescription;

    // EVENTS
    property OnConnect: TCrossSocketConnectEvent read fOnConnect write fOnConnect;
    property OnDataReceived: TCrossSocketDataReceivedEvent read fOnDataReceived write fOnDataReceived;
    property OnDataSent: TCrossSocketDataSentEvent read fOnDataSent write fOnDataSent;
    property OnDisconnect: TCrossSocketDisconnectEvent read fOnDisconnect write fOnDisconnect;
    property OnError: TCrossSocketErrorEvent read fOnError write fOnError;
    property OnHandleCommand: TCrossSocketHandleCommandEvent read fOnHandleCommand write fOnHandleCommand;
    property OnStateChange: TCrossSocketStateChangeEvent read fOnStateChange write fOnStateChange;
    property OnReconnecting: TCrossSocketReconnectingEvent read fOnReconnecting write fOnReconnecting;
    property OnReconnectFailed: TCrossSocketReconnectFailedEvent read fOnReconnectFailed write fOnReconnectFailed;
  end;

procedure Register;

implementation

const
  MESSAGE_HEADER_SIZE = 4; // 4 bytes for message length
  COMMAND_ID_SIZE = 8;     // 8 bytes for command ID (Int64)

{ TCrossSocketClient }

constructor TCrossSocketClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fInConnectEvent := False;
  fInDisconnectEvent := False;
  fInDataSentEvent := False;

  // Initialize connection properties
  fHost := 'localhost';
  fPort := 80;
  fURI := '/';
  fConnected := False;
  fConnecting := False;
  fConnection := nil;
  fCurrentState := csUnknown;

  // **Message framing defaults**
  fUseMessageFraming := True;
  fMaxMessageSize := 104857600; // 100MB
  ResetReceiveBuffer;

  // Initialize properties
  fActive := False;
  fConnectionTimeout := 30000;
  fDescription := 'Cross Socket Client Component - WITH MESSAGE FRAMING & COMMAND ID';
  fKeepAlive := True;
  fLogLevel := 1;
  fName := 'CrossClient1';
  fNoDelay := True;
  fReceiveBufferSize := 8192;
  fSendBufferSize := 8192;
  fThreadPoolSize := 4;
  fVersion := '2.1.0'; // Version bump for command ID
  fMessageReceived := False;
  fMessageSent := False;
  fTotalBytesReceived := 0;
  fTotalBytesSent := 0;

  // Initialize reconnection
  fAutoReconnect := False;
  fReconnectInterval := 5000;
  fMaxReconnectAttempts := 0;
  fReconnectAttempts := 0;
  fReconnectStrategy := rsLinear;
  fReconnecting := False;
  fReconnectState := False;
  fUserDisconnected := False;

  fReconnectTimer := TTimer.Create(Self);
  fReconnectTimer.Enabled := False;
  fReconnectTimer.OnTimer := OnReconnectTimer;

  // Create Cross Socket instance
  fCrossSocket := TCrossSocket.Create(fThreadPoolSize);
  fCrossSocket.OnConnected := OnCrossSocketConnected;
  fCrossSocket.OnDisconnected := OnCrossSocketDisconnected;
  fCrossSocket.OnReceived := OnCrossSocketReceived;
  fCrossSocket.OnSent := OnCrossSocketSent;
end;

destructor TCrossSocketClient.Destroy;
begin
  try
    try
      StopReconnectTimer;
    except
    end;

    if fConnected or fConnecting then
    begin
      try
        InternalDisconnect;
      except
        fConnected := False;
        fConnecting := False;
        fReconnecting := False;
        fReconnectState := False;
      end;
    end;

    if fCrossSocket <> nil then
    begin
      try
        fCrossSocket.StopLoop;
        fCrossSocket := nil;
      except
        fCrossSocket := nil;
      end;
    end;

  except
    fCrossSocket := nil;
    fConnection := nil;
  end;

  inherited Destroy;
end;

// =============================================================================
// **MESSAGE FRAMING WITH COMMAND ID IMPLEMENTATION**
// =============================================================================

procedure TCrossSocketClient.ResetReceiveBuffer;
begin
  SetLength(fReceiveBuffer.Buffer, 0);
  fReceiveBuffer.ExpectedLength := 0;
  fReceiveBuffer.CurrentLength := 0;
  fReceiveBuffer.HeaderReceived := False;
end;

function TCrossSocketClient.CreateMessageFrame(const aCmd: Int64; const Data: TBytes): TBytes;
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

procedure TCrossSocketClient.ProcessReceivedData(const Data: TBytes);
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

    DoHandleCommand(cmdID, cmdData);
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

        // Fire OnHandleCommand with cmdID and data
        DoHandleCommand(cmdID, cmdData);

        // Continue processing remaining data
        Continue;
      end;
    end;
  end;
end;

// =============================================================================
// CONNECTION METHODS
// =============================================================================

function TCrossSocketClient.Connect: Boolean;
begin
  Result := False;
  if fConnected or fConnecting then
    Exit;

  try
    fUserDisconnected := False;
    fReconnectState := False;
    ResetReceiveBuffer;
    DoStateChange(csConnecting);
    InternalConnect;
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoStateChange(csClosed);
      DoError(E.Message);
    end;
  end;
end;

function TCrossSocketClient.ConnectSync: Boolean;
begin
  Result := Connect;
end;

procedure TCrossSocketClient.InternalConnect;
begin
  if fConnected then
    Exit;

  try
    fConnecting := True;
    fConnected := False;

    fCrossSocket.StartLoop;

    fCrossSocket.Connect(fHost, fPort,
      procedure(const AConnection: ICrossConnection; const ASuccess: Boolean)
      begin
        if ASuccess then
        begin
          fConnection := AConnection;
        end
        else
        begin
          fConnected := False;
          fConnecting := False;
          DoStateChange(csClosed);
          DoError('Connection failed');
          HandleUnexpectedDisconnection;
        end;
      end);

  except
    on E: Exception do
    begin
      fLastError := 'Connection failed: ' + E.Message;
      fConnecting := False;
      raise;
    end;
  end;
end;

procedure TCrossSocketClient.Disconnect;
begin
  fUserDisconnected := True;
  fReconnectState := False;
  StopReconnectTimer;
  DoStateChange(csDisconnected);
  InternalDisconnect;
end;

procedure TCrossSocketClient.InternalDisconnect;
begin
  if not fConnected and not fConnecting then
    Exit;

  try
    fConnected := False;
    fConnecting := False;
    fReconnecting := False;
    ResetReceiveBuffer;

    if fConnection <> nil then
    begin
      try
        fConnection.Close;
      except
        fConnection := nil;
        if not fInDisconnectEvent then
          DoDisconnect;
      end;
    end
    else
    begin
      if not fInDisconnectEvent then
      begin
        DoStateChange(csDisconnected);
        DoDisconnect;
      end;
    end;

    if fCrossSocket <> nil then
    begin
      try
        fCrossSocket.StopLoop;
      except
      end;
    end;

  except
    on E: Exception do
    begin
      fLastError := 'Disconnect error: ' + E.Message;
      fConnection := nil;
      fConnected := False;
      fConnecting := False;
      fReconnecting := False;
      fReconnectState := False;
    end;
  end;
end;

// =============================================================================
// CROSS SOCKET EVENT HANDLERS
// =============================================================================

procedure TCrossSocketClient.OnCrossSocketConnected(const Sender: TObject; const AConnection: ICrossConnection);
begin
  if fInConnectEvent then
    Exit;

  fInConnectEvent := True;
  try
    fConnection := AConnection;
    fConnected := True;
    fConnecting := False;
    fReconnectAttempts := 0;
    fReconnecting := False;
    fReconnectState := False;
    StopReconnectTimer;
    ResetReceiveBuffer;
    DoStateChange(csConnected);
    DoConnect;
  finally
    fInConnectEvent := False;
  end;
end;

procedure TCrossSocketClient.OnCrossSocketDisconnected(const Sender: TObject; const AConnection: ICrossConnection);
begin
  if fInDisconnectEvent then
    Exit;

  fInDisconnectEvent := True;
  try
    if fConnected then
    begin
      fConnected := False;
      fConnection := nil;
      ResetReceiveBuffer;
      DoStateChange(csDisconnected);
      DoDisconnect;
      HandleUnexpectedDisconnection;
    end;
  finally
    fInDisconnectEvent := False;
  end;
end;

procedure TCrossSocketClient.OnCrossSocketReceived(const Sender: TObject; const AConnection: ICrossConnection; const ABuf: Pointer; const ALen: Integer);
var
  ReceivedData: TBytes;
begin
  SetLength(ReceivedData, ALen);
  if ALen > 0 then
    Move(ABuf^, ReceivedData[0], ALen);

  DoDataReceived(ReceivedData);

  // **Process with message framing**
  ProcessReceivedData(ReceivedData);
end;

procedure TCrossSocketClient.OnCrossSocketSent(const Sender: TObject; const AConnection: ICrossConnection; const ABuf: Pointer; const ALen: Integer);
var
  SentData: TBytes;
begin
  if fInDataSentEvent then
    Exit;

  fInDataSentEvent := True;
  try
    SetLength(SentData, ALen);
    if ALen > 0 then
      Move(ABuf^, SentData[0], ALen);

    DoDataSent(SentData);
  finally
    fInDataSentEvent := False;
  end;
end;

// =============================================================================
// SEND METHOD
// =============================================================================

function TCrossSocketClient.SendCommand(const aCmd: Int64; const aData: TBytes): Boolean;
var
  framedData: TBytes;
begin
  Result := False;
  if not IsConnected then
    Exit;

  try
    // **Apply message framing with cmdID**
    framedData := CreateMessageFrame(aCmd, aData);

    if fConnection <> nil then
    begin
      fConnection.SendBytes(framedData,
        procedure(const AConnection: ICrossConnection; const ASuccess: Boolean)
        begin
          if not ASuccess then
            DoError('Send failed');
        end);
      Result := True;
    end;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

// =============================================================================
// RECONNECTION LOGIC
// =============================================================================

procedure TCrossSocketClient.HandleUnexpectedDisconnection;
begin
  if fAutoReconnect and
     not fUserDisconnected and
     ((fMaxReconnectAttempts = 0) or (fReconnectAttempts < fMaxReconnectAttempts)) then
  begin
    fReconnecting := True;
    fReconnectState := True;
    DoStateChange(csConnecting);
    StartReconnectTimer;
  end;
end;

procedure TCrossSocketClient.StartReconnectTimer;
begin
  if fReconnectTimer <> nil then
  begin
    fReconnectTimer.Interval := fReconnectInterval;
    fReconnectTimer.Enabled := True;
  end;
end;

procedure TCrossSocketClient.StopReconnectTimer;
begin
  if fReconnectTimer <> nil then
    fReconnectTimer.Enabled := False;
end;

procedure TCrossSocketClient.OnReconnectTimer(Sender: TObject);
var
  actualInterval: Integer;
begin
  StopReconnectTimer;
  Inc(fReconnectAttempts);

  case fReconnectStrategy of
    rsLinear:
      actualInterval := fReconnectInterval;
    rsExponential:
      actualInterval := fReconnectInterval * (1 shl Min(fReconnectAttempts - 1, 10));
  else
    actualInterval := fReconnectInterval;
  end;

  if fReconnectTimer <> nil then
    fReconnectTimer.Interval := actualInterval;

  DoReconnecting(fReconnectAttempts);
  Connect;
end;

// =============================================================================
// STATE HELPER METHODS
// =============================================================================

function TCrossSocketClient.GetConnectionStateDescription: string;
begin
  case fCurrentState of
    csUnknown: Result := Format('Unknown state with %s:%d', [fHost, fPort]);
    csConnecting:
      begin
        if fReconnectState then
          Result := Format('Reconnecting to %s:%d%s (attempt %d)', [fHost, fPort, fURI, fReconnectAttempts + 1])
        else
          Result := Format('Connecting to %s:%d%s', [fHost, fPort, fURI]);
      end;
    csHandshaking: Result := Format('Handshaking with %s:%d%s', [fHost, fPort, fURI]);
    csConnected: Result := Format('Connected to %s:%d%s', [fHost, fPort, fURI]);
    csDisconnecting: Result := Format('Disconnecting from %s:%d', [fHost, fPort]);
    csDisconnected: Result := Format('Disconnected from %s:%d', [fHost, fPort]);
    csClosed: Result := Format('Connection closed with %s:%d - %s', [fHost, fPort, fLastError]);
    csError: Result := Format('Error with %s:%d - %s', [fHost, fPort, fLastError]);
  else
    Result := 'Unknown connection state';
  end;
end;

function TCrossSocketClient.GetConnectionStateAsString: string;
begin
  case fCurrentState of
    csUnknown: Result := 'Unknown';
    csConnecting: Result := 'Connecting';
    csHandshaking: Result := 'Handshaking';
    csConnected: Result := 'Connected';
    csDisconnecting: Result := 'Disconnecting';
    csDisconnected: Result := 'Disconnected';
    csClosed: Result := 'Closed';
    csError: Result := 'Error';
  else
    Result := 'Unknown';
  end;
end;

function TCrossSocketClient.GetServerIP: string;
begin
  if fHost = 'localhost' then
    Result := '127.0.0.1'
  else
    Result := fHost;
end;

// =============================================================================
// PROPERTY SETTERS
// =============================================================================

procedure TCrossSocketClient.SetActive(const Value: Boolean);
begin
  if fActive <> Value then
  begin
    fActive := Value;
    SetConnected(Value);
  end;
end;

procedure TCrossSocketClient.SetConnectionTimeout(const Value: Integer);
begin
  if Value >= 1000 then
    fConnectionTimeout := Value;
end;

procedure TCrossSocketClient.SetDescription(const Value: string);
begin
  fDescription := Value;
end;

procedure TCrossSocketClient.SetKeepAlive(const Value: Boolean);
begin
  fKeepAlive := Value;
end;

procedure TCrossSocketClient.SetLogLevel(const Value: Integer);
begin
  if (Value >= 0) and (Value <= 3) then
    fLogLevel := Value;
end;

procedure TCrossSocketClient.SetName(const Value: string);
begin
  if (Value <> '') and (Value <> Name) then
  begin
    inherited Name := Value;
    fName := Value;
  end;
end;

procedure TCrossSocketClient.SetNoDelay(const Value: Boolean);
begin
  fNoDelay := Value;
end;

procedure TCrossSocketClient.SetReceiveBufferSize(const Value: Integer);
begin
  if Value >= 1024 then
    fReceiveBufferSize := Value;
end;

procedure TCrossSocketClient.SetReconnectStrategy(const Value: TCrossSocketReconnectStrategy);
begin
  fReconnectStrategy := Value;
end;

procedure TCrossSocketClient.SetSendBufferSize(const Value: Integer);
begin
  if Value >= 1024 then
    fSendBufferSize := Value;
end;

procedure TCrossSocketClient.SetThreadPoolSize(const Value: Integer);
begin
  if Value >= 1 then
    fThreadPoolSize := Value;
end;

procedure TCrossSocketClient.SetVersion(const Value: string);
begin
  fVersion := Value;
end;

procedure TCrossSocketClient.SetConnected(const Value: Boolean);
begin
  if fConnected <> Value then
  begin
    if Value then
      Connect
    else
      Disconnect;
  end;
end;

procedure TCrossSocketClient.SetHost(const Value: string);
begin
  if fHost <> Value then
  begin
    if not (fConnected or fConnecting) then
      fHost := Value;
  end;
end;

procedure TCrossSocketClient.SetPort(const Value: Integer);
begin
  if fPort <> Value then
  begin
    if not (fConnected or fConnecting) then
      fPort := Value;
  end;
end;

procedure TCrossSocketClient.SetURI(const Value: string);
begin
  if fURI <> Value then
  begin
    if not (fConnected or fConnecting) then
      fURI := Value;
  end;
end;

procedure TCrossSocketClient.SetAutoReconnect(const Value: Boolean);
begin
  if fAutoReconnect <> Value then
  begin
    fAutoReconnect := Value;
    if not Value then
      StopReconnectTimer;
  end;
end;

procedure TCrossSocketClient.SetReconnectInterval(const Value: Integer);
begin
  if Value >= 1000 then
  begin
    fReconnectInterval := Value;
    if fReconnectTimer.Enabled then
      fReconnectTimer.Interval := fReconnectInterval;
  end;
end;

procedure TCrossSocketClient.SetMaxReconnectAttempts(const Value: Integer);
begin
  if Value >= 0 then
    fMaxReconnectAttempts := Value;
end;

procedure TCrossSocketClient.SetUseMessageFraming(const Value: Boolean);
begin
  if fConnected or fConnecting then
    raise Exception.Create('Cannot change UseMessageFraming while connected');
  fUseMessageFraming := Value;
  ResetReceiveBuffer;
end;

procedure TCrossSocketClient.SetMaxMessageSize(const Value: Integer);
begin
  if Value < 1024 then
    raise Exception.Create('MaxMessageSize must be at least 1024 bytes');
  fMaxMessageSize := Value;
end;

// =============================================================================
// STATISTICS METHODS
// =============================================================================

procedure TCrossSocketClient.UpdateBytesReceived(const Bytes: Int64);
begin
  Inc(fTotalBytesReceived, Bytes);
  fMessageReceived := True;
end;

procedure TCrossSocketClient.UpdateBytesSent(const Bytes: Int64);
begin
  Inc(fTotalBytesSent, Bytes);
  fMessageSent := True;
end;

function TCrossSocketClient.GetTotalBytesReceived: Int64;
begin
  Result := fTotalBytesReceived;
end;

function TCrossSocketClient.GetTotalBytesSent: Int64;
begin
  Result := fTotalBytesSent;
end;

procedure TCrossSocketClient.ResetByteCounters;
begin
  fTotalBytesReceived := 0;
  fTotalBytesSent := 0;
  fMessageReceived := False;
  fMessageSent := False;
end;

// =============================================================================
// STATUS METHODS
// =============================================================================

function TCrossSocketClient.IsConnected: Boolean;
begin
  Result := fConnected and (fConnection <> nil);
end;

function TCrossSocketClient.IsConnecting: Boolean;
begin
  Result := fConnecting;
end;

function TCrossSocketClient.IsReconnecting: Boolean;
begin
  Result := fReconnecting and fReconnectState;
end;

function TCrossSocketClient.GetLastError: string;
begin
  Result := fLastError;
end;

function TCrossSocketClient.GetReconnectAttempts: Integer;
begin
  Result := fReconnectAttempts;
end;

procedure TCrossSocketClient.ResetReconnectAttempts;
begin
  fReconnectAttempts := 0;
end;

// =============================================================================
// EVENT METHODS
// =============================================================================

procedure TCrossSocketClient.DoError(const ErrorMsg: string);
begin
  if Assigned(fOnError) then
    fOnError(Self, ErrorMsg);
end;

procedure TCrossSocketClient.DoDataReceived(const Data: TBytes);
begin
  UpdateBytesReceived(Length(Data));
  if Assigned(fOnDataReceived) then
    fOnDataReceived(Self, Data);
end;

procedure TCrossSocketClient.DoDataSent(const Data: TBytes);
begin
  UpdateBytesSent(Length(Data));
  if Assigned(fOnDataSent) then
    fOnDataSent(Self, Data);
end;

procedure TCrossSocketClient.DoHandleCommand(const aCmd: Int64; const aData: TBytes);
begin
  if Assigned(fOnHandleCommand) then
    fOnHandleCommand(Self, 0, aCmd, aData); // ClientID = 0 for client-side
end;

procedure TCrossSocketClient.DoConnect;
begin
  if Assigned(fOnConnect) then
    fOnConnect(Self);
end;

procedure TCrossSocketClient.DoDisconnect;
begin
  if Assigned(fOnDisconnect) then
    fOnDisconnect(Self);
end;

procedure TCrossSocketClient.DoStateChange(NewState: TCrossSocketConnectionState);
var
  OldState: TCrossSocketConnectionState;
begin
  OldState := fCurrentState;
  if OldState <> NewState then
  begin
    fCurrentState := NewState;
    if Assigned(fOnStateChange) then
      fOnStateChange(Self, OldState, NewState, GetConnectionStateDescription);
  end;
end;

procedure TCrossSocketClient.DoReconnecting(AttemptNumber: Integer);
begin
  if Assigned(fOnReconnecting) then
    fOnReconnecting(Self, AttemptNumber);
end;

procedure TCrossSocketClient.DoReconnectFailed(AttemptNumber: Integer; const ErrorMsg: string);
begin
  if Assigned(fOnReconnectFailed) then
    fOnReconnectFailed(Self, AttemptNumber, ErrorMsg);
end;

procedure Register;
begin
  RegisterComponents('Cross Socket', [TCrossSocketClient]);
end;

end.
