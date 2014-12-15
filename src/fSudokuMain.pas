unit fSudokuMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
	Dialogs, ExtCtrls, StdCtrls,
	TileControl,
  SudokuLib;

type
  TfrmSudoku = class(TForm)
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    imgTiles: TImage;
    Panel2: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure imgTilesMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure imgTilesMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
		FTiles: TTileContainer;
		FPaused: Boolean;
  public
    { Public declarations }
  end;

var
  frmSudoku: TfrmSudoku;

implementation

const
	SudokuTests: array[0..10] of TSudokuArray = (
		(0,9,0,7,0,0,0,4,3,1,0,0,0,0,0,9,0,0,0,0,7,4,8,0,0,0,0,0,8,0,0,0,0,0,0,9,0,5,0,0,1,2,0,6,0,7,0,0,0,0,0,0,0,0,0,0,5,1,0,8,0,0,2,0,1,4,0,5,7,0,0,0,0,0,0,3,9,0,0,0,1),
		(0,0,0,0,0,0,0,1,0,9,5,0,0,6,0,4,7,0,6,1,0,0,0,0,5,0,0,0,9,3,2,0,4,0,0,1,5,2,0,0,0,3,0,0,8,4,8,1,0,0,0,0,2,0,0,6,7,0,0,0,1,9,0,0,0,0,0,0,0,0,0,7,0,3,0,5,0,1,8,0,0),
		(7,0,1,0,6,4,0,5,0,0,0,4,0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0,0,8,4,0,5,9,1,3,0,0,9,3,0,6,8,7,0,2,0,0,0,0,0,0,0,0,0,0,0,0,7,0,0,0,0,0,0,0,0,0,8,2,4,0,9,5,2,0,0,0,1,0,0),
		(0,7,4,0,0,0,0,8,0,0,0,8,9,0,0,0,5,0,0,6,0,0,0,1,0,9,0,3,0,0,0,8,4,0,0,2,2,0,6,3,0,0,0,0,0,0,5,0,0,9,0,0,0,4,0,0,0,0,6,5,0,0,0,0,0,3,0,0,0,9,4,0,0,0,0,0,0,0,1,7,0),
		(0,0,0,0,6,9,0,0,0,1,0,0,0,0,3,0,2,8,5,6,0,0,0,0,9,0,3,0,0,5,0,1,7,0,0,0,0,7,0,0,2,6,8,1,0,2,0,0,0,0,0,7,0,0,0,0,0,0,0,1,0,8,0,7,0,0,0,4,2,1,0,0,4,0,9,0,7,0,0,0,6),
		(7,3,0,0,6,0,0,8,0,0,0,0,0,0,3,2,0,0,8,0,0,0,4,5,0,6,0,6,0,0,8,0,0,0,2,0,0,0,0,0,5,1,0,4,0,0,1,2,0,0,0,0,0,0,3,0,0,5,2,0,7,0,0,4,5,0,0,0,7,9,0,2,0,0,0,0,0,0,6,0,4),
		(0,0,0,0,0,0,0,1,0,0,5,0,0,0,0,8,0,7,1,0,7,9,0,3,0,6,2,4,0,6,8,3,7,5,0,0,0,1,0,0,0,5,0,0,0,0,7,0,4,1,0,0,0,6,2,6,0,7,0,0,0,0,3,0,0,0,3,2,0,0,0,0,0,9,0,0,0,4,2,0,0),
		(4,0,5,6,0,0,9,3,1,9,0,6,4,0,0,0,2,8,1,0,0,0,0,2,6,0,0,8,0,0,7,0,0,3,0,0,0,0,0,5,0,1,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,5,0,0,0,6,0,0,0,0,9,2,4,3,2,0,3,0,0,4,0,8,0),
		(2,0,6,0,0,0,0,0,0,0,0,7,0,3,8,0,0,9,5,0,9,7,0,0,4,3,0,0,0,0,0,0,5,0,0,0,0,1,0,9,0,0,7,6,0,0,0,2,0,0,4,0,8,0,0,0,0,3,9,2,5,0,0,7,2,0,5,0,6,0,1,0,0,0,0,0,1,0,0,0,0),
		(0,6,0,0,0,0,4,0,0,0,0,7,3,4,1,5,0,0,2,0,4,6,0,8,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,2,9,0,0,0,0,3,8,0,0,7,0,6,9,0,4,0,0,0,0,0,8,0,0,0,0,0,8,0,4,3,6,0,0,0,0,0,0,0,1,7,0),
		(7,0,0,0,0,0,6,9,4,0,2,5,4,0,0,0,0,0,6,0,8,0,0,1,3,2,5,2,0,0,0,0,0,8,4,0,4,0,0,3,0,0,9,0,6,5,0,0,0,0,0,0,3,0,0,0,0,0,6,5,2,0,9,1,0,0,0,0,2,0,0,0,0,6,0,0,0,3,0,0,0)
	);

{$IFDEF DEBUG}
function cbFoundSolution(const Status: TSudokuStatus): Boolean;
begin
	//TSudokuSolver.dbgPrintSudoku(Sudoku);
	//Result := False;
	Writeln(Status.Index, #9, IsSolved(Status.Sudoku^));
	Result := True;
end;

procedure testSolve;
var
	i: Integer;
begin
	for i := Low(SudokuTests) to High(SudokuTests) do
	begin
		Writeln(SolveSudoku(CreateSudokuStruct(SudokuTests[i]), cbFoundSolution));
	end;
end;

function cbOnCrossing(const Status: TSudokuStatus): Boolean;
begin
	if Status.Status=ssCrossFailed then
	begin
		Writeln(Status.Index, #9, Status.EmptyCount, #9, 81-Status.EmptyCount);
	end;
	Result	:= True;
end;

procedure testGenerate;
var
	s, cs: TSudokuStruct;
  t1	: DWORD;
begin
	s	:= GenerateSudoku;
	Writeln(dbgToString(s));
	Writeln(Ord(CheckStatus(s, True)));

  t1	:= GetTickCount;
	cs	:= CrossSudoku(s, cbOnCrossing);
  t1	:= GetTickCount - t1;
	Writeln(dbgToString(cs));
	Writeln(Format('%d %dms', [Ord(CheckStatus(cs, True)), t1]));
end;
{$ENDIF}

{$R *.dfm}

procedure TfrmSudoku.FormCreate(Sender: TObject);
begin
	FPaused	:= True;
	FTiles	:= TTileContainer.Create(imgTiles.Canvas);
	FTiles.TileSize		:= 66;
	FTiles.Font.Size	:= 30;
end;

procedure TfrmSudoku.FormDestroy(Sender: TObject);
begin
	FTiles.Free;
end;

procedure TfrmSudoku.imgTilesMouseDown(Sender: TObject;
	Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
	if FPaused then
		Exit;

end;

procedure TfrmSudoku.imgTilesMouseMove(Sender: TObject; Shift: TShiftState;
	X, Y: Integer);
begin
	if FPaused then
		Exit;

	FTiles.HoveringTile	:= FTiles.GetTileAtPoint(X, Y);
end;

procedure TfrmSudoku.Button1Click(Sender: TObject);
begin
{$IFDEF DEBUG}
	testSolve;
{$ENDIF}
	FTiles.InitRandom;
	FTiles.Repaint;
	FTiles.AutoNotifyChanged	:= True;
	FPaused	:= False;
end;

procedure TfrmSudoku.Button2Click(Sender: TObject);
begin
{$IFDEF DEBUG}
	testGenerate;
{$ENDIF}
end;

end.
