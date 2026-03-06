unit CrossUDP.Register;

interface

procedure Register;

implementation

uses
  Classes,
  DesignIntf,
  DesignEditors,
  CrossUDP.Client,
  CrossUDP.Server;

type
  TCrossUDPHostPropertyEditor = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
  end;

  TCrossUDPBindInterfacePropertyEditor = class(TPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    function GetValue: string; override;
    procedure SetValue(const Value: string); override;
  end;

{ TCrossUDPHostPropertyEditor }

function TCrossUDPHostPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paMultiSelect];
end;

procedure TCrossUDPHostPropertyEditor.GetValues(Proc: TGetStrProc);
begin
  Proc('127.0.0.1');
  Proc('localhost');
  Proc('255.255.255.255');
end;

function TCrossUDPHostPropertyEditor.GetValue: string;
begin
  Result := GetStrValue;
end;

procedure TCrossUDPHostPropertyEditor.SetValue(const Value: string);
begin
  SetStrValue(Value);
end;

{ TCrossUDPBindInterfacePropertyEditor }

function TCrossUDPBindInterfacePropertyEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paMultiSelect];
end;

procedure TCrossUDPBindInterfacePropertyEditor.GetValues(Proc: TGetStrProc);
begin
  Proc('0.0.0.0');
  Proc('127.0.0.1');
  Proc('localhost');
end;

function TCrossUDPBindInterfacePropertyEditor.GetValue: string;
begin
  Result := GetStrValue;
end;

procedure TCrossUDPBindInterfacePropertyEditor.SetValue(const Value: string);
begin
  SetStrValue(Value);
end;

procedure Register;
begin
  RegisterComponents('CrossUDP', [
    TCrossUDPClient,
    TCrossUDPServer
  ]);

  RegisterPropertyEditor(TypeInfo(string), TCrossUDPClient, 'Host', TCrossUDPHostPropertyEditor);
  RegisterPropertyEditor(TypeInfo(string), TCrossUDPServer, 'BindInterface', TCrossUDPBindInterfacePropertyEditor);
end;

end.
