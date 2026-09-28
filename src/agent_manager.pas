unit agent_manager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, fpjson, jsonparser,
  chatgpt, aiagent, aipipeline, aitools, aibase, jarvis_api,
  aiproject, aiproject_actions;

type
  TAgentState = (asIdle, asPlanning, asExecutingStep, asCallingTool, asFinished, asError, asCancelled);
  TOnStateChangeEvent = procedure(Sender: TObject; AState: TAgentState; const ADescription: string) of object;
  TOnStepEvent = procedure(Sender: TObject; AStepIndex, ATotalSteps: Integer; const AStepTitle, AStatus: string) of object;
  TOnToolLogEvent = procedure(Sender: TObject; const AToolName, AArgsJSON, AResultJSON: string; ASuccess: Boolean) of object;
  TOnCompleteEvent = procedure(Sender: TObject; const AResponseText, AProvider: string; ASuccess: Boolean) of object;

  TPlanStep = record
    ID: string;
    ParentID: string;
    Title: string;
    ToolName: string;
    Status: string;
    ResultText: string;
    Depth: Integer;
  end;

  { Fila dinamica: novos passos/subtarefas podem ser inseridos durante a execucao. }
  TAssistantPlanner = class
  private
    FSteps: array of TPlanStep;
    FCurrentStep: Integer;
    FGoal: string;
    FNextID: Integer;
    function NewID: string;
  public
    constructor Create;
    procedure Clear;
    procedure CreatePlan(const AGoal: string; AHasJarvis: Boolean; const AActiveProject: string);
    function AddTask(const ATitle, AToolName, AParentID: string; ADepth: Integer): Integer;
    function AddSubTask(const AParentID, ATitle, AToolName: string): Integer;
    function NextStep(out AStep: TPlanStep): Boolean;
    procedure UpdateCurrentStepStatus(const AStatus, AResult: string);
    function StepCount: Integer;
    function GetStep(AIndex: Integer): TPlanStep;
    property CurrentStepIndex: Integer read FCurrentStep;
    property Goal: string read FGoal;
  end;

  TAssistantManager = class(TComponent)
  private
    FChatGPT: TCHATGPT;
    FAgent: TAIAgent;
    FPipeline: TAIPipeline;
    FToolRegistry: TAIToolRegistry;
    FJarvisClient: TJarvisAPIClient;
    FPlanner: TAssistantPlanner;
    FProject: TAIProject;
    FTaskActions: TAITaskActions;
    FState: TAgentState;
    FLock: TCriticalSection;
    FCancelRequested: Boolean;
    FActiveProject: string;
    FOnStateChange: TOnStateChangeEvent;
    FOnStepUpdate: TOnStepEvent;
    FOnToolLog: TOnToolLogEvent;
    FOnComplete: TOnCompleteEvent;
    procedure SetupBuiltInTools;
    procedure SyncProjectTasks;
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
    property Project: TAIProject read FProject;
    property TaskActions: TAITaskActions read FTaskActions;
    property JarvisClient: TJarvisAPIClient read FJarvisClient write FJarvisClient;
    property ActiveProject: string read FActiveProject write FActiveProject;
    property CancelRequested: Boolean read FCancelRequested;
    property OnStateChange: TOnStateChangeEvent read FOnStateChange write FOnStateChange;
    property OnStepUpdate: TOnStepEvent read FOnStepUpdate write FOnStepUpdate;
    property OnToolLog: TOnToolLogEvent read FOnToolLog write FOnToolLog;
    property OnComplete: TOnCompleteEvent read FOnComplete write FOnComplete;
  end;

  TAgentWorkerThread = class(TThread)
  private
    FManager: TAssistantManager;
    FPrompt, FFinalResponse, FProviderName: string;
    FSuccess: Boolean;
    FCurrentStepIdx: Integer;
    FCurrentStepTitle, FCurrentStepStatus: string;
    FToolNameLog, FToolArgsLog, FToolResultLog: string;
    FToolSuccessLog: Boolean;
    procedure SyncStateChange;
    procedure SyncStepUpdate;
    procedure SyncToolLog;
    procedure SyncComplete;
    function AskLLM(const APrompt: string; out AResponse: string): Boolean;
    procedure ExpandTaskIfNeeded(const AStep: TPlanStep; const AResult: string);
  protected
    procedure Execute; override;
  public
    constructor Create(AManager: TAssistantManager; const APrompt: string);
  end;

implementation

