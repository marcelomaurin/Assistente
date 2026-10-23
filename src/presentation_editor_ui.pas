unit presentation_editor_ui;
{$mode objfpc}{$H+}
interface
uses Windows, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, SynEdit,
  Process, FileUtil, LazFileUtils, presentation_package, presentation_document,
  presentation_paths, presentation_tags, presentation_ai;
type
  TPresentationEditor = class(TForm)
  private
    FEdit: TSynEdit;FResources: TListBox;FStatus: TLabel;FToolbar: TFlowPanel;
    FAssistant: TEdit;FTimer: TTimer;
    FSettings: TPresentationAIConfig;FJob: TPresentationAIJob;
    FRoot,FFile,FOriginal: string;FDirty,FLoading: Boolean;
    procedure Action(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Closing(Sender: TObject; var CanClose: Boolean);
    procedure AddButton(const Title: string; ID: Integer);
    procedure Insert(const AText: string);
    procedure ExportTo(const AFileName: string);
    procedure RefreshResources;
    procedure ResourceInsert(Sender: TObject);
    function CanDiscard: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadPackage(const FileName: string);
    procedure SavePackage(const FileName: string);
  end;
implementation
function NewPrivateDirectory: string;
var G: TGUID;
begin CreateGUID(G);Result:=IncludeTrailingPathDelimiter(GetTempDir(False))+'assistente-editor-'+GUIDToString(G);end;
constructor TPresentationEditor.Create(AOwner: TComponent);
var P: TPanel; L: TLabel; B: TButton; Config: string;
begin
  inherited CreateNew(AOwner);Caption:='Editor de Apresentacoes';SetBounds(100,70,1180,760);
  Constraints.MinWidth:=800;Constraints.MinHeight:=500;OnCloseQuery:=@Closing;
  FRoot:=NewPrivateDirectory;ForceDirectories(FRoot+PathDelim+'assets');
  Config:=GetEnvironmentVariable('ASSISTENTE_CONFIG_DIR');
  if Config='' then begin
    Config:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))+'assistente';

  end;
  FSettings:=LoadPresentationAIConfig(Config);
  FToolbar:=TFlowPanel.Create(Self);FToolbar.Parent:=Self;FToolbar.Align:=alTop;FToolbar.Height:=88;FToolbar.AutoWrap:=True;
  AddButton('Novo',1);AddButton('Abrir .pva',2);AddButton('Salvar',3);AddButton('Salvar como',4);
  AddButton('Inserir midia',5);AddButton('Fechar midia',6);AddButton('Slide anterior',7);
  AddButton('Proximo slide',8);AddButton('Ir ao slide',9);AddButton('Desfazer',10);AddButton('Refazer',11);
  AddButton('Validar',12);AddButton('Gerar movimentos IA',13);AddButton('Previa no Assistente',14);AddButton('Cancelar IA',15);
  P:=TPanel.Create(Self);P.Parent:=Self;P.Align:=alTop;P.Height:=38;P.BevelOuter:=bvNone;
  L:=TLabel.Create(Self);L.Parent:=P;L.Caption:='Executavel do Assistente:';L.SetBounds(8,10,190,24);
  FAssistant:=TEdit.Create(Self);FAssistant.Parent:=P;FAssistant.SetBounds(200,6,800,28);FAssistant.Anchors:=[akTop,akLeft,akRight];
  FAssistant.Text:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))+'Programs'+PathDelim+'Assistente'+PathDelim+'assistente.exe';
  if FileExists(ExtractFilePath(ParamStr(0))+'assistente.exe') then FAssistant.Text:=ExtractFilePath(ParamStr(0))+'assistente.exe';
  FStatus:=TLabel.Create(Self);FStatus.Parent:=Self;FStatus.Align:=alBottom;FStatus.Height:=30;
  FStatus.Caption:='Escreva o roteiro e posicione o cursor para inserir midia.';
  B:=TButton.Create(Self);B.Parent:=P;B.SetBounds(1010,6,110,28);B.Anchors:=[akTop,akRight];
  B.Caption:='Escolher...';B.Tag:=16;B.OnClick:=@Action;
  P:=TPanel.Create(Self);P.Parent:=Self;P.Align:=alRight;P.Width:=245;
  L:=TLabel.Create(Self);L.Parent:=P;L.Align:=alTop;L.Caption:='Recursos importados (duplo clique)';
  FResources:=TListBox.Create(Self);FResources.Parent:=P;FResources.Align:=alClient;FResources.OnDblClick:=@ResourceInsert;
  FResources.Hint:='Recursos importados; somente os referenciados sao exportados.';FResources.ShowHint:=True;
  FEdit:=TSynEdit.Create(Self);FEdit.Parent:=Self;FEdit.Align:=alClient;FEdit.Font.Name:='Consolas';FEdit.Font.Size:=12;
  FEdit.OnChange:=@Changed;FEdit.Lines.Text:='Ola! Escreva aqui o roteiro da apresentacao.';FDirty:=False;
  FTimer:=TTimer.Create(Self);FTimer.Interval:=100;FTimer.OnTimer:=@Tick;
