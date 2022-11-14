page 14180853 deploymentservice
{
    APIGroup = 'deployment';
    APIPublisher = 'aupadhyay';
    APIVersion = 'v2.0';
    EntityCaption = 'deploymentservice';
    EntitySetCaption = 'deploymentservice';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityName = 'deploymentservice';
    EntitySetName = 'deploymentservice';
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = deploymentservice;
    Extensible = false;
    Permissions = TableData deploymentservice = rimd;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(systemId; SystemId)
                {
                    Caption = 'System Id';
                    Editable = false;
                }
                field(publishScope; PublishScope)
                {
                    Caption = 'publishScope';
                }
                field(extensionContent; Content)
                {
                    Caption = 'Content';
                }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Insert();
    end;

    [ServiceEnabled]
    procedure Upload(var ActionContext: WebServiceActionContext)
    var
        ExtensionManagement: Codeunit "Extension Management";
        fileMgmt: Codeunit "File Management";
        FileInStream: InStream;
        filePath: Text;
    begin
        if Content.HasValue() then begin
            Content.CreateInStream(FileInStream);
            filePath := 'C:\Users\Public\Downloads' + CreateGuid() + '.app';
            InstreamExportToServerFile(FileInStream, filePath);
            UploadExtensionToDB(filePath);
            fileMgmt.DeleteServerFile(filePath);
            Delete();
        end else
            Error('Extension content is empty');

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::deploymentservice);
        ActionContext.AddEntityKey(FieldNo(SystemId), SystemId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    local procedure UploadExtensionToDB(var filePath: Text): Text
    var
        runSpace: DotNet Runspace;
        runSpaceFactory: DotNet RunspaceFactory;
        pipeLine: Dotnet Pipeline;
        powershellObject: DotNet PSObject;
        powershellPropertyInfo: DotNet PSPropertyInfo;
        errorMsg: Text;
        serviceName: Text;
        IsServiceRunning: Boolean;
        servicePathName: Text;
    begin

        runSpace := runSpaceFactory.CreateRunspace();
        runSpace.Open();

        pipeLine := runSpace.CreatePipeline();
        pipeLine.Commands.AddScript('Get-WmiObject win32_service | where-object {$_.Name -ilike "*`$' + GetUrl(ClientType::Default).Split('/').Get(4) + '"} | Select-Object Name, State ,PathName');

        foreach powershellObject in pipeLine.Invoke() do
            foreach powershellPropertyInfo in powershellObject.Properties do
                case powershellPropertyInfo.Name.ToString() of
                    'Name':
                        serviceName := powershellPropertyInfo.Value.ToString().Substring(powershellPropertyInfo.Value.ToString().IndexOf('$') + 1);
                    'State':
                        IsServiceRunning := powershellPropertyInfo.Value.ToString().Equals('Running');
                    'PathName':
                        servicePathName := Text.CopyStr(powershellPropertyInfo.Value.ToString(), 1).Remove(powershellPropertyInfo.Value.ToString().IndexOf('Microsoft.Dynamics.Nav.Server.exe')).TrimStart('"');
                end;

        pipeLine.Stop();
        pipeLine.Dispose();

        pipeLine := runSpace.CreatePipeline();
        pipeLine.Commands.AddScript('$PublishScope = "' + Format(rec.publishScope) + '";' +
        '$Tenant = "Default";' +
        '$SkipVerification = $true;' +
        '$ServerInstance = "' + serviceName + '";' +
        '$ServiceFolder = "' + servicePathName + '";' +
        '$PackageData = "' + filePath + '";' +
        'Import-Module "$($ServiceFolder)\Microsoft.Dynamics.Nav.Apps.Management.dll" -Scope Global -Verbose:$false;' +
        '$AppInfo = Get-NAVAppInfo -Path $PackageData -Verbose:$false;' +
        '$PublishedApp = Get-NAVAppInfo -ServerInstance $ServerInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.Version -Verbose:$false -ErrorAction Stop;' +
        'if (($null -eq $PublishedApp) -or (-not $PublishedApp.IsPublished)) {' +
        '    if ($PublishScope.ToUpper() -eq "TENANT") { Publish-NAVApp -ServerInstance $ServerInstance -Path $PackageData -SkipVerification:$SkipVerification -PackageType Extension -Scope $PublishScope -Tenant $Tenant -Verbose:$false -ErrorAction Stop; }' +
        '    else { Publish-NAVApp -ServerInstance $ServerInstance -Path $PackageData -SkipVerification:$SkipVerification -PackageType Extension -Scope $PublishScope -Verbose:$false -ErrorAction Stop; }' +
        '    Sync-NAVApp -ServerInstance $ServerInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.Version -Tenant $Tenant -Verbose:$false -ErrorAction SilentlyContinue ;' +
        '    Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.Version -Tenant $Tenant -Verbose:$false -ErrorAction SilentlyContinue;' +
        '    Install-NAVApp -ServerInstance $ServerInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Version $AppInfo.Version -Tenant $Tenant -Verbose:$false -ErrorAction SilentlyContinue;' +
        '    $OldAppVersions = Get-NAVAppInfo -ServerInstance $ServerInstance -Name $AppInfo.Name -Publisher $AppInfo.Publisher -Verbose:$false -ErrorAction Stop | Where-Object { (-not $_.IsInstalled) -and ($_.Version -ne $AppInfo.Version) } | Sort-Object -Property Version;' +
        '    foreach ($OldAppVersion in $OldAppVersions) { Unpublish-NAVApp -ServerInstance $ServerInstance -Name $OldAppVersion.Name -Publisher $OldAppVersion.Publisher -Version $OldAppVersion.Version -Verbose:$false -ErrorAction SilentlyContinue ; };' +
        '};');

        pipeLine.Invoke();

        errorMsg := pipeLine.Error.Read().ToString();
        pipeLine.Stop();
        pipeLine.Dispose();

        runSpace.Close();
        exit(errorMsg)
    end;

    procedure InstreamExportToServerFile(var InStream: InStream; FilePath: Text)
    var
        OutStream: OutStream;
        OutputFile: File;
        FileMgmt: Codeunit "File Management";
    begin
        if FileMgmt.ServerFileExists(FilePath) then
            FileMgmt.DeleteServerFile(filePath);

        OutputFile.WriteMode(true);
        OutputFile.Create(FilePath);
        OutputFile.CreateOutStream(OutStream);
        CopyStream(OutStream, InStream);
        OutputFile.Close;
    end;

}