constructor TAssistantPlanner.Create;
begin inherited Create; Clear; end;
function TAssistantPlanner.NewID: string;
begin Inc(FNextID); Result := 'task-' + IntToStr(FNextID); end;
procedure TAssistantPlanner.Clear;
begin SetLength(FSteps,0); FCurrentStep := 0; FGoal := ''; FNextID := 0; end;
function TAssistantPlanner.AddTask(const ATitle, AToolName, AParentID: string; ADepth: Integer): Integer;
begin
  Result := Length(FSteps); SetLength(FSteps, Result+1);
  FSteps[Result].ID := NewID; FSteps[Result].ParentID := AParentID;
  FSteps[Result].Title := ATitle; FSteps[Result].ToolName := AToolName;
  FSteps[Result].Status := 'pending'; FSteps[Result].Depth := ADepth;
end;
function TAssistantPlanner.AddSubTask(const AParentID, ATitle, AToolName: string): Integer;
var I,D: Integer;
begin D:=1; for I:=0 to High(FSteps) do if FSteps[I].ID=AParentID then begin D:=FSteps[I].Depth+1; Break; end;
  Result:=AddTask(ATitle,AToolName,AParentID,D); end;
procedure TAssistantPlanner.CreatePlan(const AGoal: string; AHasJarvis: Boolean; const AActiveProject: string);
var L:string;
begin
  Clear; FGoal:=AGoal; L:=LowerCase(AGoal);
  AddTask('Analisar objetivo e contexto ['+AActiveProject+']','', '',0);
  if AHasJarvis and ((Pos('casa',L)>0) or (Pos('luz',L)>0) or (Pos('temperatura',L)>0)) then
    AddTask('Consultar ambiente CASA/Jarvis','casa.status','',0);
  if (Pos('arquivo',L)>0) or (Pos('codigo',L)>0) then AddTask('Inspecionar informacoes necessarias','file.read','',0);
  AddTask('Executar objetivo em unidades pequenas e verificar necessidade de subtarefas','llm.task','',0);
  AddTask('Validar resultados e sintetizar resposta final','llm.synthesize','',0);
end;
function TAssistantPlanner.NextStep(out AStep:TPlanStep):Boolean;
begin Result:=(FCurrentStep>=0) and (FCurrentStep<Length(FSteps)); if Result then AStep:=FSteps[FCurrentStep]; end;
procedure TAssistantPlanner.UpdateCurrentStepStatus(const AStatus,AResult:string);
begin if (FCurrentStep>=0) and (FCurrentStep<Length(FSteps)) then begin FSteps[FCurrentStep].Status:=AStatus; FSteps[FCurrentStep].ResultText:=AResult; Inc(FCurrentStep); end; end;
function TAssistantPlanner.StepCount:Integer; begin Result:=Length(FSteps); end;
function TAssistantPlanner.GetStep(AIndex:Integer):TPlanStep;
begin FillChar(Result,SizeOf(Result),0); if (AIndex>=0) and (AIndex<Length(FSteps)) then Result:=FSteps[AIndex]; end;

constructor TAssistantManager.Create(AOwner:TComponent);
begin
  inherited Create(AOwner); FLock:=TCriticalSection.Create; FState:=asIdle; FActiveProject:='Geral';
  FChatGPT:=TCHATGPT.Create(Self); FAgent:=TAIAgent.Create(Self); FAgent.ChatGPT:=FChatGPT;
  FPipeline:=TAIPipeline.Create(Self); FPipeline.ChatGPT:=FChatGPT; FPipeline.Agent:=FAgent;
  FToolRegistry:=TAIToolRegistry.Create(Self); FAgent.ToolRegistry:=FToolRegistry;
  FPlanner:=TAssistantPlanner.Create;
  FProject:=TAIProject.Create(Self); FProject.ChatGPT:=FChatGPT; FProject.Agent:=FAgent; FProject.ProjectName:='Assistente'; FProject.EnsureProjectStructure;
  FTaskActions:=TAITaskActions.Create(Self); FTaskActions.Project:=FProject;
  SetupBuiltInTools;
end;
destructor TAssistantManager.Destroy; begin FPlanner.Free; FLock.Free; inherited Destroy; end;
procedure TAssistantManager.SyncProjectTasks;
var Plan:TJSONObject; Arr:TJSONArray; I:Integer; S:TPlanStep;
begin
  FProject.EnsureProjectStructure; Plan:=TJSONObject(FProject.ProjectData.FindPath('planning'));
  if Plan=nil then Exit; if Plan.IndexOfName('tasks')>=0 then Plan.Delete(Plan.IndexOfName('tasks'));
  Arr:=TJSONArray.Create; Plan.Add('tasks',Arr);
  for I:=0 to FPlanner.StepCount-1 do begin S:=FPlanner.GetStep(I); Arr.Add(TJSONObject.Create(['id',S.ID,'parent_id',S.ParentID,'title',S.Title,'tool',S.ToolName,'status',S.Status,'depth',S.Depth,'result',S.ResultText])); end;