end;
destructor TPresentationEditor.Destroy;
begin
  if FJob<>nil then FJob.Free;

  if (Pos('assistente-editor-',ExtractFileName(FRoot))=1) and
    (ExtractFileDir(FRoot)=ExcludeTrailingPathDelimiter(GetTempDir(False))) then DeleteDirectory(FRoot,False);
  inherited Destroy;
end;
procedure TPresentationEditor.AddButton(const Title: string; ID: Integer);
var B: TButton;
begin B:=TButton.Create(Self);B.Parent:=FToolbar;B.Caption:=Title;B.AutoSize:=True;B.BorderSpacing.Around:=3;B.Tag:=ID;B.OnClick:=@Action;end;
procedure TPresentationEditor.Changed(Sender: TObject);
begin
  if not FLoading then FDirty:=True;
  Caption:='Editor de Apresentacoes - '+ExtractFileName(FFile);
  if FDirty then Caption:=Caption+' *';
end;
function TPresentationEditor.CanDiscard: Boolean;
var R: Integer;
begin
  Result:=True;if not FDirty then Exit;
  R:=MessageDlg('Salvar as alteracoes antes de continuar?',mtConfirmation,[mbYes,mbNo,mbCancel],0);
  if R=mrCancel then Exit(False);
  if R=mrYes then begin Action(FToolbar.Controls[2]);Result:=not FDirty;end;
