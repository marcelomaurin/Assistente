unit project_manager;

{ ============================================================================
  Maurinsoft Assistente 2.0 - Project & Memory Manager
  Gerencia projetos (CASA, Hemacias, ECG, SMS Equipamentos, Robotinics, MNote2)
  e persistencia de memorias e conversas no SQLite.
  ============================================================================ }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, sqldb, sqlite3conn, sqlite3dyn;

type
  { TProjectProfile }
  TProjectProfile = class
  public
    Code: string;
    Name: string;
    Icon: string;
    Description: string;
    SystemPrompt: string;
    ActiveTools: TStringList;
    Memories: TStringList;
    AttachedFiles: TStringList;

    constructor Create(const ACode, AName, AIcon, ADesc, APrompt: string);
    destructor Destroy; override;
    function GetContextPrompt: string;
  end;

  { TAssistantProjectManager }
  TAssistantProjectManager = class(TComponent)
  private
    FProjects: TList; // Lista de TProjectProfile
    FActiveProject: TProjectProfile;
    FConn: TSQLite3Connection;
    FTrans: TSQLTransaction;
    FDBPath: string;
    FLock: TCriticalSection;
    FIsOpen: Boolean;

    procedure InitDefaultProjects;
    procedure InitDatabase;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function ProjectCount: Integer;
    function GetProject(AIndex: Integer): TProjectProfile;
    function FindProject(const ACode: string): TProjectProfile;
    function SetActiveProjectByCode(const ACode: string): Boolean;

    // Memoria e Historico SQLite
    procedure AddMemory(const AProjectCode, AMemoryType, AContent: string);
    procedure LoadProjectMemories(AProfile: TProjectProfile);
    procedure SaveMessage(const AProjectCode, ASender, AContent: string);
    function LoadRecentMessages(const AProjectCode: string; ALimit: Integer): TStringList;

    property ActiveProject: TProjectProfile read FActiveProject;
    property DBPath: string read FDBPath;
  end;

implementation

{ TProjectProfile }

constructor TProjectProfile.Create(const ACode, AName, AIcon, ADesc, APrompt: string);
begin
  inherited Create;
  Code := ACode;
  Name := AName;
  Icon := AIcon;
  Description := ADesc;
  SystemPrompt := APrompt;
  ActiveTools := TStringList.Create;
  Memories := TStringList.Create;
  AttachedFiles := TStringList.Create;
end;

destructor TProjectProfile.Destroy;
begin
  ActiveTools.Free;
  Memories.Free;
  AttachedFiles.Free;
  inherited Destroy;
end;

function TProjectProfile.GetContextPrompt: string;
var
  I: Integer;
begin
  Result := 'Voce esta atuando no contexto do Projeto [' + Name + '].' + sLineBreak +
            'Diretrizes: ' + SystemPrompt + sLineBreak;

  if Memories.Count > 0 then
  begin
    Result := Result + sLineBreak + 'Memorias do Projeto:' + sLineBreak;
    for I := 0 to Memories.Count - 1 do
      Result := Result + '- ' + Memories[I] + sLineBreak;
  end;

  if AttachedFiles.Count > 0 then
  begin
    Result := Result + sLineBreak + 'Arquivos Vinculados:' + sLineBreak;
    for I := 0 to AttachedFiles.Count - 1 do
      Result := Result + '- ' + ExtractFileName(AttachedFiles[I]) + sLineBreak;
  end;
end;

{ TAssistantProjectManager }

constructor TAssistantProjectManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProjects := TList.Create;
  FLock := TCriticalSection.Create;
  FDBPath := ExtractFilePath(ParamStr(0)) + 'assistente_memory.db';
  FIsOpen := False;

  InitDefaultProjects;
  InitDatabase;
end;

destructor TAssistantProjectManager.Destroy;
var
  I: Integer;
begin
  for I := 0 to FProjects.Count - 1 do
    TProjectProfile(FProjects[I]).Free;
  FProjects.Free;

  if FIsOpen then
  begin
    try
      if FTrans.Active then FTrans.Commit;
      FConn.Close;
    except
    end;
  end;

  FTrans.Free;
  FConn.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TAssistantProjectManager.InitDefaultProjects;
var
  P: TProjectProfile;
