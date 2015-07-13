/// fill a VCL TClientDataset from SynVirtualDataset data access
// - this unit is a part of the freeware Synopse framework,
// licensed under a MPL/GPL/LGPL tri-license; version 1.18
unit SynRestVCL;

{
    This file is part of Synopse framework.

    Synopse framework. Copyright (C) 2015 Arnaud Bouchez
      Synopse Informatique - http://synopse.info

  *** BEGIN LICENSE BLOCK *****
  Version: MPL 1.1/GPL 2.0/LGPL 2.1

  The contents of this file are subject to the Mozilla Public License Version
  1.1 (the "License"); you may not use this file except in compliance with
  the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  The Original Code is Synopse mORMot framework.

  The Initial Developer of the Original Code is Arnaud Bouchez.

  Portions created by the Initial Developer are Copyright (C) 2015
  the Initial Developer. All Rights Reserved.

  Contributor(s):
  - Esteban Martin (EMartin)

  Alternatively, the contents of this file may be used under the terms of
  either the GNU General Public License Version 2 or later (the "GPL"), or
  the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
  in which case the provisions of the GPL or the LGPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of either the GPL or the LGPL, and not to allow others to
  use your version of this file under the terms of the MPL, indicate your
  decision by deleting the provisions above and replace them with the notice
  and other provisions required by the GPL or the LGPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the MPL, the GPL or the LGPL.

  ***** END LICENSE BLOCK *****

  Version 1.18
  - first public release, corresponding to Synopse mORMot Framework 1.18,
    which is an extraction from former SynDBVCL.pas unit.

}

{$I Synopse.inc} // define HASINLINE USETYPEINFO CPU32 CPU64 OWNNORMTOUPPER

interface

uses
  {$ifdef ISDELPHIXE2}System.SysUtils,{$else}SysUtils,{$endif}
  Classes,
{$ifndef DELPHI5OROLDER}
  Variants,
  {$ifndef FPC}
  MidasLib,
  {$endif}
{$endif}
  mORMot,
  mORMotHttpClient,
  SynCrtSock, // remover una vez implementado TSQLHttpClient
  SynCommons,
  SynDB, SynDBVCL,
  DB,
  {$ifdef FPC}
  BufDataset
  {$else}
  Contnrs,
  DBClient,
  Provider,
  SqlConst
  {$endif};


type
  /// generic Exception type
  ESQLRestException = class(ESynException);

  /// a TDataSet which allows to apply updates on a Restful connection
  // - typical usage may be for instance:
  // ! ds := TSynRestDataSet.Create(MainForm);
  // ! ds.Dataset.SQLModel := CreateModel; // The SQLModel is required
  // ! ds.CommandText := 'http://host:port/root/TableName?select=*&where=condition&sort=fieldname';
  // ! ds1.Dataset := ds; // assigning the rest dataset to TDatasource that can be associated a TDBGrid for example.
  // ! ds.Open;
  // ! // ... use ds as usual, including modifications
  // ! ds.ApplyUpdates(0);
  //   or using from a service returning a dataset:
  // ! ds := TSynRestDataSet.Create(MainForm);
  // ! ds.Dataset.SQLModel := CreateModel; // The SQLModel is required
  // ! the TSQLRecord associated should be defined with the same structure of the returned array from the service
  // ! ds.CommandText := 'http://host:port/root/ServiceName.Operation?paramname=:paramvalue';
  // ! ds.Params.ParamByName('paramname').Value := 'xyz';
  // ! ds1.Dataset := ds; // assigning the rest dataset to TDatasource that can be associated a TDBGrid for example.
  // ! ds.Open;
  // ! // ... use ds as usual, including modifications
  // ! ds.ApplyUpdates(0);
  TSynRestSQLDataSet = class(TSynBinaryDataSet)
  protected
    fBaseURL: RawUTF8;
    fCommandText: string;
    fDataSet: TSynBinaryDataSet;
    fParams: TParams;
    fProvider: TDataSetProvider;
    fRoot: RawUTF8;
    fSQLModel: TSQLModel;
    fTableName: RawUTF8;
    fURI: TURI;
    function BindParams(const aStatement: RawUTF8): RawUTF8;
    function GetSQLRecordClass: TSQLRecordClass;
    function GetTableName: string;
    // get the data
    procedure InternalInitFieldDefs; override;
    function InternalFrom(const aStatement: RawUTF8): RawByteString;
    procedure InternalOpen; override;
    procedure InternalClose; override;
    function IsTableFromService: Boolean;
    procedure ParseCommandText;
    // IProvider implementation
    procedure PSSetCommandText(const ACommandText: string); override;
    function PSGetTableName: string; override;
    function PSUpdateRecord(UpdateKind: TUpdateKind; Delta: TDataSet): Boolean; override;
    function PSIsSQLBased: Boolean; override;
    function PSIsSQLSupported: Boolean; override;
    {$ifdef ISDELPHIXE3}
    function PSExecuteStatement(const ASQL: string; AParams: TParams): Integer; overload; override;
    function PSExecuteStatement(const ASQL: string; AParams: TParams; var ResultSet: TDataSet): Integer; overload; override;
    {$else}
    function PSExecuteStatement(const ASQL: string; AParams: TParams; ResultSet: Pointer=nil): Integer; overload; override;
    {$endif}
    procedure SetCommandText(const Value: string);
  public
    /// the associated Model, if not defined an exception is raised.
    property SQLModel: TSQLModel read fSQLModel write fSQLModel;
  published
    /// the GET RESTful URI
    // - Statement will have the form http://host:port/root/tablename or
    //   http://host:port/root/servicename.operationname?paramname=:paramalias
    // examples:
    //   http://host:port/root/tablename?select=XXX or
    //   http://host:port/root/tablename?select=XXX&where=field1=XXX or field2=XXX
    //   http://host:port/root/service.operation?param=:param
    // if :param is used then before open assign the value: ds.Params.ParamByName('param').value := XXX
    property CommandText: string read fCommandText write fCommandText;
    /// the associated SynDB TDataSet, used to retrieve and update data
    property DataSet: TSynBinaryDataSet read fDataSet;
  end;

