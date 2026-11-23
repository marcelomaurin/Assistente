unit settings_nav;
{ Side navigation for the settings dialog. The existing TPageControl and its
  pages stay the source of truth (tests and code select pages through it);
  this unit hides the tabs and offers grouped entries with a status dot, a
  section header and an "unsaved changes" notice. }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, Forms, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  LCLType, Math, Spin, LazUTF8, presentation_chrome;

type
  TSettingsPageStatus = (spsNone, spsOk, spsError, spsOff);
  TSettingsStatusEvent = function(Page: TTabSheet; out Detail: string): TSettingsPageStatus of object;

  TSettingsNavigator = class(TComponent)
  private
    FPages: TPageControl;
    FForm: TCustomForm;
    FNavPanel, FContentPanel, FHeaderPanel, FNavHeader: TPanel;
    FSaveChrome, FCancelChrome: TChromeButton;
    FList: TListBox;
    FTitle, FDescription, FDirty: TLabel;
    FTimer: TTimer;
    FDescriptions: TStringList;
    FBaseline: string;
    FSaveButton, FCancelButton: TControl;
    FButtonsPanel: TPanel;
    FOnStatus: TSettingsStatusEvent;
    FSyncing: Boolean;
    procedure ListDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure ListSelectionChange(Sender: TObject; User: Boolean);
    procedure ListMeasure(Control: TWinControl; Index: Integer; var AHeight: Integer);
    procedure Tick(Sender: TObject);
    procedure ButtonsResize(Sender: TObject);
    procedure ChromeClick(Sender: TObject);
    function Fingerprint: string;
    function PageStatus(Page: TTabSheet; out Detail: string): TSettingsPageStatus;
    procedure SyncFromPages;
    procedure UpdateHeader;
  public
    constructor CreateFor(AForm: TCustomForm; APages: TPageControl; AButtons: TPanel;
      ASave, ACancel: TControl);
    destructor Destroy; override;
    procedure AddGroup(const Caption: string);
    procedure AddPage(Page: TTabSheet; const Caption, Description: string);
    { Adds any page not listed yet under the current group. }
    procedure AddRemainingPages;
    { Records the current values as saved; called after loading the form. }
    procedure MarkSaved;
    function Dirty: Boolean;
    property List: TListBox read FList;
    property SaveButton: TChromeButton read FSaveChrome;
    property CancelButton: TChromeButton read FCancelChrome;
    property OnStatus: TSettingsStatusEvent read FOnStatus write FOnStatus;
  end;

const
  SettingsNavWidth = 220;
  SettingsHeaderHeight = 72;

implementation

const
  NavBack = clWhite;
  NavSelected = $00FFF3EE;     // RGB 238,243,255
  NavSelectedText = $00D05B2D; // RGB 45,91,208
  NavText = $00685A4A;         // RGB 74,90,104
  NavMuted = $00A6948A;        // RGB 138,148,166
  DotOk = $0078B238;           // RGB 56,178,120
  DotError = $00564ED2;        // RGB 210,78,86
  DotOff = $00D6CAC3;          // RGB 195,202,214

constructor TSettingsNavigator.CreateFor(AForm: TCustomForm; APages: TPageControl;
  AButtons: TPanel; ASave, ACancel: TControl);
