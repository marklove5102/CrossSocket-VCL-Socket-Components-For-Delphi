unit CrossUDP.Server;

interface

uses
  Windows,
  Classes,
  SysUtils,
  System.Generics.Collections,
  SyncObjs,
  WinSock2,
  CrossUDP.Base;

type
  TUDPListenerThread = class(TThread)
  private
    fServer: TObject;
    fSocket: TSocket;
    fTerminated: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AServer: TObject; ASocket: TSocket);
    procedure Terminate;
  end;

  TCrossUDPServer = class(TComponent)
  private
    fSocket: TSocket;
    fListenerThread: TUDPListenerThread;
    fPort: Integer;
    fBindInterface: string;
    fActive: Boolean;
    fCurrentState: TCrossUDPServerState;
    fLastError: string;
    fShuttingDown: Boolean;
    fClientMap: TDictionary<string, TUDPClientInfo>;
    fClientLock: TCriticalSection;
    fClientTimeout: Integer;
    fAutoRemoveInactiveClients: Boolean;
    fDescription: string;
    fName: string;
    fThreadPoolSize: Integer;
    fBufferSize: Integer;
    fVersion: string;
    fTotalPacketsReceived: Int64;
    fTotalPacketsSent: Int64;
    fTotalBytesReceived: Int64;
    fTotalBytesSent: Int64;
    fTotalClientsTracked: Int64;

    fOnDataReceived: TCrossUDPServerDataReceivedEvent;
    fOnDataSent: TCrossUDPServerDataSentEvent;
    fOnError: TCrossUDPErrorEvent;
    fOnHandleCommand: TCrossUDPServerHandleCommandEvent;
    fOnStateChange: TCrossUDPServerStateChangeEvent;
    fOnClientSeen: TCrossUDPClientSeenEvent;

    procedure SetActive(const Value: Boolean);
    procedure SetPort(const Value: Integer);
    procedure SetBindInterface(const Value: string);
    procedure SetDescription(const Value: string);
    procedure SetName(const Value: string);
    procedure SetThreadPoolSize(const Value: Integer);
    procedure SetBufferSize(const Value: Integer);
    procedure SetVersion(const Value: string);
    procedure SetClientTimeout(const Value: Integer);
    procedure SetAutoRemoveInactiveClients(const Value: Boolean);

    procedure DoError(const ErrorMsg: string);
    procedure DoDataReceived(const FromEndpoint: TUDPEndpoint; const Data: TBytes);
    procedure DoDataSent(const ToEndpoint: TUDPEndpoint; const Data: TBytes);
    procedure DoHandleCommand(const FromEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes);
    procedure DoStateChange(NewState: TCrossUDPServerState);
    procedure DoClientSeen(const ClientEndpoint: TUDPEndpoint; IsNew: Boolean);
    function GetStateDescription: string;
    function CreateCommandPacket(const aCmd: Int64; const aData: TBytes): TBytes;
    procedure ProcessReceivedPacket(const FromEndpoint: TUDPEndpoint; const Data: TBytes);
    procedure TrackClient(const Endpoint: TUDPEndpoint; BytesReceived: Int64);
    function EndpointKey(const Endpoint: TUDPEndpoint): string;

  protected
    procedure InternalStart;
    procedure InternalStop;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Start: Boolean;
    procedure Stop;
    function SendCommandTo(const ToEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes): Boolean;
    function SendBytesTo(const ToEndpoint: TUDPEndpoint; const aData: TBytes): Boolean;
    function BroadcastCommand(const aCmd: Int64; const aData: TBytes; APort: Integer): Boolean;
    function GetTrackedClientCount: Integer;
    function GetClientInfo(const Endpoint: TUDPEndpoint): TUDPClientInfo;
    function GetAllClientEndpoints: TArray<TUDPEndpoint>;
    procedure RemoveInactiveClients;
    procedure ClearAllClients;
    function IsActive: Boolean;
    function GetLastError: string;
    function GetStateAsString: string;
    function GetServerStats: string;
    procedure ResetStatistics;
    procedure HandleReceivedPacket(const FromIP: string; FromPort: Integer; const Data: TBytes; DataLen: Integer);

  published
    property Active: Boolean read fActive write SetActive default False;
    property Port: Integer read fPort write SetPort default 8888;
    property BindInterface: string read fBindInterface write SetBindInterface;
    property Description: string read fDescription write SetDescription;
    property Name: string read fName write SetName;
    property ThreadPoolSize: Integer read fThreadPoolSize write SetThreadPoolSize default 4;
    property BufferSize: Integer read fBufferSize write SetBufferSize default DEFAULT_UDP_BUFFER;
    property Version: string read fVersion write SetVersion;
    property ClientTimeout: Integer read fClientTimeout write SetClientTimeout default 300;
    property AutoRemoveInactiveClients: Boolean read fAutoRemoveInactiveClients write SetAutoRemoveInactiveClients default False;
    property TotalPacketsReceived: Int64 read fTotalPacketsReceived;
    property TotalPacketsSent: Int64 read fTotalPacketsSent;
    property TotalBytesReceived: Int64 read fTotalBytesReceived;
    property TotalBytesSent: Int64 read fTotalBytesSent;
    property TotalClientsTracked: Int64 read fTotalClientsTracked;
    property CurrentState: TCrossUDPServerState read fCurrentState;
    property StateDescription: string read GetStateDescription;
    property OnDataReceived: TCrossUDPServerDataReceivedEvent read fOnDataReceived write fOnDataReceived;
    property OnDataSent: TCrossUDPServerDataSentEvent read fOnDataSent write fOnDataSent;
    property OnError: TCrossUDPErrorEvent read fOnError write fOnError;
    property OnHandleCommand: TCrossUDPServerHandleCommandEvent read fOnHandleCommand write fOnHandleCommand;
    property OnStateChange: TCrossUDPServerStateChangeEvent read fOnStateChange write fOnStateChange;
    property OnClientSeen: TCrossUDPClientSeenEvent read fOnClientSeen write fOnClientSeen;
  end;

