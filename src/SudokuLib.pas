unit SudokuLib;

interface

{$INCLUDE 'versions.inc'}

uses
  SysUtils;
  
type
	TSudokuTiles	= array[0..8, 0..8]of Byte;
	TSudokuArray	= array[0..80]of Byte;
	TSudokuDataStatus = (
		ssUnknown, ssSolved, ssInvalid,
		ssUnsolvable, ssOnlySolution, ssMuitiSolution,
		ssCrossing, ssCrossFailed );

	TSudokuStruct = record
	case Boolean of
		True	: ( TileArray: TSudokuArray; );
		False	: ( Tiles: TSudokuTiles; );
	end;
	PSudokuStruct = ^TSudokuStruct;

	TSudokuMask = set of 0..9;

	TSudokuStatus = record
		Status: TSudokuDataStatus;
		EmptyCount: Byte;
		Index: Integer;
		Sudoku: PSudokuStruct;
		UserData: Pointer;
	end;

	TSudokuCallback = function(const Status: TSudokuStatus): Boolean;
	TSudokuEvent = function(const Status: TSudokuStatus): Boolean of object;

	function SudokuTilesToStruct(const Tiles: TSudokuTiles): TSudokuStruct; {$I 'inline.inc'}
	function SudokuArrayToStruct(const TileArray: TSudokuArray): TSudokuStruct; {$I 'inline.inc'}
	function CreateSudokuStruct(const Tiles: TSudokuTiles): TSudokuStruct; overload; {$I 'inline.inc'}
	function CreateSudokuStruct(const TileArray: TSudokuArray): TSudokuStruct; overload; {$I 'inline.inc'}

	function IsValid(const sudoku: TSudokuStruct): Boolean; {$I 'inline.inc'}
	function IsSolved(const sudoku: TSudokuStruct): Boolean; {$I 'inline.inc'}
	function CheckStatus(const sudoku: TSudokuStruct; CheckSolvable: Boolean = False): TSudokuDataStatus;

	function SolveSudoku(const sudoku: TSudokuStruct; cb: TSudokuCallback; UserData: Pointer = nil): Integer; overload;
	function SolveSudoku(const sudoku: TSudokuStruct; e: TSudokuEvent; UserData: Pointer = nil): Integer; overload;

	function FindSolution(var sudoku: TSudokuStruct): TSudokuDataStatus;

	function GenerateSudoku: TSudokuStruct;

	function CrossSudoku(const sudoku: TSudokuStruct; cb: TSudokuCallback; UserData: Pointer = nil): TSudokuStruct; overload;
	function CrossSudoku(const sudoku: TSudokuStruct; e: TSudokuEvent = nil; UserData: Pointer = nil): TSudokuStruct; overload;

{$IFDEF DEBUG}
	function dbgToString(const sudoku: TSudokuStruct): string;
{$ENDIF}

implementation

{$INCLUDE 'relative.inc'}

const
	FullMask	= [1..9];

type
	TEventStruct	= array[0..1]of Pointer;
	PEventStruct	= ^TEventStruct;

function CountMaskSet(const M: TSudokuMask): Integer;
{$IFNDEF PUREPASCAL}
asm
{$IFDEF Win64}
	movzx		eax, cx
	popcnt	eax, eax
{$ELSE Win64}
	movzx		eax, ax
{$IFDEF DELPHI_2005_UP}
	popcnt	eax, eax
{$ELSE DELPHI_2005_UP}
	db	$F3, $0F, $B8, $C0	//popcnt	eax, eax
{$ENDIF DELPHI_2005_UP}
{$ENDIF Win64}
end;
{$ELSE PUREPASCAL}
var
	x: Word;
begin
	x := Word((@M)^);
	x := (x and $5555) + ((x shr 1) and $5555);
	x := (x and $3333) + ((x shr 2) and $3333);
	x := (x and $0F0F) + ((x shr 4) and $0F0F);
	Result := (x and $00FF) + (x shr 8);