end;
procedure TAssistantManager.SetupBuiltInTools;
var T:TAITool;
begin
 T:=FToolRegistry.RegisterTool('casa.status','Verifica status geral CASA/Jarvis','{}',toolRiskRead,@ToolCasaStatus); T.Policy:=toolPolicyAllow;
 T:=FToolRegistry.RegisterTool('casa.device.list','Lista dispositivos CASA','{}',toolRiskRead,@ToolCasaDeviceList); T.Policy:=toolPolicyAllow;
 T:=FToolRegistry.RegisterTool('casa.device.set','Aciona dispositivo','{"id":"integer","valor":"string"}',toolRiskUpdate,@ToolCasaDeviceSet); T.Policy:=toolPolicyAllow;
 T:=FToolRegistry.RegisterTool('casa.climate','Retorna clima','{}',toolRiskRead,@ToolCasaClimate); T.Policy:=toolPolicyAllow;
 T:=FToolRegistry.RegisterTool('file.read','Le arquivo','{"path":"string"}',toolRiskFilesystem,@ToolFileRead); T.Policy:=toolPolicyAllow;
 T:=FToolRegistry.RegisterTool('system.info','Informacoes do sistema','{}',toolRiskSafe,@ToolSystemInfo); T.Policy:=toolPolicyAllow;
end;
procedure TAssistantManager.ToolCasaStatus(Sender:TObject; ACall:TAIToolCall; AResult:TAIToolResult); var S:string; begin if Assigned(FJarvisClient) and FJarvisClient.ObterStatus(S) then begin AResult.Success:=True; AResult.Output:=S; end else begin AResult.Success:=False; AResult.ErrorText:='CASA/Jarvis indisponivel'; end; end;
procedure TAssistantManager.ToolCasaDeviceList(Sender:TObject; ACall:TAIToolCall; AResult:TAIToolResult); var S:string; begin if Assigned(FJarvisClient) and FJarvisClient.ListarDispositivos(S) then begin AResult.Success:=True; AResult.Output:=S; end else begin AResult.Success:=False; AResult.ErrorText:='Falha ao listar dispositivos'; end; end;
procedure TAssistantManager.ToolCasaDeviceSet(Sender:TObject; ACall:TAIToolCall; AResult:TAIToolResult); var M,V:string; I:Integer; begin I:=1;V:='1'; if ACall.Arguments<>nil then begin I:=ACall.Arguments.Get('id',1);V:=ACall.Arguments.Get('valor','1');end; if Assigned(FJarvisClient) and FJarvisClient.AcionarDispositivo(I,'relay',V,M) then begin AResult.Success:=True;AResult.Output:=M;end else begin AResult.Success:=False;AResult.ErrorText:='Falha ao acionar dispositivo';end; end;
procedure TAssistantManager.ToolCasaClimate(Sender:TObject; ACall:TAIToolCall; AResult:TAIToolResult); var T,U,D:string; C:Boolean; begin if Assigned(FJarvisClient) and FJarvisClient.ObterClima(T,U,D,C) then begin AResult.Success:=True;AResult.Output:=Format('Temperatura: %s | Umidade: %s | %s',[T,U,D]);end else begin AResult.Success:=False;AResult.ErrorText:='Falha ao obter clima';end;end;
procedure TAssistantManager.ToolFileRead(Sender:TObject; ACall:TAIToolCall; AResult:TAIToolResult); var P:string;SL:TStringList; begin P:='';if ACall.Arguments<>nil then P:=ACall.Arguments.Get('path',''); if (P<>'') and FileExists(P) then begin SL:=TStringList.Create;try SL.LoadFromFile(P);AResult.Success:=True;AResult.Output:=SL.Text;finally SL.Free;end;end else begin AResult.Success:=False;AResult.ErrorText:='Arquivo invalido';end;end;
procedure TAssistantManager.ToolSystemInfo(Sender:TObject; ACall:TAIToolCall; AResult:TAIToolResult); begin AResult.Success:=True;AResult.Output:='Projeto: '+FActiveProject+' | '+DateTimeToStr(Now);end;
procedure TAssistantManager.ProcessUserRequestAsync(const AUserPrompt:string); begin FCancelRequested:=False;FState:=asPlanning;TAgentWorkerThread.Create(Self,AUserPrompt);end;
procedure TAssistantManager.CancelExecution; begin FCancelRequested:=True;FState:=asCancelled;end;

