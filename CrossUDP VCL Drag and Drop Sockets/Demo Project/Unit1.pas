unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, CrossUDP.Server, CrossUDP.Client, Vcl.StdCtrls,
  Vcl.ExtCtrls, CrossUDP.Base;

type
  TForm1 = class(TForm)
    CrossUDPClient1: TCrossUDPClient;
    CrossUDPServer1: TCrossUDPServer;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    btnStartServer: TButton;
    btnStopServer: TButton;
    btnClientConnect: TButton;
    btnClientDisconnect: TButton;
    btnSendPing: TButton;
    btnSendEcho: TButton;
    btnBroadcast: TButton;
    btnClearLog: TButton;
    memoLog: TMemo;
    Label1: TLabel;
    Label2: TLabel;
    edtServerPort: TEdit;
    edtClientPort: TEdit;
    edtMessage: TEdit;
    Label3: TLabel;
    lblServerStats: TLabel;
    lblClientStats: TLabel;
    Timer1: TTimer;
    btnResetStats: TButton;
    procedure CrossUDPClient1DataReceived(Sender: TObject; const Data: TBytes);
    procedure CrossUDPClient1DataSent(Sender: TObject; const Data: TBytes);
    procedure CrossUDPClient1Error(Sender: TObject; const ErrorMsg: string);
    procedure CrossUDPClient1HandleCommand(Sender: TObject; const aCmd: Int64; const aData: TBytes);
    procedure CrossUDPClient1StateChange(Sender: TObject; OldState, NewState: TCrossUDPClientState; const StateDescription: string);
    procedure CrossUDPServer1ClientSeen(Sender: TObject; const ClientEndpoint: TUDPEndpoint; IsNew: Boolean);
    procedure CrossUDPServer1DataReceived(Sender: TObject; const FromEndpoint: TUDPEndpoint; const Data: TBytes);
    procedure CrossUDPServer1DataSent(Sender: TObject; const ToEndpoint: TUDPEndpoint; const Data: TBytes);
    procedure CrossUDPServer1Error(Sender: TObject; const ErrorMsg: string);
    procedure CrossUDPServer1HandleCommand(Sender: TObject; const FromEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes);
    procedure CrossUDPServer1StateChange(Sender: TObject; OldState, NewState: TCrossUDPServerState; const StateDescription: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnStartServerClick(Sender: TObject);
    procedure btnStopServerClick(Sender: TObject);
    procedure btnClientConnectClick(Sender: TObject);
    procedure btnClientDisconnectClick(Sender: TObject);
    procedure btnSendPingClick(Sender: TObject);
    procedure btnSendEchoClick(Sender: TObject);
    procedure btnBroadcastClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure btnResetStatsClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    procedure Log(const Msg: string);
    procedure UpdateStats;
    function StringToBytes(const S: string): TBytes;
    function BytesToString(const B: TBytes): string;
  public
  end;

const
  CMD_PING = 1;
  CMD_PONG = 2;
  CMD_ECHO = 3;
  CMD_ECHO_REPLY = 4;
  CMD_BROADCAST = 5;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function TForm1.StringToBytes(const S: string): TBytes;
var
  Encoded: UTF8String;
begin
  Encoded := UTF8Encode(S);
  SetLength(Result, Length(Encoded));
  if Length(Encoded) > 0 then
    Move(Encoded[1], Result[0], Length(Encoded));
end;

function TForm1.BytesToString(const B: TBytes): string;
var
  Temp: UTF8String;
begin
  SetLength(Temp, Length(B));
  if Length(B) > 0 then
    Move(B[0], Temp[1], Length(B));
  Result := UTF8ToString(Temp);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  edtServerPort.Text := '8888';
  edtClientPort.Text := '8888';
  edtMessage.Text := 'Hello from Client!';

  Log('=== CrossUDP Demo Ready ===');
  Log('Command IDs: PING=1, PONG=2, ECHO=3, ECHO_REPLY=4, BROADCAST=5');
  Log('');
  UpdateStats;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if CrossUDPClient1.IsActive then
    CrossUDPClient1.Close;
  if CrossUDPServer1.IsActive then
    CrossUDPServer1.Stop;
end;

procedure TForm1.Log(const Msg: string);
begin
  memoLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + Msg);
  SendMessage(memoLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TForm1.UpdateStats;
begin
  lblServerStats.Caption := Format('SERVER: %s | Clients: %d | RX: %d pkts/%d bytes | TX: %d pkts/%d bytes',
    [CrossUDPServer1.GetStateAsString,
     CrossUDPServer1.GetTrackedClientCount,
     CrossUDPServer1.TotalPacketsReceived,
     CrossUDPServer1.TotalBytesReceived,
     CrossUDPServer1.TotalPacketsSent,
     CrossUDPServer1.TotalBytesSent]);

  lblClientStats.Caption := Format('CLIENT: %s | RX: %d pkts/%d bytes | TX: %d pkts/%d bytes',
    [CrossUDPClient1.GetStateAsString,
     CrossUDPClient1.TotalPacketsReceived,
     CrossUDPClient1.TotalBytesReceived,
     CrossUDPClient1.TotalPacketsSent,
     CrossUDPClient1.TotalBytesSent]);
end;

procedure TForm1.btnStartServerClick(Sender: TObject);
begin
  CrossUDPServer1.Port := StrToIntDef(edtServerPort.Text, 8888);
  if CrossUDPServer1.Start then
    Log('[SERVER] Started on port ' + IntToStr(CrossUDPServer1.Port))
  else
    Log('[SERVER] FAILED to start: ' + CrossUDPServer1.GetLastError);
end;

procedure TForm1.btnStopServerClick(Sender: TObject);
begin
  CrossUDPServer1.Stop;
  Log('[SERVER] Stopped');
end;

procedure TForm1.btnClientConnectClick(Sender: TObject);
begin
  CrossUDPClient1.Port := StrToIntDef(edtClientPort.Text, 8888);
  if CrossUDPClient1.Open then
    Log('[CLIENT] Connected to ' + CrossUDPClient1.Host + ':' + IntToStr(CrossUDPClient1.Port))
  else
    Log('[CLIENT] FAILED to connect: ' + CrossUDPClient1.GetLastError);
end;

procedure TForm1.btnClientDisconnectClick(Sender: TObject);
begin
  CrossUDPClient1.Close;
  Log('[CLIENT] Disconnected');
end;

procedure TForm1.btnSendPingClick(Sender: TObject);
var
  Data: TBytes;
begin
  if not CrossUDPClient1.IsActive then
  begin
    ShowMessage('Client not connected!');
    Exit;
  end;

  SetLength(Data, 0);
  if CrossUDPClient1.SendCommand(CMD_PING, Data) then
    Log('[CLIENT] >>> PING sent')
  else
    Log('[CLIENT] FAILED to send PING');
end;

procedure TForm1.btnSendEchoClick(Sender: TObject);
var
  Data: TBytes;
begin
  if not CrossUDPClient1.IsActive then
  begin
    ShowMessage('Client not connected!');
    Exit;
  end;

  Data := StringToBytes(edtMessage.Text);

  if CrossUDPClient1.SendCommand(CMD_ECHO, Data) then
    Log('[CLIENT] >>> ECHO sent: "' + edtMessage.Text + '"')
  else
    Log('[CLIENT] FAILED to send ECHO');
end;

procedure TForm1.btnBroadcastClick(Sender: TObject);
var
  Data: TBytes;
begin
  if not CrossUDPClient1.IsActive then
  begin
    ShowMessage('Client not connected!');
    Exit;
  end;

  Data := StringToBytes('BROADCAST: ' + edtMessage.Text);

  if CrossUDPClient1.Broadcast(CMD_BROADCAST, Data, 8888) then
    Log('[CLIENT] >>> BROADCAST sent')
  else
    Log('[CLIENT] FAILED to send BROADCAST');
end;

procedure TForm1.btnClearLogClick(Sender: TObject);
begin
  memoLog.Clear;
  Log('Log cleared');
end;

procedure TForm1.btnResetStatsClick(Sender: TObject);
begin
  CrossUDPServer1.ResetStatistics;
  CrossUDPClient1.ResetStatistics;
  Log('[STATS] Statistics reset to zero');
  UpdateStats;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  UpdateStats;
end;

// ============================================================================
// CLIENT EVENT HANDLERS
// ============================================================================

procedure TForm1.CrossUDPClient1DataReceived(Sender: TObject; const Data: TBytes);
begin
  Log('[CLIENT] <<< Raw data received (' + IntToStr(Length(Data)) + ' bytes)');
end;

procedure TForm1.CrossUDPClient1DataSent(Sender: TObject; const Data: TBytes);
begin
  // Logged elsewhere, can add if needed
end;

procedure TForm1.CrossUDPClient1Error(Sender: TObject; const ErrorMsg: string);
begin
  Log('[CLIENT ERROR] ' + ErrorMsg);
end;

procedure TForm1.CrossUDPClient1HandleCommand(Sender: TObject; const aCmd: Int64; const aData: TBytes);
var
  ReceivedMsg: string;
begin
  Log('[CLIENT] <<< Command ' + IntToStr(aCmd) + ' received');

  case aCmd of
    CMD_PONG:
      begin
        Log('[CLIENT] <<< PONG received (ping successful!)');
      end;

    CMD_ECHO_REPLY:
      begin
        if Length(aData) > 0 then
        begin
          ReceivedMsg := BytesToString(aData);
          Log('[CLIENT] <<< ECHO_REPLY: "' + ReceivedMsg + '"');
        end;
      end;
  else
    Log('[CLIENT] <<< Unknown command: ' + IntToStr(aCmd));
  end;
end;

procedure TForm1.CrossUDPClient1StateChange(Sender: TObject; OldState, NewState: TCrossUDPClientState; const StateDescription: string);
begin
  Log('[CLIENT STATE] ' + UDPClientStateToString(OldState) + ' -> ' + UDPClientStateToString(NewState));
  Log('[CLIENT STATE] ' + StateDescription);
end;

// ============================================================================
// SERVER EVENT HANDLERS
// ============================================================================

procedure TForm1.CrossUDPServer1ClientSeen(Sender: TObject; const ClientEndpoint: TUDPEndpoint; IsNew: Boolean);
begin
  if IsNew then
    Log('[SERVER] NEW CLIENT: ' + ClientEndpoint.AsString)
  else
    Log('[SERVER] Client activity from: ' + ClientEndpoint.AsString);
end;

procedure TForm1.CrossUDPServer1DataReceived(Sender: TObject; const FromEndpoint: TUDPEndpoint; const Data: TBytes);
begin
  Log('[SERVER] <<< Raw data from ' + FromEndpoint.AsString + ' (' + IntToStr(Length(Data)) + ' bytes)');
end;

procedure TForm1.CrossUDPServer1DataSent(Sender: TObject; const ToEndpoint: TUDPEndpoint; const Data: TBytes);
begin
  // Logged elsewhere, can add if needed
end;

procedure TForm1.CrossUDPServer1Error(Sender: TObject; const ErrorMsg: string);
begin
  Log('[SERVER ERROR] ' + ErrorMsg);
end;

procedure TForm1.CrossUDPServer1HandleCommand(Sender: TObject; const FromEndpoint: TUDPEndpoint; const aCmd: Int64; const aData: TBytes);
var
  ResponseData: TBytes;
  ReceivedMsg: string;
begin
  Log('[SERVER] <<< Command ' + IntToStr(aCmd) + ' from ' + FromEndpoint.AsString);

  case aCmd of
    CMD_PING:
      begin
        Log('[SERVER] PING received, sending PONG...');
        SetLength(ResponseData, 0);
        CrossUDPServer1.SendCommandTo(FromEndpoint, CMD_PONG, ResponseData);
        Log('[SERVER] >>> PONG sent to ' + FromEndpoint.AsString);
      end;

    CMD_ECHO:
      begin
        if Length(aData) > 0 then
        begin
          ReceivedMsg := BytesToString(aData);
          Log('[SERVER] ECHO received: "' + ReceivedMsg + '"');

          ResponseData := StringToBytes('Server echoes: ' + ReceivedMsg);
          CrossUDPServer1.SendCommandTo(FromEndpoint, CMD_ECHO_REPLY, ResponseData);
          Log('[SERVER] >>> ECHO_REPLY sent to ' + FromEndpoint.AsString);
        end;
      end;

    CMD_BROADCAST:
      begin
        if Length(aData) > 0 then
        begin
          ReceivedMsg := BytesToString(aData);
          Log('[SERVER] BROADCAST received: "' + ReceivedMsg + '"');
        end;
      end;
  else
    Log('[SERVER] Unknown command: ' + IntToStr(aCmd));
  end;
end;

procedure TForm1.CrossUDPServer1StateChange(Sender: TObject; OldState, NewState: TCrossUDPServerState; const StateDescription: string);
begin
  Log('[SERVER STATE] ' + UDPServerStateToString(OldState) + ' -> ' + UDPServerStateToString(NewState));
  Log('[SERVER STATE] ' + StateDescription);
end;

end.