end;
{$ENDIF PUREPASCAL}

procedure Shuffle(var Numbers: array of Byte);
var
  i: Integer;
  r, t: Byte;
begin
  for i := High(Numbers) downto 0 do
  begin
    r := Random(i+1);
    if i=r then
    	Continue;
    t := Numbers[i];
    Numbers[i] := Numbers[r];
    Numbers[r] := t;
  end;  
end;

{$IFDEF DEBUG}
function dbgToString(const sudoku: TSudokuStruct): string;
var
	r, c: Integer;
	s: string;
	p: PChar;
begin
	Result	:= '====================='#13#10;
	for r := 0 to 8 do
	begin
		if (r > 0) and (r mod 3 = 0) then
			Result	:= Result + '------+-------+------'#13#10;

		s	:= '0 0 0 | 0 0 0 | 0 0 0'#13#10;
		UniqueString(s);
		p	:= Pointer(s);
		for c := 0 to 8 do
		begin
			p[(c+c div 3)*2]	:= Chr(Ord('0') + sudoku.Tiles[r, c]);
		end;
		Result	:= Result + s;
	end;
	Result	:= Result + '=====================';
end;
{$ENDIF}

function SudokuTilesToStruct(const Tiles :TSudokuTiles): TSudokuStruct;
begin
	Result.Tiles := Tiles;
end;

function SudokuArrayToStruct(const TileArray :TSudokuArray): TSudokuStruct;
begin
	Result.TileArray := TileArray;
end;

function CreateSudokuStruct(const Tiles :TSudokuTiles): TSudokuStruct;
begin
	Result.Tiles := Tiles;
end;

function CreateSudokuStruct(const TileArray :TSudokuArray): TSudokuStruct;
begin
	Result.TileArray := TileArray;
end;

function CheckStatus_OnFoundSolution(const Status: TSudokuStatus): Boolean;
begin
	Result := Status.Index <= 1;
end;

function CheckStatus(const sudoku: TSudokuStruct; CheckSolvable: Boolean): TSudokuDataStatus;
	function FindSolutionCount(const sudoku: TSudokuStruct): Integer;
	begin
		Result	:= SolveSudoku(sudoku, @CheckStatus_OnFoundSolution);
	end;
type
	TCountor = array[0..9]of Byte;
const
	MtxCoord	: array[0..8] of record
			r, c: Byte;
		end = (
			( r: 0; c: 0; ), ( r: 0; c: 3; ), ( r: 0; c: 6; ),
			( r: 3; c: 0; ), ( r: 3; c: 3; ), ( r: 3; c: 6; ),
			( r: 6; c: 0; ), ( r: 6; c: 3; ), ( r: 6; c: 6; )
		);
var
	has0: Boolean;
	row, col, mtx: TCountor;
	i, j, r, c: Byte;
	function IsInvalid(r, c: Byte; var x: TCountor): Boolean;
	var v, t: Byte;
	begin
		Result := True;
		v := sudoku.Tiles[r, c];
		if v > 9 then
			Exit;

		t := x[v]+1;
		if (v>0) and (t>1) then
			Exit;

		x[v] := t;
  	Result := False;
	end;
begin
	has0 := False;

	for i := 0 to 8 do
	begin
		FillChar(row, SizeOf(row), 0);
		FillChar(col, SizeOf(col), 0);
		FillChar(mtx, SizeOf(mtx), 0);
		r	:= MtxCoord[i].r;
		c	:= MtxCoord[i].c;

		for j := 0 to 8 do
		begin
			if 	IsInvalid(i, j, row) or
					IsInvalid(j, i, col) or
					IsInvalid(j div 3 + r, j mod 3 + c, mtx) then
			begin
				Result	:= ssInvalid;
				Exit;
			end;
		end;

		has0 := has0 or (row[0]>0) or (col[0]>0) or (mtx[0]>0);
	end;

	if has0 then
	begin
		if CheckSolvable then
		begin
			case FindSolutionCount(sudoku) of
				0:		Result	:= ssUnsolvable;
				1:		Result	:= ssOnlySolution;
				else	Result	:= ssMuitiSolution;
			end;
			Exit;
		end;
		Result := ssUnknown;
		Exit;
	end;
	Result := ssSolved;
