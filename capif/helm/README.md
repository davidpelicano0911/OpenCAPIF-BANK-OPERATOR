# Install CAPIF in Kubernetes using HELM

## Dependencies

- [Helm](https://helm.sh/)
- `Ingress` controller already installed in the cluster (if enabled in CAPIF's `values.yaml`)
  - **To install NGINX Ingress controller (if not present):**
    ```sh
    # OPTIONAL - if not exists Ingress in cluster, use this command to install it
    helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --set rbac.create=true --set controller.service.type=NodePort

    # OPTIONAL - if you need specify the nodePort in cluster use
    helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --set rbac.create=true --set controller.service.type=NodePort --set controller.service.nodePorts.http=32080 --set controller.service.nodePorts.https=32443 --namespace ingress-nginx --create-namespace --set controller.extraArgs."enable-ssl-passthrough=true" --kubeconfig ../oneke-new.kubeconfig 

    # Check if ssl-passthrough is enabled in nginx controller.
    kubectl -n ingress-nginx get deploy -o yaml | grep passthrough
    ```
- `PersistentVolumeClaim` already created in the cluster (if enabled in CAPIF)

## Considerations Before Installation

- **Prometheus**:
    - You can install Prometheus, but you will need permissions to deploy it in the cluster. The Helm chart creates a ClusterRole to access all resources.
    - If you lack permissions or Prometheus is already provided, set `monitoring.prometheus.enable: ""` in `capif/values.yaml`.
    - Grafana will need the Prometheus endpoint. Make sure to configure the relevant field in `capif/values.yaml`.

- **Vault**:
  - An instance of Vault must be deployed. If not available, follow the [Vault installation steps](./README-vault.md).
  - After Vault is available, create the PKI and certificates as described in the [Vault job step](./README-vault.md#creating-vault-pki-and-certificates).
    - Set `parametersVault.env.VaultHostname` to the Vault endpoint (can be a Kubernetes service or ingress).
    - Set `parametersVault.env.VaultPort` to the Vault port.
    - Set `parametersVault.env.vaultAccessToken` to a token with permissions to create PKI and certificates. Use the token from the [Vault README](./README-vault.md#creating-vault-pki-and-certificates) or obtain one from the cluster admin.

- **CAPIF**:
    - Review and configure the [`values.yaml`](capif/values.yaml) file according to your environment.

      ```sh
      # Download dependencies 
      helm dependency build capif/

      # Check ingress IP
      kubectl get svc -A | grep nginx

      # Install CAPIF
      helm upgrade --install -n mon monitoring-capif capif/ --set nginx.nginx.env.capifHostname=mon-capif.monitoring.int --set ingress_ip.oneke="10.17.173.127" --atomic --create-namespace
      ```

> **Note:** Deployment may take up to 8 minutes to be ready. If it fails, try reinstalling CAPIF.

## Troubleshooting

- [MongoDB pod fails to start (Exit code 14 or 100)](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/20.0.x?topic=troubleshooting-mongodb-pod-fails-start-container-exit-code-14-100)