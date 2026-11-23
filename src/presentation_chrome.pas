unit presentation_chrome;
{ Visual parts of the presentation mode: block step bar and spoken caption.
  Both controls only paint state given by the form; they own no flow logic. }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Controls, Graphics, Math, LCLType;

const
  ChromeDark = $00261610;      // RGB 16,22,38
  ChromeDarkPanel = $003A2218; // RGB 24,34,58
  ChromeMuted = $00B89A8C;     // RGB 140,154,184
  ChromeAccent = $00F67842;    // RGB 66,120,246
  ChromeDone = $00C3E39F;      // RGB 159,227,195
  ChromeCyan = $00F5E07F;      // RGB 127,224,245
  ChromeButtonDark = $004A3326; // RGB 38,51,74
  ChromeAmber = $003CB2F2;     // RGB 242,178,60
  ChromeAmberText = $00001A2A; // RGB 42,26,0
  ChromeBorderDark = $00543D2F; // RGB 47,61,84
  ChromeLight = $00F7EDE8;     // RGB 232,237,247
  { Light theme (settings and question card). }
  ChromeBlue = $00F67842;      // RGB 66,120,246
  ChromePage = $00F8F5F3;      // RGB 243,245,248
  ChromeLine = $00EAE3DD;      // RGB 221,227,234
  ChromeInk = $00362A1F;       // RGB 31,42,54
  ChromeInkMuted = $00857669;  // RGB 105,118,133
  ChromeQuestionHead = $00E6F6FF; // RGB 255,246,230
  ChromeQuestionLine = $00C2E2F3; // RGB 243,226,194
  ChromeQuestionTitle = $00004E7A; // RGB 122,78,0
  ChromeQuestionSub = $002E7BA7;   // RGB 167,123,46
  ChromeOkBack = $00F1F8EC;    // RGB 236,248,241
  ChromeOkLine = $00D5ECC4;    // RGB 196,236,213
  ChromeOkText = $00407A1E;    // RGB 30,122,64

type
  TPresentationStepBar = class(TCustomControl)
  private
    FSteps: TStringList;
    FCurrent: Integer;
    FTitle, FSubtitle, FChips: string;
    { Horizontal scroll of the step strip, in pixels. }
    FScroll, FContentWidth, FAreaLeft, FAreaRight: Integer;
    FFollowCurrent: Boolean;
    FLeftArrow, FRightArrow: TRect;
    procedure SetCurrent(Value: Integer);
    procedure ScrollSteps(Delta: Integer);
    function StepWidth(I: Integer): Integer;
    procedure SetTitle(const Value: string);
    procedure SetSubtitle(const Value: string);
    procedure SetChips(const Value: string);
  protected
    procedure Paint; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetSteps(Values: TStrings);
    { Scroll position of the steps (0 = first block at the left). }
    property ScrollPos: Integer read FScroll;
    function StepCount: Integer;
    property Current: Integer read FCurrent write SetCurrent;
    property Title: string read FTitle write SetTitle;
    property Subtitle: string read FSubtitle write SetSubtitle;
    { Right-aligned chips separated by '|', e.g. '⏱ 06:12|Encerrar  Esc'. }
    property Chips: string read FChips write SetChips;
  end;

  { Flat rounded button: colored fill, optional icon and keyboard hint.
    Caption stays the plain action name so code, tests and UI automation
    can find the button by its text. }
  TChromeButton = class(TCustomControl)
  private
    FFill, FTextColor, FBorder: TColor;
    FIcon, FKeyHint: string;
    FHover, FDown: Boolean;
    procedure SetFill(Value: TColor);
    procedure SetTextColor(Value: TColor);
    procedure SetBorder(Value: TColor);
    procedure SetIcon(const Value: string);
    procedure SetKeyHint(const Value: string);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure TextChanged; override;
    procedure EnabledChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    procedure SetStyle(AFill, AText, ABorder: TColor);
    property Fill: TColor read FFill write SetFill;
    property TextColor: TColor read FTextColor write SetTextColor;
    property Border: TColor read FBorder write SetBorder;
    property Icon: string read FIcon write SetIcon;
    property KeyHint: string read FKeyHint write SetKeyHint;
  published
    property Caption;
    property Enabled;
    property Font;
    property Hint;
    property ShowHint;
    property TabStop;
    property Visible;
    property OnClick;
  end;

  { "Bloco 2 de 5" text with a cyan-to-blue progress bar. }
  TPresentationProgress = class(TCustomControl)
  private
    FText, FRightText: string;
    FPosition: Double;
    procedure SetText(const Value: string);
    procedure SetRightText(const Value: string);
    procedure SetPosition(Value: Double);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Text: string read FText write SetText;
    property RightText: string read FRightText write SetRightText;
    property Position: Double read FPosition write SetPosition;
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
function BlendColor(A, B: TColor; T: Double): TColor;

