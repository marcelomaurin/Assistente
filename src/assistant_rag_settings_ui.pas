unit assistant_rag_settings_ui;
{ Configurações > "Documentos (RAG)": documents the AI uses as references.
  Adding or removing a document acts on the RAG library folder immediately;
  the "use in answers" option is saved with the other settings. }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, ComCtrls, StdCtrls, Controls, Forms, Dialogs, ExtCtrls;
type
  TRAGSettingsUI=class(TComponent)
  private
    FDialog:TOpenDialog;
    procedure AddClick(Sender:TObject);
    procedure RemoveClick(Sender:TObject);
    procedure FolderClick(Sender:TObject);
    procedure RefreshClick(Sender:TObject);
    procedure ListSelect(Sender:TObject;Item:TListItem;Selected:Boolean);
  public
    Page:TTabSheet;
    List:TListView;
    UseInAnswers:TCheckBox;
    Status:TLabel;
    AddButton,RemoveButton:TButton;
    constructor CreateFor(AOwner:TComponent;Pages:TPageControl);
    procedure RefreshList;
    { Add files without dialogs (used by the dialog and by tests). }
    function AddFiles(Files:TStrings):Integer;
  end;
  { Exportar/Importar configuração buttons on the settings button panel. }
  TConfigFileButtons=class(TComponent)
  public
    ExportButton,ImportButton:TButton;
    constructor CreateFor(AOwner:TComponent;Panel:TWinControl;OnExport,OnImport:TNotifyEvent);
  end;
function FormatDocumentSize(Size:Int64):string;
implementation
uses LCLIntf, presentation_rag;
function FormatDocumentSize(Size:Int64):string;
begin
  if Size<1024 then Result:=IntToStr(Size)+' B'
  else if Size<1024*1024 then Result:=FormatFloat('0.0',Size/1024)+' KB'
  else Result:=FormatFloat('0.0',Size/(1024*1024))+' MB';
end;
constructor TRAGSettingsUI.CreateFor(AOwner:TComponent;Pages:TPageControl);
var Info:TLabel;Bar:TPanel;Column:TListColumn;Button:TButton;
  function MakeButton(const Caption:string;Width:Integer;Handler:TNotifyEvent):TButton;
  begin
    Result:=TButton.Create(Self);Result.Parent:=Bar;Result.Caption:=Caption;
    { alLeft keeps creation order only when each button starts to the right. }
    Result.Left:=Bar.ControlCount*200;
    Result.Align:=alLeft;Result.Width:=Width;Result.BorderSpacing.Right:=6;Result.OnClick:=Handler;
  end;
begin
  inherited Create(AOwner);
  Page:=TTabSheet.Create(Self);Page.PageControl:=Pages;Page.Caption:='Documentos (RAG)';
  Info:=TLabel.Create(Self);Info.Parent:=Page;Info.Align:=alTop;Info.AutoSize:=True;Info.WordWrap:=True;
  Info.BorderSpacing.Around:=8;
  Info.Caption:='Documentos que a IA consulta como referência nas respostas e nas perguntas durante as apresentações. '+
    'Apresentações (.pva) também podem ser escolhidas para apresentar. '+
    'Formatos: .pva, .txt, .md, .csv, .json e .rag (texto UTF-8 até 1 MB). '+
    'Adicionar e remover vale na hora; o original não é alterado.';
  UseInAnswers:=TCheckBox.Create(Self);UseInAnswers.Parent:=Page;UseInAnswers.Align:=alTop;
  UseInAnswers.BorderSpacing.Left:=8;UseInAnswers.Top:=Info.Top+Info.Height+1;
  UseInAnswers.Caption:='Usar estes documentos como referência nas respostas da IA';UseInAnswers.Checked:=True;
  Bar:=TPanel.Create(Self);Bar.Parent:=Page;Bar.Align:=alBottom;Bar.Height:=36;Bar.BevelOuter:=bvNone;
  Bar.BorderSpacing.Around:=6;
  AddButton:=MakeButton('Adicionar...',92,@AddClick);
  RemoveButton:=MakeButton('Remover',72,@RemoveClick);RemoveButton.Enabled:=False;
  Button:=MakeButton('Abrir pasta',84,@FolderClick);
  Button:=MakeButton('Atualizar',72,@RefreshClick);
  Status:=TLabel.Create(Self);Status.Parent:=Page;Status.Align:=alBottom;Status.AutoSize:=True;Status.WordWrap:=True;
  Status.BorderSpacing.Left:=8;Status.BorderSpacing.Right:=8;
  List:=TListView.Create(Self);List.Parent:=Page;List.Align:=alClient;List.BorderSpacing.Around:=8;
  List.ViewStyle:=vsReport;List.ReadOnly:=True;List.RowSelect:=True;List.MultiSelect:=True;List.HideSelection:=False;
  Column:=List.Columns.Add;Column.Caption:='Documento';Column.Width:=170;
  Column:=List.Columns.Add;Column.Caption:='Tipo';Column.Width:=86;
  Column:=List.Columns.Add;Column.Caption:='Tamanho';Column.Width:=70;
  List.OnSelectItem:=@ListSelect;
  FDialog:=TOpenDialog.Create(Self);FDialog.Title:='Adicionar documentos ao RAG';
  FDialog.Options:=FDialog.Options+[ofAllowMultiSelect,ofFileMustExist];
  FDialog.Filter:='Documentos (*.pva;*.txt;*.md;*.csv;*.json;*.rag)|*.pva;*.txt;*.md;*.csv;*.json;*.rag|Todos os arquivos (*.*)|*.*';