// JSON columns to binary from a TSQLTableJSON, is not ideal because this code is a almost repeated code.
procedure JSONColumnsToBinary(const aTable: TSQLTableJSON; W: TFileBufferWriter;
  const Null: TSQLDBProxyStatementColumns;
  const ColTypes: TSQLDBFieldTypeDynArray);
// convert to binary from a TSQLTableJSON, is not ideal because this code is a almost repeated code.
function JSONToBinary(const aTable: TSQLTableJSON; Dest: TStream; MaxRowCount: cardinal=0; DataRowPosition: PCardinalDynArray=nil): cardinal;

implementation

uses
  DBCommon,
  SynVirtualDataset;

const
  FETCHALLTOBINARY_MAGIC = 1;

  SQLFIELDTYPETODBFIELDTYPE: array[TSQLFieldType] of TSQLDBFieldType =
    (SynCommons.ftUnknown,   // sftUnknown
     SynCommons.ftUTF8,      // sftAnsiText
     SynCommons.ftUTF8,      // sftUTF8Text
     SynCommons.ftInt64,     // sftEnumerate
     SynCommons.ftInt64,     // sftSet
     SynCommons.ftInt64,     // sftInteger
     SynCommons.ftInt64,     // sftID = TSQLRecord(aID)
     SynCommons.ftInt64,     // sftRecord = TRecordReference
     SynCommons.ftInt64,     // sftBoolean
     SynCommons.ftDouble,    // sftFloat
     SynCommons.ftDate,      // sftDateTime
     SynCommons.ftInt64,     // sftTimeLog
     SynCommons.ftCurrency,  // sftCurrency
     SynCommons.ftUTF8,      // sftObject
{$ifndef NOVARIANTS}
     SynCommons.ftUTF8,      // sftVariant
     SynCommons.ftUTF8,      // sftNullable
{$endif}
     SynCommons.ftBlob,      // sftBlob
     SynCommons.ftBlob,      // sftBlobDynArray
     SynCommons.ftBlob,      // sftBlobCustom
     SynCommons.ftUTF8,      // sftUTF8Custom
     SynCommons.ftUnknown,   // sftMany
     SynCommons.ftInt64,     // sftModTime
     SynCommons.ftInt64,     // sftCreateTime
     SynCommons.ftInt64,     // sftTID
     SynCommons.ftInt64);    // sftRecordVersion = TRecordVersion

  SQLFieldTypeToVCLDB: array[TSQLFieldType] of TFieldType =
    (DB.ftUnknown,           // sftUnknown
     DB.ftString,            // sftAnsiText
     DB.ftString,            // sftUTF8Text
     DB.ftLargeInt,          // sftEnumerate
     DB.ftLargeInt,          // sftSet
     DB.ftLargeInt,          // sftInteger
     DB.ftLargeInt,          // sftID = TSQLRecord(aID)
     DB.ftLargeInt,          // sftRecord = TRecordReference
     DB.ftLargeInt,          // sftBoolean
     DB.ftFloat,             // sftFloat
     DB.ftDate,              // sftDateTime
     DB.ftLargeInt,          // sftTimeLog
     DB.ftCurrency,          // sftCurrency
     DB.ftString,            // sftObject
{$ifndef NOVARIANTS}
     DB.ftString,            // sftVariant
     DB.ftString,            // sftNullable
{$endif}
     DB.ftBlob,              // sftBlob
     DB.ftBlob,              // sftBlobDynArray
     DB.ftBlob,              // sftBlobCustom
     DB.ftString,            // sftUTF8Custom
     DB.ftUnknown,           // sftMany
     DB.ftLargeInt,          // sftModTime
     DB.ftLargeInt,          // sftCreateTime
     DB.ftLargeInt,          // sftTID
     DB.ftLargeInt);         // sftRecordVersion = TRecordVersion

  VCLDBFieldTypeSQLDB: array[0..23] of TSQLFieldType =
    (sftUnknown,        // ftUnknown
     sftAnsiText,       //  ftString
     sftUTF8Text,       // ftString
     sftEnumerate,      // ftInteger
     sftSet,            // ftInteger
     sftInteger,        // ftInteger
     sftID,             // ftLargeInt = TSQLRecord(aID)
     sftRecord,         // ftLargeInt
     sftBoolean,        // ftBoolean
     sftFloat,          // ftFloat
     sftDateTime,       // ftDate
     sftTimeLog,        // ftLargeInt
     sftCurrency,       // ftCurrency
     sftObject,         // ftString
{$ifndef NOVARIANTS}
     sftVariant,        // ftString
{$endif}
     sftBlob,           // ftBlob
     sftBlob,           // ftBlob
     sftBlob,           // ftBlob
     sftUTF8Custom,     // ftString
     sftMany,           // ftUnknown
     sftModTime,        // ftLargeInt
     sftCreateTime,     // ftLargeInt
     sftID,             // ftLargeInt
     sftRecordVersion); // ftLargeInt = TRecordVersion

