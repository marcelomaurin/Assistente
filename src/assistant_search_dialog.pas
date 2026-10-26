unit assistant_search_dialog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, LCLType;
procedure SearchAssistantText(AOwner: TComponent; const Text: string; var Query: string);
implementation
uses assistant_text_search;
type
  TAssistantSearch = class(TForm)
  public
    QueryEdit: TEdit; TextMemo: TMemo; Status: TLabel; LastQuery: string;
    constructor Create(AOwner: TComponent); override;
    procedure FindNext(Sender: TObject);
    procedure SearchKeys(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;
constructor TAssistantSearch.Create(AOwner: TComponent);
var Bar: TPanel; FindButton, CloseButton: TButton;
begin
  inherited CreateNew(AOwner);
  Caption:='Pesquisar no texto';Position:=poOwnerFormCenter;
  Width:=820;Height:=600;Constraints.MinWidth:=560;Constraints.MinHeight:=350;
  Font.Name:='Segoe UI';Font.Size:=10;KeyPreview:=True;OnKeyDown:=@SearchKeys;
  Bar:=TPanel.Create(Self);Bar.Parent:=Self;Bar.Align:=alTop;Bar.Height:=52;Bar.BevelOuter:=bvNone;
  QueryEdit:=TEdit.Create(Self);QueryEdit.Parent:=Bar;
  QueryEdit.SetBounds(12,12,Width-310,28);QueryEdit.Anchors:=[akLeft,akTop,akRight];
  QueryEdit.TextHint:='Digite uma palavra ou expressão';
  FindButton:=TButton.Create(Self);FindButton.Parent:=Bar;
  FindButton.Caption:='Localizar próxima';FindButton.Default:=True;FindButton.OnClick:=@FindNext;
  FindButton.SetBounds(Width-288,10,160,32);FindButton.Anchors:=[akTop,akRight];
  CloseButton:=TButton.Create(Self);CloseButton.Parent:=Bar;CloseButton.Caption:='Fechar';
  CloseButton.ModalResult:=mrClose;CloseButton.Cancel:=True;
  CloseButton.SetBounds(Width-116,10,96,32);CloseButton.Anchors:=[akTop,akRight];
  Status:=TLabel.Create(Self);Status.Parent:=Self;Status.Align:=alBottom;
  Status.BorderSpacing.Around:=10;Status.Caption:='Enter ou F3: próxima ocorrência. A pesquisa ignora maiúsculas e minúsculas.';
  Status.WordWrap:=True;
  TextMemo:=TMemo.Create(Self);TextMemo.Parent:=Self;TextMemo.Align:=alClient;
  TextMemo.ReadOnly:=True;TextMemo.ScrollBars:=ssAutoBoth;TextMemo.WordWrap:=True;
  TextMemo.HideSelection:=False;TextMemo.BorderSpacing.Around:=12;
end;
procedure TAssistantSearch.FindNext(Sender: TObject);
var FoundPos, Count, Start: Integer; Wrapped: Boolean;
begin
  Start:=0;if QueryEdit.Text=LastQuery then Start:=TextMemo.SelStart+TextMemo.SelLength;
  LastQuery:=QueryEdit.Text;
  if LastQuery='' then begin Status.Caption:='Digite o texto que deseja localizar.';QueryEdit.SetFocus;Exit;end;
  if FindAssistantText(TextMemo.Text,LastQuery,Start,FoundPos,Count,Wrapped) then begin
    TextMemo.SetFocus;TextMemo.SelStart:=FoundPos;TextMemo.SelLength:=Count;
    if Wrapped then Status.Caption:='Ocorrência localizada; a pesquisa voltou ao início.'
    else Status.Caption:='Ocorrência localizada. F3: próxima ocorrência.';
  end else Status.Caption:='Texto não encontrado: '+LastQuery;
end;
procedure TAssistantSearch.SearchKeys(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key=VK_F3) or ((Key=VK_RETURN) and not (ssShift in Shift)) then begin FindNext(nil);Key:=0;end
  else if (Key=Ord('F')) and (Shift=[ssCtrl]) then begin QueryEdit.SetFocus;QueryEdit.SelectAll;Key:=0;end;
end;
procedure SearchAssistantText(AOwner: TComponent; const Text: string; var Query: string);
var Dialog: TAssistantSearch;
begin
  Dialog:=TAssistantSearch.Create(AOwner);
  try
    Dialog.TextMemo.Text:=Text;Dialog.QueryEdit.Text:=Query;Dialog.ActiveControl:=Dialog.QueryEdit;
    Dialog.ShowModal;Query:=Dialog.QueryEdit.Text;
  finally Dialog.Free;end;
end;
end.
