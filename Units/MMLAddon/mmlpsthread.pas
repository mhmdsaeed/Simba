{
	This file is part of the Mufasa Macro Library (MML)
	Copyright (c) 2009 by Raymond van Venetië and Merlijn Wajer

    MML is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MML is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MML.  If not, see <http://www.gnu.org/licenses/>.

	See the file COPYING, included in this distribution,
	for details about the copyright.

    MMLPSThread for the Mufasa Macro Library
}

unit mmlpsthread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, client, uPSComponent,uPSCompiler,uPSRuntime,stdCtrls, uPSPreProcessor,MufasaTypes, web;

type
    { TMMLPSThread }
    TSyncInfo = record
      V : MufasaTypes.TVariantArray;
      MethodName : string;
      Res : Variant;
      SyncMethod : procedure of object;
      OldThread : TThread;
      PSScript : TPSScript;
    end;

    TWritelnProc = procedure(s: string);

    PSyncInfo = ^TSyncInfo;
    TErrorType = (errRuntime,errCompile);
    TOnError = procedure (ErrorAtLine,ErrorPosition : integer; ErrorStr : string; ErrorType : TErrorType) of object;
    TMMLPSThread = class(TThread)
      procedure OnProcessDirective(Sender: TPSPreProcessor;
        Parser: TPSPascalPreProcessorParser; const Active: Boolean;
        const DirectiveName, DirectiveParam: string; var Continue: Boolean);
      procedure PSScriptProcessUnknowDirective(Sender: TPSPreProcessor;
        Parser: TPSPascalPreProcessorParser; const Active: Boolean;
        const DirectiveName, DirectiveParam: string; var Continue: Boolean);
    private
      ScriptPath, AppPath : string;
    protected
      //DebugTo : TMemo;
      DebugTo: TWritelnProc;
      PluginsToload : Array of integer;
      FOnError  : TOnError;
      procedure OnCompile(Sender: TPSScript);
      function RequireFile(Sender: TObject; const OriginFileName: String;
                          var FileName, OutPut: string): Boolean;
      procedure OnCompImport(Sender: TObject; x: TPSPascalCompiler);
      procedure OnExecImport(Sender: TObject; se: TPSExec; x: TPSRuntimeClassImporter);
      procedure OutputMessages;
      procedure OnThreadTerminate(Sender: TObject);
      procedure Execute; override;
    public
      PSScript : TPSScript;   // Moved to public, as we can't kill it otherwise.
      Client : TClient;
      SyncInfo : PSyncInfo; //We need this for callthreadsafe
      property OnError : TOnError read FOnError write FOnError;
      procedure SetPSScript(Script : string);
      procedure SetDebug( writelnProc : TWritelnProc );
      procedure SetPaths(ScriptP,AppP : string);
      constructor Create(CreateSuspended: Boolean; TheSyncInfo : PSyncInfo);
      destructor Destroy; override;
    end;
threadvar
  CurrThread : TMMLPSThread;
implementation
uses
  dtmutil,
  {$ifdef mswindows}windows,{$endif}
  uPSC_std, uPSC_controls,uPSC_classes,uPSC_graphics,uPSC_stdctrls,uPSC_forms,
  uPSC_extctrls, //Compile-libs

  uPSR_std, uPSR_controls,uPSR_classes,uPSR_graphics,uPSR_stdctrls,uPSR_forms,
  uPSR_extctrls, //Runtime-libs
  Graphics, //For Graphics types
  math, //Maths!
  bitmaps,
  colour_conv,
  forms,//Forms
  lclintf; // for GetTickCount and others.


{Some General PS Functions here}
procedure psWriteln(str : string);
//{$IFDEF WINDOWS}
begin
  if Assigned(CurrThread.DebugTo) then
    CurrThread.DebugTo(str)
  else
    writeln(str);
 {if CurrThread.DebugTo <> nil then
 begin;
    CurrThread.DebugTo.lines.add(str);
    CurrThread.DebugTo.Refresh;
 end; }
end;
//{$ELSE}
//begin
//writeln(str);
//end;
//{$ENDIF}