constructor TAgentWorkerThread.Create(AManager:TAssistantManager;const APrompt:string); begin inherited Create(True);FreeOnTerminate:=True;FManager:=AManager;FPrompt:=APrompt;FProviderName:='CHATGPT Suite';Start;end;
procedure TAgentWorkerThread.SyncStateChange; begin if Assigned(FManager.FOnStateChange) then FManager.FOnStateChange(FManager,FManager.FState,'Executando');end;
procedure TAgentWorkerThread.SyncStepUpdate; begin if Assigned(FManager.FOnStepUpdate) then FManager.FOnStepUpdate(FManager,FCurrentStepIdx,FManager.Planner.StepCount,FCurrentStepTitle,FCurrentStepStatus);end;
procedure TAgentWorkerThread.SyncToolLog; begin if Assigned(FManager.FOnToolLog) then FManager.FOnToolLog(FManager,FToolNameLog,FToolArgsLog,FToolResultLog,FToolSuccessLog);end;
procedure TAgentWorkerThread.SyncComplete; begin if Assigned(FManager.FOnComplete) then FManager.FOnComplete(FManager,FFinalResponse,FProviderName,FSuccess);end;
function TAgentWorkerThread.AskLLM(const APrompt:string;out AResponse:string):Boolean;
begin Result:=Assigned(FManager.FChatGPT) and FManager.FChatGPT.SendQuestion(APrompt); if Result then AResponse:=FManager.FChatGPT.Response else AResponse:='';end;
procedure TAgentWorkerThread.ExpandTaskIfNeeded(const AStep:TPlanStep;const AResult:string);
var R:string;J:TJSONData;A:TJSONArray;I:Integer;O:TJSONObject;
begin
  if AStep.Depth>=3 then Exit;
  if not AskLLM('Avalie a tarefa abaixo. Se precisar ser quebrada em subtarefas, responda SOMENTE JSON no formato {"subtasks":[{"title":"...","tool":""}]}. Se nao precisar: {"subtasks":[]}. Tarefa: '+AStep.Title+' Resultado atual: '+AResult,R) then Exit;
  try J:=GetJSON(R); try A:=TJSONArray(J.FindPath('subtasks')); if A<>nil then for I:=0 to A.Count-1 do begin O:=TJSONObject(A.Items[I]);FManager.Planner.AddSubTask(AStep.ID,O.Get('title',''),O.Get('tool',''));end; finally J.Free;end; except end;
end;
procedure TAgentWorkerThread.Execute;
var Step:TPlanStep;Tool:TAITool;CallObj:TAIToolCall;ResultObj:TAIToolResult;Ctx,PromptFinal,R:string;HasJarvis:Boolean;
begin
  HasJarvis:=Assigned(FManager.FJarvisClient) and (FManager.FJarvisClient.BaseURL<>'');
  FManager.FLock.Acquire;try FManager.Planner.CreatePlan(FPrompt,HasJarvis,FManager.FActiveProject);FManager.SyncProjectTasks;finally FManager.FLock.Release;end;
  Ctx:='';
  while FManager.Planner.NextStep(Step) do begin
    if FManager.CancelRequested then begin FFinalResponse:='Operacao cancelada.';FSuccess:=False;Synchronize(@SyncComplete);Exit;end;
    FCurrentStepIdx:=FManager.Planner.CurrentStepIndex;FCurrentStepTitle:=Step.Title;FCurrentStepStatus:='running';Synchronize(@SyncStepUpdate);
    R:='';
    if (Step.ToolName<>'') and (Pos('llm.',Step.ToolName)<>1) then begin
      Tool:=FManager.ToolRegistry.FindTool(Step.ToolName); if Tool<>nil then begin CallObj:=TAIToolCall.Create;ResultObj:=TAIToolResult.Create;try CallObj.ToolName:=Step.ToolName;Tool.Execute(CallObj,ResultObj);R:=ResultObj.Output;if not ResultObj.Success then R:=ResultObj.ErrorText;finally ResultObj.Free;CallObj.Free;end;end;
    end else if Step.ToolName='llm.task' then begin
      PromptFinal:='Objetivo: '+FPrompt+sLineBreak+'Contexto obtido: '+Ctx+sLineBreak+'Tarefa atual: '+Step.Title+sLineBreak+'Execute apenas esta tarefa, em escopo pequeno, e devolva o resultado.'; AskLLM(PromptFinal,R); ExpandTaskIfNeeded(Step,R);
    end else if Step.ToolName='llm.synthesize' then begin
      AskLLM('Objetivo original: '+FPrompt+sLineBreak+'Resultados das tarefas: '+Ctx+sLineBreak+'Valide os resultados e responda ao usuario de forma final.',R);FFinalResponse:=R;FSuccess:=R<>'';
    end else R:='Objetivo e contexto analisados.';
    if R<>'' then Ctx:=Ctx+sLineBreak+'['+Step.ID+' '+Step.Title+'] '+R;
    FManager.Planner.UpdateCurrentStepStatus('done',R);FManager.SyncProjectTasks;FCurrentStepStatus:='done';Synchronize(@SyncStepUpdate);
  end;
  if FFinalResponse='' then begin FFinalResponse:=Ctx;FSuccess:=FFinalResponse<>'';end;
  FManager.FState:=asFinished;Synchronize(@SyncComplete);
end;

end.