implementation

function BlendColor(A, B: TColor; T: Double): TColor;
var CA, CB: LongInt;
  function Mix(X, Y: Integer): Integer;
  begin Result := EnsureRange(Round(X + (Y - X) * T), 0, 255); end;
begin
  CA := ColorToRGB(A); CB := ColorToRGB(B);
  Result := RGBToColor(Mix(Red(CA), Red(CB)), Mix(Green(CA), Green(CB)), Mix(Blue(CA), Blue(CB)));
end;

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
  FFollowCurrent := True;
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
  FFollowCurrent := True; // bring the new current block into view on next paint
  Invalidate;
end;

procedure TPresentationStepBar.ScrollSteps(Delta: Integer);
begin
  FFollowCurrent := False;
  FScroll := EnsureRange(FScroll + Delta, 0, Max(0, FContentWidth - (FAreaRight - FAreaLeft)));
  Invalidate;
end;

function TPresentationStepBar.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := True;
  ScrollSteps(-WheelDelta div 2);
end;

procedure TPresentationStepBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if PtInRect(FLeftArrow, Point(X, Y)) then ScrollSteps(-Max(120, (FAreaRight - FAreaLeft) div 2))
  else if PtInRect(FRightArrow, Point(X, Y)) then ScrollSteps(Max(120, (FAreaRight - FAreaLeft) div 2));
end;

function TPresentationStepBar.StepWidth(I: Integer): Integer;
var S: string;
begin
  S := FSteps[I];
  if I < FCurrent then S := '✓ ' + S else if I = FCurrent then S := '● ' + S;
  if I = FCurrent then Canvas.Font.Style := [fsBold] else Canvas.Font.Style := [];
  Result := Canvas.TextWidth(FitText(Canvas, S, 220)) + 24;
end;

procedure TPresentationStepBar.SetTitle(const Value: string);
begin
  if Value = FTitle then Exit;
  FTitle := Value;
  Invalidate;
end;

procedure TPresentationStepBar.SetSubtitle(const Value: string);
begin
  if Value = FSubtitle then Exit;
  FSubtitle := Value;
  Invalidate;
end;

procedure TPresentationStepBar.SetChips(const Value: string);
begin
  if Value = FChips then Exit;
  FChips := Value;
  Invalidate;
end;

