# EKS deployment notes

This guide describes the EKS-specific Kustomize overlay. The existing `k8s/base` and Kind configuration remain unchanged.

## Prerequisites

Before applying the application overlay, the EKS platform must have:

- The Amazon EBS CSI driver add-on installed with its IAM permissions configured.
- A managed node group with nodes in at least two Availability Zones.
- The AWS Load Balancer Controller installed and configured with subnet discovery.
- Public ALB subnets tagged with `kubernetes.io/role/elb=1`.
- The `todo-app` Namespace and `ebs-gp3` StorageClass created by Terraform or a cluster administrator. These are cluster-scoped resources and are intentionally excluded from the application overlay so the namespace-scoped GitHub deployer does not need cluster-wide permissions.

The `ebs-gp3` StorageClass provisions encrypted gp3 EBS volumes using the EBS CSI driver. EBS volumes are AZ-scoped; MongoDB is intentionally a single-replica learning setup and is not multi-AZ database HA.

## Create application credentials

Do not commit real credentials or a populated Kubernetes Secret manifest. A cluster administrator creates the namespace and StorageClass once; the deployment role only manages namespaced application resources. Create the namespace and StorageClass, then the application Secret:

```powershell
kubectl apply -f k8s/overlays/eks/namespace.yaml
kubectl apply -f k8s/overlays/eks/storageclass.yaml

$MongoUser = "todo_admin"
$SecurePassword = Read-Host "Enter a strong MongoDB password" -AsSecureString
$MongoPasswordPlain = [System.Net.NetworkCredential]::new("", $SecurePassword).Password
$EncodedPassword = [System.Uri]::EscapeDataString($MongoPasswordPlain)
$MongoUri = "mongodb://" + $MongoUser + ":" + $EncodedPassword + "@mongodb-0.mongodb.todo-app.svc.cluster.local:27017/tododb?authSource=admin"

kubectl create secret generic todo-app-secret --namespace todo-app --from-literal="mongo-uri=$MongoUri" --from-literal="mongo-root-username=$MongoUser" --from-literal="mongo-root-password=$MongoPasswordPlain" --dry-run=client -o yaml | kubectl apply -f -

Remove-Variable SecurePassword, MongoPasswordPlain, EncodedPassword, MongoUri
```

The connection string URL-encodes the password so reserved URI characters do not break MongoDB authentication. For a long-lived production deployment, use AWS Secrets Manager with an external-secrets integration rather than manually creating a Kubernetes Secret.

## Render and apply

The overlay currently pins the latest verified `main` image SHA: `sha-4756af9d308930cd862f7d7341516f5fe77295c2`.

For a later release, update both image tags using the same immutable commit SHA before applying. Do not deploy `latest`.

Render locally:

```powershell
kubectl kustomize k8s/overlays/eks
```

Apply only after the prerequisites and Secret exist:

```powershell
kubectl apply -k k8s/overlays/eks
kubectl rollout status deployment/backend -n todo-app --timeout=5m
kubectl rollout status deployment/frontend -n todo-app --timeout=5m
kubectl get pods,pvc,ingress -n todo-app -o wide
```

## Availability and cost notes

- Frontend and backend each run two replicas and use topology spread constraints across zones and nodes.
- PodDisruptionBudgets keep at least one replica available during voluntary disruptions. They do not guarantee capacity during an AZ outage.
- MongoDB has one replica and one EBS gp3 PVC. This is a database single point of failure; protect it with tested backups.
- The frontend Service is ClusterIP. The ALB routes to pod IPs through the AWS Load Balancer Controller.
- The Ingress currently configures HTTP. Add an ACM certificate and HTTPS listener before exposing a production workload.
- The StorageClass uses reclaim policy `Delete`; deleting the PVC can delete its EBS volume. Back up data before destructive changes.

## Image release updates

Use immutable image tags of the form `sha-<40-character-git-commit>`. Keep frontend and backend on the same release SHA and never deploy the mutable `latest` tag.
