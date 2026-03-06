unit CrossSocket.WebSocket.Server;

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  SyncObjs,
  // Actual Cross Socket WebSocket units ONLY
  Net.CrossWebSocketServer,
  Net.CrossWebSocketParser,
  Net.CrossSocket.Base;

type
  ICrossWebSocketConnection = Net.CrossWebSocketServer.ICrossWebSocketConnection;
  ICrossWebSocketServer = Net.CrossWebSocketServer.ICrossWebSocketServer;
  TWsMessageType = Net.CrossWebSocketParser.TWsMessageType;

  TCrossWebSocketServerState = (
    ssIdle,
    ssListening,
    ssError
  );

  // **Receive buffer for message reassembly**
  TReceiveBuffer = record
    Buffer: TBytes;
    ExpectedLength: Integer;
    CurrentLength: Integer;
    HeaderReceived: Boolean;
  end;

  TCrossWebSocketClientConnectedEvent = procedure(Sender: TObject; ClientID: Int64; ClientConnection: ICrossWebSocketConnection) of object;
  TCrossWebSocketClientDisconnectedEvent = procedure(Sender: TObject; ClientID: Int64; ClientConnection: ICrossWebSocketConnection) of object;
  TCrossWebSocketErrorEvent = procedure(Sender: TObject; const ErrorMsg: string) of object;
  TCrossWebSocketServerHandleMessageEvent = procedure(Sender: TObject; ClientID: Int64; ClientConnection: ICrossWebSocketConnection; const aCmd: Int64; const aData: TBytes) of object;

  TClientConnectionInfo = record
    ClientID: Int64;
    Connection: ICrossWebSocketConnection;
    ReceiveBuffer: TReceiveBuffer;
  end;

  /// WebSocket Server WITH MESSAGE FRAMING AND COMMAND ID!
  TCrossSocketWebSocketServer = class(TComponent)
  private
    fWebSocketServer: ICrossWebSocketServer;
    fConnections: TList<TClientConnectionInfo>;
    fClientLookup: TDictionary<Int64, ICrossWebSocketConnection>;
    fConnectionToClientID: TDictionary<ICrossWebSocketConnection, Int64>;
    fConnectionsLock: TCriticalSection;

    fPort: Integer;
    fActive: Boolean;
    fLastError: string;
    fIoThreads: Integer;
    fBindInterface: string;
    fServerState: TCrossWebSocketServerState;

    // **Message framing**
    fUseMessageFraming: Boolean;
    fMaxMessageSize: Integer;

    fClientCount: Integer;
    fNextClientID: Int64;

    fOnClientConnected: TCrossWebSocketClientConnectedEvent;
    fOnClientDisconnected: TCrossWebSocketClientDisconnectedEvent;
    fOnError: TCrossWebSocketErrorEvent;
    fOnHandleMessage: TCrossWebSocketServerHandleMessageEvent;

    procedure SetActive(const Value: Boolean);
    procedure SetPort(const Value: Integer);
    procedure SetIoThreads(const Value: Integer);
    procedure SetBindInterface(const Value: string);
    procedure SetUseMessageFraming(const Value: Boolean);
    procedure SetMaxMessageSize(const Value: Integer);

    procedure DoError(const ErrorMsg: string);
    function GenerateClientID: Int64;
    function AddConnection(const Connection: ICrossWebSocketConnection): Int64;
    procedure RemoveConnection(const Connection: ICrossWebSocketConnection);
    function FindClientID(const Connection: ICrossWebSocketConnection): Int64;

    // **Message framing helpers**
    function CreateMessageFrame(const aCmd: Int64; const Data: TBytes): TBytes;
    procedure ProcessReceivedData(ClientID: Int64; const Data: TBytes);
    procedure ResetReceiveBuffer(var Buffer: TReceiveBuffer);

  protected
    procedure InternalStart;
    procedure InternalStop;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Start: Boolean;
    procedure Stop;
    function SendCommandToClient(ClientID: Int64; const aCmd: Int64; const aData: TBytes): Boolean;
    procedure BroadcastCommand(const aCmd: Int64; const aData: TBytes);
    function GetClientIDs: TArray<Int64>;
    function IsClientConnected(ClientID: Int64): Boolean;
    function GetClientConnection(ClientID: Int64): ICrossWebSocketConnection;
    function IsActive: Boolean;
    function GetLastError: string;
    function GetClientCount: Integer;
    function GetConnectionCount: Integer;

  published
    property Port: Integer read fPort write SetPort default 8080;
    property Active: Boolean read fActive write SetActive default False;
    property IoThreads: Integer read fIoThreads write SetIoThreads default 64;
    property BindInterface: string read fBindInterface write SetBindInterface;

    // **Message framing properties**
    property UseMessageFraming: Boolean read fUseMessageFraming write SetUseMessageFraming default True;
    property MaxMessageSize: Integer read fMaxMessageSize write SetMaxMessageSize default 104857600; // 100MB

    property ServerState: TCrossWebSocketServerState read fServerState;
    property ClientCount: Integer read fClientCount;
    property ConnectionCount: Integer read GetConnectionCount;

    property OnClientConnected: TCrossWebSocketClientConnectedEvent read fOnClientConnected write fOnClientConnected;
    property OnClientDisconnected: TCrossWebSocketClientDisconnectedEvent read fOnClientDisconnected write fOnClientDisconnected;
    property OnError: TCrossWebSocketErrorEvent read fOnError write fOnError;
    property OnHandleMessage: TCrossWebSocketServerHandleMessageEvent read fOnHandleMessage write fOnHandleMessage;
  end;

