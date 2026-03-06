unit CrossUDP.Client;

interface

uses
  Windows,
  Classes,
  SysUtils,
  WinSock2,
  CrossUDP.Base;

type
  TCrossUDPClient = class(TComponent)
  private
    fSocket: TSocket;
    fHost: string;
    fPort: Integer;
    fLocalPort: Integer;
    fBroadcastEnabled: Boolean;
    fActive: Boolean;
    fCurrentState: TCrossUDPClientState;
    fLastError: string;
    fDescription: string;
    fName: string;
    fReceiveTimeout: Integer;
    fSendTimeout: Integer;
    fBufferSize: Integer;
    fVersion: string;
    fTotalPacketsSent: Int64;
    fTotalPacketsReceived: Int64;
    fTotalBytesSent: Int64;
    fTotalBytesReceived: Int64;

    fOnDataReceived: TCrossUDPDataReceivedEvent;
    fOnDataSent: TCrossUDPDataSentEvent;
    fOnError: TCrossUDPErrorEvent;
    fOnHandleCommand: TCrossUDPHandleCommandEvent;
    fOnStateChange: TCrossUDPClientStateChangeEvent;

    procedure SetActive(const Value: Boolean);
    procedure SetHost(const Value: string);
    procedure SetPort(const Value: Integer);
    procedure SetLocalPort(const Value: Integer);
    procedure SetBroadcastEnabled(const Value: Boolean);
    procedure SetDescription(const Value: string);
    procedure SetName(const Value: string);
    procedure SetReceiveTimeout(const Value: Integer);
    procedure SetSendTimeout(const Value: Integer);
    procedure SetBufferSize(const Value: Integer);
    procedure SetVersion(const Value: string);

    procedure DoError(const ErrorMsg: string);
    procedure DoDataReceived(const Data: TBytes);
    procedure DoDataSent(const Data: TBytes);
    procedure DoHandleCommand(const aCmd: Int64; const aData: TBytes);
    procedure DoStateChange(NewState: TCrossUDPClientState);
    function GetStateDescription: string;
    function CreateCommandPacket(const aCmd: Int64; const aData: TBytes): TBytes;
    procedure ProcessReceivedPacket(const Data: TBytes);

  protected
    procedure InternalOpen;
    procedure InternalClose;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Open: Boolean;
    procedure Close;
    function SendCommand(const aCmd: Int64; const aData: TBytes): Boolean; overload;
    function SendCommand(const aCmd: Int64; const aData: TBytes; const AHost: string; APort: Integer): Boolean; overload;
    function SendBytes(const aData: TBytes): Boolean; overload;
    function SendBytes(const aData: TBytes; const AHost: string; APort: Integer): Boolean; overload;
    function ReceiveBytes: TBytes; overload;
    function ReceiveBytes(var FromIP: string; var FromPort: Integer): TBytes; overload;
    function Broadcast(const aCmd: Int64; const aData: TBytes; APort: Integer): Boolean;
    function IsActive: Boolean;
    function GetLastError: string;
    function GetStateAsString: string;
    procedure ResetStatistics;

  published
    property Active: Boolean read fActive write SetActive default False;
    property Host: string read fHost write SetHost;
    property Port: Integer read fPort write SetPort default 8888;
    property LocalPort: Integer read fLocalPort write SetLocalPort default 0;
    property BroadcastEnabled: Boolean read fBroadcastEnabled write SetBroadcastEnabled default False;
    property Description: string read fDescription write SetDescription;
    property Name: string read fName write SetName;
    property ReceiveTimeout: Integer read fReceiveTimeout write SetReceiveTimeout default 1000;
    property SendTimeout: Integer read fSendTimeout write SetSendTimeout default 1000;
    property BufferSize: Integer read fBufferSize write SetBufferSize default DEFAULT_UDP_BUFFER;
    property Version: string read fVersion write SetVersion;
    property TotalPacketsSent: Int64 read fTotalPacketsSent;
    property TotalPacketsReceived: Int64 read fTotalPacketsReceived;
    property TotalBytesSent: Int64 read fTotalBytesSent;
    property TotalBytesReceived: Int64 read fTotalBytesReceived;
    property CurrentState: TCrossUDPClientState read fCurrentState;
    property StateDescription: string read GetStateDescription;
    property OnDataReceived: TCrossUDPDataReceivedEvent read fOnDataReceived write fOnDataReceived;
    property OnDataSent: TCrossUDPDataSentEvent read fOnDataSent write fOnDataSent;
    property OnError: TCrossUDPErrorEvent read fOnError write fOnError;
    property OnHandleCommand: TCrossUDPHandleCommandEvent read fOnHandleCommand write fOnHandleCommand;
    property OnStateChange: TCrossUDPClientStateChangeEvent read fOnStateChange write fOnStateChange;
  end;

