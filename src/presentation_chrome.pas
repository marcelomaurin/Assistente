unit presentation_chrome;
{ Visual parts of the presentation mode: block step bar and spoken caption.
  Both controls only paint state given by the form; they own no flow logic. }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, Graphics, Math;

const
  ChromeDark = $00261610;      // RGB 16,22,38
  ChromeDarkPanel = $003A2218; // RGB 24,34,58
  ChromeMuted = $00B89A8C;     // RGB 140,154,184
  ChromeAccent = $00F67842;    // RGB 66,120,246
  ChromeDone = $00C3E39F;      // RGB 159,227,195
  ChromeCyan = $00F5E07F;      // RGB 127,224,245

type
  TPresentationStepBar = class(TCustomControl)
  private
    FSteps: TStringList;
    FCurrent: Integer;
    FTitle: string;
    procedure SetCurrent(Value: Integer);
    procedure SetTitle(const Value: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSteps(Values: TStrings);
    function StepCount: Integer;
    property Current: Integer read FCurrent write SetCurrent;
    property Title: string read FTitle write SetTitle;
  end;

  TPresentationCaption = class(TCustomControl)
  private
    FText, FTag: string;
    procedure SetText(const Value: string);
    procedure SetTagText(const Value: string);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Text: string read FText write SetText;
    property TagText: string read FTag write SetTagText;
  end;

function FitText(ACanvas: TCanvas; const S: string; MaxWidth: Integer): string;

implementation

function FitText(ACanvas: TCanvas; const S: string; MaxWidth: Integer): string;
var Count: Integer;
begin
  Result := S;
  if (MaxWidth <= 0) or (ACanvas.TextWidth(S) <= MaxWidth) then Exit;
  Count := Length(S);
  while (Count > 0) and (ACanvas.TextWidth(Copy(S, 1, Count) + '…') > MaxWidth) do Dec(Count);
  { Avoid cutting inside a UTF-8 sequence. }
  while (Count > 0) and ((Ord(S[Count + 1]) and $C0) = $80) do Dec(Count);
  Result := Copy(S, 1, Count) + '…';
end;

constructor TPresentationStepBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSteps := TStringList.Create;
  FCurrent := -1;
  Color := ChromeDark;
  DoubleBuffered := True;
  Height := 40;
end;

destructor TPresentationStepBar.Destroy;
begin
  FSteps.Free;
  inherited Destroy;
end;

procedure TPresentationStepBar.SetSteps(Values: TStrings);
begin
  FSteps.Clear;
  if Values <> nil then FSteps.AddStrings(Values);
  if FCurrent >= FSteps.Count then FCurrent := FSteps.Count - 1;
  Invalidate;
end;

function TPresentationStepBar.StepCount: Integer;
begin
  Result := FSteps.Count;
end;

procedure TPresentationStepBar.SetCurrent(Value: Integer);
begin
  if Value = FCurrent then Exit;
  FCurrent := Value;
  Invalidate;
end;

procedure TPresentationStepBar.SetTitle(const Value: string);
begin
  if Value = FTitle then Exit;
  FTitle := Value;
  Invalidate;
end;

procedure TPresentationStepBar.Paint;
const PadX = 12; Gap = 18; PillH = 28;
var X, Y, I, First, W, TitleW: Integer; R: TRect; S: string;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  Y := Max(0, (Height - PillH) div 2);
  X := 4;
  if FTitle <> '' then begin
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := clWhite;
    S := FitText(Canvas, FTitle, Max(60, Width div 4));
    TitleW := Canvas.TextWidth(S);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(X, (Height - Canvas.TextHeight(S)) div 2, S);
    Inc(X, TitleW + 20);
  end;
  Canvas.Font.Style := [];
  if FSteps.Count = 0 then Exit;
  { Keep the current block and the previous one in view; later blocks are
    drawn while space remains and the rest is summarized as "+N". }
  First := Max(0, FCurrent - 1);
  if First > 0 then begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := ChromeMuted;
    S := '… ';
    Canvas.TextOut(X, (Height - Canvas.TextHeight(S)) div 2, S);
    Inc(X, Canvas.TextWidth(S));
  end;
  for I := First to FSteps.Count - 1 do begin
    S := FSteps[I];
    if I < FCurrent then S := '✓ ' + S else if I = FCurrent then S := '● ' + S;
    if I = FCurrent then Canvas.Font.Style := [fsBold] else Canvas.Font.Style := [];
    S := FitText(Canvas, S, 220);
    W := Canvas.TextWidth(S) + 2 * PadX;
    if (I > FCurrent) and (X + W + 40 > Width) then begin
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Style := [];
      Canvas.Font.Color := ChromeMuted;
      S := '+' + IntToStr(FSteps.Count - I);
      Canvas.TextOut(X, (Height - Canvas.TextHeight(S)) div 2, S);
      Break;
    end;
    R := Rect(X, Y, X + W, Y + PillH);
    Canvas.Brush.Style := bsSolid;
    if I = FCurrent then begin
      Canvas.Brush.Color := ChromeAccent; Canvas.Pen.Color := ChromeAccent; Canvas.Font.Color := clWhite;
    end else begin
      Canvas.Brush.Color := ChromeDarkPanel; Canvas.Pen.Color := ChromeDarkPanel;
      if I < FCurrent then Canvas.Font.Color := ChromeDone else Canvas.Font.Color := ChromeMuted;
    end;
    Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, PillH, PillH);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(R.Left + PadX, R.Top + (PillH - Canvas.TextHeight(S)) div 2, S);
    Inc(X, W + Gap);
    if I < FSteps.Count - 1 then begin
      Canvas.Font.Style := [];
      Canvas.Font.Color := ChromeMuted;
      Canvas.TextOut(X - Gap + 5, (Height - Canvas.TextHeight('›')) div 2, '›');
    end;
  end;
end;

constructor TPresentationCaption.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := ChromeDark;
  DoubleBuffered := True;
  FTag := 'LEGENDA';
  Height := 48;
end;

procedure TPresentationCaption.SetText(const Value: string);
begin
  if Value = FText then Exit;
  FText := Value;
  Invalidate;
end;

procedure TPresentationCaption.SetTagText(const Value: string);
begin
  if Value = FTag then Exit;
  FTag := Value;
  Invalidate;
end;

procedure TPresentationCaption.Paint;
var R: TRect; X: Integer; S: string; Style: TTextStyle;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Brush.Color := ChromeDarkPanel;
  Canvas.Pen.Color := ChromeDarkPanel;
  Canvas.RoundRect(0, 0, Width - 1, Height - 1, 16, 16);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Assign(Font);
  X := 16;
  if FTag <> '' then begin
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Height := -11;
    Canvas.Font.Color := ChromeCyan;
    Canvas.TextOut(X, (Height - Canvas.TextHeight(FTag)) div 2, FTag);
    Inc(X, Canvas.TextWidth(FTag) + 14);
  end;
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := clWhite;
  R := Rect(X, 4, Width - 14, Height - 4);
  Style := Canvas.TextStyle;
  Style.Layout := tlCenter;
  Style.Wordbreak := True;
  Style.SingleLine := False;
  Style.EndEllipsis := True;
  Style.Clipping := True;
  S := FText;
  Canvas.TextRect(R, R.Left, R.Top, S, Style);
end;

end.