procedure Register;

implementation

uses
  Windows;

const
  MESSAGE_HEADER_SIZE = 4; // 4 bytes for message length
  COMMAND_ID_SIZE = 8;     // 8 bytes for command ID (Int64)

{ TCrossSocketWebSocketServer }

constructor TCrossSocketWebSocketServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fPort := 8080;
  fActive := False;
  fClientCount := 0;
  fNextClientID := 1;
  fIoThreads := 64;
  fBindInterface := '0.0.0.0';
  fServerState := ssIdle;

  // **Message framing defaults**
  fUseMessageFraming := True;
  fMaxMessageSize := 104857600; // 100MB

  fConnections := TList<TClientConnectionInfo>.Create;
  fClientLookup := TDictionary<Int64, ICrossWebSocketConnection>.Create;
  fConnectionToClientID := TDictionary<ICrossWebSocketConnection, Int64>.Create;
  fConnectionsLock := TCriticalSection.Create;

  fWebSocketServer := TCrossWebSocketServer.Create(fIoThreads, False);

  fWebSocketServer
    .OnOpen(
      procedure(const AConnection: ICrossWebSocketConnection)
      var
        ClientID: Int64;
      begin
        ClientID := AddConnection(AConnection);
        InterlockedIncrement(fClientCount);

        if Assigned(fOnClientConnected) then
          fOnClientConnected(Self, ClientID, AConnection);
      end)
    .OnMessage(
      procedure(const AConnection: ICrossWebSocketConnection; const ARequestType: TWsMessageType; const ARequestData: TBytes)
      var
        ClientID: Int64;
      begin
        ClientID := FindClientID(AConnection);
        if ClientID > 0 then
          ProcessReceivedData(ClientID, ARequestData);
      end)
    .OnClose(
      procedure(const AConnection: ICrossWebSocketConnection)
      var
        ClientID: Int64;
      begin
        ClientID := FindClientID(AConnection);
        RemoveConnection(AConnection);
        InterlockedDecrement(fClientCount);

        if fClientCount < 0 then
          fClientCount := 0;

        if Assigned(fOnClientDisconnected) then
          fOnClientDisconnected(Self, ClientID, AConnection);
      end);
end;

destructor TCrossSocketWebSocketServer.Destroy;
begin
  try
    if fActive then
      InternalStop;

    if fWebSocketServer <> nil then
    begin
      try
        fWebSocketServer.Stop;
        fWebSocketServer := nil;
      except
        fWebSocketServer := nil;
      end;
    end;

    if fConnectionsLock <> nil then
    begin
      fConnectionsLock.Enter;
      try
        if fConnections <> nil then
        begin
          fConnections.Clear;
          FreeAndNil(fConnections);
        end;
        if fClientLookup <> nil then
        begin
          fClientLookup.Clear;
          FreeAndNil(fClientLookup);
        end;
        if fConnectionToClientID <> nil then
        begin
          fConnectionToClientID.Clear;
          FreeAndNil(fConnectionToClientID);
        end;
      finally
        fConnectionsLock.Leave;
      end;
      FreeAndNil(fConnectionsLock);
    end;
  except
  end;
  inherited Destroy;
