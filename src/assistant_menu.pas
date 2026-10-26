unit assistant_menu;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, Menus, LCLType;
type
  TAssistantMenu = class(TMainMenu)
  public
    OpenFile, CloseFile, PrintPDF, FindText, About: TMenuItem;
    constructor Create(AOwner: TComponent); override;
  end;
implementation
constructor TAssistantMenu.Create(AOwner: TComponent);
var FileMenu, SearchMenu, HelpMenu: TMenuItem;
  function Item(Parent: TMenuItem; const ID, Title: string; Key: TShortCut): TMenuItem;
  begin
    Result:=TMenuItem.Create(Self);Result.Name:=ID;Result.Caption:=Title;
    Result.ShortCut:=Key;Parent.Add(Result);
  end;
begin
  inherited Create(AOwner);Name:='AssistantMainMenu';
  FileMenu:=Item(Items,'FileMenu','&Arquivo',0);
  OpenFile:=Item(FileMenu,'OpenFileMenuItem','&Abrir arquivo...',Menus.ShortCut(Ord('O'),[ssCtrl]));
  CloseFile:=Item(FileMenu,'CloseFileMenuItem','&Fechar arquivo',Menus.ShortCut(Ord('W'),[ssCtrl]));
  Item(FileMenu,'FileSeparator','-',0);
  PrintPDF:=Item(FileMenu,'PrintPresentationMenuItem','&Imprimir apresentação / Salvar PDF...',Menus.ShortCut(Ord('P'),[ssCtrl]));
  SearchMenu:=Item(Items,'SearchMenu','&Pesquisar',0);
  FindText:=Item(SearchMenu,'FindTextMenuItem','&Localizar no texto...',Menus.ShortCut(Ord('F'),[ssCtrl]));
  HelpMenu:=Item(Items,'HelpMenu','A&juda',0);
  About:=Item(HelpMenu,'AboutMenuItem','&Sobre o Assistente...',0);
end;
end.