procedure Register;

implementation

uses
  DateUtils;

{ TUDPListenerThread }

constructor TUDPListenerThread.Create(AServer: TObject; ASocket: TSocket);
begin
  inherited Create(False);
  fServer := AServer;
  fSocket := ASocket;
  fTerminated := False;
  FreeOnTerminate := False;
end;

procedure TUDPListenerThread.Terminate;
begin
  fTerminated := True;
  inherited Terminate;
end;

procedure TUDPListenerThread.Execute;
var
  buffer: array[0..MAX_UDP_PACKET_SIZE-1] of Byte;
  addr: TSockAddrIn;
  addrLen: Integer;
  received: Integer;
  fromIP: string;
  receivedData: TBytes;
begin
  while not fTerminated do
  begin
    addrLen := SizeOf(addr);
    received := recvfrom(fSocket, buffer[0], SizeOf(buffer), 0, TSockAddr(addr), addrLen);

    if received = SOCKET_ERROR then
    begin
      if WSAGetLastError = WSAETIMEDOUT then
        Continue;
      if not fTerminated then
        Break;
    end;

    if received > 0 then
    begin
      fromIP := string(inet_ntoa(addr.sin_addr));
      SetLength(receivedData, received);
      Move(buffer[0], receivedData[0], received);
      Synchronize(procedure
      begin
        (fServer as TCrossUDPServer).HandleReceivedPacket(fromIP, ntohs(addr.sin_port), receivedData, received);
      end);
    end;
  end;
end;

{ TCrossUDPServer }