end;

// =============================================================================
// **MESSAGE FRAMING WITH COMMAND ID IMPLEMENTATION**
// =============================================================================

procedure TCrossSocketWebSocketServer.ResetReceiveBuffer(var Buffer: TReceiveBuffer);
begin
  SetLength(Buffer.Buffer, 0);
  Buffer.ExpectedLength := 0;
  Buffer.CurrentLength := 0;
  Buffer.HeaderReceived := False;
end;

function TCrossSocketWebSocketServer.CreateMessageFrame(const aCmd: Int64; const Data: TBytes): TBytes;
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

procedure TCrossSocketWebSocketServer.ProcessReceivedData(ClientID: Int64; const Data: TBytes);
var
  clientInfo: TClientConnectionInfo;
  dataOffset: Integer;
  bytesToCopy: Integer;
  completeMessage: TBytes;
  expectedLen: Cardinal;
  cmdID: Int64;
  cmdData: TBytes;
  I: Integer;
  found: Boolean;
begin
  if not fUseMessageFraming then
  begin
    // No framing - extract cmdID and data directly
    if Length(Data) < COMMAND_ID_SIZE then
    begin
      DoError(Format('Client #%d sent message too short - missing command ID', [ClientID]));
      Exit;
    end;

    cmdID := PInt64(@Data[0])^;
    SetLength(cmdData, Length(Data) - COMMAND_ID_SIZE);
    if Length(cmdData) > 0 then
      Move(Data[COMMAND_ID_SIZE], cmdData[0], Length(cmdData));

    if Assigned(fOnHandleMessage) then
    begin
      fConnectionsLock.Enter;
      try
        if fClientLookup.TryGetValue(ClientID, clientInfo.Connection) then
          fOnHandleMessage(Self, ClientID, clientInfo.Connection, cmdID, cmdData);
      finally
        fConnectionsLock.Leave;
      end;
    end;
    Exit;
  end;

  fConnectionsLock.Enter;
  try
    found := False;
    for I := 0 to fConnections.Count - 1 do
    begin
      if fConnections[I].ClientID = ClientID then
      begin
        clientInfo := fConnections[I];
        found := True;
        Break;
      end;
    end;

    if not found then
      Exit;

    dataOffset := 0;

    while dataOffset < Length(Data) do
    begin
      // Step 1: Read header if not received yet
      if not clientInfo.ReceiveBuffer.HeaderReceived then
      begin
        bytesToCopy := MESSAGE_HEADER_SIZE - clientInfo.ReceiveBuffer.CurrentLength;
        if bytesToCopy > (Length(Data) - dataOffset) then
          bytesToCopy := Length(Data) - dataOffset;

        if Length(clientInfo.ReceiveBuffer.Buffer) < MESSAGE_HEADER_SIZE then
          SetLength(clientInfo.ReceiveBuffer.Buffer, MESSAGE_HEADER_SIZE);

        Move(Data[dataOffset], clientInfo.ReceiveBuffer.Buffer[clientInfo.ReceiveBuffer.CurrentLength], bytesToCopy);
        Inc(clientInfo.ReceiveBuffer.CurrentLength, bytesToCopy);
        Inc(dataOffset, bytesToCopy);

        // Check if header complete
        if clientInfo.ReceiveBuffer.CurrentLength = MESSAGE_HEADER_SIZE then
        begin
          expectedLen := PCardinal(@clientInfo.ReceiveBuffer.Buffer[0])^;

          // Validate message size (must be at least cmdID size)
          if (expectedLen < COMMAND_ID_SIZE) or (expectedLen > Cardinal(fMaxMessageSize)) then
          begin
            DoError(Format('Client #%d sent invalid message size: %d bytes', [ClientID, expectedLen]));
            ResetReceiveBuffer(clientInfo.ReceiveBuffer);
            for I := 0 to fConnections.Count - 1 do
            begin
              if fConnections[I].ClientID = ClientID then
              begin
                fConnections[I] := clientInfo;
                Break;
              end;
            end;
            Exit;
          end;

          clientInfo.ReceiveBuffer.HeaderReceived := True;
          clientInfo.ReceiveBuffer.ExpectedLength := expectedLen;
          clientInfo.ReceiveBuffer.CurrentLength := 0;
          SetLength(clientInfo.ReceiveBuffer.Buffer, expectedLen);
        end;
      end
      // Step 2: Read message body
      else
      begin
        bytesToCopy := clientInfo.ReceiveBuffer.ExpectedLength - clientInfo.ReceiveBuffer.CurrentLength;
        if bytesToCopy > (Length(Data) - dataOffset) then
          bytesToCopy := Length(Data) - dataOffset;

        Move(Data[dataOffset], clientInfo.ReceiveBuffer.Buffer[clientInfo.ReceiveBuffer.CurrentLength], bytesToCopy);
        Inc(clientInfo.ReceiveBuffer.CurrentLength, bytesToCopy);
        Inc(dataOffset, bytesToCopy);

        // Check if message complete
        if clientInfo.ReceiveBuffer.CurrentLength = clientInfo.ReceiveBuffer.ExpectedLength then
        begin
          // Extract complete message
          SetLength(completeMessage, clientInfo.ReceiveBuffer.ExpectedLength);
          Move(clientInfo.ReceiveBuffer.Buffer[0], completeMessage[0], clientInfo.ReceiveBuffer.ExpectedLength);

          // Reset buffer for next message
          ResetReceiveBuffer(clientInfo.ReceiveBuffer);

          // Update client info
          for I := 0 to fConnections.Count - 1 do
          begin
            if fConnections[I].ClientID = ClientID then
            begin
              fConnections[I] := clientInfo;
              Break;
            end;
          end;

          // Extract cmdID (first 8 bytes)
          cmdID := PInt64(@completeMessage[0])^;

          // Extract data (remaining bytes)
          SetLength(cmdData, Length(completeMessage) - COMMAND_ID_SIZE);
          if Length(cmdData) > 0 then
            Move(completeMessage[COMMAND_ID_SIZE], cmdData[0], Length(cmdData));

          // Fire OnHandleMessage with ClientID, cmdID and data
          if Assigned(fOnHandleMessage) then
            fOnHandleMessage(Self, ClientID, clientInfo.Connection, cmdID, cmdData);

          // Continue processing remaining data
          Continue;
        end;
      end;
    end;

    // Save updated buffer state
    for I := 0 to fConnections.Count - 1 do
    begin
      if fConnections[I].ClientID = ClientID then
      begin
        fConnections[I] := clientInfo;
        Break;
      end;
    end;

  finally
    fConnectionsLock.Leave;
  end;
