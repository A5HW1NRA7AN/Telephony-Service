# Setup Guide: Jenkins CI/CD and Helm Deployment

This guide outlines the steps required to configure your Jenkins pipeline and deploy the telephony application stack to your Kubernetes cluster using Helm.

---

## 1. Configure Jenkins Credentials

To run the pipeline defined in the `Jenkinsfile`, you must add the following credentials to your Jenkins server under **Dashboard > Manage Jenkins > Credentials > System > Global credentials**:

### AWS Credentials
* **Kind**: AWS Credentials (requires the *Pipeline: AWS Steps* or *AWS Credentials* plugin) or Username with Password.
* **ID**: `aws-credentials`
* **Access Key ID**: The AWS Access Key ID with permissions to push to ECR.
* **Secret Access Key**: The corresponding AWS Secret Access Key.

### Kubernetes Kubeconfig
* **Kind**: Secret file
* **ID**: `kubeconfig`
* **File**: Upload your Kubernetes config file (retrieved from Kubespray at `inventory/mycluster/artifacts/admin.conf` or from EKS).

---

## 2. Configure ECR Repositories

Ensure that the ECR repositories exist in your AWS account (`ap-northeast-1`). If they do not exist, create them using the AWS CLI:
```bash
aws ecr create-repository --repository-name freeswitch-lead-service --region ap-northeast-1
aws ecr create-repository --repository-name freeswitch-event-publisher --region ap-northeast-1
aws ecr create-repository --repository-name freeswitch-freeswitch --region ap-northeast-1
```

---

## 3. Create Jenkins Pipeline Job

1. Open Jenkins and click **New Item**.
2. Enter a name (e.g., `telephony-pipeline`), select **Pipeline**, and click **OK**.
3. Under the **Build Triggers** section, configure it to poll your Git repository or trigger automatically on webhooks.
4. Under the **Pipeline** section:
   * **Definition**: select *Pipeline script from SCM*.
   * **SCM**: select *Git*.
   * **Repository URL**: `https://github.com/A5HW1NRA7AN/Telephony.git`
   * **Branch Specifier**: `*/freeswitch-kubernetes`
   * **Script Path**: `Jenkinsfile`
5. Save the job.

---

## 4. Manual Deployment via Helm

To deploy or update the stack manually without Jenkins:

1. Ensure your local `kubectl` is connected to the cluster.
2. Run the Helm upgrade command from the root of the repository:
   ```bash
   helm upgrade --install telephony ./infra/helm/telephony \
     --set global.registry="379220350808.dkr.ecr.ap-northeast-1.amazonaws.com" \
     --set leadService.image.tag="latest" \
     --set eventPublisher.image.tag="latest" \
     --set freeswitch.image.tag="latest"
   ```

To deploy in an **on-premise** simulation:
1. Configure your local IP range for load balancing in `infra/helm/telephony/values.yaml` under `metallb.ipRange`.
2. Run:
   ```bash
   helm upgrade --install telephony ./infra/helm/telephony \
     --set global.onPremise=true
   ```
This will configure MetalLB to assign a static IP to the FreeSWITCH load balancer and Kong ingress automatically.
