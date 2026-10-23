program professor_movement_sequence_tests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, fpjson, jsonparser, reception_core, professor_commands,
  movement_catalog, presentation_tags;
var Config:TReceptionConfig;Job:TReceptionJob;Step:TAvatarScriptStep;
  Original,Fixture:string;Catalog:TJSONObject;List:TJSONArray;Text:TStringList;
  Started,Previous,LastDelivered:QWord;Count,I:Integer;Expected:string;
procedure Check(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
procedure Run(const Script:string;CancelLast,PauseFirst:Boolean);
begin
  Job:=TReceptionJob.Create(rjSpeak,Config,Script,'','movement-sequence');
  Started:=GetTickCount64;Previous:=Started;LastDelivered:=0;Count:=0;
  try
    repeat
      Check(GetTickCount64-Started<5000,'Movement sequence stalled');
      if Job.TakeScriptCommand(Step) then begin
        Inc(Count);
        if Count=1 then Expected:='sequence_one' else if Count=2 then Expected:='sequence_two' else Expected:='';
        Check(Step.MovementID=Expected,'Movement identity/order lost');
        if Count=2 then Check(GetTickCount64-Previous>=190,'Consecutive tags replaced an unfinished gesture');
        if Count=3 then Check(Step.Presentation.Action=paEndTask,'Expected final presentation event');
        if Count=3 then Check(GetTickCount64-Previous>=170,'FIM erased an unfinished pose');
        Previous:=GetTickCount64;LastDelivered:=Previous;Job.ConfirmAvatarCommand;
        if PauseFirst and (Count=1) then begin
          Job.SetPaused(True);Sleep(250);
          Check(not Job.Done,'Paused gesture completed the presentation');
          Job.SetPaused(False);Previous:=Previous+250;
        end;
        if CancelLast and (Count=2) then begin Job.Cancel;Break;end;
      end;
      if Job.Done then Break;
      Sleep(2);
    until False;
    if CancelLast then begin
      Started:=GetTickCount64;Job.WaitFor;
      Check((GetTickCount64-Started<500) and not Job.Success,'Cancellation blocked on gesture timing');
    end else begin
      Check(Job.Success,Job.ErrorText);
      if Pos('[FIM]',Script)>0 then Check(Count=3,'Missing end event')
      else begin
        Check(Count=2,'Missing movement');
        Check(GetTickCount64-LastDelivered>=170,'Trailing pose ended before its transition');
      end;
      Check(Pos('[',Job.Text)=0,'Tags reached speech');
    end;
  finally Job.Free;end;
end;
begin
  Original:=MovementCatalogFile;Fixture:=ExpandFileName(ParamStr(1));
  Text:=TStringList.Create;Catalog:=TJSONObject.Create;List:=TJSONArray.Create;
  try
    Catalog.Add('version',1);Catalog.Add('movements',List);
    List.Add(TJSONObject.Create(['id','sequence_one','tag','primeiro gesto','mode','gesture','clip','wave','duration_ms',200,'transition_ms',50]));
    List.Add(TJSONObject.Create(['id','sequence_two','tag','segunda pose','mode','pose','clip','idle','transition_ms',180]));
    Text.Text:=Catalog.AsJSON;Text.SaveToFile(Fixture);ReloadMovementCatalog(Fixture);
    Config:=Default(TReceptionConfig);Config.EnableAvatarCommands:=True;
    Config.EnablePresentationCommands:=True;Config.SilentPresentation:=True;
    Run('[primeiro gesto][segunda pose]',False,False);
    Run('[primeiro gesto][segunda pose][FIM]',False,False);
    Run('[primeiro gesto] Oi [segunda pose]',False,False);
    Run('[primeiro gesto][segunda pose]',False,True);
    Run('[primeiro gesto][segunda pose]',True,False);
    WriteLn('PASS: ordered dynamic tags, visible trailing pose, FIM, speech, pause and cancellation');
  finally ReloadMovementCatalog(Original);Text.Free;Catalog.Free;end;
end.
