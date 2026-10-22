unit assistant_integration_jobs;
{$mode objfpc}{$H+}
interface
uses SysUtils, fpjson;
type
  TIntegrationJobs=class
  private
    FItems:TJSONObject;
    FPrefix:string;
    FCounter:LongWord;
  public
    constructor Create;
    destructor Destroy;override;
    function BeginJob:string;
    procedure Complete(const ID,Text,Provider:string;Success,Cancelled:Boolean);
    function Lookup(const ID:string):TJSONData;
  end;
implementation
uses assistant_integration_protocol;
constructor TIntegrationJobs.Create;
begin inherited;FItems:=TJSONObject.Create;FPrefix:=Copy(GenerateIntegrationToken,1,16);end;
destructor TIntegrationJobs.Destroy;
begin FItems.Free;inherited;end;
function TIntegrationJobs.BeginJob:string;
begin
  // Main-thread only; app accepts one conversation at a time. Retain at most
  // 32 bounded results, in memory only; an eviction/restart returns not_found.
  while FItems.Count>=32 do FItems.Delete(0);
  Inc(FCounter);Result:=FPrefix+'-'+IntToStr(FCounter);
  FItems.Add(Result,TJSONObject.Create(['id',Result,'state','running']));
end;
procedure TIntegrationJobs.Complete(const ID,Text,Provider:string;Success,Cancelled:Boolean);
var O:TJSONObject;S:UTF8String;State:string;N:Integer;
begin
  if ID='' then Exit;N:=FItems.IndexOfName(ID);if N<0 then Exit;
  S:=Copy(Text,1,65536);
  // Back up to a valid UTF-8 prefix if a bounded result cut a code point.
  while (Length(S)>0) and not IsValidUTF8(S) do Delete(S,Length(S),1);
  if Cancelled then State:='cancelled' else if Success then State:='completed' else State:='failed';
  O:=TJSONObject.Create(['id',ID,'state',State,'text',S,'provider',Copy(Provider,1,256)]);
  FItems.Delete(N);FItems.Add(ID,O);
end;
function TIntegrationJobs.Lookup(const ID:string):TJSONData;
var D:TJSONData;
begin D:=FItems.Find(ID);if D=nil then Result:=nil else Result:=D.Clone;end;
end.