procedure TPresentationStepBar.Paint;
const PadX = 12; Gap = 18; PillH = 28;
var X, Y, I, W, TitleW, Right, TH: Integer; R: TRect; S: string; Parts: TStringList; Bmp: TBitmap;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  Y := Max(0, (Height - PillH) div 2);
  { Chips on the right (timer, shortcuts), drawn first so the steps stop before them. }
  Right := Width - 2;
  if FChips <> '' then begin
    Parts := TStringList.Create;
    try
      Parts.StrictDelimiter := True; Parts.Delimiter := '|'; Parts.DelimitedText := FChips;
      Canvas.Font.Style := [];
      for I := Parts.Count - 1 downto 0 do begin
        S := Parts[I];
        W := Canvas.TextWidth(S) + 2 * PadX;
        if Right - W < Width div 2 then Break;
        R := Rect(Right - W, Y, Right, Y + PillH);
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := ChromeDarkPanel; Canvas.Pen.Color := ChromeBorderDark;
        Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, PillH, PillH);
        Canvas.Brush.Style := bsClear; Canvas.Font.Color := ChromeLight;
        Canvas.TextOut(R.Left + PadX, R.Top + (PillH - Canvas.TextHeight(S)) div 2, S);
        Right := R.Left - 8;
      end;
    finally Parts.Free; end;
  end;
  X := 4;
  if FTitle <> '' then begin
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := clWhite;
    S := FitText(Canvas, FTitle, Max(60, Width div 5));
    TitleW := Canvas.TextWidth(S);
    TH := Canvas.TextHeight(S);
    Canvas.Brush.Style := bsClear;
    if FSubtitle <> '' then begin
      Canvas.TextOut(X, (Height - 2 * TH) div 2, S);
      Canvas.Font.Style := []; Canvas.Font.Color := ChromeMuted;
      S := FitText(Canvas, FSubtitle, Max(60, Width div 5));
      Canvas.TextOut(X, (Height - 2 * TH) div 2 + TH, S);
      TitleW := Max(TitleW, Canvas.TextWidth(S));
    end else
      Canvas.TextOut(X, (Height - TH) div 2, S);
    Inc(X, TitleW + 24);
  end;
  Canvas.Font.Style := [];
  FLeftArrow := Rect(0, 0, 0, 0); FRightArrow := Rect(0, 0, 0, 0);
  if FSteps.Count = 0 then Exit;
  { All blocks sit on one strip that scrolls horizontally (mouse wheel or
    the arrows); the current block is scrolled into view when it changes. }
  FAreaLeft := X; FAreaRight := Right;
  FContentWidth := 0;
  for I := 0 to FSteps.Count - 1 do Inc(FContentWidth, StepWidth(I) + Gap);
  Dec(FContentWidth, Gap);
  if FContentWidth > FAreaRight - FAreaLeft then begin
    FLeftArrow := Rect(FAreaLeft, Y, FAreaLeft + 26, Y + PillH);
    FRightArrow := Rect(FAreaRight - 26, Y, FAreaRight, Y + PillH);
    FAreaLeft := FLeftArrow.Right + 6; FAreaRight := FRightArrow.Left - 6;
  end;
  if FFollowCurrent and (FCurrent >= 0) and (FCurrent < FSteps.Count) then begin
    W := 0;
    for I := 0 to FCurrent - 1 do Inc(W, StepWidth(I) + Gap);
    { Show the previous block too, so the strip reads as a path. }
    if FCurrent > 0 then Dec(W, StepWidth(FCurrent - 1) + Gap);
    FScroll := W;
    FFollowCurrent := False;
  end;
  FScroll := EnsureRange(FScroll, 0, Max(0, FContentWidth - (FAreaRight - FAreaLeft)));
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(Max(1, FAreaRight - FAreaLeft), Height);
    Bmp.Canvas.Brush.Color := Color;
    Bmp.Canvas.FillRect(0, 0, Bmp.Width, Bmp.Height);
    Bmp.Canvas.Font.Assign(Canvas.Font);
    X := -FScroll;
    for I := 0 to FSteps.Count - 1 do begin
      S := FSteps[I];
      if I < FCurrent then S := '✓ ' + S else if I = FCurrent then S := '● ' + S;
      if I = FCurrent then Bmp.Canvas.Font.Style := [fsBold] else Bmp.Canvas.Font.Style := [];
      S := FitText(Bmp.Canvas, S, 220);
      W := Bmp.Canvas.TextWidth(S) + 2 * PadX;
      if (X + W >= 0) and (X <= Bmp.Width) then begin
        R := Rect(X, Y, X + W, Y + PillH);
        Bmp.Canvas.Brush.Style := bsSolid;
        if I = FCurrent then begin
          Bmp.Canvas.Brush.Color := ChromeAccent; Bmp.Canvas.Pen.Color := ChromeAccent; Bmp.Canvas.Font.Color := clWhite;
        end else begin
          Bmp.Canvas.Brush.Color := ChromeDarkPanel; Bmp.Canvas.Pen.Color := ChromeDarkPanel;
          if I < FCurrent then Bmp.Canvas.Font.Color := ChromeDone else Bmp.Canvas.Font.Color := ChromeMuted;
        end;
        Bmp.Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, PillH, PillH);
        Bmp.Canvas.Brush.Style := bsClear;
        Bmp.Canvas.TextOut(R.Left + PadX, R.Top + (PillH - Bmp.Canvas.TextHeight(S)) div 2, S);
      end;
      Inc(X, W + Gap);
      if (I < FSteps.Count - 1) and (X - Gap + 5 < Bmp.Width) then begin
        Bmp.Canvas.Brush.Style := bsClear;
        Bmp.Canvas.Font.Style := [];
        Bmp.Canvas.Font.Color := ChromeMuted;
        Bmp.Canvas.TextOut(X - Gap + 5, (Height - Bmp.Canvas.TextHeight('›')) div 2, '›');
      end;
    end;
    Canvas.Draw(FAreaLeft, 0, Bmp);
  finally Bmp.Free; end;
  { Scroll arrows, dimmed at either end. }
  if not IsRectEmpty(FLeftArrow) then begin
    Canvas.Font.Style := [fsBold];
    for I := 0 to 1 do begin
      if I = 0 then R := FLeftArrow else R := FRightArrow;
      Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := ChromeDarkPanel; Canvas.Pen.Color := ChromeBorderDark;
      Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, PillH, PillH);
      if ((I = 0) and (FScroll > 0)) or ((I = 1) and (FScroll < FContentWidth - (FAreaRight - FAreaLeft))) then
        Canvas.Font.Color := clWhite else Canvas.Font.Color := ChromeBorderDark;
      if I = 0 then S := '‹' else S := '›';
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(R.Left + (R.Right - R.Left - Canvas.TextWidth(S)) div 2,
        R.Top + (PillH - Canvas.TextHeight(S)) div 2, S);
    end;
  end;