begin
  inherited Create(AForm);
  FForm := AForm; FPages := APages; FButtonsPanel := AButtons;
  FSaveButton := ASave; FCancelButton := ACancel;
  FDescriptions := TStringList.Create;

  FNavPanel := TPanel.Create(Self);
  FNavPanel.Name := 'SettingsNavigation'; FNavPanel.Caption := '';
  FNavPanel.Parent := AForm; FNavPanel.Align := alLeft; FNavPanel.Width := SettingsNavWidth;
  FNavPanel.BevelOuter := bvNone; FNavPanel.Color := NavBack;
  FNavPanel.BorderSpacing.Right := 1;
  FNavPanel.ParentBackground := False;
  AForm.Color := ChromeLine; // shows as the 1 px line between list and content

  FNavHeader := TPanel.Create(Self);
  FNavHeader.Caption := ''; FNavHeader.Parent := FNavPanel; FNavHeader.Align := alTop;
  FNavHeader.Height := 64; FNavHeader.BevelOuter := bvNone;
  FNavHeader.ParentBackground := False; FNavHeader.Color := NavBack;
  with TLabel.Create(Self) do begin
    Parent := FNavHeader; SetBounds(16, 12, SettingsNavWidth - 24, 26);
    Font.Height := -20; Font.Style := [fsBold]; Font.Color := ChromeInk;
    Caption := 'Configurações';
  end;
  with TLabel.Create(Self) do begin
    Parent := FNavHeader; SetBounds(16, 40, SettingsNavWidth - 24, 18);
    Font.Height := -12; Font.Color := NavMuted;
    Caption := 'Assistente';
  end;

  FList := TListBox.Create(Self);
  FList.Name := 'SettingsSections';
  FList.Parent := FNavPanel; FList.Align := alClient;
  FList.BorderSpacing.Around := 8;
  FList.BorderStyle := bsNone;
  FList.Style := lbOwnerDrawVariable;
  FList.Color := NavBack;
  FList.Font.Height := -14;
  FList.OnDrawItem := @ListDrawItem;
  FList.OnMeasureItem := @ListMeasure;
  FList.OnSelectionChange := @ListSelectionChange;

  FContentPanel := TPanel.Create(Self);
  FContentPanel.Name := 'SettingsContent'; FContentPanel.Caption := '';
  FContentPanel.Parent := AForm; FContentPanel.Align := alClient;
  FContentPanel.BevelOuter := bvNone;
  FContentPanel.ParentBackground := False; FContentPanel.Color := ChromePage;

  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Name := 'SettingsSectionHeader'; FHeaderPanel.Caption := '';
  FHeaderPanel.Parent := FContentPanel; FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := SettingsHeaderHeight; FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.ParentBackground := False; FHeaderPanel.Color := ChromePage;

  FTitle := TLabel.Create(Self);
  FTitle.Parent := FHeaderPanel; FTitle.SetBounds(18, 12, 420, 32);
  FTitle.Font.Height := -24; FTitle.Font.Style := [fsBold]; FTitle.Font.Color := ChromeInk;

  FDescription := TLabel.Create(Self);
  FDescription.Parent := FHeaderPanel; FDescription.AutoSize := False;
  FDescription.SetBounds(18, 46, 420, 20); FDescription.Font.Height := -13; FDescription.Font.Color := NavText;

  APages.Parent := FContentPanel;
  APages.Align := alClient;
  APages.ShowTabs := False;

  if AButtons <> nil then begin
    AButtons.Height := 60;
    AButtons.ParentBackground := False; AButtons.Color := ChromePage;
    { Colored Salvar / Cancelar. The original buttons stay as the actions'
      owners (handlers, Default/Cancel keys, tests) but are not shown. }
    if ASave <> nil then begin
      FSaveChrome := TChromeButton.Create(Self);
      FSaveChrome.Name := 'SettingsSaveButton';
      FSaveChrome.Parent := AButtons; FSaveChrome.Caption := TButton(ASave).Caption;
      FSaveChrome.SetStyle(ChromeBlue, clWhite, ChromeBlue);
      FSaveChrome.Font.Height := -14; FSaveChrome.SetBounds(0, 10, 110, 40);
      FSaveChrome.OnClick := @ChromeClick;
      ASave.Visible := False;
    end;
    if ACancel <> nil then begin
      FCancelChrome := TChromeButton.Create(Self);
      FCancelChrome.Name := 'SettingsCancelButton';
      FCancelChrome.Parent := AButtons; FCancelChrome.Caption := TButton(ACancel).Caption;
      FCancelChrome.SetStyle(clWhite, ChromeInk, ChromeLine);
      FCancelChrome.Font.Height := -14; FCancelChrome.SetBounds(0, 10, 110, 40);
      FCancelChrome.OnClick := @ChromeClick;
      ACancel.Visible := False;
    end;
    FDirty := TLabel.Create(Self);
    FDirty.Name := 'SettingsUnsavedLabel';
    FDirty.Parent := AButtons; FDirty.AutoSize := False; FDirty.Layout := tlCenter;
    FDirty.Font.Color := $003EA7EB; // RGB 235,167,62
    FDirty.Caption := '● Alterações não salvas';
    FDirty.Visible := False;
    AButtons.OnResize := @ButtonsResize;
  end;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 300;
  FTimer.OnTimer := @Tick;