constructor TCrossUDPServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fSocket := INVALID_SOCKET;
  fListenerThread := nil;
  fPort := 8888;
  fBindInterface := '0.0.0.0';
  fActive := False;
  fCurrentState := usIdle;
  fShuttingDown := False;
  fDescription := 'CrossUDP Server Component - RAW SOCKETS';
  fName := 'CrossUDPServer1';
  fThreadPoolSize := 4;
  fBufferSize := DEFAULT_UDP_BUFFER;
  fVersion := '1.0.0';
  fClientTimeout := 300;
  fAutoRemoveInactiveClients := False;
  fClientMap := TDictionary<string, TUDPClientInfo>.Create;
  fClientLock := TCriticalSection.Create;
  fTotalPacketsReceived := 0;
  fTotalPacketsSent := 0;
  fTotalBytesReceived := 0;
  fTotalBytesSent := 0;
  fTotalClientsTracked := 0;
end;

destructor TCrossUDPServer.Destroy;
begin
  if fActive then
    InternalStop;
  FreeAndNil(fClientMap);
  FreeAndNil(fClientLock);
  inherited Destroy;
end;

function TCrossUDPServer.EndpointKey(const Endpoint: TUDPEndpoint): string;
begin
  Result := Endpoint.AsString;
end;

function TCrossUDPServer.CreateCommandPacket(const aCmd: Int64; const aData: TBytes): TBytes;
begin
  SetLength(Result, COMMAND_ID_SIZE + Length(aData));
  PInt64(@Result[0])^ := aCmd;
  if Length(aData) > 0 then
    Move(aData[0], Result[COMMAND_ID_SIZE], Length(aData));
end;

procedure TCrossUDPServer.ProcessReceivedPacket(const FromEndpoint: TUDPEndpoint; const Data: TBytes);
var
  cmdID: Int64;
  cmdData: TBytes;
begin
  if Length(Data) < COMMAND_ID_SIZE then
  begin
    DoError(Format('Received packet from %s too short - missing command ID', [FromEndpoint.AsString]));
    Exit;
  end;
  cmdID := PInt64(@Data[0])^;
  SetLength(cmdData, Length(Data) - COMMAND_ID_SIZE);
  if Length(cmdData) > 0 then
    Move(Data[COMMAND_ID_SIZE], cmdData[0], Length(cmdData));
  DoHandleCommand(FromEndpoint, cmdID, cmdData);
end;

procedure TCrossUDPServer.TrackClient(const Endpoint: TUDPEndpoint; BytesReceived: Int64);
var
  key: string;
  clientInfo: TUDPClientInfo;
  isNew: Boolean;
begin
  key := EndpointKey(Endpoint);
  isNew := False;
  fClientLock.Enter;
  try
    if not fClientMap.TryGetValue(key, clientInfo) then
    begin
      clientInfo.Endpoint := Endpoint;
      clientInfo.LastSeen := Now;
      clientInfo.TotalPacketsReceived := 0;
      clientInfo.TotalBytesSent := 0;
      clientInfo.TotalBytesReceived := 0;
      Inc(fTotalClientsTracked);
      isNew := True;
    end;
    clientInfo.LastSeen := Now;
    Inc(clientInfo.TotalPacketsReceived);
    Inc(clientInfo.TotalBytesReceived, BytesReceived);
    fClientMap.AddOrSetValue(key, clientInfo);
  finally
    fClientLock.Leave;
  end;
  DoClientSeen(Endpoint, isNew);
end;

procedure TCrossUDPServer.HandleReceivedPacket(const FromIP: string; FromPort: Integer; const Data: TBytes; DataLen: Integer);
var
  fromEndpoint: TUDPEndpoint;
begin
  fromEndpoint := TUDPEndpoint.Create(FromIP, FromPort);
  TrackClient(fromEndpoint, DataLen);
  Inc(fTotalPacketsReceived);
  Inc(fTotalBytesReceived, DataLen);
  DoDataReceived(fromEndpoint, Data);
  ProcessReceivedPacket(fromEndpoint, Data);
end;

procedure TCrossUDPServer.InternalStart;
var
  addr: TSockAddrIn;
  timeout: Integer;
