program criador_avatar;
{ Criador Avatar: cria e importa avatares para o Assistente.
  Corpo e rosto com os modificadores do MakeHuman, aparência (pele, olhos,
  cabelo, roupa e acessórios), importação de perfis do MakeHuman (.mhm) e de
  personagens do Avaturn e do Tripo3D (.glb), prévia 3D e geração na pasta
  AVATARES com os movimentos calibrados. A geração usa o gerador em Python
  distribuído em tools\ (runtime\python no instalador). }
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SysUtils, Classes, Math, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs,
  Graphics, Process, LCLIntf, LCLType, fpjson, jsonparser, LazFileUtils, FileUtil,
  CastleVectors, multisuite_controls, multisuite_icons, professor_view;

const
  MACROS: array[0..10] of string = (
    'macrodetails/Gender', 'macrodetails/Age', 'macrodetails-universal/Muscle',
    'macrodetails-universal/Weight', 'macrodetails-height/Height',
    'macrodetails-proportions/BodyProportions', 'macrodetails/African',
    'macrodetails/Asian', 'macrodetails/Caucasian', 'breast/BreastSize', 'breast/BreastFirmness');
  MACRO_LABELS: array[0..10] of string = (
    'Gênero (feminino ↔ masculino)', 'Idade (1 ↔ 90 anos)', 'Músculos', 'Peso', 'Altura',
    'Proporções do corpo', 'Ascendência africana', 'Ascendência asiática',
    'Ascendência europeia', 'Busto', 'Firmeza do busto');
  FACE_GROUPS: array[0..12] of string = ('head', 'forehead', 'eyebrows', 'eyes', 'nose', 'mouth',
    'ears', 'chin', 'cheek', 'neck', 'torso', 'hip', 'armslegs');
  FACE_GROUP_LABELS: array[0..12] of string = ('Cabeça', 'Testa', 'Sobrancelhas', 'Olhos', 'Nariz',
    'Boca', 'Orelhas', 'Queixo', 'Bochechas', 'Pescoço', 'Tronco', 'Quadril', 'Braços e pernas');
  OUTFITS: array[0..5] of string = ('female_casualsuit01', 'male_casualsuit01', 'male_casualsuit02',
    'male_casualsuit03', 'male_elegantsuit01', 'male_worksuit01');
  OUTFIT_LABELS: array[0..5] of string = ('Casual feminino (camiseta e jeans)', 'Casual masculino 1',
    'Casual masculino 2', 'Camisa e calça', 'Terno / tailleur', 'Uniforme de trabalho');
  HAIRS: array[0..5] of string = ('long', 'long_curly', 'short02', 'short03', 'bob01', 'afro01');
  HAIR_LABELS: array[0..5] of string = ('Longo liso', 'Longo cacheado', 'Curto 1', 'Curto 2', 'Chanel', 'Crespo');
  SKINS: array[0..4] of string = ('young_caucasian_female', 'young_caucasian_male', 'young_african_female',
    'young_african_male', 'old_caucasian_male');
  SKIN_LABELS: array[0..4] of string = ('Clara (feminina)', 'Clara (masculina)', 'Negra (feminina)',
    'Negra (masculina)', 'Clara madura (masculina)');
  IRIS: array[0..8] of string = ('brown', 'brownlight', 'blue', 'bluegreen', 'deepblue', 'green', 'grey', 'ice', 'lightblue');
  IRIS_LABELS: array[0..8] of string = ('Castanhos', 'Castanho-claros', 'Azuis', 'Azul-esverdeados',
    'Azul-escuros', 'Verdes', 'Cinzentos', 'Azul-gelo', 'Azul-claros');

type
  TJob = (jbNone, jbPreview, jbBuild, jbImportMhm, jbImportGlb, jbTripo);

  TCreatorForm = class(TForm)
  private
    View: TProfessorView;
    Pages: TPageControl;
    MacroBars: array[0..10] of TTrackBar;
    GroupBox: TComboBox;
    FaceBox: TScrollBox;
    IdEdit, NameEdit, BadgeEdit, TripoKeyEdit: TEdit;
    SkinBox, IrisBox, HairBox, OutfitBox, TopBox, GlassesBox: TComboBox;
    HairRoot, HairTip, TopColor, TieColor, ShoeColor: TColorButton;
    TieCheck, BadgeCheck, HoopsCheck, ShoeCheck, TripoRigCheck: TCheckBox;
    SmileBar, BeardBar, VolumeBar: TTrackBar;
    Log: TMemo;
    Status: TLabel;
    Proc: TProcess;
    Poll: TTimer;
    Job: TJob;
    JobFile: string;
    Modifiers: TStringList;     { name=value of the regular (non macro) modifiers }
    Catalog: TJSONArray;
    FLoading: Boolean;
    function AppDir: string;
    function ToolsDir: string;
    function AvatarsDir: string;
    function PythonExe: string;
    function WorkDir: string;
    procedure LoadCatalog;
    procedure BuildFaceSliders;
    procedure FaceSliderChange(Sender: TObject);
    procedure GroupChange(Sender: TObject);
    function SpecJSON: TJSONObject;
    procedure ApplySpec(Spec: TJSONObject);
    procedure SaveSpec(const FileName: string);
    procedure RunPython(const Args: array of string; AJob: TJob; const Env: string = '');
    procedure PollTick(Sender: TObject);
    procedure JobDone(Code: Integer);
    procedure Say(const S: string);
    procedure NewClick(Sender: TObject);
    procedure OpenSpecClick(Sender: TObject);
    procedure SaveSpecClick(Sender: TObject);
    procedure PreviewClick(Sender: TObject);
    procedure BuildClick(Sender: TObject);
    procedure ImportMhmClick(Sender: TObject);
    procedure ImportAvaturnClick(Sender: TObject);
    procedure ImportTripoClick(Sender: TObject);
    procedure TripoPhotoClick(Sender: TObject);
    procedure OpenAvaturnSite(Sender: TObject);
    procedure OpenTripoSite(Sender: TObject);
    procedure OpenMakeHumanSite(Sender: TObject);
    function CheckId: Boolean;
    function Female: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

