program sudoku;

{$IFDEF DEBUG}
	{$APPTYPE CONSOLE}
{$ENDIF}

uses
  FastMM4,
  Forms,
  fSudokuMain in 'src\fSudokuMain.pas' {frmSudoku},
  SudokuLib in 'src\SudokuLib.pas',
  TileControl in 'src\TileControl.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmSudoku, frmSudoku);
  Application.Run;
end.