{$ifndef FPC}


procedure JSONColumnsToBinary(const aTable: TSQLTableJSON; W: TFileBufferWriter;
  const Null: TSQLDBProxyStatementColumns; const ColTypes: TSQLDBFieldTypeDynArray);
var F: integer;
    VDouble: double;
    VCurrency: currency absolute VDouble;
    VDateTime: TDateTime absolute VDouble;
    colType: TSQLDBFieldType;
begin
  for F := 0 to length(ColTypes)-1 do
    if not (F in Null) then begin
      colType := ColTypes[F];
      if colType<ftInt64 then begin // ftUnknown,ftNull
        colType := SQLFIELDTYPETODBFIELDTYPE[aTable.FieldType(F)]; // per-row column type (SQLite3 only)
        W.Write1(ord(colType));
      end;
      case colType of
      ftInt64:
      begin
        W.WriteVarInt64(aTable.FieldAsInteger(F));
      end;
      ftDouble: begin
        VDouble := aTable.FieldAsFloat(F);
        W.Write(@VDouble,sizeof(VDouble));
      end;
      SynCommons.ftCurrency: begin
        VCurrency := aTable.Field(F);
        W.Write(@VCurrency,sizeof(VCurrency));
      end;
      SynCommons.ftDate: begin
        VDateTime := aTable.Field(F);
        W.Write(@VDateTime,sizeof(VDateTime));
      end;
      SynCommons.ftUTF8:
      begin
        W.Write(aTable.FieldBuffer(F));
      end;
      SynCommons.ftBlob:
      begin
        W.Write(aTable.FieldBuffer(F));
      end;
      else
      raise ESQLDBException.CreateUTF8('JSONColumnsToBinary: Invalid ColumnType(%)=%',
        [aTable.Get(0, F),ord(colType)]);
    end;
  end;
end;