function ColorHex(C: TColor): string;
var R: LongInt;
begin
  R := ColorToRGB(C);
  Result := Format('#%.2x%.2x%.2x', [Red(R), Green(R), Blue(R)]);
end;

function HexColor(const S: string; Default: TColor): TColor;
var V: LongInt;
begin
  Result := Default;
  if (Length(S) = 7) and (S[1] = '#') and TryStrToInt('$' + Copy(S, 2, 6), V) then
    Result := RGBToColor((V shr 16) and $FF, (V shr 8) and $FF, V and $FF);
end;

function RGBArray(C: TColor): TJSONArray;
var R: LongInt;
begin
  R := ColorToRGB(C);
  Result := TJSONArray.Create([Red(R), Green(R), Blue(R)]);
end;

function ArrayColor(A: TJSONData; Default: TColor): TColor;
begin
  Result := Default;
  if (A <> nil) and (A.JSONType = jtArray) and (A.Count >= 3) then
    Result := RGBToColor(A.Items[0].AsInteger, A.Items[1].AsInteger, A.Items[2].AsInteger)
  else if (A <> nil) and (A.JSONType = jtString) then
    Result := HexColor(A.AsString, Default);
end;

function DotFormat: TFormatSettings;
begin
  Result := DefaultFormatSettings;
  Result.DecimalSeparator := '.';
end;

function IndexOfStr(const Items: array of string; const S: string): Integer;
var I: Integer;
begin
  for I := 0 to High(Items) do
    if Items[I] = S then Exit(I);
  Result := -1;
end;

{ ------------------------------------------------------------------ paths }

function TCreatorForm.AppDir: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

function TCreatorForm.ToolsDir: string;
begin
  Result := AppDir + 'tools' + PathDelim;
  if not DirectoryExists(Result) then
    Result := ExpandFileName(AppDir + '..' + PathDelim + 'tools') + PathDelim;
end;

function TCreatorForm.AvatarsDir: string;
begin
  Result := ExpandFileName(ToolsDir + '..' + PathDelim + 'AVATARES');
end;

function TCreatorForm.PythonExe: string;
begin
  Result := AppDir + 'runtime' + PathDelim + 'python' + PathDelim + {$IFDEF WINDOWS}'python.exe'{$ELSE}'bin/python3'{$ENDIF};
  if not FileExists(Result) then
    Result := {$IFDEF WINDOWS}'python.exe'{$ELSE}'python3'{$ENDIF};
end;

function TCreatorForm.WorkDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'criador_avatar' + PathDelim;
  ForceDirectories(Result);
end;

{ ------------------------------------------------------------------ UI }

constructor TCreatorForm.Create(AOwner: TComponent);
var
  LeftPanel, Bottom, Host, P: TPanel;
  Header: TSuiteHeader;
  Tab: TTabSheet;
  I, Y: Integer;

  function Lbl(Parent: TWinControl; const Text: string; X, AY, W: Integer): TLabel;
  begin
    Result := TLabel.Create(Self); Result.Parent := Parent; Result.SetBounds(X, AY, W, 20);
    Result.Caption := Text; Result.Font.Color := clSuiteMuted;
  end;

  function Btn(Parent: TWinControl; const Text: string; X, AY, W: Integer; Handler: TNotifyEvent;
    Icon: TSuiteIconKind; Solid: Boolean = False): TSuiteButton;
  begin
    Result := TSuiteButton.Create(Self); Result.Parent := Parent; Result.SetBounds(X, AY, W, 32);
    Result.Caption := Text; Result.OnClick := Handler;
    if Solid then Result.SetLook(sbsSolid, clSuitePrimary, Icon) else Result.SetLook(sbsOutline, clSuitePrimary, Icon);
  end;

  function Combo(Parent: TWinControl; X, AY, W: Integer; const Items: array of string): TComboBox;
  var K: Integer;
  begin
    Result := TComboBox.Create(Self); Result.Parent := Parent; Result.SetBounds(X, AY, W, 28);
    Result.Style := csDropDownList;
    for K := 0 to High(Items) do Result.Items.Add(Items[K]);
    Result.ItemIndex := 0;
  end;

  function ColorBtn(Parent: TWinControl; X, AY: Integer; C: TColor): TColorButton;
  begin
    Result := TColorButton.Create(Self); Result.Parent := Parent; Result.SetBounds(X, AY, 64, 26);
    Result.ButtonColor := C;
  end;

  function Bar(Parent: TWinControl; X, AY, W, AMin, AMax, Value: Integer): TTrackBar;
  begin
    Result := TTrackBar.Create(Self); Result.Parent := Parent; Result.SetBounds(X, AY, W, 30);
    Result.Min := AMin; Result.Max := AMax; Result.Position := Value; Result.TickStyle := tsNone;
  end;