end;

// =============================================================================
// CLIENT ID MANAGEMENT
// =============================================================================

function TCrossSocketWebSocketServer.GenerateClientID: Int64;
begin
  Result := InterlockedIncrement64(fNextClientID);
end;

function TCrossSocketWebSocketServer.FindClientID(const Connection: ICrossWebSocketConnection): Int64;
begin
  Result := 0;
  if (Connection = nil) or (fConnectionToClientID = nil) then
    Exit;

  fConnectionsLock.Enter;
  try
    if not fConnectionToClientID.TryGetValue(Connection, Result) then
      Result := 0;
  finally
    fConnectionsLock.Leave;
  end;
end;

// =============================================================================
// CONNECTION MANAGEMENT
// =============================================================================

function TCrossSocketWebSocketServer.AddConnection(const Connection: ICrossWebSocketConnection): Int64;
var
  ClientInfo: TClientConnectionInfo;
begin
  Result := 0;
  if (Connection = nil) or (fConnections = nil) then
    Exit;

  fConnectionsLock.Enter;
  try
    if fConnectionToClientID.TryGetValue(Connection, Result) then
      Exit;

    Result := GenerateClientID;

    ClientInfo.ClientID := Result;
    ClientInfo.Connection := Connection;
    ResetReceiveBuffer(ClientInfo.ReceiveBuffer);

    fConnections.Add(ClientInfo);
    fClientLookup.Add(Result, Connection);
    fConnectionToClientID.Add(Connection, Result);
  finally
    fConnectionsLock.Leave;
  end;
