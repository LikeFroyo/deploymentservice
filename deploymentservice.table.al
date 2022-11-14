table 14180814 deploymentservice
{
    fields
    {
        field(1; Id; Integer)
        {
            Caption = 'Id';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(2; publishScope; Option)
        {
            Caption = 'publishScope';
            OptionMembers = "Global","Tenant";
            DataClassification = SystemMetadata;
        }
        field(20; Content; Blob)
        {
            Caption = 'Content';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(Key1; Id)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}