begin
  inherited CreateNew(AOwner);
  Caption := 'Criador Avatar - Assistente';
  Width := 1440; Height := 920; Position := poScreenCenter;
  Constraints.MinWidth := 1180; Constraints.MinHeight := 820;
  Font.Name := SUITE_FONT; Font.Size := 10; Color := clSuiteSurface;
  Modifiers := TStringList.Create;
  Modifiers.NameValueSeparator := '=';

  Header := TSuiteHeader.Create(Self); Header.Parent := Self; Header.Align := alTop; Header.Height := 72;
  Header.Setup('Criador Avatar', 'Assistente • Corpo, rosto, aparência e importação (MakeHuman, Avaturn, Tripo3D)', sikAssembly);

  Bottom := TPanel.Create(Self); Bottom.Parent := Self; Bottom.Align := alBottom; Bottom.Height := 170;
  Bottom.BevelOuter := bvNone; Bottom.Color := clSuiteCard;
  LeftPanel := TPanel.Create(Self); LeftPanel.Parent := Self; LeftPanel.Align := alLeft; LeftPanel.Width := 470;
  LeftPanel.BevelOuter := bvNone; LeftPanel.Color := clSuiteCard;
  Host := TPanel.Create(Self); Host.Parent := Self; Host.Align := alClient; Host.BevelOuter := bvNone; Host.Color := clSuiteSurface;

  { Bottom: identity, actions, log }
  Lbl(Bottom, 'ID (pasta)', 12, 8, 120);
  IdEdit := TEdit.Create(Self); IdEdit.Parent := Bottom; IdEdit.SetBounds(12, 28, 200, 28); IdEdit.Text := 'novo_avatar';
  Lbl(Bottom, 'Nome na lista do Assistente', 224, 8, 220);
  NameEdit := TEdit.Create(Self); NameEdit.Parent := Bottom; NameEdit.SetBounds(224, 28, 230, 28); NameEdit.Text := 'Novo avatar';
  Btn(Bottom, 'Novo', 12, 66, 90, @NewClick, sikNew);
  Btn(Bottom, 'Abrir ficha', 108, 66, 120, @OpenSpecClick, sikFolder);
  Btn(Bottom, 'Salvar ficha', 234, 66, 120, @SaveSpecClick, sikSave);
  Btn(Bottom, 'Prévia 3D', 12, 106, 140, @PreviewClick, sikEye, True);
  Btn(Bottom, 'Gerar no Assistente', 158, 106, 196, @BuildClick, sikExport, True);
  Log := TMemo.Create(Self); Log.Parent := Bottom; Log.SetBounds(470, 8, Width - 490, 150);
  Log.Anchors := [akLeft, akTop, akRight]; Log.ReadOnly := True; Log.ScrollBars := ssVertical;
  Status := TLabel.Create(Self); Status.Parent := Bottom; Status.SetBounds(12, 146, 450, 20); Status.Font.Color := clSuiteMuted;

  Pages := TPageControl.Create(Self); Pages.Parent := LeftPanel; Pages.Align := alClient;

  { Corpo }
  Tab := Pages.AddTabSheet; Tab.Caption := 'Corpo';
  for I := 0 to High(MACROS) do
  begin
    Lbl(Tab, MACRO_LABELS[I], 12, 10 + I * 52, 420);
    MacroBars[I] := Bar(Tab, 12, 28 + I * 52, 430, 0, 100, 50);
  end;

  { Rosto }
  Tab := Pages.AddTabSheet; Tab.Caption := 'Rosto e detalhes';
  Lbl(Tab, 'Região', 12, 10, 100);
  GroupBox := Combo(Tab, 12, 30, 430, FACE_GROUP_LABELS); GroupBox.OnChange := @GroupChange;
  FaceBox := TScrollBox.Create(Self); FaceBox.Parent := Tab; FaceBox.SetBounds(4, 66, 452, 520);
  FaceBox.Anchors := [akLeft, akTop, akRight, akBottom]; FaceBox.HorzScrollBar.Visible := False;

  { Aparência }
  Tab := Pages.AddTabSheet; Tab.Caption := 'Aparência';
  P := TPanel.Create(Self); P.Parent := Tab; P.Align := alClient; P.BevelOuter := bvNone;
  Y := 10;
  Lbl(P, 'Pele', 12, Y, 200); SkinBox := Combo(P, 12, Y + 20, 210, SKIN_LABELS);
  Lbl(P, 'Olhos', 236, Y, 200); IrisBox := Combo(P, 236, Y + 20, 210, IRIS_LABELS); Inc(Y, 60);
  Lbl(P, 'Cabelo', 12, Y, 200); HairBox := Combo(P, 12, Y + 20, 210, HAIR_LABELS);
  Lbl(P, 'Raiz', 236, Y, 60); HairRoot := ColorBtn(P, 236, Y + 20, RGBToColor(46, 30, 22));
  Lbl(P, 'Pontas', 312, Y, 60); HairTip := ColorBtn(P, 312, Y + 20, RGBToColor(120, 80, 50)); Inc(Y, 60);
  Lbl(P, 'Volume do cabelo longo', 12, Y, 300); VolumeBar := Bar(P, 12, Y + 18, 430, 0, 60, 0); Inc(Y, 56);
  Lbl(P, 'Roupa', 12, Y, 200); OutfitBox := Combo(P, 12, Y + 20, 300, OUTFIT_LABELS); Inc(Y, 60);
  Lbl(P, 'Peça superior', 12, Y, 200);
  TopBox := Combo(P, 12, Y + 20, 210, ['Cores originais', 'Blusa clara e jeans escuro', 'Terno/tailleur com camisa']);
  Lbl(P, 'Cor', 236, Y, 60); TopColor := ColorBtn(P, 236, Y + 20, RGBToColor(22, 23, 27)); Inc(Y, 60);
  TieCheck := TCheckBox.Create(Self); TieCheck.Parent := P; TieCheck.SetBounds(12, Y, 120, 24); TieCheck.Caption := 'Gravata';
  TieColor := ColorBtn(P, 132, Y, RGBToColor(89, 96, 108));
  ShoeCheck := TCheckBox.Create(Self); ShoeCheck.Parent := P; ShoeCheck.SetBounds(220, Y, 150, 24); ShoeCheck.Caption := 'Sapato fechado';
  ShoeColor := ColorBtn(P, 372, Y, RGBToColor(6, 6, 7)); Inc(Y, 40);
  Lbl(P, 'Óculos', 12, Y, 200); GlassesBox := Combo(P, 12, Y + 20, 210, ['Sem óculos', 'Armação escura', 'Armação de metal']);
  HoopsCheck := TCheckBox.Create(Self); HoopsCheck.Parent := P; HoopsCheck.SetBounds(236, Y + 22, 200, 24); HoopsCheck.Caption := 'Argolas douradas'; Inc(Y, 60);
  BadgeCheck := TCheckBox.Create(Self); BadgeCheck.Parent := P; BadgeCheck.SetBounds(12, Y, 160, 24); BadgeCheck.Caption := 'Crachá com cordão';
  BadgeEdit := TEdit.Create(Self); BadgeEdit.Parent := P; BadgeEdit.SetBounds(180, Y, 160, 26); BadgeEdit.Text := 'FATEC'; Inc(Y, 40);
  Lbl(P, 'Sorriso', 12, Y, 200); SmileBar := Bar(P, 12, Y + 18, 430, 0, 100, 40); Inc(Y, 52);
  Lbl(P, 'Barba', 12, Y, 200); BeardBar := Bar(P, 12, Y + 18, 430, 0, 100, 0);

  { Importar }
  Tab := Pages.AddTabSheet; Tab.Caption := 'Importar';
  Lbl(Tab, 'MAKEHUMAN', 12, 12, 400);
  Btn(Tab, 'Abrir perfil do MakeHuman (.mhm)', 12, 36, 430, @ImportMhmClick, sikImport, True);
  Btn(Tab, 'Baixar o MakeHuman (gratuito)', 12, 74, 430, @OpenMakeHumanSite, sikArrowRight);
  Lbl(Tab, 'Ajusta corpo e rosto exatamente como no MakeHuman; roupas e cabelos', 12, 112, 440);
  Lbl(Tab, 'sem equivalente aqui são trocados pelos mais próximos (veja o registro).', 12, 130, 440);
  Lbl(Tab, 'AVATURN', 12, 168, 400);
  Btn(Tab, 'Abrir hub.avaturn.me (criar com fotos)', 12, 192, 430, @OpenAvaturnSite, sikArrowRight);
  Btn(Tab, 'Importar .glb exportado do Avaturn', 12, 230, 430, @ImportAvaturnClick, sikImport, True);
  Lbl(Tab, 'TRIPO3D', 12, 280, 400);
  Btn(Tab, 'Abrir studio.tripo3d.ai', 12, 304, 430, @OpenTripoSite, sikArrowRight);
  Btn(Tab, 'Importar .glb exportado do Tripo3D', 12, 342, 430, @ImportTripoClick, sikImport, True);
  Lbl(Tab, 'Chave da API do Tripo (não é gravada)', 12, 386, 400);
  TripoKeyEdit := TEdit.Create(Self); TripoKeyEdit.Parent := Tab; TripoKeyEdit.SetBounds(12, 406, 430, 28); TripoKeyEdit.PasswordChar := '*';
  TripoRigCheck := TCheckBox.Create(Self); TripoRigCheck.Parent := Tab; TripoRigCheck.SetBounds(12, 440, 430, 24);
  TripoRigCheck.Caption := 'Pedir esqueleto ao Tripo (bípede)'; TripoRigCheck.Checked := True;
  Btn(Tab, 'Gerar no Tripo3D a partir de uma foto', 12, 470, 430, @TripoPhotoClick, sikImage, True);
  Lbl(Tab, 'O personagem deve estar em pé, de frente, em pose T ou A.', 12, 512, 440);

  View := TProfessorView.Create(Self, Host);
  if not View.LoadModel('', True) then Say(View.Diagnostic);
  View.Viewport.BackgroundColor := Vector4(0.945, 0.961, 0.980, 1);

  Poll := TTimer.Create(Self); Poll.Interval := 150; Poll.Enabled := False; Poll.OnTimer := @PollTick;
  LoadCatalog;
  GroupBox.ItemIndex := 4; BuildFaceSliders;
  NewClick(nil);
  Say('Pronto. Ajuste o corpo, o rosto e a aparência, depois clique em Prévia 3D.');