end;
procedure TRAGSettingsUI.RefreshList;
var Index:TPresentationRAG;I:Integer;Item:TListItem;E:TPresentationRAGEntry;
begin
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    Index:=TPresentationRAG.Create(PresentationRAGDirectory);
    try
      try Index.Refresh;
      except on X:Exception do begin Status.Caption:='Biblioteca indisponível: '+X.Message;Exit;end;end;
      for I:=0 to Index.Count-1 do begin
        E:=Index.Entry(I);Item:=List.Items.Add;Item.Caption:=ExtractFileName(E.FileName);
        if E.Playable then Item.SubItems.Add('Apresentação') else Item.SubItems.Add('Consulta');
        Item.SubItems.Add(FormatDocumentSize(E.Size));
      end;
      for I:=0 to Index.Errors.Count-1 do begin
        Item:=List.Items.Add;Item.Caption:=Copy(Index.Errors[I],1,Pos(':',Index.Errors[I]+':')-1);
        Item.SubItems.Add('Com erro');Item.SubItems.Add('');
      end;
      if Index.Errors.Count>0 then
        Status.Caption:=IntToStr(Index.Count)+' documento(s) na biblioteca. Não indexados: '+
          StringReplace(Trim(Index.Errors.Text),LineEnding,'; ',[rfReplaceAll])
      else Status.Caption:=IntToStr(Index.Count)+' documento(s) na biblioteca.';
    finally Index.Free;end;
  finally List.Items.EndUpdate;end;
  RemoveButton.Enabled:=List.SelCount>0;
end;
function TRAGSettingsUI.AddFiles(Files:TStrings):Integer;
var I:Integer;Failed:TStringList;
begin
  Result:=0;Failed:=TStringList.Create;
  try
    for I:=0 to Files.Count-1 do
      try AddRAGDocument(Files[I]);Inc(Result);
      except on E:Exception do Failed.Add(ExtractFileName(Files[I])+': '+E.Message);end;
    RefreshList;
    if Failed.Count>0 then
      Status.Caption:=IntToStr(Result)+' adicionado(s). Não adicionados: '+StringReplace(Trim(Failed.Text),LineEnding,'; ',[rfReplaceAll])
    else Status.Caption:=IntToStr(Result)+' documento(s) adicionado(s) à biblioteca.';
  finally Failed.Free;end;
end;
procedure TRAGSettingsUI.AddClick(Sender:TObject);
var I:Integer;Existing:TStringList;Target:string;
begin
  if not FDialog.Execute then Exit;
  Existing:=TStringList.Create;
  try
    for I:=0 to FDialog.Files.Count-1 do begin
      Target:=IncludeTrailingPathDelimiter(PresentationRAGDirectory)+ExtractFileName(FDialog.Files[I]);
      if FileExists(Target) and not SameText(ExpandFileName(FDialog.Files[I]),ExpandFileName(Target)) then
        Existing.Add(ExtractFileName(Target));
    end;
    if (Existing.Count>0) and (MessageDlg('Substituir documentos',
      'Já existem na biblioteca: '+StringReplace(Trim(Existing.Text),LineEnding,', ',[rfReplaceAll])+'. Substituir?',
      mtConfirmation,[mbYes,mbNo],0)<>mrYes) then Exit;
  finally Existing.Free;end;
  Screen.Cursor:=crHourGlass;
  try AddFiles(FDialog.Files);finally Screen.Cursor:=crDefault;end;
end;
procedure TRAGSettingsUI.RemoveClick(Sender:TObject);
var I,Removed:Integer;Names:TStringList;
begin
  Names:=TStringList.Create;
  try
    for I:=0 to List.Items.Count-1 do if List.Items[I].Selected then Names.Add(List.Items[I].Caption);
    if Names.Count=0 then Exit;
    if MessageDlg('Remover documentos','Remover da biblioteca da IA: '+
      StringReplace(Trim(Names.Text),LineEnding,', ',[rfReplaceAll])+'?'+LineEnding+
      'A cópia na pasta RAG será apagada; o arquivo original não é alterado.',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
    Removed:=0;
    for I:=0 to Names.Count-1 do
      try RemoveRAGDocument(Names[I]);Inc(Removed);
      except on E:Exception do Status.Caption:=E.Message;end;
    RefreshList;
    if Removed=Names.Count then Status.Caption:=IntToStr(Removed)+' documento(s) removido(s).';
  finally Names.Free;end;
end;
procedure TRAGSettingsUI.FolderClick(Sender:TObject);
begin
  ForceDirectories(PresentationRAGDirectory);
  OpenDocument(PresentationRAGDirectory);
end;
procedure TRAGSettingsUI.RefreshClick(Sender:TObject);
begin RefreshList;end;
procedure TRAGSettingsUI.ListSelect(Sender:TObject;Item:TListItem;Selected:Boolean);
begin RemoveButton.Enabled:=List.SelCount>0;end;

constructor TConfigFileButtons.CreateFor(AOwner:TComponent;Panel:TWinControl;OnExport,OnImport:TNotifyEvent);
begin
  inherited Create(AOwner);
  ExportButton:=TButton.Create(Self);ExportButton.Parent:=Panel;ExportButton.Caption:='Exportar...';
  ExportButton.SetBounds(8,8,92,30);ExportButton.OnClick:=OnExport;
  ExportButton.Hint:='Gerar um arquivo com esta configuração para usar em outra instalação';ExportButton.ShowHint:=True;
  ImportButton:=TButton.Create(Self);ImportButton.Parent:=Panel;ImportButton.Caption:='Importar...';
  ImportButton.SetBounds(106,8,92,30);ImportButton.OnClick:=OnImport;
  ImportButton.Hint:='Aplicar um arquivo de configuração do Assistente';ImportButton.ShowHint:=True;
end;
end.
