# ADOTサンプル

サイト：<https://developer.mamezou-tech.com/containers/k8s/tutorial/ops/jaeger/>

以下を修正してください。

## `overlays/prod/kustomization.yaml`

`images`配下をAWSアカウントを自身の環境のものに修正。

```yaml
images:
  - name: task-service
    newName: <aws-account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/mamezou-tech/task-service
    newTag: 1.0.0
  - name: task-reporter
    newName: <aws-account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/mamezou-tech/task-reporter
    newTag: 1.0.0
  - name: task-web
    newName: <aws-account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/mamezou-tech/task-web
    newTag: 1.0.0
```

## `overlays/prod/lets-encrypt-issuer.template.yaml`

以下を自身のメールアドレスに変更して、ファイル名を`lets-encrypt-issuer.yaml`にリネーム。

```yaml
spec:
  acme:
    # (省略)
    email: '<your-mail-address>'
    # (省略)
```