end;

destructor TCreatorForm.Destroy;
begin
  if Assigned(Proc) and Proc.Running then Proc.Terminate(1);
  Proc.Free;
  Catalog.Free;
  Modifiers.Free;
  inherited Destroy;
end;

procedure TCreatorForm.Say(const S: string);
begin
  Log.Lines.Add(S);
  Status.Caption := S;
end;

procedure TCreatorForm.LoadCatalog;
var F: string; S: TStringList; D: TJSONData;
begin
  F := ToolsDir + 'avatar-source' + PathDelim + 'criador-catalogo.json';
  Catalog := TJSONArray.Create;
  if not FileExists(F) then begin Say('Catálogo de modificadores ausente: ' + F); Exit; end;
  S := TStringList.Create;
  try
    S.LoadFromFile(F);
    D := GetJSON(S.Text);
    try
      Catalog.Free;
      Catalog := TJSONArray(TJSONObject(D).Arrays['modifiers'].Clone);
    finally D.Free; end;
  finally S.Free; end;
end;

procedure TCreatorForm.BuildFaceSliders;
var I, Y, V: Integer; M: TJSONObject; Group, MKey: string; L: TLabel; B: TTrackBar;
begin
  while FaceBox.ControlCount > 0 do FaceBox.Controls[0].Free;
  Group := FACE_GROUPS[Max(0, GroupBox.ItemIndex)];
  Y := 6;
  for I := 0 to Catalog.Count - 1 do
  begin
    M := Catalog.Objects[I];
    if (M.Get('group', '') <> Group) or M.Get('macro', False) then Continue;
    MKey := M.Get('name', '');
    L := TLabel.Create(FaceBox); L.Parent := FaceBox; L.SetBounds(8, Y, 400, 18); L.Caption := M.Get('label', MKey);
    L.Font.Color := clSuiteMuted;
    B := TTrackBar.Create(FaceBox); B.Parent := FaceBox; B.SetBounds(8, Y + 16, 410, 28); B.TickStyle := tsNone;
    B.Min := Round(M.Get('min', 0.0) * 100); B.Max := Round(M.Get('max', 1.0) * 100);
    V := Round(StrToFloatDef(Modifiers.Values[MKey], 0, DotFormat) * 100);
    FLoading := True; B.Position := V; FLoading := False;
    B.Hint := MKey; B.OnChange := @FaceSliderChange;
    Inc(Y, 50);
  end;