begin
  if fActive then
    Exit;

  try
    DoStateChange(usStarting);

    fSocket := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if fSocket = INVALID_SOCKET then
      raise Exception.CreateFmt('Failed to create socket: %d', [WSAGetLastError]);

    timeout := 1000;
    setsockopt(fSocket, SOL_SOCKET, SO_RCVTIMEO, @timeout, SizeOf(timeout));

    FillChar(addr, SizeOf(addr), 0);
    addr.sin_family := AF_INET;
    addr.sin_port := htons(fPort);
    addr.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(fBindInterface)));
    if addr.sin_addr.S_addr = INADDR_NONE then
      addr.sin_addr.S_addr := INADDR_ANY;

    if bind(fSocket, PSockAddr(@addr)^, SizeOf(addr)) = SOCKET_ERROR then
      raise Exception.CreateFmt('Failed to bind to %s:%d - Error: %d', [fBindInterface, fPort, WSAGetLastError]);

    fListenerThread := TUDPListenerThread.Create(Self, fSocket);
    fActive := True;
    DoStateChange(usListening);
  except
    on E: Exception do
    begin
      if fSocket <> INVALID_SOCKET then
      begin
        closesocket(fSocket);
        fSocket := INVALID_SOCKET;
      end;
      fLastError := E.Message;
      DoStateChange(usError);
      DoError(E.Message);
      raise;
    end;
  end;
end;

procedure TCrossUDPServer.InternalStop;
begin
  if not fActive then
    Exit;
  DoStateChange(usStopping);
  fActive := False;

  if fListenerThread <> nil then
  begin
    fListenerThread.Terminate;
    fListenerThread.WaitFor;
    FreeAndNil(fListenerThread);
  end;

  if fSocket <> INVALID_SOCKET then
  begin
    closesocket(fSocket);
    fSocket := INVALID_SOCKET;
  end;

  fClientLock.Enter;
  try
    fClientMap.Clear;
  finally
    fClientLock.Leave;
  end;
  DoStateChange(usIdle);
end;

function TCrossUDPServer.Start: Boolean;
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

procedure TCrossUDPServer.Stop;
begin
  if fShuttingDown then
    Exit;
  fShuttingDown := True;
  try
    InternalStop;
  finally
    fShuttingDown := False;
  end;
end;

function TCrossUDPServer.SendCommandTo(const ToEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes): Boolean;
var
  packet: TBytes;
begin
  packet := CreateCommandPacket(aCmd, aData);
  Result := SendBytesTo(ToEndpoint, packet);
end;

function TCrossUDPServer.SendBytesTo(const ToEndpoint: TUDPEndpoint; const aData: TBytes): Boolean;
var
  addr: TSockAddrIn;
  sent: Integer;
  clientInfo: TUDPClientInfo;
  key: string;
begin
  Result := False;
  if not fActive then
  begin
    DoError('Server not active');
    Exit;
  end;

  try
    FillChar(addr, SizeOf(addr), 0);
    addr.sin_family := AF_INET;
    addr.sin_port := htons(ToEndpoint.Port);
    addr.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(ToEndpoint.IP)));

    sent := sendto(fSocket, aData[0], Length(aData), 0, @addr, SizeOf(addr));
    if sent = SOCKET_ERROR then
      raise Exception.CreateFmt('Send failed: %d', [WSAGetLastError]);

    Inc(fTotalPacketsSent);
    Inc(fTotalBytesSent, sent);

    key := EndpointKey(ToEndpoint);
    fClientLock.Enter;
    try
      if fClientMap.TryGetValue(key, clientInfo) then
      begin
        Inc(clientInfo.TotalBytesSent, sent);
        fClientMap.AddOrSetValue(key, clientInfo);
      end;
    finally
      fClientLock.Leave;
    end;

    DoDataSent(ToEndpoint, aData);
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

function TCrossUDPServer.BroadcastCommand(const aCmd: Int64; const aData: TBytes; APort: Integer): Boolean;
var
  packet: TBytes;
  addr: TSockAddrIn;
  sent: Integer;
  enable: Integer;
