codeunit 14180827 deploymentservice_install
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        WebServiceAggregate: Record "Web Service Aggregate";
    begin
        if not WebServiceAggregate.Get(ObjectType::Page, 'deploymentservice') then begin
            WebServiceAggregate.Init();
            WebServiceAggregate.Validate("Object Type", WebServiceAggregate."Object Type"::Page);
            WebServiceAggregate.Validate("Object ID", Page::deploymentservice);
            WebServiceAggregate.Validate("Service Name", 'deploymentservice');
            WebServiceAggregate.Validate(Published, true);
            WebServiceAggregate.Validate(ExcludeFieldsOutsideRepeater, false);
            WebServiceAggregate.Validate(ExcludeNonEditableFlowFields, false);
            WebServiceAggregate.Validate("All Tenants", true);
            WebServiceAggregate.Insert(true);
        end else begin
            WebServiceAggregate.Validate("Object Type", WebServiceAggregate."Object Type"::Page);
            WebServiceAggregate.Validate("Object ID", Page::deploymentservice);
            WebServiceAggregate.Validate("Service Name", 'deploymentservice');
            WebServiceAggregate.Validate(Published, true);
            WebServiceAggregate.Validate(ExcludeFieldsOutsideRepeater, false);
            WebServiceAggregate.Validate(ExcludeNonEditableFlowFields, false);
            WebServiceAggregate.Validate("All Tenants", true);
            WebServiceAggregate.Modify(true);
        end;
    end;
}