function JSONToBinary(const aTable: TSQLTableJSON; Dest: TStream; MaxRowCount: cardinal=0; DataRowPosition: PCardinalDynArray=nil): cardinal;
var F, FMax, FieldSize, NullRowSize: integer;
    StartPos: cardinal;
    Null: TSQLDBProxyStatementColumns;
    W: TFileBufferWriter;
    ColTypes: TSQLDBFieldTypeDynArray;
begin
  FillChar(Null,sizeof(Null),0);
  result := 0;
  W := TFileBufferWriter.Create(Dest);
  try
    W.WriteVarUInt32(FETCHALLTOBINARY_MAGIC);
    FMax := aTable.FieldCount;
    W.WriteVarUInt32(FMax);
    if FMax>0 then begin
      // write column description
      SetLength(ColTypes,FMax);
      dec(FMax);
      for F := 0 to FMax do begin
        W.Write(aTable.Get(0, F));
        ColTypes[F] := SQLFIELDTYPETODBFIELDTYPE[aTable.FieldType(F)];
        FieldSize := aTable.FieldLengthMax(F);
        W.Write1(ord(ColTypes[F]));
        W.WriteVarUInt32(FieldSize);
      end;
      // initialize null handling
      NullRowSize := (FMax shr 3)+1;
      if NullRowSize>sizeof(Null) then
        raise ESQLDBException.CreateUTF8(
          'JSONToBinary: too many columns', []);
      // save all data rows
      StartPos := W.TotalWritten;
      if aTable.Step or (aTable.RowCount=1) then // Need step first or error is raised in Table.Field function.
      repeat
        // save row position in DataRowPosition[] (if any)
        if DataRowPosition<>nil then begin
          if Length(DataRowPosition^)<=integer(result) then
            SetLength(DataRowPosition^,result+result shr 3+256);
          DataRowPosition^[result] := W.TotalWritten-StartPos;
        end;
        // first write null columns flags
        if NullRowSize>0 then begin
          FillChar(Null,NullRowSize,0);
          NullRowSize := 0;
        end;
        for F := 0 to FMax do
        begin
          if VarIsNull(aTable.Field(F)) then begin
            include(Null,F);
            NullRowSize := (F shr 3)+1;
          end;
        end;
        W.WriteVarUInt32(NullRowSize);
        if NullRowSize>0 then
          W.Write(@Null,NullRowSize);
        // then write data values
        JSONColumnsToBinary(aTable, W,Null,ColTypes);
        inc(result);
        if (MaxRowCount>0) and (result>=MaxRowCount) then
          break;
      until not aTable.Step;
    end;
    W.Write(@result,SizeOf(result)); // fixed size at the end for row count
    W.Flush;
  finally
    W.Free;
  end;
end;

{ TSynRestSQLDataSet }

function TSynRestSQLDataSet.BindParams(const aStatement: RawUTF8): RawUTF8;
var
  I: Integer;
  lParamName: string;
begin
  Result := aStatement;
  if (Pos(':', aStatement) = 0) and (fParams.Count = 0) then
    Exit;
  if ((Pos(':', aStatement) = 0) and (fParams.Count > 0)) or ((Pos(':', aStatement) > 0) and (fParams.Count = 0)) then
    raise ESQLRestException.CreateUTF8('Statement parameters (%) not match with Params (Count=%) property',
      [aStatement, fParams.Count]);
  for I := 0 to fParams.Count-1 do
  begin
    lParamName := ':' + fParams[I].Name;
    Result := StringReplace(Result, lParamName, fParams[I].AsString, [rfIgnoreCase]);
  end;
  // remove space before and after &
  Result := StringReplaceAll(Result, ' & ', '&');
end;

function TSynRestSQLDataSet.GetSQLRecordClass: TSQLRecordClass;
begin
  Result := fSQLModel.Table[GetTableName];
  if not Assigned(Result) then
    raise ESQLRestException.CreateUTF8('Table % not registered in SQL Model', [GetTableName]);
end;

function TSynRestSQLDataSet.GetTableName: string;
var
  I: Integer;
begin
  if not IsTableFromService then
    Result := PSGetTableName
  else
  begin
    Result := fTableName;
    for I := 1 to Length(Result) do
      if (Result[I] = '.') then
      begin
        Result[I] := '_';  // change only the firs found
        Break;
      end;
  end;
end;

procedure TSynRestSQLDataSet.InternalClose;
begin
  inherited InternalClose;
  FreeAndNil(fDataAccess);
  fData := '';
end;