end;

procedure TCrossSocketWebSocketServer.RemoveConnection(const Connection: ICrossWebSocketConnection);
var
  I: Integer;
  ClientID: Int64;
begin
  if (Connection = nil) or (fConnections = nil) then
    Exit;

  fConnectionsLock.Enter;
  try
    if fConnectionToClientID.TryGetValue(Connection, ClientID) then
    begin
      fConnectionToClientID.Remove(Connection);

      if fClientLookup.ContainsKey(ClientID) then
        fClientLookup.Remove(ClientID);

      for I := fConnections.Count - 1 downto 0 do
      begin
        if fConnections[I].Connection = Connection then
        begin
          fConnections.Delete(I);
          Break;
        end;
      end;
    end;
  finally
    fConnectionsLock.Leave;
  end;
end;

// =============================================================================
// CORE METHODS
// =============================================================================

function TCrossSocketWebSocketServer.Start: Boolean;
begin
  Result := False;
  try
    InternalStart;
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

procedure TCrossSocketWebSocketServer.InternalStart;
begin
  if fActive then
    Exit;

  try
    fServerState := ssListening;
    fLastError := '';
    fClientCount := 0;
    fNextClientID := 0;

    fConnectionsLock.Enter;
    try
      fConnections.Clear;
      fClientLookup.Clear;
      fConnectionToClientID.Clear;
    finally
      fConnectionsLock.Leave;
    end;

    fWebSocketServer.Addr := fBindInterface;
    fWebSocketServer.Port := fPort;
    fWebSocketServer.Start;

    fActive := True;

  except
    on E: Exception do
    begin
      fLastError := E.Message;
      fServerState := ssError;
      fActive := False;
      raise;
    end;
  end;
end;

procedure TCrossSocketWebSocketServer.Stop;
begin
  InternalStop;
end;

procedure TCrossSocketWebSocketServer.InternalStop;
begin
  if not fActive then
    Exit;

  fActive := False;

  if fWebSocketServer <> nil then
  begin
    try
      fWebSocketServer.Stop;
    except
    end;
  end;

  fConnectionsLock.Enter;
  try
    fConnections.Clear;
    fClientLookup.Clear;
    fConnectionToClientID.Clear;
  finally
    fConnectionsLock.Leave;
  end;

  fClientCount := 0;
  fNextClientID := 0;
  fServerState := ssIdle;
end;

// =============================================================================
// SEND METHODS
// =============================================================================

function TCrossSocketWebSocketServer.SendCommandToClient(ClientID: Int64; const aCmd: Int64; const aData: TBytes): Boolean;
begin
  Result := True;
  if (fWebSocketServer = nil) or not fActive or (ClientID = 0) then
  begin
    Result := False;
    Exit;
  end;

  try
    TThread.CreateAnonymousThread(
      procedure
      var
        Connection: ICrossWebSocketConnection;
        framedData: TBytes;
      begin
        fConnectionsLock.Enter;
        try
          if fClientLookup.TryGetValue(ClientID, Connection) then
          begin
            if Connection <> nil then
            begin
              try
                framedData := CreateMessageFrame(aCmd, aData);
                Connection.WsSend(framedData);
              except
                on E: Exception do
                begin
                  fLastError := E.Message;
                  DoError('Send to client #' + IntToStr(ClientID) + ' failed: ' + E.Message);
                end;
              end;
            end;
          end;
        finally
          fConnectionsLock.Leave;
        end;
      end).Start;
  except
    Result := False;
  end;
end;

procedure TCrossSocketWebSocketServer.BroadcastCommand(const aCmd: Int64; const aData: TBytes);
begin
  if (fWebSocketServer = nil) or not fActive or (fConnections = nil) then
    Exit;

  try
    TThread.CreateAnonymousThread(
      procedure
      var
        ConnectionsCopy: TArray<ICrossWebSocketConnection>;
        Connection: ICrossWebSocketConnection;
        framedData: TBytes;
        I: Integer;
      begin
        framedData := CreateMessageFrame(aCmd, aData);

        fConnectionsLock.Enter;
        try
          SetLength(ConnectionsCopy, fConnections.Count);
          for I := 0 to fConnections.Count - 1 do
            ConnectionsCopy[I] := fConnections[I].Connection;
        finally
          fConnectionsLock.Leave;
        end;

        for Connection in ConnectionsCopy do
        begin
          if Connection <> nil then
          begin
            try
              Connection.WsSend(framedData);
            except
            end;
          end;
        end;
      end).Start;
  except
  end;
