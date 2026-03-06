object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'CrossUDP Socket Demo'
  ClientHeight = 600
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 201
    Align = alTop
    TabOrder = 0
    object GroupBox1: TGroupBox
      Left = 8
      Top = 8
      Width = 377
      Height = 185
      Caption = ' SERVER CONTROLS '
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      object Label1: TLabel
        Left = 16
        Top = 24
        Width = 22
        Height = 15
        Caption = 'Port'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object edtServerPort: TEdit
        Left = 64
        Top = 21
        Width = 121
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        Text = '8888'
      end
      object btnStartServer: TButton
        Left = 16
        Top = 56
        Width = 169
        Height = 33
        Caption = 'Start Server'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        OnClick = btnStartServerClick
      end
      object btnStopServer: TButton
        Left = 16
        Top = 95
        Width = 169
        Height = 33
        Caption = 'Stop Server'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        OnClick = btnStopServerClick
      end
      object btnResetStats: TButton
        Left = 16
        Top = 140
        Width = 169
        Height = 33
        Caption = 'Reset Statistics'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 3
        OnClick = btnResetStatsClick
      end
    end
    object GroupBox2: TGroupBox
      Left = 408
      Top = 8
      Width = 377
      Height = 185
      Caption = ' CLIENT CONTROLS '
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      object Label2: TLabel
        Left = 16
        Top = 24
        Width = 22
        Height = 15
        Caption = 'Port'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object Label3: TLabel
        Left = 16
        Top = 56
        Width = 46
        Height = 15
        Caption = 'Message'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object edtClientPort: TEdit
        Left = 64
        Top = 21
        Width = 121
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        Text = '8888'
      end
      object btnClientConnect: TButton
        Left = 200
        Top = 18
        Width = 161
        Height = 25
        Caption = 'Connect Client'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        OnClick = btnClientConnectClick
      end
      object btnClientDisconnect: TButton
        Left = 231
        Top = 88
        Width = 130
        Height = 33
        Caption = 'Disconnect Client'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        OnClick = btnClientDisconnectClick
      end
      object btnSendPing: TButton
        Left = 16
        Top = 88
        Width = 65
        Height = 33
        Caption = 'Send PING'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 3
        OnClick = btnSendPingClick
      end
      object btnSendEcho: TButton
        Left = 87
        Top = 88
        Width = 74
        Height = 33
        Caption = 'Send ECHO'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 4
        OnClick = btnSendEchoClick
      end
      object btnBroadcast: TButton
        Left = 167
        Top = 88
        Width = 58
        Height = 33
        Caption = 'Broadcast'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 5
        OnClick = btnBroadcastClick
      end
      object edtMessage: TEdit
        Left = 72
        Top = 53
        Width = 289
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 6
        Text = 'Hello from Client!'
      end
      object btnClearLog: TButton
        Left = 16
        Top = 140
        Width = 345
        Height = 33
        Caption = 'Clear Log'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 7
        OnClick = btnClearLogClick
      end
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 201
    Width = 800
    Height = 360
    Align = alClient
    TabOrder = 1
    object memoLog: TMemo
      Left = 1
      Top = 1
      Width = 798
      Height = 358
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 561
    Width = 800
    Height = 39
    Align = alBottom
    TabOrder = 2
    object lblServerStats: TLabel
      Left = 8
      Top = 6
      Width = 60
      Height = 15
      Caption = 'Server Stats'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblClientStats: TLabel
      Left = 8
      Top = 21
      Width = 59
      Height = 15
      Caption = 'Client Stats'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object CrossUDPClient1: TCrossUDPClient
    Name = 'CrossUDPClient1'
    Host = '127.0.0.1'
    Description = 'CrossUDP Client Component - RAW SOCKETS'
    Version = '1.0.0'
    OnDataReceived = CrossUDPClient1DataReceived
    OnDataSent = CrossUDPClient1DataSent
    OnError = CrossUDPClient1Error
    OnHandleCommand = CrossUDPClient1HandleCommand
    OnStateChange = CrossUDPClient1StateChange
    Left = 592
    Top = 128
  end
  object CrossUDPServer1: TCrossUDPServer
    Name = 'CrossUDPServer1'
    BindInterface = '0.0.0.0'
    Description = 'CrossUDP Server Component - RAW SOCKETS'
    Version = '1.0.0'
    OnDataReceived = CrossUDPServer1DataReceived
    OnDataSent = CrossUDPServer1DataSent
    OnError = CrossUDPServer1Error
    OnHandleCommand = CrossUDPServer1HandleCommand
    OnStateChange = CrossUDPServer1StateChange
    OnClientSeen = CrossUDPServer1ClientSeen
    Left = 280
    Top = 112
  end
  object Timer1: TTimer
    Interval = 500
    OnTimer = Timer1Timer
    Left = 304
    Top = 32
  end
end