end;

procedure TCreatorForm.FaceSliderChange(Sender: TObject);
var B: TTrackBar; FS: TFormatSettings;
begin
  if FLoading then Exit;
  B := TTrackBar(Sender);
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  if B.Position = 0 then Modifiers.Values[B.Hint] := ''
  else Modifiers.Values[B.Hint] := FloatToStr(B.Position / 100, FS);
end;

procedure TCreatorForm.GroupChange(Sender: TObject);
begin
  BuildFaceSliders;
end;

function TCreatorForm.Female: Boolean;
begin
  Result := MacroBars[0].Position < 50;
end;

{ ------------------------------------------------------------------ spec }

function TCreatorForm.SpecJSON: TJSONObject;
var Mods, Style: TJSONObject; I: Integer; FS: TFormatSettings; Hair: string;
begin
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  Result := TJSONObject.Create;
  Result.Add('format', 'assistente-avatar-spec');
  Result.Add('version', 1);
  Result.Add('id', Trim(IdEdit.Text));
  Result.Add('name', Trim(NameEdit.Text));
  Mods := TJSONObject.Create;
  for I := 0 to High(MACROS) do Mods.Add(MACROS[I], MacroBars[I].Position / 100);
  for I := 0 to Modifiers.Count - 1 do
    if Modifiers.ValueFromIndex[I] <> '' then
      Mods.Add(Modifiers.Names[I], StrToFloatDef(Modifiers.ValueFromIndex[I], 0, FS));
  Result.Add('modifiers', Mods);
  Result.Add('skin', SKINS[Max(0, SkinBox.ItemIndex)]);
  Result.Add('outfit', OUTFITS[Max(0, OutfitBox.ItemIndex)]);
  Hair := HAIRS[Max(0, HairBox.ItemIndex)];
  Style := TJSONObject.Create;
  if Hair = 'long_curly' then begin Hair := 'long'; Style.Add('hair_curl', 1); end;
  Result.Add('hair', Hair);
  if Hair = 'long' then
  begin
    Style.Add('hair_root', RGBArray(HairRoot.ButtonColor));
    Style.Add('hair_tip', RGBArray(HairTip.ButtonColor));
    if VolumeBar.Position > 0 then Style.Add('hair_volume', VolumeBar.Position / 1000);
  end
  else
    Style.Add('hair_tint', TJSONArray.Create([ColorHex(HairRoot.ButtonColor), ColorHex(HairTip.ButtonColor)]));
  Style.Add('iris', IRIS[Max(0, IrisBox.ItemIndex)]);
  Style.Add('smile', SmileBar.Position / 100 * 0.6);
  if BeardBar.Position > 0 then Style.Add('beard', BeardBar.Position / 100);
  case TopBox.ItemIndex of
    1: begin Style.Add('top', 'blouse'); Style.Add('top_color', ColorHex(TopColor.ButtonColor)); Style.Add('bottom', 'jeans'); end;
    2: begin Style.Add('top', 'blazer'); Style.Add('top_color', ColorHex(TopColor.ButtonColor)); end;
  end;
  if TieCheck.Checked then Style.Add('tie', ColorHex(TieColor.ButtonColor));
  if ShoeCheck.Checked then
  begin
    Style.Add('shoe_shell', True);
    Style.Add('shoes', TJSONArray.Create([ColorHex(ShoeColor.ButtonColor), ColorHex(ShoeColor.ButtonColor)]));
  end;
  case GlassesBox.ItemIndex of
    1: Style.Add('glasses', 'dark');
    2: Style.Add('glasses', 'metal');
  end;
  if HoopsCheck.Checked then Style.Add('earrings', 'hoops');
  if BadgeCheck.Checked and (Trim(BadgeEdit.Text) <> '') then Style.Add('badge', Trim(BadgeEdit.Text));
  Result.Add('style', Style);
  Result.Add('source', TJSONObject.Create(['kind', 'criador-avatar']));