procedure Register;

implementation

{ TCrossUDPClient }

constructor TCrossUDPClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fSocket := INVALID_SOCKET;
  fHost := '127.0.0.1';
  fPort := 8888;
  fLocalPort := 0;
  fBroadcastEnabled := False;
  fActive := False;
  fCurrentState := ucIdle;
  fDescription := 'CrossUDP Client Component - RAW SOCKETS';
  fName := 'CrossUDPClient1';
  fReceiveTimeout := 1000;
  fSendTimeout := 1000;
  fBufferSize := DEFAULT_UDP_BUFFER;
  fVersion := '1.0.0';
  fTotalPacketsSent := 0;
  fTotalPacketsReceived := 0;
  fTotalBytesSent := 0;
  fTotalBytesReceived := 0;
end;

destructor TCrossUDPClient.Destroy;
begin
  if fActive then
    InternalClose;
  inherited Destroy;
end;

function TCrossUDPClient.CreateCommandPacket(const aCmd: Int64; const aData: TBytes): TBytes;
begin
  SetLength(Result, COMMAND_ID_SIZE + Length(aData));
  PInt64(@Result[0])^ := aCmd;
  if Length(aData) > 0 then
    Move(aData[0], Result[COMMAND_ID_SIZE], Length(aData));
end;

procedure TCrossUDPClient.ProcessReceivedPacket(const Data: TBytes);
var
  cmdID: Int64;
  cmdData: TBytes;
begin
  if Length(Data) < COMMAND_ID_SIZE then
  begin
    DoError('Received packet too short - missing command ID');
    Exit;
  end;
  cmdID := PInt64(@Data[0])^;
  SetLength(cmdData, Length(Data) - COMMAND_ID_SIZE);
  if Length(cmdData) > 0 then
    Move(Data[COMMAND_ID_SIZE], cmdData[0], Length(cmdData));
  DoHandleCommand(cmdID, cmdData);
end;

procedure TCrossUDPClient.InternalOpen;
var
  addr: TSockAddrIn;
  optval: Integer;
begin
  if fActive then
    Exit;

  try
    fSocket := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if fSocket = INVALID_SOCKET then
      raise Exception.CreateFmt('Failed to create socket: %d', [WSAGetLastError]);

    setsockopt(fSocket, SOL_SOCKET, SO_RCVTIMEO, @fReceiveTimeout, SizeOf(fReceiveTimeout));
    setsockopt(fSocket, SOL_SOCKET, SO_SNDTIMEO, @fSendTimeout, SizeOf(fSendTimeout));

    if fBroadcastEnabled then
    begin
      optval := 1;
      setsockopt(fSocket, SOL_SOCKET, SO_BROADCAST, @optval, SizeOf(optval));
    end;

    if fLocalPort > 0 then
    begin
      FillChar(addr, SizeOf(addr), 0);
      addr.sin_family := AF_INET;
      addr.sin_port := htons(fLocalPort);
      addr.sin_addr.S_addr := INADDR_ANY;

      if bind(fSocket, PSockAddr(@addr)^, SizeOf(addr)) = SOCKET_ERROR then
        raise Exception.CreateFmt('Failed to bind to port %d: %d', [fLocalPort, WSAGetLastError]);
    end;

    fActive := True;
    DoStateChange(ucReady);
  except
    on E: Exception do
    begin
      if fSocket <> INVALID_SOCKET then
      begin
        closesocket(fSocket);
        fSocket := INVALID_SOCKET;
      end;
      fLastError := E.Message;
      DoStateChange(ucError);
      DoError(E.Message);
      raise;
    end;
  end;
end;

procedure TCrossUDPClient.InternalClose;
begin
  if not fActive then
    Exit;
  fActive := False;
  if fSocket <> INVALID_SOCKET then
  begin
    closesocket(fSocket);
    fSocket := INVALID_SOCKET;
  end;
  DoStateChange(ucIdle);
end;

function TCrossUDPClient.Open: Boolean;
begin
  Result := False;
  try
    InternalOpen;
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

procedure TCrossUDPClient.Close;
begin
  InternalClose;
end;

function TCrossUDPClient.SendCommand(const aCmd: Int64; const aData: TBytes): Boolean;
var
  packet: TBytes;
