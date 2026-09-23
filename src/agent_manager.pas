unit agent_manager;

{ ============================================================================
  Maurinsoft Assistente 2.0 - Agent Manager & Planner
  Construido sobre a suite de componentes CHATGPT:
    - TAIAgent (aiagent.pas)
    - TAIPipeline (aipipeline.pas)
    - TAIToolRegistry (aitools.pas)
    - TCHATGPT (chatgpt.pas)
  ============================================================================ }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, fpjson, jsonparser,
  chatgpt, aiagent, aipipeline, aitools, aibase, jarvis_api;

type
  TAgentState = (asIdle, asPlanning, asExecutingStep, asCallingTool, asFinished, asError, asCancelled);

  TOnStateChangeEvent = procedure(Sender: TObject; AState: TAgentState; const ADescription: string) of object;
  TOnStepEvent = procedure(Sender: TObject; AStepIndex, ATotalSteps: Integer; const AStepTitle, AStatus: string) of object;
  TOnToolLogEvent = procedure(Sender: TObject; const AToolName, AArgsJSON, AResultJSON: string; ASuccess: Boolean) of object;
  TOnCompleteEvent = procedure(Sender: TObject; const AResponseText, AProvider: string; ASuccess: Boolean) of object;

  { TPlanStep }
  TPlanStep = record
    Title: string;
    ToolName: string;
    Status: string; // 'pending', 'running', 'done', 'error'
    ResultText: string;
  end;

  { TAssistantPlanner }
  TAssistantPlanner = class
  private
    FSteps: array of TPlanStep;
    FCurrentStep: Integer;
    FGoal: string;
  public
    constructor Create;
    procedure Clear;
    procedure CreatePlan(const AGoal: string; AHasJarvis: Boolean; const AActiveProject: string);
    function NextStep(out AStep: TPlanStep): Boolean;
    procedure UpdateCurrentStepStatus(const AStatus, AResult: string);
    function StepCount: Integer;
    function GetStep(AIndex: Integer): TPlanStep;
    property CurrentStepIndex: Integer read FCurrentStep;
    property Goal: string read FGoal;
  end;

  { TAssistantManager }
  TAssistantManager = class(TComponent)
  private
    FChatGPT: TCHATGPT;
    FAgent: TAIAgent;
    FPipeline: TAIPipeline;
    FToolRegistry: TAIToolRegistry;
    FJarvisClient: TJarvisAPIClient;
    FPlanner: TAssistantPlanner;
    FState: TAgentState;
    FLock: TCriticalSection;
    FCancelRequested: Boolean;
    FActiveProject: string;

    FOnStateChange: TOnStateChangeEvent;
    FOnStepUpdate: TOnStepEvent;
    FOnToolLog: TOnToolLogEvent;
    FOnComplete: TOnCompleteEvent;

    procedure SetupBuiltInTools;
    procedure ToolCasaStatus(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
    procedure ToolCasaDeviceList(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
    procedure ToolCasaDeviceSet(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
    procedure ToolCasaClimate(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
    procedure ToolFileRead(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
    procedure ToolSystemInfo(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ProcessUserRequestAsync(const AUserPrompt: string);
    procedure CancelExecution;

    property State: TAgentState read FState;
    property Planner: TAssistantPlanner read FPlanner;
    property ChatGPT: TCHATGPT read FChatGPT;
    property Agent: TAIAgent read FAgent;
    property Pipeline: TAIPipeline read FPipeline;
    property ToolRegistry: TAIToolRegistry read FToolRegistry;
    property JarvisClient: TJarvisAPIClient read FJarvisClient write FJarvisClient;
    property ActiveProject: string read FActiveProject write FActiveProject;
    property CancelRequested: Boolean read FCancelRequested;

    property OnStateChange: TOnStateChangeEvent read FOnStateChange write FOnStateChange;
    property OnStepUpdate: TOnStepEvent read FOnStepUpdate write FOnStepUpdate;
    property OnToolLog: TOnToolLogEvent read FOnToolLog write FOnToolLog;
    property OnComplete: TOnCompleteEvent read FOnComplete write FOnComplete;
  end;

  { TAgentWorkerThread }
  TAgentWorkerThread = class(TThread)
  private
    FManager: TAssistantManager;
    FPrompt: string;
    FFinalResponse: string;
    FProviderName: string;
    FSuccess: Boolean;
    FCurrentStepIdx: Integer;
    FCurrentStepTitle: string;
    FCurrentStepStatus: string;
    FToolNameLog: string;
    FToolArgsLog: string;
    FToolResultLog: string;
    FToolSuccessLog: Boolean;

    procedure SyncStateChange;
    procedure SyncStepUpdate;
    procedure SyncToolLog;
    procedure SyncComplete;
  protected
    procedure Execute; override;
  public
    constructor Create(AManager: TAssistantManager; const APrompt: string);
  end;

implementation

{ TAssistantPlanner }

constructor TAssistantPlanner.Create;
begin
  inherited Create;
  Clear;
end;

procedure TAssistantPlanner.Clear;
begin
  SetLength(FSteps, 0);
  FCurrentStep := -1;
  FGoal := '';
end;

procedure TAssistantPlanner.CreatePlan(const AGoal: string; AHasJarvis: Boolean; const AActiveProject: string);
var
  LowGoal: string;
begin
  Clear;
  FGoal := AGoal;
  LowGoal := LowerCase(AGoal);

  // 1. Passo inicial comum a todo planejamento
  SetLength(FSteps, 1);
  FSteps[0].Title := 'Analisar intencao e contexto do projeto [' + AActiveProject + ']';
  FSteps[0].ToolName := '';
  FSteps[0].Status := 'pending';
  FSteps[0].ResultText := '';

  // 2. Se a intencao envolver automacao residencial / CASA / Jarvis
  if AHasJarvis and ((Pos('casa', LowGoal) > 0) or (Pos('luz', LowGoal) > 0) or
     (Pos('dispositivo', LowGoal) > 0) or (Pos('rele', LowGoal) > 0) or
     (Pos('temperatura', LowGoal) > 0) or (Pos('clima', LowGoal) > 0) or
     (Pos('ligar', LowGoal) > 0) or (Pos('desligar', LowGoal) > 0)) then
  begin
    SetLength(FSteps, Length(FSteps) + 1);
    if (Pos('temperatura', LowGoal) > 0) or (Pos('clima', LowGoal) > 0) or (Pos('chuva', LowGoal) > 0) then
    begin
      FSteps[High(FSteps)].Title := 'Consultar telemetria climatica (casa.climate)';
      FSteps[High(FSteps)].ToolName := 'casa.climate';
    end
    else if (Pos('ligar', LowGoal) > 0) or (Pos('desligar', LowGoal) > 0) or (Pos('acionar', LowGoal) > 0) then
    begin
      FSteps[High(FSteps)].Title := 'Executar controle de dispositivo IoT (casa.device.set)';
      FSteps[High(FSteps)].ToolName := 'casa.device.set';
    end
    else
    begin
      FSteps[High(FSteps)].Title := 'Consultar status dos dispositivos da casa (casa.device.list)';
      FSteps[High(FSteps)].ToolName := 'casa.device.list';
    end;
    FSteps[High(FSteps)].Status := 'pending';
  end
  // 3. Se envolver consulta a arquivos ou sistema
  else if (Pos('arquivo', LowGoal) > 0) or (Pos('ler', LowGoal) > 0) or (Pos('codigo', LowGoal) > 0) then
  begin
    SetLength(FSteps, Length(FSteps) + 1);
    FSteps[High(FSteps)].Title := 'Inspecionar arquivos do projeto (file.read)';
    FSteps[High(FSteps)].ToolName := 'file.read';
    FSteps[High(FSteps)].Status := 'pending';
  end
  else if (Pos('sistema', LowGoal) > 0) or (Pos('memoria', LowGoal) > 0) or (Pos('cpu', LowGoal) > 0) then
  begin
    SetLength(FSteps, Length(FSteps) + 1);
    FSteps[High(FSteps)].Title := 'Coletar telemetria operacional da maquina (system.info)';
    FSteps[High(FSteps)].ToolName := 'system.info';
    FSteps[High(FSteps)].Status := 'pending';
  end;

  // 4. Sintese final com modelo de linguagem (LLM)
  SetLength(FSteps, Length(FSteps) + 1);
  FSteps[High(FSteps)].Title := 'Sintetizar parecer cognitivo e formatar resposta';
  FSteps[High(FSteps)].ToolName := 'llm.synthesize';
  FSteps[High(FSteps)].Status := 'pending';

  FCurrentStep := 0;
end;

function TAssistantPlanner.NextStep(out AStep: TPlanStep): Boolean;
begin
  Result := False;
  if (FCurrentStep >= 0) and (FCurrentStep < Length(FSteps)) then
  begin
    AStep := FSteps[FCurrentStep];
    Result := True;
  end;
end;

procedure TAssistantPlanner.UpdateCurrentStepStatus(const AStatus, AResult: string);
begin
  if (FCurrentStep >= 0) and (FCurrentStep < Length(FSteps)) then
  begin
    FSteps[FCurrentStep].Status := AStatus;
    FSteps[FCurrentStep].ResultText := AResult;
    Inc(FCurrentStep);
  end;
end;

function TAssistantPlanner.StepCount: Integer;
begin
  Result := Length(FSteps);
end;

function TAssistantPlanner.GetStep(AIndex: Integer): TPlanStep;
begin
  if (AIndex >= 0) and (AIndex < Length(FSteps)) then
    Result := FSteps[AIndex]
  else
  begin
    Result.Title := '';
    Result.ToolName := '';
    Result.Status := '';
    Result.ResultText := '';
  end;
end;

{ TAssistantManager }

constructor TAssistantManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TCriticalSection.Create;
  FCancelRequested := False;
  FState := asIdle;
  FActiveProject := 'Geral';

  FChatGPT := TCHATGPT.Create(Self);
  FAgent := TAIAgent.Create(Self);
  FAgent.ChatGPT := FChatGPT;

  FPipeline := TAIPipeline.Create(Self);
  FPipeline.ChatGPT := FChatGPT;
  FPipeline.Agent := FAgent;

  FToolRegistry := TAIToolRegistry.Create(Self);
  FAgent.ToolRegistry := FToolRegistry;

  FPlanner := TAssistantPlanner.Create;

  SetupBuiltInTools;
end;

destructor TAssistantManager.Destroy;
begin
  FPlanner.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TAssistantManager.SetupBuiltInTools;
var
  T: TAITool;
begin
  // Tool 1: casa.status
  T := FToolRegistry.RegisterTool('casa.status', 'Verifica status geral da automacao residencial CASA/Jarvis', '{}', toolRiskRead, @ToolCasaStatus);
  T.Policy := toolPolicyAllow;

  // Tool 2: casa.device.list
  T := FToolRegistry.RegisterTool('casa.device.list', 'Lista todos os dispositivos e reles cadastrados no CASA', '{}', toolRiskRead, @ToolCasaDeviceList);
  T.Policy := toolPolicyAllow;

  // Tool 3: casa.device.set
  T := FToolRegistry.RegisterTool('casa.device.set', 'Aciona ou desliga um rele ou dispositivo IoT', '{"id": "integer", "valor": "string"}', toolRiskUpdate, @ToolCasaDeviceSet);
  T.Policy := toolPolicyAllow;

  // Tool 4: casa.climate
  T := FToolRegistry.RegisterTool('casa.climate', 'Retorna temperatura, umidade e previsao do tempo de Ribeirao Preto', '{}', toolRiskRead, @ToolCasaClimate);
  T.Policy := toolPolicyAllow;

  // Tool 5: file.read
  T := FToolRegistry.RegisterTool('file.read', 'Le conteudo textual de um arquivo no disco', '{"path": "string"}', toolRiskFilesystem, @ToolFileRead);
  T.Policy := toolPolicyAllow;

  // Tool 6: system.info
  T := FToolRegistry.RegisterTool('system.info', 'Retorna informacoes do sistema operacional e runtime', '{}', toolRiskSafe, @ToolSystemInfo);
  T.Policy := toolPolicyAllow;
end;

procedure TAssistantManager.ToolCasaStatus(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
var
  Resumo: string;
begin
  if FJarvisClient <> nil then
  begin
    if FJarvisClient.ObterStatus(Resumo) then
    begin
      AResult.Success := True;
      AResult.Output := Resumo;
    end
    else
    begin
      AResult.Success := False;
      AResult.ErrorText := 'Falha ao conectar com o servico CASA/Jarvis: ' + FJarvisClient.LastError;
    end;
  end
  else
  begin
    AResult.Success := False;
    AResult.ErrorText := 'Cliente CASA/Jarvis nao configurado.';
  end;
end;

procedure TAssistantManager.ToolCasaDeviceList(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
var
  JsonDevices: string;
begin
  if FJarvisClient <> nil then
  begin
    if FJarvisClient.ListarDispositivos(JsonDevices) then
    begin
      AResult.Success := True;
      AResult.Output := JsonDevices;
    end
    else
    begin
      AResult.Success := False;
      AResult.ErrorText := 'Falha ao listar dispositivos: ' + FJarvisClient.LastError;
    end;
  end
  else
  begin
    AResult.Success := False;
    AResult.ErrorText := 'Cliente CASA/Jarvis nao configurado.';
  end;
end;

procedure TAssistantManager.ToolCasaDeviceSet(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
var
  IdDev: Integer;
  ValStr, Msg: string;
begin
  if FJarvisClient <> nil then
  begin
    IdDev := 1;
    ValStr := '1';
    if ACall.Arguments <> nil then
    begin
      IdDev := ACall.Arguments.Get('id', 1);
      ValStr := ACall.Arguments.Get('valor', '1');
    end;

    if FJarvisClient.AcionarDispositivo(IdDev, 'relay', ValStr, Msg) then
    begin
      AResult.Success := True;
      AResult.Output := Msg;
    end
    else
    begin
      AResult.Success := False;
      AResult.ErrorText := 'Falha ao acionar dispositivo: ' + FJarvisClient.LastError;
    end;
  end
  else
  begin
    AResult.Success := False;
    AResult.ErrorText := 'Cliente CASA/Jarvis nao configurado.';
  end;
end;

procedure TAssistantManager.ToolCasaClimate(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
var
  Temp, Umid, Desc: string;
  VaiChover: Boolean;
begin
  if FJarvisClient <> nil then
  begin
    if FJarvisClient.ObterClima(Temp, Umid, Desc, VaiChover) then
    begin
      AResult.Success := True;
      AResult.Output := Format('Temperatura: %s | Umidade: %s | Condicao: %s | Chuva prevista: %s',
        [Temp, Umid, Desc, BoolToStr(VaiChover, 'Sim', 'Nao')]);
    end
    else
    begin
      AResult.Success := False;
      AResult.ErrorText := 'Falha ao obter clima: ' + FJarvisClient.LastError;
    end;
  end
  else
  begin
    AResult.Success := False;
    AResult.ErrorText := 'Cliente CASA/Jarvis nao configurado.';
  end;
end;

procedure TAssistantManager.ToolFileRead(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
var
  FPath: string;
  SL: TStringList;
begin
  FPath := '';
  if ACall.Arguments <> nil then
    FPath := ACall.Arguments.Get('path', '');

  if (FPath <> '') and FileExists(FPath) then
  begin
    SL := TStringList.Create;
    try
      try
        SL.LoadFromFile(FPath);
        AResult.Success := True;
        AResult.Output := SL.Text;
      except
        on E: Exception do
        begin
          AResult.Success := False;
          AResult.ErrorText := 'Erro ao ler arquivo: ' + E.Message;
        end;
      end;
    finally
      SL.Free;
    end;
  end
  else
  begin
    AResult.Success := False;
    AResult.ErrorText := 'Arquivo inexistente ou caminho invalido: ' + FPath;
  end;
end;

procedure TAssistantManager.ToolSystemInfo(Sender: TObject; ACall: TAIToolCall; AResult: TAIToolResult);
begin
  AResult.Success := True;
  AResult.Output := Format('OS: Windows | FPC: %s | LCL: 3.2+ | Projeto Ativo: %s | Horario: %s',
    [{$I %FPCVERSION%}, FActiveProject, DateTimeToStr(Now)]);
end;

procedure TAssistantManager.ProcessUserRequestAsync(const AUserPrompt: string);
begin
  FCancelRequested := False;
  FState := asPlanning;
  TAgentWorkerThread.Create(Self, AUserPrompt);
end;

procedure TAssistantManager.CancelExecution;
begin
  FCancelRequested := True;
  FState := asCancelled;
end;

{ TAgentWorkerThread }

constructor TAgentWorkerThread.Create(AManager: TAssistantManager; const APrompt: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FManager := AManager;
  FPrompt := APrompt;
  FSuccess := False;
  FFinalResponse := '';
  FProviderName := 'CHATGPT Suite';
  Start;
end;

procedure TAgentWorkerThread.SyncStateChange;
begin
  if Assigned(FManager.FOnStateChange) then
    FManager.FOnStateChange(FManager, FManager.FState, 'Executando');
end;

procedure TAgentWorkerThread.SyncStepUpdate;
begin
  if Assigned(FManager.FOnStepUpdate) then
    FManager.FOnStepUpdate(FManager, FCurrentStepIdx, FManager.Planner.StepCount, FCurrentStepTitle, FCurrentStepStatus);
end;

procedure TAgentWorkerThread.SyncToolLog;
begin
  if Assigned(FManager.FOnToolLog) then
    FManager.FOnToolLog(FManager, FToolNameLog, FToolArgsLog, FToolResultLog, FToolSuccessLog);
end;

procedure TAgentWorkerThread.SyncComplete;
begin
  if Assigned(FManager.FOnComplete) then
    FManager.FOnComplete(FManager, FFinalResponse, FProviderName, FSuccess);
end;

procedure TAgentWorkerThread.Execute;
var
  Step: TPlanStep;
  Tool: TAITool;
  CallObj: TAIToolCall;
  ResultObj: TAIToolResult;
  AccumulatedContext: string;
  PromptFinal: string;
  HasJarvis: Boolean;
begin
  HasJarvis := (FManager.FJarvisClient <> nil) and (FManager.FJarvisClient.BaseURL <> '');

  // 1. Planejamento (TAIPlanner)
  FManager.FLock.Acquire;
  try
    FManager.Planner.CreatePlan(FPrompt, HasJarvis, FManager.FActiveProject);
  finally
    FManager.FLock.Release;
  end;

  AccumulatedContext := '';

  // 2. Executa cada passo do plano
  while FManager.Planner.NextStep(Step) do
  begin
    if FManager.CancelRequested then
    begin
      FManager.FState := asCancelled;
      FFinalResponse := 'Operacao cancelada pelo usuario.';
      FSuccess := False;
      Synchronize(@SyncComplete);
      Exit;
    end;

    FCurrentStepIdx := FManager.Planner.CurrentStepIndex;
    FCurrentStepTitle := Step.Title;
    FCurrentStepStatus := 'running';
    Synchronize(@SyncStepUpdate);

    // Se o passo requerer uma ferramenta (Tool)
    if (Step.ToolName <> '') and (Step.ToolName <> 'llm.synthesize') then
    begin
      Tool := FManager.ToolRegistry.FindTool(Step.ToolName);
      if Tool <> nil then
      begin
        CallObj := TAIToolCall.Create;
        ResultObj := TAIToolResult.Create;
        try
          CallObj.ToolName := Step.ToolName;
          Tool.Execute(CallObj, ResultObj);

          FToolNameLog := Step.ToolName;
          FToolArgsLog := '{}';
          FToolResultLog := ResultObj.Output;
          FToolSuccessLog := ResultObj.Success;
          Synchronize(@SyncToolLog);

          if ResultObj.Success then
            AccumulatedContext := AccumulatedContext + sLineBreak +
              '[' + Step.ToolName + ']: ' + ResultObj.Output
          else
            AccumulatedContext := AccumulatedContext + sLineBreak +
              '[Erro em ' + Step.ToolName + ']: ' + ResultObj.ErrorText;
        finally
          ResultObj.Free;
          CallObj.Free;
        end;
      end;
      FCurrentStepStatus := 'done';
      FManager.Planner.UpdateCurrentStepStatus('done', AccumulatedContext);
      Synchronize(@SyncStepUpdate);
    end
    else if Step.ToolName = 'llm.synthesize' then
    begin
      // Monta prompt enriquecido com contexto recolhido pelas ferramentas
      PromptFinal := FPrompt;
      if AccumulatedContext <> '' then
        PromptFinal := 'Contexto operacional apurado:' + sLineBreak + AccumulatedContext +
                       sLineBreak + sLineBreak + 'Solicitacao do usuario: ' + FPrompt;

      // Executa via TCHATGPT da suite
      if Assigned(FManager.FChatGPT) then
      begin
        FSuccess := FManager.FChatGPT.SendQuestion(PromptFinal);
        if FSuccess then
          FFinalResponse := FManager.FChatGPT.Response
        else
        begin
          FFinalResponse := 'Nao foi possivel obter a resposta da IA.';
          if FManager.FChatGPT.LastError <> '' then
            FFinalResponse := FFinalResponse + ' (' + FManager.FChatGPT.LastError + ')';
        end;
      end
      else
        FFinalResponse := 'Componente TCHATGPT nao inicializado.';

      FCurrentStepStatus := 'done';
      FManager.Planner.UpdateCurrentStepStatus('done', FFinalResponse);
      Synchronize(@SyncStepUpdate);
    end
    else
    begin
      // Passo cognitivo simples
      FCurrentStepStatus := 'done';
      FManager.Planner.UpdateCurrentStepStatus('done', 'OK');
      Synchronize(@SyncStepUpdate);
    end;
  end;

  FManager.FState := asFinished;
  Synchronize(@SyncComplete);
end;

end.