end;

function IsValid(const sudoku: TSudokuStruct): Boolean;
begin
	Result	:= CheckStatus(sudoku) in [ssUnknown, ssSolved];
end;

function IsSolved(const sudoku: TSudokuStruct): Boolean;
begin
	Result	:= CheckStatus(sudoku)=ssSolved;
end;

function SolveSudoku_OnFoundEvent(cb: TSudokuCallback; const Status: TSudokuStatus): Boolean;
begin
	if Assigned(cb) then
		Result := cb(Status)
	else
		Result := True;
end;

function SolveSudoku(const sudoku: TSudokuStruct; cb: TSudokuCallback; UserData: Pointer): Integer;
var
	e: TSudokuEvent;
	p: PEventStruct;
begin
	p	:= @@e;
	p[0]	:= @SolveSudoku_OnFoundEvent;
	p[1]	:= @cb;
  Result := SolveSudoku(sudoku, e, UserData);
end;

function SolveSudoku(const sudoku: TSudokuStruct; e: TSudokuEvent; UserData: Pointer): Integer;
var
	tiles: TSudokuArray;
	status: TSudokuStatus;
	candMask	: array[0..80]of TSudokuMask;
	unsetIndex, candCount : array[0..80]of Byte;
	unsetCnt : Integer;
	goon : Boolean;

	procedure DoNextTile;
  var
    i : Integer;
    minIndex, minCount, minRefUnsetIdx : Integer;
    idx, cnt : Integer;
		bakMasks : array[0..80]of TSudokuMask;
    bakCount : array[0..80]of Byte;
    PRelRef : PByteArray;
		ccMask : TSudokuMask;
		procedure TryCandidate(v: Byte);
    var
			j, rel, t : Integer;
      msk	: TSudokuMask;
    begin
			tiles[minIndex] := v;

      // update relatived
      for j := 0 to 19 do
      begin
        rel := PRelRef[j];
				if tiles[rel]<>0 then
        	Continue;

        msk := bakMasks[rel];
				if v in msk then
				begin
					candMask[rel]	:= msk;
					candCount[rel]	:= bakCount[rel];
				end else
				begin
					t := bakCount[rel] - 1;
					if t=0 then
						Exit;
					Include(msk, v);
					candMask[rel]	:= msk;
					candCount[rel] := t;
				end;
      end;

      if goon then
				DoNextTile;
    end;
  begin
    // found and fire event!
    if unsetCnt=0 then
    begin
      Inc(Result);
			if Assigned(e) then
			begin
				status.Index := Result;
				status.EmptyCount := 0;
				goon	:= e(status);
			end;
			Exit;
		end;

		// find next min to try
		minCount := 9;
    minRefUnsetIdx	:= -1;
    for i := 0 to unsetCnt-1 do
    begin
      idx	:= unsetIndex[i];
      cnt := candCount[idx];
      if cnt >= minCount then
      	Continue;

      minIndex := idx;
      minRefUnsetIdx := i;
      minCount := cnt;
		end;
		if tiles[minIndex]<>0 then
    	Writeln(minIndex);
    PRelRef := @RelativedTiles[minIndex];
    ccMask	:= candMask[minIndex];

    // backup
    Move(candMask, bakMasks, SizeOf(candMask));
    Move(candCount, bakCount, SizeOf(candCount));
    Dec(unsetCnt);
    unsetIndex[minRefUnsetIdx] := unsetIndex[unsetCnt];

		// try each one candidate
{$IFDEF DELPHI_2005_UP}
		for i in FullMask - ccMask do
		begin
			if not goon then
				Exit;
			TryCandidate(i);
		end;
{$ELSE}
		for i := 1 to 9 do
		begin
			if not goon then
				Exit;
			if i in ccMask then
				Continue;
			TryCandidate(i);
		end;
{$ENDIF}

    // restore
		tiles[minIndex] := 0;
    Move(bakMasks, candMask, SizeOf(candMask));
		Move(bakCount, candCount, SizeOf(candCount));
		unsetIndex[minRefUnsetIdx] := minIndex;
		Inc(unsetCnt);
	end;

	procedure Prepare;
	var
    i, j : Integer;
    v : Byte;
	begin
		tiles	:= sudoku.TileArray;
		FillChar(candMask, SizeOf(candMask), 0);
		unsetCnt := 0;
		for i := Low(tiles)  to High(tiles) do
		begin
			v := tiles[i];
			if v=0 then
			begin
				unsetIndex[unsetCnt] := i;
				Inc(unsetCnt);
				Continue;
			end;

			for j := Low(RelativedTiles[i]) to High(RelativedTiles[i]) do
				Include(candMask[RelativedTiles[i, j]], v);
		end;

		for i := Low(tiles)  to High(tiles) do
			candCount[i] := 9-CountMaskSet(candMask[i]);
	end;
