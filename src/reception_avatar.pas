unit reception_avatar;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, Graphics, Math, aiavatar3d, aiavatartypes;
type
  { A responsive procedural avatar when no licensed 3D model is configured.
    Its expression and attention follow the CHATGPT avatar controller. }
  TReceptionAvatar = class(TCustomControl)
  public
    Avatar: TAIAvatar3D;
    procedure Paint; override;
  end;
implementation
procedure TReceptionAvatar.Paint;
var X,Y,R, EyeH, MouthH, Sway: Integer; Speaking, Thinking: Boolean; T: Double;
begin
  Canvas.Brush.Color := $00201912; Canvas.FillRect(ClientRect);
  T := GetTickCount64 / 1000;
  X := Width div 2; Y := Height div 2 - 15;
  R := Min(Width div 4, Height div 3);
  if R < 20 then Exit;
  Speaking := Assigned(Avatar) and (Avatar.State = avSpeaking);
  Thinking := Assigned(Avatar) and (Avatar.State = avThinking);
  Sway := Round(Sin(T * 1.4) * R * 0.025);
  Inc(Y, Sway);
  Canvas.Pen.Color := $00E2C376; Canvas.Pen.Width := 3;
  Canvas.Brush.Color := $00453729;
  Canvas.RoundRect(X-R, Y-R, X+R, Y+R, R div 2, R div 2);
  Canvas.Brush.Color := $00241C14;
  Canvas.RoundRect(X-R+14, Y-R+22, X+R-14, Y+R-22, 30, 30);
  Canvas.Pen.Style := psClear; Canvas.Brush.Color := $00F5DF8C;
  EyeH := Max(5, R div 6);
  if (Frac(T / 4.3) < 0.04) then EyeH := 3;
  if Thinking then EyeH := Max(4, EyeH div 2);
  Canvas.RoundRect(X-R div 2-10,Y-R div 4-EyeH,X-R div 2+25,Y-R div 4+EyeH,12,12);
  Canvas.RoundRect(X+R div 2-25,Y-R div 4-EyeH,X+R div 2+10,Y-R div 4+EyeH,12,12);
  MouthH := 5;
  if Speaking then MouthH := 8 + Round((1+Sin(T*18))*R*0.08);
  Canvas.RoundRect(X-R div 3,Y+R div 3-MouthH,X+R div 3,Y+R div 3+MouthH,12,12);
  Canvas.Brush.Color := $00453729;
  Canvas.RoundRect(X-R-R div 4,Y+R+18,X+R+R div 4,Y+R+R div 2,28,28);
  Canvas.Brush.Color := $00F5DF8C;
  Canvas.Ellipse(X-7,Y+R+R div 4-7,X+7,Y+R+R div 4+7);
  if Assigned(Avatar) and (Avatar.Gesture = agWave) then
    Canvas.Ellipse(X+R+20,Y+Round(Sin(T*8)*12),X+R+50,Y+38+Round(Sin(T*8)*12));
  Canvas.Pen.Style := psSolid;
end;
end.