end;

destructor TSettingsNavigator.Destroy;
begin
  FDescriptions.Free;
  inherited Destroy;
end;

procedure TSettingsNavigator.AddGroup(const Caption: string);
begin
  FList.Items.AddObject(UTF8UpperCase(Caption), nil);
  FDescriptions.Add('');
end;

procedure TSettingsNavigator.AddPage(Page: TTabSheet; const Caption, Description: string);
begin
  if Page = nil then Exit;
  FList.Items.AddObject(Caption, Page);
  FDescriptions.Add(Description);
  SyncFromPages;
end;

procedure TSettingsNavigator.AddRemainingPages;
var I: Integer;
begin
  for I := 0 to FPages.PageCount - 1 do
    if FList.Items.IndexOfObject(FPages.Pages[I]) < 0 then
      AddPage(FPages.Pages[I], FPages.Pages[I].Caption, '');
end;

procedure TSettingsNavigator.ListMeasure(Control: TWinControl; Index: Integer; var AHeight: Integer);
begin
  if FList.Items.Objects[Index] = nil then AHeight := 34 else AHeight := 40;
end;

function TSettingsNavigator.PageStatus(Page: TTabSheet; out Detail: string): TSettingsPageStatus;
begin
  Detail := '';
  if Assigned(FOnStatus) then Result := FOnStatus(Page, Detail) else Result := spsNone;
end;

procedure TSettingsNavigator.ListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var C: TCanvas; S, Detail: string; Page: TTabSheet; Status: TSettingsPageStatus; Y: Integer;
begin
  C := FList.Canvas;
  C.Brush.Style := bsSolid;
  C.Brush.Color := NavBack;
  C.FillRect(ARect);
  S := FList.Items[Index];
  Page := TTabSheet(FList.Items.Objects[Index]);
  C.Font.Assign(FList.Font);
  if Page = nil then begin
    C.Font.Height := -11; C.Font.Style := [fsBold]; C.Font.Color := NavMuted;
    C.Brush.Style := bsClear;
    C.TextOut(ARect.Left + 10, ARect.Bottom - C.TextHeight(S) - 4, S);
    Exit;
  end;
  if Page = FPages.ActivePage then begin
    C.Brush.Color := NavSelected; C.Pen.Color := NavSelected;
    C.RoundRect(ARect.Left + 2, ARect.Top + 2, ARect.Right - 2, ARect.Bottom - 2, 12, 12);
    C.Font.Color := NavSelectedText; C.Font.Style := [fsBold];
  end else C.Font.Color := NavText;
  C.Brush.Style := bsClear;
  C.TextOut(ARect.Left + 12, ARect.Top + (ARect.Bottom - ARect.Top - C.TextHeight(S)) div 2, S);
  Status := PageStatus(Page, Detail);
  if Status <> spsNone then begin
    case Status of
      spsOk: C.Brush.Color := DotOk;
      spsError: C.Brush.Color := DotError;
    else C.Brush.Color := DotOff;
    end;
    C.Brush.Style := bsSolid; C.Pen.Color := C.Brush.Color;
    Y := (ARect.Top + ARect.Bottom) div 2;
    C.Ellipse(ARect.Right - 20, Y - 4, ARect.Right - 12, Y + 4);
  end;
end;

procedure TSettingsNavigator.ListSelectionChange(Sender: TObject; User: Boolean);
var Page: TTabSheet;
begin
  if FSyncing or (FList.ItemIndex < 0) then Exit;
  Page := TTabSheet(FList.Items.Objects[FList.ItemIndex]);
  if Page = nil then begin SyncFromPages; Exit; end;  // group headers are not selectable
  FPages.ActivePage := Page;
  UpdateHeader;
  FList.Invalidate;
end;

procedure TSettingsNavigator.SyncFromPages;
var I: Integer;
begin
  I := FList.Items.IndexOfObject(FPages.ActivePage);
  if I = FList.ItemIndex then Exit;
  FSyncing := True;
  try FList.ItemIndex := I; finally FSyncing := False; end;
  UpdateHeader;
  FList.Invalidate;
end;