begin
  // 1. CASA
  P := TProjectProfile.Create(
    'CASA', 'CASA / Jarvis', '🏠',
    'Automacao Residencial Inteligente, Telemetria e Clima',
    'Voce e o assistente de automacao residencial JARVIS. Tem acesso aos dispositivos IoT, controle de reles, telemetria de Ribeirao Preto e seguranca de rede.'
  );
  P.ActiveTools.Add('casa.status');
  P.ActiveTools.Add('casa.device.list');
  P.ActiveTools.Add('casa.device.set');
  P.ActiveTools.Add('casa.climate');
  P.Memories.Add('Túnel Cloudflare Zero-Trust ativo em 192.168.2.12.');
  P.Memories.Add('Dispositivo 1 controla Iluminação Sala.');
  P.Memories.Add('Dispositivo 2 controla Bomba da Piscina.');
  FProjects.Add(P);

  // 2. Hemacias
  P := TProjectProfile.Create(
    'HEMACIAS', 'Hemácias', '🩸',
    'Visao Computacional Biomedica & Contagem Celular',
    'Especialista em hematologia digital e analise celular. Utiliza modelo YOLOv8m-blood-cell.pt para deteccao de eritrocitos, leucocitos e plaquetas.'
  );
  P.Memories.Add('Modelo treinado: yolov8m-blood-cell.pt com resolucao 640x640.');
  P.Memories.Add('Filtro de contagem elimina celulas cortadas nas bordas do campo microscopico.');
  FProjects.Add(P);

  // 3. ECG
  P := TProjectProfile.Create(
    'ECG', 'ECG Monitor', '❤️',
    'Monitoramento Cardiaco em Tempo Real, DSP e YOLO 1D',
    'Especialista em telemetria biomedica de eletrocardiograma (AD8232 a 500 Hz). Utiliza filtros passa-faixa, detector QRS e rede YOLO 1D para arritmias.'
  );
  P.Memories.Add('Aquisicao AD8232 serial 9600/115200 a 500 Hz.');
  P.Memories.Add('Classificacao YOLO 1D detecta classes N (Normal), V (PVC), A (PAC), TACHY e BRADY.');
  FProjects.Add(P);

  // 4. SMS Equipamentos
  P := TProjectProfile.Create(
    'SMS', 'SMS Equipamentos', '🏥',
    'Manutencao Hospitalar, Ordens de Servico e Engenharia Clinica',
    'Gestao de equipamentos medicos hospitalares, calibracao, ordens de servico preventivas e corretivas.'
  );
  P.Memories.Add('Consultas SQL devem priorizar ordens de servico com status pendente (id_status_os = 11).');
  FProjects.Add(P);

  // 5. Robotinics
  P := TProjectProfile.Create(
    'ROBOTINICS', 'Robotinics', '🤖',
    'Robotica, ROS, Sensores e Atuadores',
    'Sistemas embarcados, cinemática de robôs móveis, nós ROS e controle de motores.'
  );
  FProjects.Add(P);

  // 6. MNote2
  P := TProjectProfile.Create(
    'MNOTE2', 'MNote2', '💻',
    'Bloco de Notas Inteligente, Markdown e Documentacao',
    'Assistente de escrita, geracao de documentacao tecnica, markdown e resumo de logs.'
  );
  FProjects.Add(P);

  // Projeto padrao inicial
  FActiveProject := TProjectProfile(FProjects[0]);
end;

procedure TAssistantProjectManager.InitDatabase;
begin
  SQLiteDefaultLibrary := ExtractFilePath(ParamStr(0)) + 'sqlite3.dll';
  if not FileExists(SQLiteDefaultLibrary) then
    SQLiteDefaultLibrary := 'sqlite3.dll';

  FConn := TSQLite3Connection.Create(nil);
  FTrans := TSQLTransaction.Create(nil);
  FConn.Transaction := FTrans;
  FConn.DatabaseName := FDBPath;

  FLock.Acquire;
  try
    try
      FConn.Open;
      FTrans.StartTransaction;

      // Cria tabelas de memorias e mensagens
      FConn.ExecuteDirect(
        'CREATE TABLE IF NOT EXISTS memorias (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        '  project_code TEXT NOT NULL,' +
        '  memory_type TEXT NOT NULL,' +
        '  content TEXT NOT NULL,' +
        '  created_at TEXT NOT NULL' +
        ');'
      );

      FConn.ExecuteDirect(
        'CREATE TABLE IF NOT EXISTS mensagens (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        '  project_code TEXT NOT NULL,' +
        '  sender TEXT NOT NULL,' +
        '  content TEXT NOT NULL,' +
        '  created_at TEXT NOT NULL' +
        ');'
      );

      FConn.ExecuteDirect('CREATE INDEX IF NOT EXISTS idx_mem_proj ON memorias(project_code);');
      FConn.ExecuteDirect('CREATE INDEX IF NOT EXISTS idx_msg_proj ON mensagens(project_code);');

      try FConn.ExecuteDirect('PRAGMA journal_mode = WAL;'); except end;
      try FConn.ExecuteDirect('PRAGMA synchronous = NORMAL;'); except end;

      FTrans.CommitRetaining;
      FIsOpen := True;
    except
      on E: Exception do
      begin
        if FTrans.Active then try FTrans.Rollback; except end;
        FIsOpen := False;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TAssistantProjectManager.ProjectCount: Integer;
begin
  Result := FProjects.Count;
end;

function TAssistantProjectManager.GetProject(AIndex: Integer): TProjectProfile;
begin
  if (AIndex >= 0) and (AIndex < FProjects.Count) then
    Result := TProjectProfile(FProjects[AIndex])
  else
    Result := nil;