end;

// =============================================================================
// CLIENT MANAGEMENT
// =============================================================================

function TCrossSocketWebSocketServer.GetClientIDs: TArray<Int64>;
var
  I: Integer;
begin
  if fConnections = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  fConnectionsLock.Enter;
  try
    SetLength(Result, fConnections.Count);
    for I := 0 to fConnections.Count - 1 do
      Result[I] := fConnections[I].ClientID;
  finally
    fConnectionsLock.Leave;
  end;
end;

function TCrossSocketWebSocketServer.IsClientConnected(ClientID: Int64): Boolean;
begin
  if (fClientLookup = nil) or (ClientID = 0) then
  begin
    Result := False;
    Exit;
  end;

  fConnectionsLock.Enter;
  try
    Result := fClientLookup.ContainsKey(ClientID);
  finally
    fConnectionsLock.Leave;
  end;
end;

function TCrossSocketWebSocketServer.GetClientConnection(ClientID: Int64): ICrossWebSocketConnection;
begin
  Result := nil;
  if (fClientLookup = nil) or (ClientID = 0) then
    Exit;

  fConnectionsLock.Enter;
  try
    fClientLookup.TryGetValue(ClientID, Result);
  finally
    fConnectionsLock.Leave;
  end;
end;

// =============================================================================
// UTILITY METHODS
// =============================================================================

function TCrossSocketWebSocketServer.IsActive: Boolean;
begin
  Result := fActive and (fWebSocketServer <> nil);
end;

function TCrossSocketWebSocketServer.GetLastError: string;
begin
  Result := fLastError;
end;

function TCrossSocketWebSocketServer.GetClientCount: Integer;
begin
  Result := fClientCount;
end;

function TCrossSocketWebSocketServer.GetConnectionCount: Integer;
begin
  if fConnections = nil then
  begin
    Result := 0;
    Exit;
  end;

  fConnectionsLock.Enter;
  try
    Result := fConnections.Count;
  finally
    fConnectionsLock.Leave;
  end;
end;

// =============================================================================
// PROPERTY SETTERS
// =============================================================================

procedure TCrossSocketWebSocketServer.SetActive(const Value: Boolean);
begin
  if fActive <> Value then
  begin
    if Value then
      Start
    else
      Stop;
  end;
end;

procedure TCrossSocketWebSocketServer.SetPort(const Value: Integer);
begin
  if fPort <> Value then
  begin
    if fActive then
      raise Exception.Create('Cannot change Port while server is active');
    fPort := Value;
  end;
end;

procedure TCrossSocketWebSocketServer.SetIoThreads(const Value: Integer);
begin
  if fIoThreads <> Value then
  begin
    if fActive then
      raise Exception.Create('Cannot change IoThreads while server is active');
    if Value > 0 then
      fIoThreads := Value;
  end;
end;

procedure TCrossSocketWebSocketServer.SetBindInterface(const Value: string);
begin
  fBindInterface := Value;
end;

procedure TCrossSocketWebSocketServer.SetUseMessageFraming(const Value: Boolean);
begin
  if fActive then
    raise Exception.Create('Cannot change UseMessageFraming while server is active');
  fUseMessageFraming := Value;
end;

procedure TCrossSocketWebSocketServer.SetMaxMessageSize(const Value: Integer);
begin
  if Value < 1024 then
    raise Exception.Create('MaxMessageSize must be at least 1024 bytes');
  fMaxMessageSize := Value;
end;

procedure TCrossSocketWebSocketServer.DoError(const ErrorMsg: string);
begin
  if Assigned(fOnError) then
    fOnError(Self, ErrorMsg);
end;

procedure Register;
begin
  RegisterComponents('Cross Socket', [TCrossSocketWebSocketServer]);
end;

end.