function TSynRestSQLDataSet.InternalFrom(const aStatement: RawUTF8): RawByteString;

  procedure UpdateFields(aSQLTableJSON: TSQLTableJSON);
  var
    I, J: Integer;
    lFields: TSQLPropInfoList;
  begin
    lFields := GetSQLRecordClass.RecordProps.Fields;
    for I := 0 to aSQLTableJSON.FieldCount-1 do
    begin
      J := lFields.IndexByName(aSQLTableJSON.Get(0, I));
      if (J > -1) then
        aSQLTableJSON.SetFieldType(I, lFields.Items[J].SQLFieldType, Nil, lFields.Items[J].FieldWidth);
    end;
  end;

var
  lData: TRawByteStringStream;
  lSQLTableJSON: TSQLTableJSON;
  lStatement: RawUTF8;
  lDocVar: TDocVariantData;
  lTmp: RawUTF8;
  lResp: TDocVariantData;
begin
  Result := '';
  lStatement := BindParams(aStatement);
  if (lStatement <> '') then
    lStatement := '?' + lStatement;
  Result := TWinHTTP.Get(fBaseURL + fRoot + fTableName + lStatement);
  if (Result = '') then
    raise ESynException.CreateUTF8('Cannot get response (timeout?) from %', [fBaseURL + fRoot + fTableName + lStatement]);
  if (Result <> '') then
  begin
    lResp.InitJSON(Result);
    if (lResp.Kind = dvUndefined) then
      raise ESynException.CreateUTF8('Invalid JSON response' + sLineBreak + '%' + sLineBreak + 'from' + sLineBreak + '%',
                                     [Result, fBaseURL + fRoot + fTableName + lStatement]);
    if (lResp.Kind = dvObject) then
      if (lResp.GetValueIndex('errorCode') > -1) then
        if (lResp.GetValueIndex('errorText') > -1) then
          raise ESynException.CreateUTF8('Error' + sLineBreak + '%' + sLineBreak + 'from' + sLineBreak + '%',
                                         [lResp.Value['errorText'], fBaseURL + fRoot + fTableName + lStatement])
        else if (lResp.GetValueIndex('error') > -1) then
          raise ESynException.CreateUTF8('Error' + sLineBreak + '%' + sLineBreak + 'from' + sLineBreak + '%', [lResp.Value['error'], fBaseURL + fRoot + fTableName + lStatement]);

    if IsTableFromService then // is the source dataset from a service ?
    begin
      lDocVar.InitJSON(Result);
      lTmp := lDocVar.Values[0];
      lDocVar.Clear;
      lDocVar.InitJSON(lTmp);
      if (lDocVar.Kind <> dvArray) then
        raise ESQLRestException.CreateUTF8('The service % not return an array', [fTableName]);
      // if the array is empty, nothing to return
      Result := lDocVar.Values[0];
      if (Result = '') or (Result = '[]') or (Result = '{}') then
        raise ESQLRestException.CreateUTF8('Service % not return a valid array', [fTableName]);
    end;
    lSQLTableJSON := TSQLTableJSON.CreateFromTables([GetSQLRecordClass], '', Result);
    // update info fields for avoid error conversion in JSONToBinary
    UpdateFields(lSQLTableJSON);
    lData := TRawByteStringStream.Create('');
    try
      JSONToBinary(lSQLTableJSON, lData);
      Result := lData.DataString
    finally
      FreeAndNil(lData);
      FreeAndNil(lSQLTableJSON);
    end;
  end;
end;

procedure TSynRestSQLDataSet.InternalInitFieldDefs;
var F: integer;
    lFields: TSQLPropInfoList;
    lFieldDef: TFieldDef;
begin
  inherited;
  if (GetTableName = '') then // JSON conversion to dataset ?
    Exit;
  // update field definitions from associated TSQLRecordClass of the table
  lFields := GetSQLRecordClass.RecordProps.Fields;
  for F := 0 to lFields.Count-1 do
  begin
    lFieldDef := TFieldDef(TDefCollection(FieldDefs).Find(lFields.Items[F].Name));
    if Assigned(lFieldDef) then
    begin
      if (lFieldDef.DataType <> SQLFieldTypeToVCLDB[lFields.Items[F].SQLFieldType]) then
        lFieldDef.DataType := SQLFieldTypeToVCLDB[lFields.Items[F].SQLFieldType];
      if (lFieldDef.Size < lFields.Items[F].FieldWidth) then
        lFieldDef.Size := lFields.Items[F].FieldWidth;
    end;
  end;
