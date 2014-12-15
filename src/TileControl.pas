unit TileControl;

interface

uses
	SysUtils, Classes, Graphics, Windows, SudokuLib;

type
	TColorItem	= ( ciBackground, ciBorder, ciDigit );
	TDigitStatus	= ( dsEmpty, dsFixed, dsRight, dsWrong );
	TInteractStatus	= ( isNormal, isSelected, isNormalHover, isSelectedHover );

	TUIBuff		= ( ubSelected, ubHovering );
	TUIBuffs	= set of TUIBuff;

	TTileItem	= class;

	TTileContainer	= class
	private
		FCanvas: TCanvas;
		FTileSize: Integer;
		FColorSettings: array[TColorItem, TDigitStatus, TInteractStatus] of TColor;
		FAutoNotifyChanged, FAutoNotifyChangedBackup: Boolean;
		FTiles: array[0..80] of TTileItem;
		FSelectedTile, FHoveringTile: TTileItem;
    FBackgroundColorEven: TColor;
    FBackgroundColorOdd: TColor;
    FBorderWeight: Integer;

		function GetTile(row, col: Integer): TTileItem;
		function GetTiles(index: Integer): TTileItem;
		procedure SetTileSize(const Value: Integer);
    procedure SetFont(const Value: TFont);
    function GetFont: TFont;
    function GetColorSettings(const Item: TColorItem;
      const Status: TDigitStatus; const UIBuff: TUIBuffs): TColor;
    procedure SetColorSettings(const Item: TColorItem;
      const Status: TDigitStatus; const UIBuff: TUIBuffs;
      const Value: TColor);
    procedure SetHoveringTile(const Value: TTileItem);
    procedure SetSelectedTile(const Value: TTileItem);
    procedure SetBackgroundColorEven(const Value: TColor);
    procedure SetBackgroundColorOdd(const Value: TColor);
    procedure SetBorderWeight(const Value: Integer);
	protected
		procedure DrawBackground;
	public
		constructor Create(ACanvas: TCanvas);
		destructor Destroy; override;
		procedure Reset;

		procedure InitSolution(const solution: TSudokuStruct);
		procedure SetMystery(const initial: TSudokuStruct);
		procedure InitSudoku(const solution, initial: TSudokuStruct);
		procedure InitRandomSudoku(const solution: TSudokuStruct);
		procedure InitRandom;

		procedure BeginUpdate;
		procedure EndUpdate;
		procedure EndUpdateAndDraw;
		procedure Repaint;
		procedure SettingChanged;

		function GetTileAtPoint(X, Y: Integer): TTileItem;

		property Canvas: TCanvas read FCanvas;
		property Font: TFont read GetFont write SetFont;
		property TileSize: Integer read FTileSize write SetTileSize;
		property BorderWeight: Integer read FBorderWeight write SetBorderWeight;

		property BackgroundColorOdd: TColor read FBackgroundColorOdd write SetBackgroundColorOdd;
		property BackgroundColorEven: TColor read FBackgroundColorEven write SetBackgroundColorEven;
		property ColorSettings[const Item: TColorItem; const Status: TDigitStatus; const UIBuff: TUIBuffs]: TColor
				read GetColorSettings write SetColorSettings;

		property Tiles[index: Integer]: TTileItem read GetTiles;
		property Tile[row, col: Integer]: TTileItem read GetTile; default;
		property SelectedTile: TTileItem read FSelectedTile write SetSelectedTile;
		property HoveringTile: TTileItem read FHoveringTile write SetHoveringTile;
		property AutoNotifyChanged: Boolean read FAutoNotifyChanged write FAutoNotifyChanged;
	end;

	TTileItem	= class
	private
		FContainer: TTileContainer;
		FRow, FCol: Byte;
		FRightDigit, FDigit: Byte;
		FDigitStatus: TDigitStatus;
		FIsDirty: Boolean;
    FUIBuffs: TUIBuffs;

		procedure SetDigit(const Value: Byte);
		procedure SetDigitStatus(const Value: TDigitStatus);
    procedure SetUIBuffs(const Value: TUIBuffs);
	protected
		procedure NotifyChanged;
		procedure DrawBackground(Color: TColor; X, Y, W: Integer);
		procedure DrawBorder(Color: TColor; X, Y, W: Integer);
		procedure DrawDigit(Color: TColor; X, Y, W: Integer);
	public
		constructor Create(AContainer: TTileContainer; const ARow, ACol: Byte);
		procedure Draw;
		procedure Reset;

		property Container: TTileContainer read FContainer;
		property Row: Byte read FRow;
		property Col: Byte read FCol;
		property IsDirty: Boolean read FIsDirty;

		property RightDigit: Byte read FRightDigit write FRightDigit;
		property Digit: Byte read FDigit write SetDigit;

		property DigitStatus: TDigitStatus read FDigitStatus write SetDigitStatus;
		property UIBuffs: TUIBuffs read FUIBuffs write SetUIBuffs;
	end;