begin
	if not IsValid(sudoku) then
	begin
		if Assigned(e) then
		begin
			status.UserData := UserData;
			status.Sudoku := @sudoku;
			status.Index := -1;
			status.EmptyCount := 0;
			status.Status := ssInvalid;
			goon	:= e(status);
		end;
		Result := -1;
		Exit;
	end;

	status.UserData := UserData;
	status.Sudoku := @tiles;
	status.Status	:= ssSolved;
	Prepare;

	Result := 0;
	goon	:= True;
	DoNextTile;
	{
	if (Result=0) and Assigned(e) then
	begin
		status.Index := 0;
		status.EmptyCount := 0;
		status.Status	:= ssUnsolvable;
	end;	//}
end;

type
	TCBData	= record
		pResult: ^TSudokuDataStatus;
		pSudoku: PSudokuStruct;
	end;

function FindSolution_OnFoundEvent(const Status: TSudokuStatus): Boolean;
var p: ^TCBData;
begin
	p	:= Status.UserData;
	p.pResult^	:= Status.Status;
	p.pSudoku^	:= Status.Sudoku^;
	Result := False;
end;

function FindSolution(var sudoku: TSudokuStruct): TSudokuDataStatus;
var
	r : TCBData;
begin
	r.pResult	:= @Result;
	r.pSudoku	:= @sudoku;
	SolveSudoku(sudoku, @FindSolution_OnFoundEvent, @r);
end;

function GenerateSudoku: TSudokuStruct;
const
	MtxCoord	: array[0..2] of record
			r, c: Byte;
		end = (
			( r: 0; c: 0; ), ( r: 3; c: 3; ), ( r: 6; c: 6; )
		);
	Singles : array[0..5] of record
			r, c: Byte;
		end = (
			( r: 0; c: 5; ), ( r: 0; c: 8; ),
			( r: 4; c: 1; ), ( r: 4; c: 7; ),
			( r: 8; c: 0; ), ( r: 8; c: 3; )
		);
var
	i, j, br, bc : Integer;
	num: array[0..8] of Byte;
	used: TSudokuMask;
begin
	for i := Low(num) to High(num) do
		num[i] := i+1;
	repeat
		FillChar(Result, SizeOf(Result), 0);
		// Fill Matrix
		for i := Low(MtxCoord) to High(MtxCoord) do
		begin
			br	:= MtxCoord[i].r;
			bc	:= MtxCoord[i].c;
			Shuffle(num);
			for j := 0 to 8 do
				Result.Tiles[j div 3 + br, j mod 3 + bc]	:= num[j];
		end;

		// Fill Points
		for i := Low(Singles) to High(Singles) do
		begin
			used	:= [];
			br	:= Singles[i].r;
			bc	:= Singles[i].c;

			for j := 0 to 8 do
			begin
				Include(used, Result.Tiles[br, j]);
				Include(used, Result.Tiles[j, bc]);
			end;

			repeat
				j := Random(8)+1;
			until not (j in used);
			Result.Tiles[br, bc]	:= j;
		end;
	until FindSolution(Result) = ssSolved;
end;

function CrossSudoku_OnCrossingEvent(cb: TSudokuCallback; const Status: TSudokuStatus): Boolean;
begin
	if Assigned(cb) then
		Result	:= cb(Status)
	else
		Result	:= True;
end;

function CrossSudoku(const sudoku: TSudokuStruct; cb: TSudokuCallback; UserData: Pointer): TSudokuStruct;
var
	e: TSudokuEvent;
	p: PEventStruct;
begin
	p	:= @@e;
	p[0]	:= @CrossSudoku_OnCrossingEvent;
	p[1]	:= @cb;
	Result	:= CrossSudoku(sudoku, e, UserData);
end;

function CrossSudoku_OnFoundSolution(const Status: TSudokuStatus): Boolean;
begin
	Result := Status.Index <= 1;
end;

function CrossSudoku(const sudoku: TSudokuStruct; e: TSudokuEvent; UserData: Pointer): TSudokuStruct;
	function FindSolutionCount(const sudoku: TSudokuStruct): Integer;
	begin
		Result	:= SolveSudoku(sudoku, CrossSudoku_OnFoundSolution);
  end;
const
	MaxTry = 24;
var
	i, last: Integer;
	eventData	: TSudokuStatus;
	index	: array[0..80]of Byte;
	//succ	: Boolean;
	status	: TSudokuDataStatus;
	failed, rnd, rIdx, t: Integer;
begin
	eventData.Index			:= 0;
	eventData.Sudoku		:= @sudoku;
	eventData.UserData	:= UserData;

	// pre-check
	status	:= CheckStatus(sudoku, True);
	case status of
		ssSolved:
		begin
			eventData.EmptyCount	:= 0;
			last	:= 81;
			for i := 0 to 80 do
				index[i]	:= i;
		end;
		ssOnlySolution:
		begin
			last	:= 0;
			for i := 0 to 80 do
			begin
				if sudoku.TileArray[i] = 0 then
					Continue;
				index[last]	:= i;
				Inc(last);
			end;
			eventData.EmptyCount	:= 81 - last;
		end;
		else
		begin
			if Assigned(e) then
			begin
				eventData.Status	:= status;
				e(eventData);
			end;
			Exit;
		end;
	end;

	eventData.Status	:= ssCrossing;
	eventData.Sudoku	:= @Result;
	Result.Tiles	:= sudoku.Tiles;

	if (last < 18) then
	begin
		Result	:= sudoku;
		Exit;
	end;

	failed	:= 0;
	while failed <= last do
	begin
		rnd		:= failed + Random(last - failed);
		ridx	:= index[rnd];
		t	 		:= Result.TileArray[rIdx];
		Result.TileArray[rIdx]	:= 0;

		if FindSolutionCount(Result) = 1 then
		begin
			// succ
      Inc(eventData.EmptyCount);
			if Assigned(e) and (not e(eventData)) then
				Exit;

			if rnd < last then
				index[rnd]	:= index[last];
			Dec(last);
		end else
		begin
			// fail
			Result.TileArray[rIdx]	:= t;
			index[rIdx]		:= index[failed];
			Inc(failed);
		end;
	end;

	if Assigned(e) then
	begin
		eventData.Status  := ssCrossFailed;
		e(eventData);
	end;
end;

end.