end;

function TSynRestSQLDataSet.IsTableFromService: Boolean;
begin
  Result := (Pos('.', fTableName) > 0);
end;

procedure TSynRestSQLDataSet.InternalOpen;
var
  lData: RawByteString;
begin
  if (fCommandText='') and (not IsTableFromService) then begin
    if fData<>'' then // called e.g. after From() method
      inherited InternalOpen;
    exit;
  end;
  lData := InternalFrom(fCommandText);
  if (lData <> '') then
  begin
    From(lData);
    inherited InternalOpen;
  end;
end;

procedure TSynRestSQLDataSet.ParseCommandText;
var
  lSQL: RawUTF8;
begin
  // it is assumed http://host:port/root/tablename, the rest is optional: ?select=&where=&sort= etc.
  if not fURI.From(fCommandText) then
    raise ESynException.CreateUTF8('Invalid % command text. Must have the format protocol://host:port', [fCommandText]);
  if not fURI.Https then
    fBaseURL := FormatUTF8('http://%:%/', [fURI.Server, fURI.Port])
  else
    fBaseURL := FormatUTF8('https://%:%/', [fURI.Server, fURI.Port]);
  Split(fURI.Address, '/', fRoot, fTableName);
  if (fRoot = '') or (fTableName = '') then
    raise ESynException.CreateUTF8('Invalid % root. Must have the format protocol://host:port/root/tablename', [fCommandText]);
  fRoot := fRoot + '/';
  if (Pos('?', fTableName) > 0) then
    Split(fTableName, '?', fTableName, lSQL);
  if not Assigned(fSQLModel) then
    raise ESQLRestException.CreateUTF8('Error parsing command text. Empty Model.', []);
  fCommandText := lSQL
end;

{$ifdef ISDELPHIXE3}

function TSynRestSQLDataSet.PSExecuteStatement(const ASQL: string; AParams: TParams; var ResultSet: TDataSet): Integer;
{$else}
function TSynRestSQLDataSet.PSExecuteStatement(const ASQL: string; AParams: TParams; ResultSet: Pointer): Integer;
{$endif}

  function Compute(const aJSON: SockString; const aOccasion: TSQLOccasion): SockString;
  var
    lRec: TSQLRecord;
    lRecBak: TSQLRecord; // backup for get modifications
    lJSON: TDocVariantData;
    I: Integer;
    lCount: Integer;
    lOccasion: TSQLEvent;
    lVarValue: Variant;
    lVarValueBak: Variant;
  begin
    lRec := GetSQLRecordClass.Create;
    lRecBak := GetSQLRecordClass.Create;
    try
      lJSON.InitJSON(aJSON);
      lCount := lJSON.Count;
      // update record fields
      for I := 0 to lCount-1 do
        lRec.SetFieldValue(lJSON.Names[I], PUTF8Char(VariantToUTF8(lJSON.Values[I])));
      lOccasion := seUpdate;
      if (aOccasion = soInsert) then
        lOccasion := seAdd;
      lRec.ComputeFieldsBeforeWrite(Nil, lOccasion);
      // get modified fields
      for I := 0 to lRec.RecordProps.Fields.Count-1 do
      begin
        lRec.RecordProps.Fields.Items[I].GetVariant(lRec, lVarValue);
        lRecBak.RecordProps.Fields.Items[I].GetVariant(lRecBak, lVarValueBak);
        if (lVarValue <> lVarValueBak) then
          lJSON.Value[lRec.RecordProps.Fields.Items[I].Name] := lVarValue;
      end;
      Result := lJSON.ToJSON;
    finally
      lRec.Free;
      lRecBak.Free;
    end;
  end;

  function ExtractFields(const aSQL, aAfterStr, aBeforeStr: string): string;
  var
    lPosStart: Integer;
    lPosEnd: Integer;
    lSQL: string;
  begin
    lSQL := StringReplace(aSQL, sLineBreak, ' ', [rfReplaceAll]);
    lPosStart := Pos(aAfterStr, lSQL)+Length(aAfterStr);
    lPosEnd   := Pos(aBeforeStr, lSQL);
    Result := Trim(Copy(lSQL, lPosStart, lPosEnd-lPosStart));
  end;

  function SQLFieldsToJSON(const aSQLOccasion: TSQLOccasion; const aSQL, aAfterStr, aBeforeStr: string; aParams: TParams): SockString;
  var
    I: Integer;
    lLastPos: Integer;
    lFieldValues: TStrings;
  begin
    lFieldValues := TStringList.Create;
    try
      ExtractStrings([','], [], PAnsiChar(ExtractFields(aSQL, aAfterStr, aBeforeStr)), lFieldValues);
      lLastPos := 0;
      with TTextWriter.CreateOwnedStream do
      begin
        Add('{');
        for I := 0 to lFieldValues.Count-1 do
        begin
          if (Pos('=', lFieldValues[I]) = 0) then
            lFieldValues[I] := lFieldValues[I] + '=';
          AddFieldName(Trim(lFieldValues.Names[I]));
          AddVariant(aParams[I].Value);
          Add(',');
          lLastPos := I;
        end;
        CancelLastComma;
        Add('}');
        Result := Text;
        Free;
      end;
      lFieldValues.Clear;
      // the first field after the where clause is the ID
      if (aSQLOccasion <> soInsert) then
        aParams[lLastPos+1].Name := 'ID';
    finally
      lFieldValues.Free;
    end;
  end;

  function GetSQLOccasion(const aSQL: string): TSQLOccasion;
  begin
    if IdemPChar(PUTF8Char(UpperCase(aSQL)), 'DELETE') then
      Result := soDelete
    else if IdemPChar(PUTF8Char(UpperCase(aSQL)), 'INSERT') then
      Result := soInsert
    else
      Result := soUpdate;
  end;