end;

procedure TCreatorForm.ApplySpec(Spec: TJSONObject);
var I, K: Integer; Mods, Style: TJSONObject; D: TJSONData; Hair, MKey: string; FS: TFormatSettings;
const DEF: array[0..10] of Double = (0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1/3, 1/3, 1/3, 0.5, 0.5);
begin
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  FLoading := True;
  try
    IdEdit.Text := Spec.Get('id', IdEdit.Text);
    NameEdit.Text := Spec.Get('name', NameEdit.Text);
    Mods := Spec.Get('modifiers', TJSONObject(nil));
    Modifiers.Clear;
    for I := 0 to High(MACROS) do MacroBars[I].Position := Round(DEF[I] * 100);
    if Mods <> nil then
      for K := 0 to Mods.Count - 1 do
      begin
        MKey := Mods.Names[K];
        I := IndexOfStr(MACROS, MKey);
        if I >= 0 then MacroBars[I].Position := Round(Mods.Items[K].AsFloat * 100)
        else Modifiers.Values[MKey] := FloatToStr(Mods.Items[K].AsFloat, FS);
      end;
    SkinBox.ItemIndex := Max(0, IndexOfStr(SKINS, Spec.Get('skin', '')));
    OutfitBox.ItemIndex := Max(0, IndexOfStr(OUTFITS, Spec.Get('outfit', '')));
    Style := Spec.Get('style', TJSONObject(nil));
    D := Spec.Find('hair');
    if (D = nil) or (D.JSONType = jtNull) then Hair := 'short02' else Hair := D.AsString;
    if (Style <> nil) and (Hair = 'long') and (Style.Get('hair_curl', 0) > 0) then Hair := 'long_curly';
    HairBox.ItemIndex := Max(0, IndexOfStr(HAIRS, Hair));
    TopBox.ItemIndex := 0; TieCheck.Checked := False; ShoeCheck.Checked := False; GlassesBox.ItemIndex := 0;
    HoopsCheck.Checked := False; BadgeCheck.Checked := False; BeardBar.Position := 0; VolumeBar.Position := 0;
    if Style <> nil then
    begin
      HairRoot.ButtonColor := ArrayColor(Style.Find('hair_root'), HairRoot.ButtonColor);
      HairTip.ButtonColor := ArrayColor(Style.Find('hair_tip'), HairTip.ButtonColor);
      D := Style.Find('hair_tint');
      if (D <> nil) and (D.JSONType = jtArray) and (D.Count = 2) then
      begin
        HairRoot.ButtonColor := HexColor(D.Items[0].AsString, HairRoot.ButtonColor);
        HairTip.ButtonColor := HexColor(D.Items[1].AsString, HairTip.ButtonColor);
      end;
      VolumeBar.Position := Round(Style.Get('hair_volume', 0.0) * 1000);
      IrisBox.ItemIndex := Max(0, IndexOfStr(IRIS, Style.Get('iris', 'brown')));
      SmileBar.Position := Round(Style.Get('smile', 0.24) / 0.6 * 100);
      BeardBar.Position := Round(Style.Get('beard', 0.0) * 100);
      if Style.Get('top', '') = 'blouse' then TopBox.ItemIndex := 1
      else if Style.Get('top', '') = 'blazer' then TopBox.ItemIndex := 2;
      TopColor.ButtonColor := HexColor(Style.Get('top_color', ''), TopColor.ButtonColor);
      D := Style.Find('tie');
      TieCheck.Checked := (D <> nil) and (D.JSONType = jtString);
      if TieCheck.Checked then TieColor.ButtonColor := HexColor(D.AsString, TieColor.ButtonColor);
      ShoeCheck.Checked := Style.Get('shoe_shell', False);
      D := Style.Find('shoes');
      if (D <> nil) and (D.JSONType = jtArray) and (D.Count > 0) then ShoeColor.ButtonColor := HexColor(D.Items[0].AsString, ShoeColor.ButtonColor);
      if Style.Get('glasses', '') = 'dark' then GlassesBox.ItemIndex := 1
      else if Style.Get('glasses', '') = 'metal' then GlassesBox.ItemIndex := 2;
      HoopsCheck.Checked := Style.Get('earrings', '') = 'hoops';
      BadgeCheck.Checked := Style.Get('badge', '') <> '';
      if BadgeCheck.Checked then BadgeEdit.Text := Style.Get('badge', '');
    end;
  finally
    FLoading := False;
  end;
  BuildFaceSliders;
end;

procedure TCreatorForm.SaveSpec(const FileName: string);
var J: TJSONObject; S: TStringList;
begin
  J := SpecJSON;
  S := TStringList.Create;
  try
    S.Text := J.FormatJSON;
    S.SaveToFile(FileName);
  finally S.Free; J.Free; end;
end;

function TCreatorForm.CheckId: Boolean;
var S: string; C: Char;
begin
  S := Trim(IdEdit.Text);
  Result := (Length(S) >= 2) and (Length(S) <= 41);
  for C in S do
    if not (C in ['a'..'z', '0'..'9', '_']) then Result := False;
  if not Result then
    MessageDlg('ID inválido', 'Use de 2 a 41 letras minúsculas, números ou _ (sem acentos nem espaços).', mtWarning, [mbOK], 0);
