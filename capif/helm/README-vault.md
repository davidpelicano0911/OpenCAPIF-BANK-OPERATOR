# Install Vault

Add the HashiCorp Helm repository and install Vault in the `mon` namespace:

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install vault hashicorp/vault -n mon --set server.standalone.enabled=true --create-namespace
```

## Using an Ingress Controller

If you are using an ingress controller, install Vault with:

```bash
helm upgrade --install vault hashicorp/vault -n mon \
  --set server.ingress.enabled=true \
  --set server.ingress.hosts[0].host="vault.mon.int" \
  --set server.ingress.ingressClassName=nginx \
  --set server.standalone.enabled=true \
  --create-namespace
```

## Verify Vault Pods

Check that Vault pods are running:

```bash
kubectl -n mon get pods
```

---

## Using Traefik IngressRoute

If you are using **IngressRoute** (Traefik), create a file named `ingress-route.yaml` with the following content:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: vault-ingress-route
  namespace: mon
spec:
  entryPoints: [web]
  routes:
    - kind: Rule
      match: Host(`vault.mon.int`)
      services:
        - kind: Service
          name: vault-internal
          port: 8200
          scheme: http
```
See more information [here](https://doc.traefik.io/traefik/getting-started/quick-start-with-kubernetes/).

Apply the ingress route:

```bash
kubectl apply -f ingress-route.yaml
```

---

# Creating Vault PKI and Certificates

## Considerations

If you change default values in `capi/values.yaml`, review the following:

- You must create PKI and certificates. The `VAULT_TOKEN` provided must have sufficient permissions in Vault.
- Modify these variables as needed:
  - `namespace` in `vault-job/vault-job.yaml` (default: `mon`, should match your deployment namespace)
  - `export VAULT_ADDR` (default: `http://vault-internal:8200`)
  - `export VAULT_TOKEN` (default: `dev-only-token`)
  - `DOMAIN1` for generating CSRs for Capif (example: `DOMAIN1=capif.mobile.cloud`)

Apply the Vault job manifests:

```bash
kubectl apply -f vault-job/
```