procedure TSettingsNavigator.UpdateHeader;
var I: Integer; Detail, Text: string; Status: TSettingsPageStatus;
begin
  if FPages.ActivePage = nil then Exit;
  I := FList.Items.IndexOfObject(FPages.ActivePage);
  if I >= 0 then FTitle.Caption := FList.Items[I] else FTitle.Caption := FPages.ActivePage.Caption;
  Text := '';
  if (I >= 0) and (I < FDescriptions.Count) then Text := FDescriptions[I];
  Status := PageStatus(FPages.ActivePage, Detail);
  FDescription.Font.Color := NavText;
  if (Status in [spsOk, spsError]) and (Detail <> '') then begin
    Text := 'Último teste: ' + Detail;
    if Status = spsOk then FDescription.Font.Color := DotOk else FDescription.Font.Color := DotError;
  end;
  FDescription.Caption := Text;
  FDescription.Hint := Text; FDescription.ShowHint := True;
  FDescription.Width := Max(100, FHeaderPanel.ClientWidth - 28);
end;

function TSettingsNavigator.Fingerprint: string;
var B: TStringBuilder;
  procedure Walk(Parent: TWinControl; const Path: string);
  var I: Integer; C: TControl; P: string;
  begin
    for I := 0 to Parent.ControlCount - 1 do begin
      C := Parent.Controls[I];
      P := Path + '/' + IntToStr(I);
      if C is TCustomComboBox then B.Append(P).Append('=').Append(TCustomComboBox(C).ItemIndex).Append(':').Append(TCustomComboBox(C).Text).Append(#10)
      else if C is TCustomFloatSpinEdit then B.Append(P).Append('=').Append(FloatToStr(TCustomFloatSpinEdit(C).Value)).Append(#10)
      else if C is TCustomEdit then B.Append(P).Append('=').Append(TCustomEdit(C).Text).Append(#10)
      else if C is TCustomCheckBox then B.Append(P).Append('=').Append(Ord(TCustomCheckBox(C).State)).Append(#10)
      else if C is TRadioButton then B.Append(P).Append('=').Append(TRadioButton(C).Checked).Append(#10)
      else if C is TCustomTrackBar then B.Append(P).Append('=').Append(TCustomTrackBar(C).Position).Append(#10);
      if C is TWinControl then Walk(TWinControl(C), P);
    end;
  end;
begin
  { Every value control under the pages, including pages built in code. }
  B := TStringBuilder.Create;
  try Walk(FPages, ''); Result := B.ToString; finally B.Free; end;
end;

procedure TSettingsNavigator.MarkSaved;
begin
  FBaseline := Fingerprint;
  if FDirty <> nil then FDirty.Visible := False;
  SyncFromPages;
  UpdateHeader;
end;

function TSettingsNavigator.Dirty: Boolean;
begin
  Result := (FBaseline <> '') and (Fingerprint <> FBaseline);
end;

procedure TSettingsNavigator.ChromeClick(Sender: TObject);
begin
  { Run the original button so ModalResult, handlers and validation stay the same. }
  if (Sender = FSaveChrome) and (FSaveButton is TButton) then TButton(FSaveButton).Click
  else if (Sender = FCancelChrome) and (FCancelButton is TButton) then TButton(FCancelButton).Click;
end;

procedure TSettingsNavigator.ButtonsResize(Sender: TObject);
var W, X: Integer; Save, Cancel: TControl;
begin
  if FButtonsPanel = nil then Exit;
  W := FButtonsPanel.ClientWidth;
  if FSaveChrome <> nil then Save := FSaveChrome else Save := FSaveButton;
  if FCancelChrome <> nil then Cancel := FCancelChrome else Cancel := FCancelButton;
  if Cancel <> nil then Cancel.Left := W - Cancel.Width - 16;
  if Save <> nil then begin
    if Cancel <> nil then Save.Left := Cancel.Left - Save.Width - 10
    else Save.Left := W - Save.Width - 16;
    X := Save.Left - 12;
  end else X := W - 12;
  if FDirty <> nil then FDirty.SetBounds(212, 0, Max(1, X - 212), FButtonsPanel.ClientHeight);
end;

procedure TSettingsNavigator.Tick(Sender: TObject);
begin
  if (FForm = nil) or not FForm.Visible then Exit;
  SyncFromPages;
  if FDirty <> nil then FDirty.Visible := Dirty;
  UpdateHeader;
  FList.Invalidate;
end;

end.