begin
  Result := False;
  if not fActive then
  begin
    DoError('Server not active');
    Exit;
  end;

  try
    enable := 1;
    setsockopt(fSocket, SOL_SOCKET, SO_BROADCAST, @enable, SizeOf(enable));

    packet := CreateCommandPacket(aCmd, aData);
    FillChar(addr, SizeOf(addr), 0);
    addr.sin_family := AF_INET;
    addr.sin_port := htons(APort);
    addr.sin_addr.S_addr := INADDR_BROADCAST;

    sent := sendto(fSocket, packet[0], Length(packet), 0, @addr, SizeOf(addr));
    if sent = SOCKET_ERROR then
      raise Exception.CreateFmt('Broadcast failed: %d', [WSAGetLastError]);

    Inc(fTotalPacketsSent);
    Inc(fTotalBytesSent, sent);
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

function TCrossUDPServer.GetTrackedClientCount: Integer;
begin
  fClientLock.Enter;
  try
    Result := fClientMap.Count;
  finally
    fClientLock.Leave;
  end;
end;

function TCrossUDPServer.GetClientInfo(const Endpoint: TUDPEndpoint): TUDPClientInfo;
var
  key: string;
begin
  key := EndpointKey(Endpoint);
  fClientLock.Enter;
  try
    if not fClientMap.TryGetValue(key, Result) then
    begin
      FillChar(Result, SizeOf(Result), 0);
      Result.Endpoint := Endpoint;
    end;
  finally
    fClientLock.Leave;
  end;
end;

function TCrossUDPServer.GetAllClientEndpoints: TArray<TUDPEndpoint>;
var
  key: string;
  clientInfo: TUDPClientInfo;
  i: Integer;
begin
  fClientLock.Enter;
  try
    SetLength(Result, fClientMap.Count);
    i := 0;
    for key in fClientMap.Keys do
    begin
      if fClientMap.TryGetValue(key, clientInfo) then
      begin
        Result[i] := clientInfo.Endpoint;
        Inc(i);
      end;
    end;
  finally
    fClientLock.Leave;
  end;
end;

procedure TCrossUDPServer.RemoveInactiveClients;
var
  key: string;
  clientInfo: TUDPClientInfo;
  keysToRemove: TList<string>;
  timeoutSeconds: Integer;
begin
  keysToRemove := TList<string>.Create;
  try
    fClientLock.Enter;
    try
      timeoutSeconds := fClientTimeout;
      for key in fClientMap.Keys do
      begin
        if fClientMap.TryGetValue(key, clientInfo) then
        begin
          if SecondsBetween(Now, clientInfo.LastSeen) > timeoutSeconds then
            keysToRemove.Add(key);
        end;
      end;
      for key in keysToRemove do
        fClientMap.Remove(key);
    finally
      fClientLock.Leave;
    end;
  finally
    keysToRemove.Free;
  end;
end;

procedure TCrossUDPServer.ClearAllClients;
begin
  fClientLock.Enter;
  try
    fClientMap.Clear;
  finally
    fClientLock.Leave;
  end;
end;

function TCrossUDPServer.IsActive: Boolean;
begin
  Result := fActive;
end;

function TCrossUDPServer.GetLastError: string;
begin
  Result := fLastError;
end;

function TCrossUDPServer.GetStateAsString: string;
begin
  Result := UDPServerStateToString(fCurrentState);
end;

function TCrossUDPServer.GetStateDescription: string;
begin
  case fCurrentState of
    usIdle: Result := Format('Server idle on port %d', [fPort]);
    usStarting: Result := Format('Server starting on port %d', [fPort]);
    usListening: Result := Format('Server listening on %s:%d (%d clients tracked)',
      [fBindInterface, fPort, GetTrackedClientCount]);
    usStopping: Result := Format('Server stopping on port %d', [fPort]);
    usError: Result := Format('Server error: %s', [fLastError]);
  else
    Result := 'Unknown state';
  end;
end;

