program assistant_menu_tests;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Classes, SysUtils, Menus, LCLType, assistant_menu, assistant_search_dialog;
var Owner: TComponent; Menu: TAssistantMenu;
procedure Check(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message);end;
begin
  Application.Initialize;Owner:=TComponent.Create(nil);
  try
    Menu:=TAssistantMenu.Create(Owner);
    Check(Menu is TMainMenu,'Native menu missing');
    Check(Menu.Items.Count=4,'File, Presentation, Search and Help menus missing');
    Check(Menu.OpenFile.ShortCut=Menus.ShortCut(Ord('O'),[ssCtrl]),'Open shortcut');
    Check(Menu.CloseFile.ShortCut=Menus.ShortCut(Ord('W'),[ssCtrl]),'Close shortcut');
    Check(Menu.PrintPDF.ShortCut=Menus.ShortCut(Ord('P'),[ssCtrl]),'Print shortcut');
    Check(Menu.FindText.ShortCut=Menus.ShortCut(Ord('F'),[ssCtrl]),'Search shortcut');
    Check(Menu.OpenFile.Parent=Menu.CloseFile.Parent,'Open and close must share File menu');
    Check(Menu.PrintPDF.Parent=Menu.OpenFile.Parent,'Print must be in File menu');
    Check(Menu.About.Parent<>Menu.OpenFile.Parent,'About must be in Help menu');
    Check((Menu.LoadPresentation.Parent=Menu.PlayPresentation.Parent) and (Menu.Topics.Parent=Menu.LoadPresentation.Parent),'Presentation items must share the Presentation menu');
    Check(Menu.LoadPresentation.Parent<>Menu.OpenFile.Parent,'Presentation items must not be in File menu');
    Check(Owner.ComponentCount=1,'Menus must not create toolbar buttons');
    WriteLn('PASS: native dropdown menus, presentation menu, keyboard shortcuts and no extra buttons');
  finally Owner.Free;end;
end.