var
  lJSON: SockString;
  lOccasion: TSQLOccasion;
  lResult: SockString;
  lURI: SockString;
  lID: string;
begin // only execute writes in current implementation
  Result := -1;
  if IsTableFromService then
    DatabaseError('Cannot apply updates from a service');
  // build the RESTful URL
  if fURI.Https then
    lURI := FormatUTF8('https://%:%/%/%/',
              [fURI.Server, fURI.Port, fSQLModel.Root, StringToUTF8(PSGetTableName)])
  else
    lURI := FormatUTF8('http://%:%/%/%/' ,
              [fURI.Server, fURI.Port, fSQLModel.Root, StringToUTF8(PSGetTableName)]);
  lOccasion := GetSQLOccasion(aSQL);
  case lOccasion of
    soDelete:
    begin
      lID := aParams[0].Value;
      lURI := lURI + lID;
      lResult := TWinHTTP.Delete(lURI, '');
      if (lResult = '') then
        Result := 1;
    end;
    soInsert:
    begin
      lJSON := SQLFieldsToJSON(soInsert, aSQL, '(', ') ', aParams);
      try
        lJSON := Compute(lJSON, soInsert);
      except
        Result := -1;
        lResult := Exception(ExceptObject).Message;
      end;
      lResult := TWinHTTP.Post(lURI, lJSON);
      if (lResult = '') then
        Result := 1;
    end;
    soUpdate:
    begin
      lJSON := SQLFieldsToJSON(soUpdate, aSQL, 'set ', 'where ', aParams);
      try
        lJSON := Compute(lJSON, soUpdate);
      except
        Result := -1;
        lResult := Exception(ExceptObject).Message;
      end;
      lID := aParams.ParamByName('ID').AsString;
      lURI := lURI + lID;
      lResult := TWinHTTP.Put(lURI, lJSON);
      if (lResult = '') then
        Result := 1;
    end
  end;
  if (Result = -1) and (lResult <> '') then
    DatabaseError(lResult);
end;

function TSynRestSQLDataSet.PSGetTableName: string;
begin
  Result := fTableName;
end;

function TSynRestSQLDataSet.PSIsSQLBased: Boolean;
begin
  result := true;
end;

function TSynRestSQLDataSet.PSIsSQLSupported: Boolean;
begin
  result := true;
end;

procedure TSynRestSQLDataSet.PSSetCommandText(const ACommandText: string);
begin
  if (fCommandText <> ACommandText) then
    SetCommandText(ACommandText);
end;

function TSynRestSQLDataSet.PSUpdateRecord(UpdateKind: TUpdateKind;
  Delta: TDataSet): Boolean;
begin
  result := false;
end;

procedure TSynRestSQLDataSet.SetCommandText(const Value: string);
begin
  if (Value <> fCommandtext) then
  begin
    fCommandText := Value;
    ParseCommandText;
  end;
end;

{$endif FPC}

end.