function ThreadSafeCall(ProcName: string; var V: TVariantArray): Variant;
begin;
  CurrThread.SyncInfo^.MethodName:= ProcName;
  CurrThread.SyncInfo^.V:= V;
  CurrThread.SyncInfo^.PSScript := CurrThread.PSScript;
  CurrThread.SyncInfo^.OldThread := CurrThread;
  CurrThread.Synchronize(CurrThread.SyncInfo^.SyncMethod);
  Result := CurrThread.SyncInfo^.Res;
{  Writeln('We have a length of: '  + inttostr(length(v)));
  Try
    Result := CurrThread.PSScript.Exec.RunProcPVar(v,CurrThread.PSScript.Exec.GetProc(Procname));
  Except
    Writeln('We has some errors :-(');
  end;}
end;


{
  Note to Raymond: For PascalScript, Create it on the .Create,
  Execute it on the .Execute, and don't forget to Destroy it on .Destroy.

  Furthermore, all the wrappers can be in the unit "implementation" section.
  Better still to create an .inc for it, otherwise this unit will become huge.
  (You can even split up the .inc's in stuff like color, bitmap, etc. )

  Also, don't add PS to this unit, but make a seperate unit for it.
  Unit "MMLPSThread", perhaps?

  See the TestUnit for use of this thread, it's pretty straightforward.

  It may also be wise to turn the "Importing of wrappers" into an include as
  well, it will really make the unit more straightforward to use and read.
}


constructor TMMLPSThread.Create(CreateSuspended : boolean; TheSyncInfo : PSyncInfo);
begin
  SyncInfo:= TheSyncInfo;
  SetLength(PluginsToLoad,0);
  Client := TClient.Create;
  PSScript := TPSScript.Create(nil);
  PSScript.UsePreProcessor:= True;
  PSScript.OnNeedFile := @RequireFile;
  PSScript.OnProcessDirective:=@OnProcessDirective;
  PSScript.OnProcessUnknowDirective:=@PSScriptProcessUnknowDirective;
  PSScript.OnCompile:= @OnCompile;
  PSScript.OnCompImport:= @OnCompImport;
  PSScript.OnExecImport:= @OnExecImport;
  OnError:= nil;
  // Set some defines
  {$I PSInc/psdefines.inc}


  FreeOnTerminate := True;
  Self.OnTerminate := @Self.OnThreadTerminate;
  inherited Create(CreateSuspended);
end;

procedure TMMLPSThread.OnThreadTerminate(Sender: TObject);
begin
//  Writeln('Terminating the thread');
end;

destructor TMMLPSThread.Destroy;
begin
  SetLength(PluginsToLoad,0);
  Client.Free;
  PSScript.Free;
  inherited;
end;

// include PS wrappers
{$I PSInc/Wrappers/other.inc}
{$I PSInc/Wrappers/bitmap.inc}
{$I PSInc/Wrappers/window.inc}
{$I PSInc/Wrappers/colour.inc}
{$I PSInc/Wrappers/math.inc}
{$I PSInc/Wrappers/mouse.inc}

{$I PSInc/Wrappers/keyboard.inc}
{$I PSInc/Wrappers/dtm.inc}
{$I PSInc/Wrappers/ocr.inc}

procedure TMMLPSThread.OnProcessDirective(Sender: TPSPreProcessor;
  Parser: TPSPascalPreProcessorParser; const Active: Boolean;
  const DirectiveName, DirectiveParam: string; var Continue: Boolean);
begin
end;

procedure TMMLPSThread.PSScriptProcessUnknowDirective(Sender: TPSPreProcessor;
  Parser: TPSPascalPreProcessorParser; const Active: Boolean;
  const DirectiveName, DirectiveParam: string; var Continue: Boolean);
var
  TempNum : integer;
  I: integer;
begin
  if DirectiveName= 'LOADDLL' then
    if DirectiveParam <> '' then
    begin;
      TempNum := PluginsGlob.LoadPlugin(DirectiveParam);
      if TempNum < 0 then
        psWriteln(Format('Your DLL %s has not been found',[DirectiveParam]))
      else
      begin;
        for i := High(PluginsToLoad) downto 0 do
          if PluginsToLoad[i] = TempNum then
            Exit;
        SetLength(PluginsToLoad,Length(PluginsToLoad)+1);
        PluginsToLoad[High(PluginsToLoad)] := TempNum;
      end;
    end;
  Continue:= True;
end;

procedure TMMLPSThread.OnCompile(Sender: TPSScript);
var
  i,ii : integer;
begin
  for i := high(PluginsToLoad) downto 0 do
    for ii := 0 to PluginsGlob.MPlugins[PluginsToLoad[i]].MethodLen - 1 do
      PSScript.AddFunctionEx(PluginsGlob.MPlugins[PluginsToLoad[i]].Methods[i].FuncPtr,
                           PluginsGlob.MPlugins[PluginsToLoad[i]].Methods[i].FuncStr, cdStdCall);
  // Here we add all the functions to the engine.
  {$I PSInc/pscompile.inc}
end;

function TMMLPSThread.RequireFile(Sender: TObject;
  const OriginFileName: String; var FileName, OutPut: string): Boolean;
var
  path: string;
  f: TFileStream;
begin
  if FileExists(FileName) then
    Path := FileName
  else
    Path :=  AppPath+ 'Includes' + DS + Filename;
  if not FileExists(Path) then
  begin;
    psWriteln(Path + ' doesn''t exist');
    Result := false;
    Exit;
  end;
  try
    F := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  except
    Result := false;
    exit;
  end;
  try
    SetLength(Output, f.Size);
    f.Read(Output[1], Length(Output));
  finally
    f.Free;
  end;
  Result := True;
end;

procedure TMMLPSThread.OnCompImport(Sender: TObject; x: TPSPascalCompiler);
begin
  SIRegister_Std(x);
  SIRegister_Controls(x);
  SIRegister_Classes(x, true);
  SIRegister_Graphics(x, true);
  SIRegister_stdctrls(x);
  SIRegister_Forms(x);
  SIRegister_ExtCtrls(x);
end;

procedure TMMLPSThread.OnExecImport(Sender: TObject; se: TPSExec;
  x: TPSRuntimeClassImporter);
begin
  RIRegister_Std(x);
  RIRegister_Classes(x, True);
  RIRegister_Controls(x);
  RIRegister_Graphics(x, True);
  RIRegister_stdctrls(x);
  RIRegister_Forms(x);
  RIRegister_ExtCtrls(x);
end;

procedure TMMLPSThread.OutputMessages;
var
  l: Longint;
  b: Boolean;
begin
  b := False;
  for l := 0 to PSScript.CompilerMessageCount - 1 do
  begin
    psWriteln(PSScript.CompilerErrorToStr(l));
    if (not b) and (PSScript.CompilerMessages[l] is TIFPSPascalCompilerError) then
    begin
      b := True;
      if OnError <> nil then
        with PSScript.CompilerMessages[l] do
          OnError(Row, Pos, MessageToString,errCompile);
    end;
  end;
end;

procedure TMMLPSThread.Execute;
var
  time: DWord;
begin;
  CurrThread := Self;
  time := lclintf.GetTickCount;
  try
    if PSScript.Compile then
    begin
      OutputMessages;
      psWriteln('Compiled succesfully in ' + IntToStr(GetTickCount - time) + ' ms.');
//      if not (ScriptState = SCompiling) then
        if not PSScript.Execute then
        begin
          if OnError <> nil then
            OnError(PSScript.ExecErrorRow,PSScript.ExecErrorPosition,PSScript.ExecErrorToString,errRuntime);
        end else psWriteln('Succesfully executed');
    end else
    begin
      OutputMessages;
      psWriteln('Compiling failed');
    end;
  except
     on E : Exception do
       psWriteln('ERROR IN PSSCRIPT: ' + e.message);
  end;
end;

procedure TMMLPSThread.SetPSScript(Script: string);
begin
   PSScript.Script.Text:= Script;
end;

procedure TMMLPSThread.SetDebug(writelnProc: TWritelnProc);
begin
  DebugTo := writelnProc;
end;

procedure TMMLPSThread.SetPaths(ScriptP, AppP: string);
begin
  AppPath:= AppP;
  ScriptPath:= ScriptP;
end;


{ Include stuff here? }

//{$I inc/colors.inc}
//{$I inc/bitmaps.inc}


end.