end;


{ TChromeButton }

constructor TChromeButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse] - [csDoubleClicks];
  FFill := ChromeButtonDark; FTextColor := ChromeLight; FBorder := ChromeBorderDark;
  DoubleBuffered := True;
  TabStop := True;
  Cursor := crHandPoint;
  SetInitialBounds(0, 0, 110, 40);
end;

procedure TChromeButton.SetStyle(AFill, AText, ABorder: TColor);
begin
  FFill := AFill; FTextColor := AText; FBorder := ABorder;
  Invalidate;
end;

procedure TChromeButton.SetFill(Value: TColor);
begin if Value <> FFill then begin FFill := Value; Invalidate; end; end;

procedure TChromeButton.SetTextColor(Value: TColor);
begin if Value <> FTextColor then begin FTextColor := Value; Invalidate; end; end;

procedure TChromeButton.SetBorder(Value: TColor);
begin if Value <> FBorder then begin FBorder := Value; Invalidate; end; end;

procedure TChromeButton.SetIcon(const Value: string);
begin if Value <> FIcon then begin FIcon := Value; Invalidate; end; end;

procedure TChromeButton.SetKeyHint(const Value: string);
begin if Value <> FKeyHint then begin FKeyHint := Value; Invalidate; end; end;

procedure TChromeButton.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TChromeButton.EnabledChanged;
begin
  inherited EnabledChanged;
  Invalidate;
end;

procedure TChromeButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True; Invalidate;
end;

procedure TChromeButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False; FDown := False; Invalidate;
end;

procedure TChromeButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin FDown := True; Invalidate; end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TChromeButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin FDown := False; Invalidate; end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TChromeButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = 13) or (Key = 32) then begin Key := 0; Click; end;
end;

procedure TChromeButton.Click;
begin
  if not Enabled then Exit;
  inherited Click;
end;