implementation

const
	DefaultColorSettings: array[TColorItem, TDigitStatus, TInteractStatus] of TColor = (
		// ciBackground
		(
			// dsEmpty
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clWhite, clSkyBlue, clInfoBk, clSkyBlue ),
			// dsFixed
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clSilver, clGray, clSilver, clGray ),
			// dsRight
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clMoneyGreen, clLime, clMoneyGreen, clLime ),
			// dsWrong
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clMaroon, clRed, clMaroon, clRed )
		),
		// ciBorder
		(
			// dsEmpty
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clBlack, clGreen, clBlue, clLime ),
			// dsFixed
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clBlack, clGreen, clBlue, clLime ),
			// dsRight
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clBlack, clGreen, clBlue, clLime ),
			// dsWrong
				// [], [Selected], [Hovering], [Selected, Hovering]
				( clBlack, clGreen, clBlue, clLime )
		),
		// ciDigit
		(
			// isNormal
				// dsEmpty, dsFixed, dsRight, dsWrong
				( clBlack, clBlack, clBlack, clWhite ),
			// isSelected
				// dsEmpty, dsFixed, dsRight, dsWrong
				( clBlack, clBlack, clBlack, clWhite ),
			// isHover
				// dsEmpty, dsFixed, dsRight, dsWrong
				( clBlack, clBlack, clBlack, clWhite ),
			// isSelHover
				// dsEmpty, dsFixed, dsRight, dsWrong
				( clBlack, clBlack, clBlack, clWhite )
		)
	);

{ TTileContainer }

procedure TTileContainer.BeginUpdate;
begin
	FAutoNotifyChangedBackup	:= AutoNotifyChanged;
	AutoNotifyChanged	:= False;
end;

constructor TTileContainer.Create(ACanvas: TCanvas);
var
	r, c: Integer;
begin
	FCanvas	:= ACanvas;
	FTileSize	:= 50;
	FBorderWeight	:= 2;
	FBackgroundColorOdd		:= clAqua;
	FBackgroundColorEven	:= clWhite;

	Move(DefaultColorSettings, FColorSettings, SizeOf(DefaultColorSettings));
	for r := 0 to 8 do
		for c := 0 to 8 do
			FTiles[r*9 + c]	:= TTileItem.Create(Self, r, c);
end;

destructor TTileContainer.Destroy;
var
	i: Integer;
begin
	FAutoNotifyChanged	:= False;
	for i := Low(FTiles) to High(FTiles) do
		FTiles[i].Free;
	inherited;
end;

procedure TTileContainer.DrawBackground;
var
	i, t, x, y, w: Integer;
begin
	w	:= TileSize * 3 + 1;

	Canvas.Brush.Color	:= BackgroundColorOdd;
	for i := 0 to 3 do
	begin
		// 1, 3, 5, 7
		t	:= 1+i*2;
		x	:= t mod 3 * w;
		y	:= t div 3 * w;
		Canvas.FillRect(Rect(x, y, x+w, y+w));
	end;

	Canvas.Brush.Color	:= BackgroundColorEven;
	for i := 0 to 4 do
	begin
		// 0 2 4 6 8
		t	:= i*2;
		x	:= t mod 3 * w;
		y	:= t div 3 * w;
		Canvas.FillRect(Rect(x, y, x+w, y+w));
	end;
end;

procedure TTileContainer.EndUpdate;
begin
	AutoNotifyChanged	:= FAutoNotifyChangedBackup;
end;

procedure TTileContainer.EndUpdateAndDraw;
begin
	EndUpdate;
	Repaint;
end;

