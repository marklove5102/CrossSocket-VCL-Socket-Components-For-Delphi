unit CrossUDP.Base;

interface

uses
  Windows,
  SysUtils;

const
  MAX_UDP_PACKET_SIZE = 65507;
  COMMAND_ID_SIZE = 8;
  DEFAULT_UDP_BUFFER = 8192;

type
  TCrossUDPServerState = (
    usIdle,
    usStarting,
    usListening,
    usStopping,
    usError
  );

  TCrossUDPClientState = (
    ucIdle,
    ucReady,
    ucError
  );

  TUDPEndpoint = record
    IP: string;
    Port: Integer;
    function AsString: string;
    function IsValid: Boolean;
    class function Create(const AIP: string; APort: Integer): TUDPEndpoint; static;
  end;

  TUDPClientInfo = record
    Endpoint: TUDPEndpoint;
    LastSeen: TDateTime;
    TotalPacketsReceived: Int64;
    TotalBytesSent: Int64;
    TotalBytesReceived: Int64;
  end;

  TCrossUDPDataReceivedEvent = procedure(Sender: TObject; const Data: TBytes) of object;
  TCrossUDPDataSentEvent = procedure(Sender: TObject; const Data: TBytes) of object;
  TCrossUDPErrorEvent = procedure(Sender: TObject; const ErrorMsg: string) of object;
  TCrossUDPHandleCommandEvent = procedure(Sender: TObject; const aCmd: Int64; const aData: TBytes) of object;
  
  TCrossUDPServerDataReceivedEvent = procedure(Sender: TObject; const FromEndpoint: TUDPEndpoint; const Data: TBytes) of object;
  TCrossUDPServerDataSentEvent = procedure(Sender: TObject; const ToEndpoint: TUDPEndpoint; const Data: TBytes) of object;
  TCrossUDPServerHandleCommandEvent = procedure(Sender: TObject; const FromEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes) of object;
  TCrossUDPClientSeenEvent = procedure(Sender: TObject; const ClientEndpoint: TUDPEndpoint; IsNew: Boolean) of object;
  
  TCrossUDPServerStateChangeEvent = procedure(Sender: TObject; OldState, NewState: TCrossUDPServerState; const StateDescription: string) of object;
  TCrossUDPClientStateChangeEvent = procedure(Sender: TObject; OldState, NewState: TCrossUDPClientState; const StateDescription: string) of object;

function UDPServerStateToString(State: TCrossUDPServerState): string;
function UDPClientStateToString(State: TCrossUDPClientState): string;
function EndpointToString(const Endpoint: TUDPEndpoint): string;
function InitWinSock: Boolean;
procedure CleanupWinSock;

implementation

uses
  WinSock2;

var
  WinSockInitialized: Boolean = False;

function InitWinSock: Boolean;
var
  WSAData: TWSAData;
begin
  if not WinSockInitialized then
  begin
    Result := WSAStartup(MAKEWORD(2, 2), WSAData) = 0;
    WinSockInitialized := Result;
  end
  else
    Result := True;
end;

procedure CleanupWinSock;
begin
  if WinSockInitialized then
  begin
    WSACleanup;
    WinSockInitialized := False;
  end;
end;

{ TUDPEndpoint }

class function TUDPEndpoint.Create(const AIP: string; APort: Integer): TUDPEndpoint;
begin
  Result.IP := AIP;
  Result.Port := APort;
end;

function TUDPEndpoint.AsString: string;
begin
  Result := Format('%s:%d', [IP, Port]);
end;

function TUDPEndpoint.IsValid: Boolean;
begin
  Result := (IP <> '') and (Port > 0) and (Port <= 65535);
end;

function UDPServerStateToString(State: TCrossUDPServerState): string;
begin
  case State of
    usIdle: Result := 'Idle';
    usStarting: Result := 'Starting';
    usListening: Result := 'Listening';
    usStopping: Result := 'Stopping';
    usError: Result := 'Error';
  else
    Result := 'Unknown';
  end;
end;

function UDPClientStateToString(State: TCrossUDPClientState): string;
begin
  case State of
    ucIdle: Result := 'Idle';
    ucReady: Result := 'Ready';
    ucError: Result := 'Error';
  else
    Result := 'Unknown';
  end;
end;

function EndpointToString(const Endpoint: TUDPEndpoint): string;
begin
  Result := Endpoint.AsString;
end;

initialization
  InitWinSock;

finalization
  CleanupWinSock;

end.