end;
procedure TPresentationEditor.Closing(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=False;
  if FJob<>nil then begin FJob.Cancel;FStatus.Caption:='Cancelando geracao. Aguarde o termino antes de fechar.';Exit;end;
  CanClose:=CanDiscard;
end;
procedure TPresentationEditor.Insert(const AText: string);
begin FEdit.SelText:=AText;FEdit.SetFocus;end;
procedure TPresentationEditor.ResourceInsert(Sender: TObject);
begin
  if (FJob=nil) and (FResources.ItemIndex>=0) then Insert('[executar arquivo='+FResources.Items[FResources.ItemIndex]+']');
end;
procedure TPresentationEditor.RefreshResources;
var R: TSearchRec;
begin
  FResources.Clear;
  if FindFirst(FRoot+PathDelim+'assets'+PathDelim+'*',faAnyFile,R)=0 then
  try repeat if (R.Attr and faDirectory)=0 then FResources.Items.Add('assets/'+R.Name);until FindNext(R)<>0;finally FindClose(R);end;
end;
procedure TPresentationEditor.ExportTo(const AFileName: string);
var P: TPVAPackage;
begin
  ValidatePresentationScript(FEdit.Text);P:=TPVAPackage.Create;
  try P.ExportFile(AFileName,FEdit.Text,FRoot);finally P.Free;end;
end;
procedure TPresentationEditor.SavePackage(const FileName: string);
begin
  if FJob<>nil then raise Exception.Create('Aguarde a geracao');
  ExportTo(FileName);FFile:=FileName;FDirty:=False;
  Caption:='Editor de Apresentacoes - '+ExtractFileName(FFile);FStatus.Caption:='Pacote salvo e validado.';
end;
procedure TPresentationEditor.LoadPackage(const FileName: string);
var P: TPVAPackage;NewRoot: string;Succeeded: Boolean;
begin
  if FJob<>nil then raise Exception.Create('Aguarde a geracao');
  P:=TPVAPackage.Create;NewRoot:=NewPrivateDirectory;Succeeded:=False;
  try
    P.Load(FileName);P.ExtractTo(NewRoot);
    ForceDirectories(NewRoot+PathDelim+'assets');
    DeleteDirectory(FRoot,False);FRoot:=NewRoot;Succeeded:=True;FLoading:=True;
    try FEdit.Text:=P.Script;finally FLoading:=False;end;
    FFile:=FileName;FDirty:=False;FEdit.ClearUndo;RefreshResources;
    Caption:='Editor de Apresentacoes - '+ExtractFileName(FFile);
  finally
    P.Free;
    if not Succeeded and DirectoryExists(NewRoot) then DeleteDirectory(NewRoot,False);
  end;
end;
procedure TPresentationEditor.Action(Sender: TObject);
var ID,N: Integer; D: TOpenDialog; S: TSaveDialog; P: TPVAPackage; M: TMemoryStream;
  AFileName,Dest: string; Proc: TProcess;
begin
  ID:=TControl(Sender).Tag;
  if FJob<>nil then begin if ID=15 then FJob.Cancel;Exit;end;
  try
    case ID of
      1: if CanDiscard then begin FEdit.Clear;FEdit.ClearUndo;FFile:='';FDirty:=False;Caption:='Editor de Apresentacoes';end;
      2: if CanDiscard then begin
        D:=TOpenDialog.Create(Self);
        try
          D.Filter:='Apresentacao|*.pva';
          if D.Execute then begin
            LoadPackage(D.FileName);
          end;
        finally D.Free;end;
      end;
      3,4: begin
        AFileName:=FFile;
        if (ID=4) or (AFileName='') then begin
          S:=TSaveDialog.Create(Self);
          try S.Filter:='Apresentacao|*.pva';S.DefaultExt:='pva';S.Options:=S.Options+[ofOverwritePrompt];if not S.Execute then Exit;AFileName:=S.FileName;finally S.Free;end;
        end;
        SavePackage(AFileName);
      end;
      5: begin
        D:=TOpenDialog.Create(Self);
        try
          D.Filter:='Midia|*.png;*.jpg;*.jpeg;*.bmp;*.mp4;*.avi;*.wmv;*.pptx';
          if D.Execute then begin
            if not SupportedPresentationMedia(D.FileName) then raise Exception.Create('Formato nao suportado');
            M:=TMemoryStream.Create;
            try
              if FileSize(D.FileName)>PVAMaxFile then raise Exception.Create('Arquivo excede 64 MiB');
              M.LoadFromFile(D.FileName);
              AFileName:='assets/'+PresentationSHA256(M)+LowerCase(ExtractFileExt(D.FileName));
              Dest:=FRoot+PathDelim+StringReplace(AFileName,'/',PathDelim,[rfReplaceAll]);
              M.SaveToFile(Dest);
            finally M.Free;end;
            Insert('[executar arquivo='+AFileName+']');RefreshResources;
          end;
        finally D.Free;end;
      end;
      6: Insert('[fechar arquivo]');
      7: Insert('[slide anterior]');
      8: Insert('[proximo slide]');
      9: begin
        AFileName:=InputBox('Ir ao slide','Numero do slide (a partir de 1)','1');
        if not TryStrToInt(AFileName,N) or (N<1) or (N>10000) then raise Exception.Create('Slide invalido');
        Insert('[ir para slide='+IntToStr(N)+']');
      end;
      10: FEdit.Undo;
      11: FEdit.Redo;
      12: begin
        AFileName:=FRoot+PathDelim+'validacao.pva';ExportTo(AFileName);
        P:=TPVAPackage.Create;try P.Load(AFileName);finally P.Free;end;
        FStatus.Caption:='Roteiro, recursos e integridade validos.';
      end;
      13: begin
        ValidatePresentationScript(FEdit.Text);FOriginal:=FEdit.Text;
        FJob:=TPresentationAIJob.Create(FSettings,FOriginal);FEdit.ReadOnly:=True;FStatus.Caption:='Gerando movimentos...';
      end;
      16: begin
        D:=TOpenDialog.Create(Self);
        try D.Filter:='Assistente|assistente.exe';if D.Execute then FAssistant.Text:=D.FileName;finally D.Free;end;
      end;
      14: begin
        if not FileExists(FAssistant.Text) then raise Exception.Create('Selecione o executavel atualizado do Assistente');
        AFileName:=FRoot+PathDelim+'previa.pva';ExportTo(AFileName);
        Proc:=TProcess.Create(nil);
        try
          Proc.Executable:=FAssistant.Text;Proc.Parameters.Add('--presentation');Proc.Parameters.Add(AFileName);
          Proc.Options:=[poNoConsole];Proc.Execute;FStatus.Caption:='Previa iniciada. P pausa/retoma; Esc cancela no Assistente.';
        finally Proc.Free;end;
      end;
    end;
  except on E: Exception do MessageDlg(E.Message,mtError,[mbOK],0);end;
end;
procedure TPresentationEditor.Tick(Sender: TObject);
var J: TPresentationAIJob; Saved: string;
begin
  if (FJob=nil) or not FJob.Finished then Exit;
  J:=FJob;FJob:=nil;FEdit.ReadOnly:=False;
  try
    if J.WasCancelled then FStatus.Caption:='Geracao cancelada.'
    else if J.ErrorText<>'' then FStatus.Caption:=J.ErrorText
    else begin
      if FEdit.Text<>FOriginal then raise Exception.Create('Roteiro mudou durante a geracao');
      Saved:=AcceptGeneratedMovements(FOriginal,J.Output);
      FEdit.BeginUndoBlock;
      try FEdit.SelectAll;FEdit.SelText:=Saved;finally FEdit.EndUndoBlock;end;
      FStatus.Caption:='Movimentos aplicados. Desfazer restaura o roteiro anterior.';
    end;
  except on E: Exception do FStatus.Caption:=E.Message;end;
  J.Free;
end;
end.