begin
  Result := False;
  if not fActive then
  begin
    DoError('Client not active');
    Exit;
  end;
  packet := CreateCommandPacket(aCmd, aData);
  Result := SendBytes(packet, fHost, fPort);
end;

function TCrossUDPClient.SendCommand(const aCmd: Int64; const aData: TBytes; const AHost: string; APort: Integer): Boolean;
var
  packet: TBytes;
begin
  Result := False;
  if not fActive then
  begin
    DoError('Client not active');
    Exit;
  end;
  packet := CreateCommandPacket(aCmd, aData);
  Result := SendBytes(packet, AHost, APort);
end;

function TCrossUDPClient.SendBytes(const aData: TBytes): Boolean;
begin
  Result := SendBytes(aData, fHost, fPort);
end;

function TCrossUDPClient.SendBytes(const aData: TBytes; const AHost: string; APort: Integer): Boolean;
var
  addr: TSockAddrIn;
  sent: Integer;
  hostent: PHostEnt;
begin
  Result := False;
  if not fActive then
  begin
    DoError('Client not active');
    Exit;
  end;

  try
    FillChar(addr, SizeOf(addr), 0);
    addr.sin_family := AF_INET;
    addr.sin_port := htons(APort);

    addr.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(AHost)));
    if addr.sin_addr.S_addr = INADDR_NONE then
    begin
      hostent := gethostbyname(PAnsiChar(AnsiString(AHost)));
      if hostent = nil then
        raise Exception.CreateFmt('Cannot resolve host: %s', [AHost]);
      addr.sin_addr.S_addr := PCardinal(hostent^.h_addr^)^;
    end;

   sent := sendto(fSocket, aData[0], Length(aData), 0, @addr, SizeOf(addr));
    if sent = SOCKET_ERROR then
      raise Exception.CreateFmt('Send failed: %d', [WSAGetLastError]);

    Inc(fTotalPacketsSent);
    Inc(fTotalBytesSent, sent);
    DoDataSent(aData);
    Result := True;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

function TCrossUDPClient.ReceiveBytes: TBytes;
var
  FromIP: string;
  FromPort: Integer;
begin
  Result := ReceiveBytes(FromIP, FromPort);
end;

function TCrossUDPClient.ReceiveBytes(var FromIP: string; var FromPort: Integer): TBytes;
var
  buffer: array[0..MAX_UDP_PACKET_SIZE-1] of Byte;
  addr: TSockAddrIn;
  addrLen: Integer;
  received: Integer;
begin
  SetLength(Result, 0);
  if not fActive then
  begin
    DoError('Client not active');
    Exit;
  end;

  try
    addrLen := SizeOf(addr);
    received := recvfrom(fSocket, buffer[0], SizeOf(buffer), 0, TSockAddr(addr), addrLen);

    if received = SOCKET_ERROR then
    begin
      if WSAGetLastError <> WSAETIMEDOUT then
        raise Exception.CreateFmt('Receive failed: %d', [WSAGetLastError]);
      Exit;
    end;

    if received > 0 then
    begin
      SetLength(Result, received);
      Move(buffer[0], Result[0], received);
      FromIP := string(inet_ntoa(addr.sin_addr));
      FromPort := ntohs(addr.sin_port);
      Inc(fTotalPacketsReceived);
      Inc(fTotalBytesReceived, received);
      DoDataReceived(Result);
      ProcessReceivedPacket(Result);
    end;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

function TCrossUDPClient.Broadcast(const aCmd: Int64; const aData: TBytes; APort: Integer): Boolean;
var
  packet: TBytes;
  oldBroadcast: Integer;
  optlen: Integer;
  enable: Integer;
begin
  Result := False;
  if not fActive then
  begin
    DoError('Client not active');
    Exit;
  end;

  try
    optlen := SizeOf(oldBroadcast);
    getsockopt(fSocket, SOL_SOCKET, SO_BROADCAST, @oldBroadcast, optlen);

    enable := 1;
    setsockopt(fSocket, SOL_SOCKET, SO_BROADCAST, @enable, SizeOf(enable));
    try
      packet := CreateCommandPacket(aCmd, aData);
      Result := SendBytes(packet, '255.255.255.255', APort);
    finally
      setsockopt(fSocket, SOL_SOCKET, SO_BROADCAST, @oldBroadcast, SizeOf(oldBroadcast));
    end;
  except
    on E: Exception do
    begin
      fLastError := E.Message;
      DoError(E.Message);
    end;
  end;
end;

function TCrossUDPClient.IsActive: Boolean;
begin
  Result := fActive;