end;

function TAssistantProjectManager.FindProject(const ACode: string): TProjectProfile;
var
  I: Integer;
  P: TProjectProfile;
begin
  Result := nil;
  for I := 0 to FProjects.Count - 1 do
  begin
    P := TProjectProfile(FProjects[I]);
    if SameText(P.Code, ACode) then
      Exit(P);
  end;
end;

function TAssistantProjectManager.SetActiveProjectByCode(const ACode: string): Boolean;
var
  P: TProjectProfile;
begin
  P := FindProject(ACode);
  if P <> nil then
  begin
    FActiveProject := P;
    LoadProjectMemories(P);
    Result := True;
  end
  else
    Result := False;
end;

procedure TAssistantProjectManager.AddMemory(const AProjectCode, AMemoryType, AContent: string);
var
  Q: TSQLQuery;
  DataHoraStr: string;
begin
  if not FIsOpen then Exit;
  FLock.Acquire;
  try
    try
      if not FTrans.Active then FTrans.StartTransaction;
      DataHoraStr := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
      Q := TSQLQuery.Create(nil);
      try
        Q.DataBase := FConn;
        Q.Transaction := FTrans;
        Q.SQL.Text := 'INSERT INTO memorias (project_code, memory_type, content, created_at) ' +
                      'VALUES (:proj, :mtype, :content, :c_at);';
        Q.Params.ParamByName('proj').AsString := AProjectCode;
        Q.Params.ParamByName('mtype').AsString := AMemoryType;
        Q.Params.ParamByName('content').AsString := AContent;
        Q.Params.ParamByName('c_at').AsString := DataHoraStr;
        Q.ExecSQL;
        FTrans.CommitRetaining;
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        if FTrans.Active then try FTrans.Rollback; except end;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TAssistantProjectManager.LoadProjectMemories(AProfile: TProjectProfile);
var
  Q: TSQLQuery;
begin
  if (AProfile = nil) or not FIsOpen then Exit;
  FLock.Acquire;
  try
    try
      if not FTrans.Active then FTrans.StartTransaction;
      Q := TSQLQuery.Create(nil);
      try
        Q.DataBase := FConn;
        Q.Transaction := FTrans;
        Q.SQL.Text := 'SELECT content FROM memorias WHERE project_code = :proj ORDER BY id ASC;';
        Q.Params.ParamByName('proj').AsString := AProfile.Code;
        Q.Open;
        while not Q.EOF do
        begin
          AProfile.Memories.Add(Q.FieldByName('content').AsString);
          Q.Next;
        end;
        Q.Close;
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        if FTrans.Active then try FTrans.Rollback; except end;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TAssistantProjectManager.SaveMessage(const AProjectCode, ASender, AContent: string);
var
  Q: TSQLQuery;
  DataHoraStr: string;
begin
  if not FIsOpen then Exit;
  FLock.Acquire;
  try
    try
      if not FTrans.Active then FTrans.StartTransaction;
      DataHoraStr := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
      Q := TSQLQuery.Create(nil);
      try
        Q.DataBase := FConn;
        Q.Transaction := FTrans;
        Q.SQL.Text := 'INSERT INTO mensagens (project_code, sender, content, created_at) ' +
                      'VALUES (:proj, :sender, :content, :c_at);';
        Q.Params.ParamByName('proj').AsString := AProjectCode;
        Q.Params.ParamByName('sender').AsString := ASender;
        Q.Params.ParamByName('content').AsString := AContent;
        Q.Params.ParamByName('c_at').AsString := DataHoraStr;
        Q.ExecSQL;
        FTrans.CommitRetaining;
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        if FTrans.Active then try FTrans.Rollback; except end;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TAssistantProjectManager.LoadRecentMessages(const AProjectCode: string; ALimit: Integer): TStringList;
var
  Q: TSQLQuery;
begin
  Result := TStringList.Create;
  if not FIsOpen then Exit;
  FLock.Acquire;
  try
    try
      if not FTrans.Active then FTrans.StartTransaction;
      Q := TSQLQuery.Create(nil);
      try
        Q.DataBase := FConn;
        Q.Transaction := FTrans;
        Q.SQL.Text := 'SELECT sender, content, created_at FROM mensagens WHERE project_code = :proj ' +
                      'ORDER BY id DESC LIMIT :lim;';
        Q.Params.ParamByName('proj').AsString := AProjectCode;
        Q.Params.ParamByName('lim').AsInteger := ALimit;
        Q.Open;
        while not Q.EOF do
        begin
          Result.Add('[' + Q.FieldByName('created_at').AsString + '] ' +
                     Q.FieldByName('sender').AsString + ': ' +
                     Q.FieldByName('content').AsString);
          Q.Next;
        end;
        Q.Close;
      finally
        Q.Free;
      end;
    except
      on E: Exception do
      begin
        if FTrans.Active then try FTrans.Rollback; except end;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

end.