dotnet
{
    assembly("System.Management.Automation")
    {
        Culture = 'neutral';
        PublicKeyToken = '31bf3856ad364e35';
        type(System.Management.Automation.Runspaces.Runspace; Runspace) { }
        type(System.Management.Automation.Runspaces.RunspaceFactory; RunspaceFactory) { }
        type(System.Management.Automation.PowerShell; PowerShell) { }
        type(System.Management.Automation.Runspaces.WSManConnectionInfo; WSManConnectionInfo) { }
        type(System.Management.Automation.Runspaces.AuthenticationMechanism; AuthenticationMechanism) { }
        type(System.Management.Automation.Runspaces.Pipeline; Pipeline) { }
        type(System.Management.Automation.Runspaces.Command; Command) { }
        type(System.Management.Automation.PSPropertyInfo; PSPropertyInfo) { }
        type(System.Management.Automation.PSObject; PSObject) { }
    }
    assembly("mscorlib")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type(System.Reflection.Missing; Missing) { }
        type(System.Reflection.Assembly; Assembly) { }
        type(System.AppDomain; AppDomain) { }
        type(System.Security.Principal.WindowsIdentity; WindowsIdentity) { }
    }
    assembly("Microsoft.VisualBasic")
    {
        Culture = 'neutral';
        PublicKeyToken = 'b03f5f7f11d50a3a';
        type(Microsoft.VisualBasic.Strings; Strings) { }
    }
}