function TTileContainer.GetColorSettings(const Item: TColorItem;
  const Status: TDigitStatus; const UIBuff: TUIBuffs): TColor;
begin
	Result	:= FColorSettings[Item, Status, TInteractStatus((@UIBuff)^)];
end;

function TTileContainer.GetFont: TFont;
begin
	if Assigned(FCanvas) then
		Result	:= FCanvas.Font
	else
		Result	:= nil;
end;

function TTileContainer.GetTile(row, col: Integer): TTileItem;
begin
	Result	:= FTiles[row*9 + col];
end;

function TTileContainer.GetTileAtPoint(X, Y: Integer): TTileItem;
begin
	X	:= X div TileSize;
	Y	:= Y div TileSize;
	if (X >= 0) and (X <= 8) and (Y >= 0) and (Y <= 8) then
		Result	:= Tile[Y, X]
	else
		Result	:= nil;
end;

function TTileContainer.GetTiles(index: Integer): TTileItem;
begin
	Result	:= FTiles[index];
end;

procedure TTileContainer.InitRandom;
begin
	InitRandomSudoku(GenerateSudoku);
end;

procedure TTileContainer.InitRandomSudoku(
	const solution: TSudokuStruct);
begin
	InitSolution(solution);
	SetMystery(CrossSudoku(solution));
end;

procedure TTileContainer.InitSolution(const solution: TSudokuStruct);
var i: Integer;
begin
	Reset;
	BeginUpdate;
	for i := 0 to 80 do
		Tiles[i].RightDigit	:= solution.TileArray[i];
	EndUpdate;
end;

procedure TTileContainer.InitSudoku(const solution,
	initial: TSudokuStruct);
begin
	InitSolution(solution);
	SetMystery(initial);
end;

procedure TTileContainer.Repaint;
var
	i: Integer;
begin
	DrawBackground;
	for i := Low(FTiles) to High(FTiles) do
		FTiles[i].Draw;
end;

procedure TTileContainer.Reset;
var i: Integer;
begin
	FHoveringTile	:= nil;
	FSelectedTile	:= nil;
	for i := 0 to 80 do
		Tiles[i].Reset;
end;

procedure TTileContainer.SetBackgroundColorEven(const Value: TColor);
begin
	if FBackgroundColorEven = Value then
		Exit;

	FBackgroundColorEven := Value;
	SettingChanged;
end;

procedure TTileContainer.SetBackgroundColorOdd(const Value: TColor);
begin
	if FBackgroundColorOdd = Value then
		Exit;

	FBackgroundColorOdd := Value;
	SettingChanged;
end;

procedure TTileContainer.SetBorderWeight(const Value: Integer);
begin
	if FBorderWeight = Value then
		Exit;

	FBorderWeight := Value;
	SettingChanged;
end;

procedure TTileContainer.SetColorSettings(const Item: TColorItem;
  const Status: TDigitStatus; const UIBuff: TUIBuffs; const Value: TColor);
begin
	if FColorSettings[Item, Status, TInteractStatus((@UIBuff)^)] = Value then
		Exit;

	FColorSettings[Item, Status, TInteractStatus((@UIBuff)^)]	:= Value;
	SettingChanged;
end;

procedure TTileContainer.SetFont(const Value: TFont);
begin
	if Assigned(FCanvas) then
		FCanvas.Font.Assign(Value);
	SettingChanged;
end;

procedure TTileContainer.SetHoveringTile(const Value: TTileItem);
begin
	if FHoveringTile = Value then
		Exit;

	if Assigned(FHoveringTile) then
		FHoveringTile.UIBuffs	:= FHoveringTile.UIBuffs - [ubHovering];
	if Assigned(Value) then
		Value.UIBuffs	:= Value.UIBuffs + [ubHovering];
	FHoveringTile := Value;
	SettingChanged;
end;

procedure TTileContainer.SetMystery(const initial: TSudokuStruct);
var i: Integer;
begin
	BeginUpdate;
	for i := 0 to 80 do
	begin
		if initial.TileArray[i] <> 0  then
			Tiles[i].DigitStatus	:= dsFixed;
	end;
	EndUpdate;
end;