end;

{ ------------------------------------------------------------------ jobs }

procedure TCreatorForm.RunPython(const Args: array of string; AJob: TJob; const Env: string);
var I: Integer;
begin
  if Assigned(Proc) and Proc.Running then
  begin
    Say('Aguarde: outra operação ainda está em andamento.');
    Exit;
  end;
  FreeAndNil(Proc);
  Proc := TProcess.Create(nil);
  Proc.Executable := PythonExe;
  { The packaged interpreter ignores environment variables in isolated mode. }
  Proc.Parameters.Add('-X');
  Proc.Parameters.Add('utf8');
  Proc.Parameters.Add('-u');
  for I := 0 to High(Args) do Proc.Parameters.Add(Args[I]);
  Proc.CurrentDirectory := ToolsDir;
  Proc.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
  { UTF-8 output so accents show correctly in the log on Windows. }
  for I := 0 to GetEnvironmentVariableCount - 1 do Proc.Environment.Add(GetEnvironmentString(I));
  Proc.Environment.Add('PYTHONUTF8=1');
  Proc.Environment.Add('PYTHONIOENCODING=utf-8');
  if Env <> '' then Proc.Environment.Add(Env);
  Job := AJob;
  Screen.Cursor := crAppStart;
  try
    Proc.Execute;
  except
    on E: Exception do
    begin
      Screen.Cursor := crDefault; Job := jbNone;
      Say('Não foi possível iniciar o gerador (' + PythonExe + '): ' + E.Message);
      Exit;
    end;
  end;
  Poll.Enabled := True;
end;

procedure TCreatorForm.PollTick(Sender: TObject);
var Buf: string; N: Integer; Lines: TStringList; I: Integer;
begin
  if Proc = nil then Exit;
  while Proc.Output.NumBytesAvailable > 0 do
  begin
    SetLength(Buf, Proc.Output.NumBytesAvailable);
    N := Proc.Output.Read(Buf[1], Length(Buf));
    SetLength(Buf, N);
    Lines := TStringList.Create;
    try
      Lines.Text := Buf;
      for I := 0 to Lines.Count - 1 do
        if Trim(Lines[I]) <> '' then Say(Lines[I]);
    finally Lines.Free; end;
  end;
  if not Proc.Running then
  begin
    Poll.Enabled := False;
    Screen.Cursor := crDefault;
    JobDone(Proc.ExitStatus);
  end;
end;

procedure TCreatorForm.JobDone(Code: Integer);
var Model, F: string; S: TStringList; D: TJSONData;
begin
  if Code <> 0 then
  begin
    Say('A operação falhou (código ' + IntToStr(Code) + '). Veja as mensagens acima.');
    Job := jbNone;
    Exit;
  end;
  case Job of
    jbPreview:
      begin
        Model := WorkDir + 'AVATARES' + PathDelim + Trim(IdEdit.Text) + PathDelim + 'modelo.gltf';
        if View.LoadModel(Model, True) then Say('Prévia carregada.') else Say(View.Diagnostic);
      end;
    jbBuild, jbImportGlb, jbTripo:
      begin
        Model := IncludeTrailingPathDelimiter(AvatarsDir) + Trim(IdEdit.Text) + PathDelim + 'modelo.gltf';
        if View.LoadModel(Model, True) then
          Say('Avatar gerado em ' + ExtractFileDir(Model) + '. No Assistente, clique em ↻ na lista de avatares.')
        else Say(View.Diagnostic);
      end;
    jbImportMhm:
      begin
        F := JobFile;
        S := TStringList.Create;
        try
          S.LoadFromFile(F);
          D := GetJSON(S.Text);
          try ApplySpec(TJSONObject(D)); finally D.Free; end;
        finally S.Free; end;
        Say('Perfil do MakeHuman importado. Ajuste se quiser e clique em Prévia 3D ou Gerar.');
      end;
  end;
  Job := jbNone;
end;

{ ------------------------------------------------------------------ actions }

procedure TCreatorForm.NewClick(Sender: TObject);
var J: TJSONObject;
begin
  J := TJSONObject(GetJSON('{"id":"novo_avatar","name":"Novo avatar","modifiers":{"macrodetails/Gender":0.0,' +
    '"macrodetails/Caucasian":1.0,"macrodetails/African":0.0,"macrodetails/Asian":0.0},"skin":"young_caucasian_female",' +
    '"outfit":"female_casualsuit01","hair":"long","style":{"hair_root":[46,30,22],"hair_tip":[120,80,50],"iris":"brown","smile":0.24}}'));
  try ApplySpec(J); finally J.Free; end;
end;

procedure TCreatorForm.OpenSpecClick(Sender: TObject);
var D: TOpenDialog; S: TStringList; J: TJSONData;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Ficha de avatar (*.avatar.json;*.json)|*.avatar.json;*.json';
    D.InitialDir := AvatarsDir;
    if not D.Execute then Exit;
    S := TStringList.Create;
    try
      S.LoadFromFile(D.FileName);
      J := GetJSON(S.Text);
      try
        if (J.JSONType <> jtObject) or (TJSONObject(J).Get('format', '') <> 'assistente-avatar-spec') then
          raise Exception.Create('o arquivo não é uma ficha de avatar do Assistente');
        ApplySpec(TJSONObject(J));
      finally J.Free; end;
      Say('Ficha aberta: ' + D.FileName);
    except
      on E: Exception do Say('Não foi possível abrir: ' + E.Message);
    end;
    S.Free;
  finally D.Free; end;
