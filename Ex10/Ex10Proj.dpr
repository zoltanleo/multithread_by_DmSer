program Ex10Proj;

uses
  Forms,
  Ex10Unit in 'Ex10Unit.pas' {Form1},
  MTUtils in '..\CommonUtils\MTUtils.pas',
  TimeIntervals in '..\CommonUtils\TimeIntervals.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
