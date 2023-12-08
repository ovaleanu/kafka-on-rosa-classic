# ROSA STS cluster provison

This example shows how to create an STS _ROSA_ cluster, operator IAM roles and OIDC provider.
_ROSA_ stands for Red Hat Openshift Service on AWS
and is a cluster that is created in the AWS cloud infrastructure.

To run it:

Provide OCM Authentication Token that you can get from [here](https://console.redhat.com/openshift/token)

```bash
export TF_VAR_token=...
```

then run 

```bash
terraform init
terraform apply --auto-approved
```

ROSA cluster Admin user: cluster-admin

Get cluster-admin user password: `aws secretsmanager get-secret-value --secret-id <output.rosa_admin_password_secret_name> --region $AWS_REGION --query "SecretString" --output text`