procedure TTileContainer.SetSelectedTile(const Value: TTileItem);
begin
	if FSelectedTile = Value then
		Exit;

	if Assigned(FSelectedTile) then
		FSelectedTile.UIBuffs	:= FSelectedTile.UIBuffs - [ubHovering];
	if Assigned(Value) then
		Value.UIBuffs	:= Value.UIBuffs + [ubHovering];
	FSelectedTile := Value;
	SettingChanged;
end;

procedure TTileContainer.SetTileSize(const Value: Integer);
begin
	if FTileSize = Value then
		Exit;

	FTileSize := Value;
	SettingChanged;
end;

procedure TTileContainer.SettingChanged;
var
	i: Integer;
begin
	if AutoNotifyChanged then
	begin
		for i := Low(FTiles) to High(FTiles) do
			FTiles[i].Draw;
	end else
	begin
		for i := Low(FTiles) to High(FTiles) do
			FTiles[i].FIsDirty	:= True;
	end;
end;

{ TTileItem }

constructor TTileItem.Create(AContainer: TTileContainer; const ARow, ACol: Byte);
begin
	FContainer	:= AContainer;
	FIsDirty	:= True;
	FRow	:= ARow;
	FCol	:= ACol;
end;

procedure TTileItem.Draw;
var
	x, y, w: Integer;
begin
	FIsDirty	:= False;
	w	:= Container.TileSize;
	x	:= Col * w + 3;
	y	:= Row * w + 3;
	w	:= w - 3;
	DrawBackground(Container.ColorSettings[ciBackground, FDigitStatus, FUIBuffs], x, y, w);
	DrawBorder(Container.ColorSettings[ciBorder, FDigitStatus, FUIBuffs], x, y, w);
	DrawDigit(Container.ColorSettings[ciDigit, FDigitStatus, FUIBuffs], x, y, w);
end;

procedure TTileItem.DrawBackground(Color: TColor; X, Y, W: Integer);
begin
	Container.Canvas.Brush.Color	:= Color;
  Container.Canvas.FillRect(Rect(X, Y, X+W, Y+W));
end;

procedure TTileItem.DrawBorder(Color: TColor; X, Y, W: Integer);
begin
	if Container.BorderWeight <= 0 then
		Exit;

	Container.Canvas.Pen.Color	:= Color;
	Container.Canvas.Pen.Width	:= Container.BorderWeight;
	Container.Canvas.Rectangle(X, Y, X+W, Y+W);
end;

procedure TTileItem.DrawDigit(Color: TColor; X, Y, W: Integer);
const
  FlagCenter	= DT_CENTER or DT_SINGLELINE or DT_VCENTER;
var
	d: Byte;
	r: TRect;
	t: string;
begin
	d	:= Digit;
	if DigitStatus = dsFixed then
		d	:= RightDigit;
	if d = 0 then
		Exit;

	t	:= IntToStr(d);
	r	:= Rect(X, Y, X+W, Y+W);
	Container.Canvas.Font.Color	:= Color;
  DrawText(Container.Canvas.Handle, Pointer(t), 1, r, FlagCenter);
end;

procedure TTileItem.NotifyChanged;
begin
	FIsDirty	:= True;
	if Container.AutoNotifyChanged then
		Draw;
end;

procedure TTileItem.Reset;
begin
	FRightDigit	:= 0;
	FDigit	:= 0;
	FDigitStatus	:= dsEmpty;
	FUIBuffs	:= [];
	FIsDirty	:= False;
end;

procedure TTileItem.SetDigit(const Value: Byte);
begin
	if FDigit = Value then
		Exit;

	FDigit := Value;
	if Value = RightDigit then
	begin
		// correct
		FDigitStatus	:= dsRight;
	end else if Value = 0 then
	begin
		// empty
		FDigitStatus	:= dsEmpty;
	end else
	begin
		// wrong
		FDigitStatus	:= dsWrong;
	end;
	NotifyChanged;
end;

procedure TTileItem.SetDigitStatus(const Value: TDigitStatus);
begin
	if FDigitStatus = Value then
		Exit;

	FDigitStatus := Value;
	NotifyChanged;
end;

procedure TTileItem.SetUIBuffs(const Value: TUIBuffs);
begin
	if FUIBuffs = Value then
		Exit;

	FUIBuffs := Value;
	if ubSelected in Value then
		Container.SelectedTile	:= Self;

	if ubHovering in Value then
		Container.HoveringTile	:= Self;
	NotifyChanged;
end;

end.
