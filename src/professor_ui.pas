unit professor_ui;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Buttons;
type
  TRoundedCard = class(TCustomControl)
  private
    FFill, FBorder: TColor;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Fill: TColor read FFill write FFill;
    property Border: TColor read FBorder write FBorder;
  end;
  TConversationView = class(TScrollBox)
  private
    FCards: TList;
    FReflowing: Boolean;
    procedure Reflow;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddMessage(const AText: string; AUser: Boolean);
    function ContentWidth: Integer;
  end;
procedure SetLineIcon(Button: TSpeedButton; const Kind: string; AColor: TColor);
implementation
uses Math, Types, LCLIntf, LCLType;
constructor TRoundedCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFill := clWhite;
  FBorder := $00E9E9E9;
  Color := clWhite;
  DoubleBuffered := True;
end;
procedure TRoundedCard.Paint;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Brush.Color := FFill;
  Canvas.Pen.Color := FBorder;
  Canvas.RoundRect(0, 0, Width-1, Height-1, 22, 22);
end;
constructor TConversationView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCards := TList.Create;
  BorderStyle := bsNone;
  Color := clWhite;
  HorzScrollBar.Visible := False;
  VertScrollBar.Tracking := True;
  DoubleBuffered := True;
end;
destructor TConversationView.Destroy;
begin
  FreeAndNil(FCards);
  inherited Destroy;
end;
function TConversationView.ContentWidth: Integer;
begin Result := Min(760, Max(220, Width-24)); end;
procedure TConversationView.AddMessage(const AText: string; AUser: Boolean);
var Card: TRoundedCard; TextLabel: TLabel;
begin
  Card := TRoundedCard.Create(Self);
  Card.Parent := Self;
  if AUser then begin Card.Fill:=$00FFF0E7;Card.Border:=$00F5DECB;Card.Tag:=1;end
  else begin Card.Fill := $00F6F6F6; Card.Border := $00F6F6F6; end;
  TextLabel := TLabel.Create(Card);
  TextLabel.Parent := Card;
  TextLabel.AutoSize := False;
  TextLabel.WordWrap := True;
  TextLabel.Caption := AText;
  TextLabel.Font.Assign(Font);
  TextLabel.Font.Color := $00252525;
  TextLabel.Transparent := True;
  FCards.Add(Card);
  Reflow;
  VertScrollBar.Position := Max(0, VertScrollBar.Range - VertScrollBar.Page);
end;
procedure TConversationView.Reflow;
var I, Y, W, H, Scroll: Integer; Card: TRoundedCard; L: TLabel; R: TRect;
begin
  if (FCards = nil) or FReflowing or (csDestroying in ComponentState) then Exit;
  FReflowing := True;
  try
  Scroll := VertScrollBar.Position;
  VertScrollBar.Position := 0;
  Y := 0; W := ContentWidth;
  for I := 0 to FCards.Count-1 do
  begin
    Card := TRoundedCard(FCards[I]);
    L := TLabel(Card.Controls[0]);
    R := Rect(0, 0, W-24, 0);
    Card.Canvas.Font.Assign(L.Font);
    DrawText(Card.Canvas.Handle, PChar(L.Caption), Length(L.Caption), R,
      DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    H := Max(34, R.Bottom + 20);
    if Card.Tag=1 then Card.SetBounds(Max(0,Width-W-24),Y,W,H) else Card.SetBounds(0,Y,W,H);
    L.SetBounds(12, 10, W-24, H-20);
    Inc(Y, H + 8);
  end;
  VertScrollBar.Page := Max(1, ClientHeight);
  VertScrollBar.Range := Max(Y, ClientHeight);
  VertScrollBar.Visible := Y > ClientHeight;
  VertScrollBar.Position := Scroll;
  finally FReflowing := False; end;
end;
procedure TConversationView.Resize;
begin inherited Resize; Reflow; end;
procedure SetLineIcon(Button: TSpeedButton; const Kind: string; AColor: TColor);
var B: TBitmap; I: Integer; P: array[0..15] of TPoint; A, Radius: Double;
begin
  B := TBitmap.Create;
  try
    B.SetSize(18, 18);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(0, 0, 18, 18);
    B.Canvas.Pen.Color := AColor;
    B.Canvas.Pen.Width := 1;
    B.Canvas.Brush.Style := bsClear;
    if Kind = 'send' then
    begin
      B.Canvas.Polygon([Point(2,7), Point(16,2), Point(11,16), Point(8,10), Point(2,7)]);
      B.Canvas.Line(8,10,16,2);
    end
    else if Kind = 'config' then
    begin
      for I := 0 to 15 do
      begin
        A := I * Pi / 8;
        if Odd(I) then Radius := 5 else Radius := 7;
        P[I] := Point(9+Round(Cos(A)*Radius), 9+Round(Sin(A)*Radius));
      end;
      B.Canvas.Polygon(P);
      B.Canvas.Ellipse(6,6,12,12);
    end
    else
    begin
      B.Canvas.RoundRect(7,2,12,11,5,5);
      B.Canvas.MoveTo(4,7); B.Canvas.LineTo(4,10); B.Canvas.LineTo(6,13);
      B.Canvas.LineTo(12,13); B.Canvas.LineTo(15,10); B.Canvas.LineTo(15,7);
      B.Canvas.Line(9,13,9,16); B.Canvas.Line(6,16,13,16);
    end;
    B.Transparent := True;
    B.TransparentColor := clFuchsia;
    Button.Glyph.Assign(B);
  finally B.Free; end;
end;
end.