end;

function TCrossUDPClient.GetLastError: string;
begin
  Result := fLastError;
end;

function TCrossUDPClient.GetStateAsString: string;
begin
  Result := UDPClientStateToString(fCurrentState);
end;

function TCrossUDPClient.GetStateDescription: string;
begin
  case fCurrentState of
    ucIdle: Result := Format('Client idle (target: %s:%d)', [fHost, fPort]);
    ucReady: Result := Format('Client ready (target: %s:%d, local port: %d)', [fHost, fPort, fLocalPort]);
    ucError: Result := Format('Client error: %s', [fLastError]);
  else
    Result := 'Unknown state';
  end;
end;

procedure TCrossUDPClient.ResetStatistics;
begin
  fTotalPacketsSent := 0;
  fTotalPacketsReceived := 0;
  fTotalBytesSent := 0;
  fTotalBytesReceived := 0;
end;

procedure TCrossUDPClient.SetActive(const Value: Boolean);
begin
  if fActive <> Value then
  begin
    if Value then
      Open
    else
      Close;
  end;
end;

procedure TCrossUDPClient.SetHost(const Value: string);
begin
  if fHost <> Value then
  begin
    if not fActive then
      fHost := Value;
  end;
end;

procedure TCrossUDPClient.SetPort(const Value: Integer);
begin
  if fPort <> Value then
  begin
    if not fActive then
      fPort := Value;
  end;
end;

procedure TCrossUDPClient.SetLocalPort(const Value: Integer);
begin
  if fLocalPort <> Value then
  begin
    if not fActive then
      fLocalPort := Value;
  end;
end;

procedure TCrossUDPClient.SetBroadcastEnabled(const Value: Boolean);
var
  optval: Integer;
begin
  fBroadcastEnabled := Value;
  if fActive and (fSocket <> INVALID_SOCKET) then
  begin
    optval := Ord(Value);
    setsockopt(fSocket, SOL_SOCKET, SO_BROADCAST, @optval, SizeOf(optval));
  end;
end;

procedure TCrossUDPClient.SetDescription(const Value: string);
begin
  fDescription := Value;
end;

procedure TCrossUDPClient.SetName(const Value: string);
begin
  if (Value <> '') and (Value <> Name) then
  begin
    inherited Name := Value;
    fName := Value;
  end;
end;

procedure TCrossUDPClient.SetReceiveTimeout(const Value: Integer);
begin
  fReceiveTimeout := Value;
  if fActive and (fSocket <> INVALID_SOCKET) then
    setsockopt(fSocket, SOL_SOCKET, SO_RCVTIMEO, @fReceiveTimeout, SizeOf(fReceiveTimeout));
end;

procedure TCrossUDPClient.SetSendTimeout(const Value: Integer);
begin
  fSendTimeout := Value;
  if fActive and (fSocket <> INVALID_SOCKET) then
    setsockopt(fSocket, SOL_SOCKET, SO_SNDTIMEO, @fSendTimeout, SizeOf(fSendTimeout));
end;

procedure TCrossUDPClient.SetBufferSize(const Value: Integer);
begin
  if Value >= 512 then
    fBufferSize := Value;
end;

procedure TCrossUDPClient.SetVersion(const Value: string);
begin
  fVersion := Value;
end;

procedure TCrossUDPClient.DoError(const ErrorMsg: string);
begin
  if Assigned(fOnError) then
    fOnError(Self, ErrorMsg);
end;

procedure TCrossUDPClient.DoDataReceived(const Data: TBytes);
begin
  if Assigned(fOnDataReceived) then
    fOnDataReceived(Self, Data);
end;

procedure TCrossUDPClient.DoDataSent(const Data: TBytes);
begin
  if Assigned(fOnDataSent) then
    fOnDataSent(Self, Data);
end;

procedure TCrossUDPClient.DoHandleCommand(const aCmd: Int64; const aData: TBytes);
begin
  if Assigned(fOnHandleCommand) then
    fOnHandleCommand(Self, aCmd, aData);
end;

procedure TCrossUDPClient.DoStateChange(NewState: TCrossUDPClientState);
var
  OldState: TCrossUDPClientState;
begin
  OldState := fCurrentState;
  if OldState <> NewState then
  begin
    fCurrentState := NewState;
    if Assigned(fOnStateChange) then
      fOnStateChange(Self, OldState, NewState, GetStateDescription);
  end;
end;

procedure Register;
begin
  RegisterComponents('CrossUDP', [TCrossUDPClient]);
end;

end.