function TCrossUDPServer.GetServerStats: string;
begin
  Result := Format(
    'State: %s, Active: %s, Clients: %d, Packets Sent: %d, Packets Received: %d, Bytes Sent: %d, Bytes Received: %d',
    [GetStateAsString, BoolToStr(fActive, True), GetTrackedClientCount,
     fTotalPacketsSent, fTotalPacketsReceived, fTotalBytesSent, fTotalBytesReceived]);
end;

procedure TCrossUDPServer.ResetStatistics;
begin
  fTotalPacketsReceived := 0;
  fTotalPacketsSent := 0;
  fTotalBytesReceived := 0;
  fTotalBytesSent := 0;
  fTotalClientsTracked := 0;
end;

procedure TCrossUDPServer.SetActive(const Value: Boolean);
begin
  if fActive <> Value then
  begin
    if Value then
      Start
    else
      Stop;
  end;
end;

procedure TCrossUDPServer.SetPort(const Value: Integer);
begin
  if fPort <> Value then
  begin
    if fActive then
      raise Exception.Create('Cannot change Port while server is active');
    fPort := Value;
  end;
end;

procedure TCrossUDPServer.SetBindInterface(const Value: string);
begin
  if fBindInterface <> Value then
  begin
    if fActive then
      raise Exception.Create('Cannot change BindInterface while server is active');
    fBindInterface := Value;
  end;
end;

procedure TCrossUDPServer.SetDescription(const Value: string);
begin
  fDescription := Value;
end;

procedure TCrossUDPServer.SetName(const Value: string);
begin
  if (Value <> '') and (Value <> Name) then
  begin
    inherited Name := Value;
    fName := Value;
  end;
end;

procedure TCrossUDPServer.SetThreadPoolSize(const Value: Integer);
begin
  fThreadPoolSize := Value;
end;

procedure TCrossUDPServer.SetBufferSize(const Value: Integer);
begin
  if Value >= 512 then
    fBufferSize := Value;
end;

procedure TCrossUDPServer.SetVersion(const Value: string);
begin
  fVersion := Value;
end;

procedure TCrossUDPServer.SetClientTimeout(const Value: Integer);
begin
  if Value >= 10 then
    fClientTimeout := Value;
end;

procedure TCrossUDPServer.SetAutoRemoveInactiveClients(const Value: Boolean);
begin
  fAutoRemoveInactiveClients := Value;
end;

procedure TCrossUDPServer.DoError(const ErrorMsg: string);
begin
  if Assigned(fOnError) then
    fOnError(Self, ErrorMsg);
end;

procedure TCrossUDPServer.DoDataReceived(const FromEndpoint: TUDPEndpoint; const Data: TBytes);
begin
  if Assigned(fOnDataReceived) then
    fOnDataReceived(Self, FromEndpoint, Data);
end;

procedure TCrossUDPServer.DoDataSent(const ToEndpoint: TUDPEndpoint; const Data: TBytes);
begin
  if Assigned(fOnDataSent) then
    fOnDataSent(Self, ToEndpoint, Data);
end;

procedure TCrossUDPServer.DoHandleCommand(const FromEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes);
begin
  if Assigned(fOnHandleCommand) then
    fOnHandleCommand(Self, FromEndpoint, aCmd, aData);
end;

procedure TCrossUDPServer.DoStateChange(NewState: TCrossUDPServerState);
var
  OldState: TCrossUDPServerState;
begin
  OldState := fCurrentState;
  if OldState <> NewState then
  begin
    fCurrentState := NewState;
    if Assigned(fOnStateChange) then
      fOnStateChange(Self, OldState, NewState, GetStateDescription);
  end;
end;

procedure TCrossUDPServer.DoClientSeen(const ClientEndpoint: TUDPEndpoint; IsNew: Boolean);
begin
  if Assigned(fOnClientSeen) then
    fOnClientSeen(Self, ClientEndpoint, IsNew);
end;

procedure Register;
begin
  RegisterComponents('CrossUDP', [TCrossUDPServer]);
end;

end.