procedure TChromeButton.Paint;
const Radius = 12;
var R: TRect; F, T: TColor; S: string; W, KW, X, TH: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  if Parent <> nil then Canvas.Brush.Color := Parent.Color else Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  F := FFill; T := FTextColor;
  if not Enabled then begin F := BlendColor(FFill, Canvas.Brush.Color, 0.55); T := BlendColor(FTextColor, F, 0.5); end
  else if FDown then F := BlendColor(FFill, clBlack, 0.15)
  else if FHover then F := BlendColor(FFill, clWhite, 0.12);
  R := Rect(0, 0, Width, Height);
  Canvas.Brush.Color := F;
  if FBorder = clNone then Canvas.Pen.Color := F else Canvas.Pen.Color := FBorder;
  Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Radius, Radius);
  if Focused then begin
    Canvas.Brush.Style := bsClear; Canvas.Pen.Color := ChromeCyan;
    Canvas.RoundRect(R.Left + 2, R.Top + 2, R.Right - 2, R.Bottom - 2, Radius - 2, Radius - 2);
  end;
  Canvas.Font.Assign(Font);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := T;
  Canvas.Brush.Style := bsClear;
  S := Caption;
  if FIcon <> '' then S := FIcon + ' ' + S;
  W := Canvas.TextWidth(S);
  KW := 0;
  if FKeyHint <> '' then KW := Canvas.TextWidth(FKeyHint) + 14;
  if W + KW + 16 > Width then KW := 0;
  S := FitText(Canvas, S, Width - 12 - KW);
  W := Canvas.TextWidth(S);
  TH := Canvas.TextHeight(S);
  X := (Width - W - KW) div 2;
  Canvas.TextOut(X, (Height - TH) div 2, S);
  if KW > 0 then begin
    Canvas.Font.Style := [];
    Canvas.Font.Height := -11;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := BlendColor(F, T, 0.18); Canvas.Pen.Color := Canvas.Brush.Color;
    R := Rect(X + W + 8, (Height - 20) div 2, X + W + KW + 4, (Height - 20) div 2 + 20);
    Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(R.Left + (R.Right - R.Left - Canvas.TextWidth(FKeyHint)) div 2,
      R.Top + (20 - Canvas.TextHeight(FKeyHint)) div 2, FKeyHint);
  end;
end;

{ TPresentationProgress }

constructor TPresentationProgress.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Color := ChromeDarkPanel;
  SetInitialBounds(0, 0, 200, 40);
end;

procedure TPresentationProgress.SetText(const Value: string);
begin if Value <> FText then begin FText := Value; Invalidate; end; end;

procedure TPresentationProgress.SetRightText(const Value: string);
begin if Value <> FRightText then begin FRightText := Value; Invalidate; end; end;

procedure TPresentationProgress.SetPosition(Value: Double);
begin
  Value := EnsureRange(Value, 0, 1);
  if Value <> FPosition then begin FPosition := Value; Invalidate; end;
end;

procedure TPresentationProgress.Paint;
const BarH = 6;
var TH, BarTop, Filled, I, Steps: Integer; S: string; R: TRect;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := ChromeMuted;
  TH := Canvas.TextHeight('Bg');
  BarTop := (Height + TH) div 2 - BarH div 2 + 2;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(0, BarTop - TH - 6, FitText(Canvas, FText, Width div 2));
  if FRightText <> '' then begin
    S := FitText(Canvas, FRightText, Width div 2 - 8);
    Canvas.TextOut(Width - Canvas.TextWidth(S), BarTop - TH - 6, S);
  end;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ChromeButtonDark; Canvas.Pen.Color := ChromeButtonDark;
  Canvas.RoundRect(0, BarTop, Width, BarTop + BarH, BarH, BarH);
  Filled := Round(Width * FPosition);
  if Filled > BarH then begin
    { Horizontal gradient from cyan to blue, drawn in slices. }
    Steps := Max(1, Filled div 4);
    for I := 0 to Steps - 1 do begin
      Canvas.Brush.Color := BlendColor(ChromeCyan, ChromeAccent, I / Max(1, Steps - 1));
      R := Rect(I * Filled div Steps, BarTop, (I + 1) * Filled div Steps, BarTop + BarH);
      if I = 0 then Inc(R.Left, BarH div 2);
      if I = Steps - 1 then Dec(R.Right, BarH div 2);
      Canvas.FillRect(R);
    end;
    Canvas.Brush.Color := ChromeCyan; Canvas.Pen.Color := ChromeCyan;
    Canvas.Ellipse(0, BarTop, BarH, BarTop + BarH);
    Canvas.Brush.Color := ChromeAccent; Canvas.Pen.Color := ChromeAccent;
    Canvas.Ellipse(Filled - BarH, BarTop, Filled, BarTop + BarH);
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