end;

procedure TCreatorForm.SaveSpecClick(Sender: TObject);
var D: TSaveDialog;
begin
  if not CheckId then Exit;
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Ficha de avatar (*.avatar.json)|*.avatar.json';
    D.FileName := Trim(IdEdit.Text) + '.avatar.json';
    D.Options := D.Options + [ofOverwritePrompt];
    if D.Execute then begin SaveSpec(D.FileName); Say('Ficha salva: ' + D.FileName); end;
  finally D.Free; end;
end;

procedure TCreatorForm.PreviewClick(Sender: TObject);
var F, Dir: string;
begin
  if not CheckId then Exit;
  Dir := WorkDir + 'AVATARES';
  ForceDirectories(Dir);
  F := WorkDir + 'previa.avatar.json';
  SaveSpec(F);
  Say('Gerando prévia (cerca de 20 segundos)...');
  RunPython(['avatar_spec.py', 'build', F, '--preview', '--avatars', Dir], jbPreview);
end;

procedure TCreatorForm.BuildClick(Sender: TObject);
var F: string;
begin
  if not CheckId then Exit;
  if DirectoryExists(IncludeTrailingPathDelimiter(AvatarsDir) + Trim(IdEdit.Text)) and
     (MessageDlg('Substituir avatar', 'Já existe um avatar com o ID "' + Trim(IdEdit.Text) + '". Substituir?',
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  F := WorkDir + Trim(IdEdit.Text) + '.avatar.json';
  SaveSpec(F);
  Say('Gerando o avatar e calibrando os 53 movimentos (alguns minutos)...');
  RunPython(['avatar_spec.py', 'build', F, '--avatars', AvatarsDir], jbBuild);
end;

procedure TCreatorForm.ImportMhmClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Perfil do MakeHuman (*.mhm)|*.mhm';
    if not D.Execute then Exit;
    JobFile := WorkDir + 'importado.avatar.json';
    Say('Importando ' + ExtractFileName(D.FileName) + '...');
    RunPython(['avatar_spec.py', 'import-mhm', D.FileName, '--out', JobFile], jbImportMhm);
  finally D.Free; end;
end;

procedure ImportGlb(Form: TCreatorForm; const Source, Title: string);
var D: TOpenDialog; Args: array of string;
begin
  if not Form.CheckId then Exit;
  D := TOpenDialog.Create(Form);
  try
    D.Title := Title;
    D.Filter := 'Modelo 3D (*.glb;*.gltf)|*.glb;*.gltf';
    if not D.Execute then Exit;
    Args := ['glb_import.py', D.FileName, '--id', Trim(Form.IdEdit.Text), '--name', Trim(Form.NameEdit.Text),
      '--source', Source, '--avatars', Form.AvatarsDir];
    if not Form.Female then begin SetLength(Args, Length(Args) + 1); Args[High(Args)] := '--male'; end;
    Form.Say('Importando ' + ExtractFileName(D.FileName) + ' e calibrando os movimentos...');
    Form.RunPython(Args, jbImportGlb);
  finally D.Free; end;
end;

procedure TCreatorForm.ImportAvaturnClick(Sender: TObject);
begin
  ImportGlb(Self, 'avaturn', 'Modelo exportado do Avaturn');
end;

procedure TCreatorForm.ImportTripoClick(Sender: TObject);
begin
  ImportGlb(Self, 'tripo3d', 'Modelo exportado do Tripo3D');
end;

procedure TCreatorForm.TripoPhotoClick(Sender: TObject);
var D: TOpenDialog; Args: array of string;
begin
  if not CheckId then Exit;
  if Trim(TripoKeyEdit.Text) = '' then
  begin
    Say('Informe a chave da API do Tripo (em studio.tripo3d.ai, área de API).');
    Exit;
  end;
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Foto (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp';
    if not D.Execute then Exit;
    Args := ['tripo_client.py', 'from-image', D.FileName, '--id', Trim(IdEdit.Text), '--name', Trim(NameEdit.Text),
      '--avatars', AvatarsDir];
    if TripoRigCheck.Checked then begin SetLength(Args, Length(Args) + 1); Args[High(Args)] := '--rig'; end;
    if not Female then begin SetLength(Args, Length(Args) + 1); Args[High(Args)] := '--male'; end;
    Say('Enviando a foto ao Tripo3D. A geração leva alguns minutos...');
    { The key goes to the child process environment only, never to the command line or disk. }
    RunPython(Args, jbTripo, 'TRIPO_API_KEY=' + Trim(TripoKeyEdit.Text));
  finally D.Free; end;
end;

procedure TCreatorForm.OpenAvaturnSite(Sender: TObject);
begin
  OpenURL('https://hub.avaturn.me');
  Say('No Avaturn: crie o avatar com fotos, exporte em .glb e use "Importar .glb exportado do Avaturn".');
end;

procedure TCreatorForm.OpenTripoSite(Sender: TObject);
begin
  OpenURL('https://studio.tripo3d.ai');
  Say('No Tripo3D: gere o personagem em pose T ou A, exporte em .glb e use "Importar .glb exportado do Tripo3D".');
end;

procedure TCreatorForm.OpenMakeHumanSite(Sender: TObject);
begin
  OpenURL('https://static.makehumancommunity.org/makehuman.html');
end;

var
  Form: TCreatorForm;
begin
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TCreatorForm, Form);
  Application.Run;
end.
