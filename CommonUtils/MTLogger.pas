unit MTLogger;

interface

uses
  Windows, SysUtils, Classes, SyncObjs, MTUtils;

type
  TLoggerThread = class(TThread)
  private
    FLogFileName: string;
    Event: TEvent;
    CritSect: TCriticalSection; // ��� ������ ������ �����
    LogStrings: TStringList;
  protected
    procedure Execute; override;
  public
    constructor Create(LogFileName: string);
    destructor Destroy; override;
    procedure AddToLog(const Msg: string);
  end;

var
  DefLogger: TLoggerThread;
  AllowMessageBoxIfError: Boolean = False; 

procedure CreateDefLogger(DefLogFileName: string);
procedure FreeDefLogger;

// ���������� �������� ������ ������ � ��������� ����
procedure WriteStringToTextFile(AFileName: string; Msg: string);

implementation

procedure CreateDefLogger(DefLogFileName: string);
begin
  if DefLogger = nil then
    DefLogger := TLoggerThread.Create(DefLogFileName);
end;

procedure FreeDefLogger;
begin
  FreeAndNil(DefLogger);
end;

procedure WriteStringToTextFile(AFileName: string; Msg: string);
var
  AFile: TextFile;
begin
  try
    // ��������� ���� ��� ������ ���������� ������! ��� ������� ������ ������
    // � ��� ���� ��� ����� �������������!
    AssignFile(AFile, AFileName);
    if FileExists(AFileName) then
      Append(AFile)
    else
      Rewrite(AFile);
    Writeln(AFile, Msg);
    CloseFile(AFile);
  except
    on E: Exception do
    begin
      // ��������! � �������� ���������� ������ ������������ ��������� �� ������
      // ������ � ���-���� �����������!
      if AllowMessageBoxIfError then
        ThreadShowMessageFmt('������ ��� ������ � ���� [%s] ������ "%s": %s', [AFileName, Msg, E.Message]);
    end;
  end;
end;

{ TLoggerThread }

procedure TLoggerThread.AddToLog(const Msg: string);
begin
  CritSect.Enter;
  try
    LogStrings.Add(Format('%s [P:%d T:%d] - %s', [FormatDateTime('dd.mm.yyyy hh:nn:ss.zzz', Now),
      GetCurrentProcessId, GetCurrentThreadId, Msg]));
  finally
    CritSect.Leave;
  end;
  Event.SetEvent;
end;

constructor TLoggerThread.Create(LogFileName: string);
const
  STATE_NONSIGNALED = FALSE;
  AUTO_RESET  = FALSE;
begin
  inherited Create(False);

  // ������ ������ "Event" � ��������� "nonsignaled" � ������, �����
  // �� ������������� ��������� � ��������� "nonsignaled" ����� WaitFor
  Event := TEvent.Create(nil, AUTO_RESET, STATE_NONSIGNALED, '', False);

  // ������ ������ ����� LogStrings
  LogStrings := TStringList.Create;

  // ������ ����������� ������ ��� ������ ������ ����� �� ��������������
  // ������� �� ���������� �������
  CritSect := TCriticalSection.Create;

  FLogFileName := LogFileName;
end;

destructor TLoggerThread.Destroy;
begin
  // ����� �����, ����� ����� Terminate ��� ������ ������ SetEvent!
  Terminate;      // 1. ���������� ���� Terminated
  Event.SetEvent; // 2. ��������� Event � ��������� SIGNALED
  inherited;      // 3. ���������� ������ �� ������ Execute
  Event.Free;     // 4. ���������� ������ Event
  CritSect.Free;
  LogStrings.Free;
end;

procedure TLoggerThread.Execute;
var
  TmpList: TStringList;
begin
  while True do
  begin
    // ��������� ������ ������ � ��� ������, ���� ������������ ������� �� ���������,
    // � ����� ����� ������� � ���-���� ��� ��������� �� ������ LogStrings
    if Terminated and (LogStrings.Count = 0) then Exit;

    // ������� ������������ ������� Event � ��������� signaled, �� �� ����� 2� ������
    // ��� ������ ������ TLoggerThread.AddToLog ����������� ����� Event.SetEvent,
    // ������ ����� ���������������� � �� ������ �������� �����������
    Event.WaitFor(2000);

    // ��������� �������� Count ��� ����������� ������ (��� ���������)
    if LogStrings.Count > 0 then
    begin
      TmpList := TStringList.Create;
      try
        // 1. ������ � ����������� ������
        CritSect.Enter;
        try
          // 2. �������� ��� ������ �� LogStrings � TmpList
          TmpList.Assign(LogStrings);
          // 3. ������� ������ LogStrings
          LogStrings.Clear;
        finally
          // 4. ������� �� ����������� ������
          CritSect.Leave;
        end;

        // ������ TmpList �������� ���������, ������� ��� �� ����� ��������
        // ����������� �������.

        // 5. �� ���� �������� ���������� ��� ������ �� ������ TmpList � ���-����
        WriteStringToTextFile(FLogFileName, Trim(TmpList.Text));
      finally
        TmpList.Free;
      end;
    end;
  end;
end;

end.
